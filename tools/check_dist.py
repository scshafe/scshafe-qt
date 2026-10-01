#!/usr/bin/env python3
"""Check the built distributions in dist/: the wheel carries the QML module, nothing leaks.

    uv build && uv run python tools/check_dist.py [--smoke]

- the wheel contains the package, the module's qmldir, every file qmldir names,
  and every QML file of the source module (src/scshafe_qt/qml/Scshafe/Ui), which
  qmldir must list;
- the wheel's metadata requires PySide6-Essentials;
- the sdist carries the token snapshot and the generator (it can rebuild SuiTheme.qml);
- no file in either archive contains a home path or a token-shaped string
  (the library standard's payload scan, LIB-12a);
- the sdist carries the gallery (examples/), which the tests load;
- --smoke installs the wheel into a throwaway environment (uv run --isolated) and,
  offscreen from the installed copy, builds every public component in one scene
  and opens a dialog.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
MODULE = "scshafe_qt/qml/Scshafe/Ui"
SOURCE_MODULE = ROOT / "src" / MODULE
# Assembled from pieces so this file does not match its own scan.
FORBIDDEN = re.compile(
    b"|".join(
        re.escape(p[0] + p[1])
        for p in [(b"/ho", b"me/"), (b"/Use", b"rs/"), (b"~", b"/"), (b".open", b"claw"),
                  (b".mission-", b"control"), (b"gh", b"p_"), (b"github_", b"pat_"), (b"-----BEG", b"IN")]
    )
)

SMOKE = r"""
import os, sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_BACKEND"] = "software"
from PySide6.QtCore import QMetaObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickWindow
import scshafe_qt
app = QGuiApplication(sys.argv)
engine = QQmlEngine()
path = scshafe_qt.register(engine)
assert "site-packages" in path, path  # the installed copy, not the checkout
comp = QQmlComponent(engine)
comp.setData(SCENE.encode(), "smoke.qml")
window = comp.create()
assert window is not None, [e.toString() for e in comp.errors()]
QMetaObject.invokeMethod(window, "openDialog")
app.processEvents()
built = window.property("built")
print("smoke ok:", path, "registry", window.property("registryVersion"), "components", built)
assert built == EXPECTED, (built, EXPECTED)
"""

# One instance of every public component (qmldir), built from the installed wheel.
SMOKE_SCENE = """
import QtQuick
import Scshafe.Ui
Window {
    width: 900; height: 600; visible: true; color: SuiTheme.bg
    property string registryVersion: SuiTheme.registryVersion
    property int built: 0
    function openDialog() { dialog.open() }
    SuiAppShell {
        anchors.fill: parent
        Component.onCompleted: built++
        sidebar: SuiSidebarList { model: [{ text: "Unsorted", count: 1, status: "ok" }]; Component.onCompleted: built++ }
        content: Column {
            SuiButton { text: "Go"; Component.onCompleted: built++ }
            SuiIconButton { label: "Close"; icon.name: "close"; Component.onCompleted: built++ }
            SuiTextField { label: "Note"; Component.onCompleted: built++ }
            SuiSearchField { Component.onCompleted: built++ }
            SuiChip { text: "Receipts"; tone: "bucket1"; Component.onCompleted: built++ }
            SuiBadge { count: 3; Component.onCompleted: built++ }
            SuiKbd { text: "K"; Component.onCompleted: built++ }
            SuiIcon { name: "inbox"; Component.onCompleted: built++ }
            SuiSidebarItem { text: "Item"; Component.onCompleted: built++ }
            SuiList { width: 200; height: 60; model: 1
                delegate: SuiListRow { title: "Ada"; Component.onCompleted: built++ }
                Component.onCompleted: built++ }
            SuiEmptyState { title: "Empty"; Component.onCompleted: built++ }
            SuiBanner { text: "Note"; Component.onCompleted: built++ }
            SuiToast { text: "Saved"; timeout: 0; Component.onCompleted: built++ }
        }
        inspector: SuiTrail { steps: [{ title: "Rules", outcome: "no match" }]; Component.onCompleted: built++ }
    }
    SuiToastHost { anchors.fill: parent; Component.onCompleted: { built++; show("ok") } }
    SuiDialog { id: dialog; title: "Dialog"; Component.onCompleted: built++ }
    SuiSheet { title: "Sheet"; Component.onCompleted: built++ }
    SuiShortcutOverlay { shortcuts: [{ keys: ["?"], description: "Help" }]; Component.onCompleted: built++ }
}
"""
SMOKE_COMPONENTS = 21  # public components in qmldir, each built once above


def one(pattern: str) -> Path:
    found = sorted(DIST.glob(pattern))
    if len(found) != 1:
        sys.exit(f"error: expected one {pattern} in dist/, found {[p.name for p in found]}")
    return found[0]


def scan(name: str, data: bytes, problems: list[str]) -> None:
    if m := FORBIDDEN.search(data):
        problems.append(f"{name}: forbidden string {m.group().decode(errors='replace')!r}")


def check_wheel(wheel: Path, problems: list[str]) -> list[str]:
    with zipfile.ZipFile(wheel) as zf:
        names = zf.namelist()
        for n in names:
            scan(f"{wheel.name}:{n}", zf.read(n), problems)
        qmldir_name = f"{MODULE}/qmldir"
        if qmldir_name not in names:
            problems.append(f"{wheel.name}: no {qmldir_name}")
            return names
        qmldir = zf.read(qmldir_name).decode().splitlines()
        if qmldir[:1] != ["module Scshafe.Ui"]:
            problems.append(f"{wheel.name}: qmldir does not declare module Scshafe.Ui")
        for line in qmldir[1:]:
            target = f"{MODULE}/{line.split()[-1]}"
            if target not in names:
                problems.append(f"{wheel.name}: qmldir names {target}, missing")
        listed = {line.split()[-1] for line in qmldir[1:] if line.strip()}
        source = sorted(p.name for p in SOURCE_MODULE.glob("*.qml"))
        for name in source:
            if f"{MODULE}/{name}" not in names:
                problems.append(f"{wheel.name}: missing {MODULE}/{name} (in the source module)")
            if name not in listed:
                problems.append(f"qmldir does not list {name}")
        public = [line.split()[0] for line in qmldir[1:] if line.strip() and line.split()[0] not in ("singleton", "internal")]
        if len(public) != SMOKE_COMPONENTS:
            problems.append(f"qmldir has {len(public)} public components, the smoke scene builds {SMOKE_COMPONENTS}")
        if "scshafe_qt/__init__.py" not in names:
            problems.append(f"{wheel.name}: missing scshafe_qt/__init__.py")
        meta = next((n for n in names if n.endswith(".dist-info/METADATA")), None)
        if meta is None or b"requires-dist: pyside6-essentials" not in zf.read(meta).lower():
            problems.append(f"{wheel.name}: METADATA does not require PySide6-Essentials")
    return names


def check_sdist(sdist: Path, problems: list[str]) -> None:
    with tarfile.open(sdist) as tf:
        members = [m for m in tf.getmembers() if m.isfile()]
        names = {m.name.split("/", 1)[1] for m in members}
        for m in members:
            scan(f"{sdist.name}:{m.name}", tf.extractfile(m).read(), problems)
    for required in ("tokens/sui-tokens.json", "tools/gen_tokens.py", f"src/{MODULE}/qmldir", "pyproject.toml",
                     "examples/gallery.py", "examples/gallery.qml"):
        if required not in names:
            problems.append(f"{sdist.name}: missing {required}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--smoke", action="store_true", help="install the wheel in a throwaway env and load the module")
    args = ap.parse_args()
    problems: list[str] = []
    wheel, sdist = one("scshafe_qt-*.whl"), one("scshafe_qt-*.tar.gz")
    names = check_wheel(wheel, problems)
    check_sdist(sdist, problems)
    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        return 1
    qml = sorted(n for n in names if n.startswith(MODULE))
    print(f"ok: {wheel.name} ({len(names)} files) carries {len(qml)} QML module files: "
          + ", ".join(n.rsplit("/", 1)[1] for n in qml))
    print(f"ok: {sdist.name} carries the snapshot and the generator; payload scan clean")
    if args.smoke:
        subprocess.run(
            ["uv", "run", "--isolated", "--no-project", "--with", str(wheel), "python", "-c",
             f"SCENE = {SMOKE_SCENE!r}\nEXPECTED = {SMOKE_COMPONENTS}\n" + SMOKE],
            check=True,
            cwd=DIST,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
