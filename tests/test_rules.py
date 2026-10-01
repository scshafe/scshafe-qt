"""Module-wide rules (the native counterparts of @scshafe/ui's stylesheet tests):

- components carry no colour literals: every colour comes from SuiTheme, so both
  themes apply (only SuiTheme.qml, generated, holds literals);
- every animation runs on SuiTheme.duration, so reduced motion stops them all
  (checked statically and at runtime over the gallery);
- every QML file in the module is listed in qmldir.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
import scshafe_qt
from conftest import ROOT, track
from PySide6.QtCore import QMetaObject, QObject
from PySide6.QtGui import QColor

MODULE = Path(scshafe_qt.qml_import_path()) / "Scshafe" / "Ui"
GENERATED = {"SuiTheme.qml"}
COMPONENTS = sorted(p for p in MODULE.glob("*.qml") if p.name not in GENERATED)
CHECKED = [*COMPONENTS, ROOT / "examples" / "gallery.qml"]

ANIMATIONS = re.compile(r"\b(\w*Animation)\s*\{")
COLOUR_FUNCTIONS = re.compile(r"\bQt\.(rgba|hsla|hsva|hsl|hsv|color|lighter|darker|tint)\s*\(")
HEX = re.compile(r"[\"']#[0-9a-fA-F]{3,8}[\"']")
STRING = re.compile(r"\"([^\"\\]*)\"|'([^'\\]*)'")
# Named colours QColor accepts, except "transparent" (allowed: it is not a colour choice).
NAMED = {n.lower() for n in QColor.colorNames()} - {"transparent"}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return "\n".join(re.sub(r"(^|\s)//.*$", "", line) for line in text.splitlines())


def block(text: str, start: int) -> str:
    """The `{ ... }` block opening at or after `start`."""
    i = text.index("{", start)
    depth = 0
    for j in range(i, len(text)):
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return text[i : j + 1]
    raise AssertionError("unbalanced braces")


def test_module_has_the_q1_components():
    names = {p.stem for p in COMPONENTS}
    assert {
        "SuiAppShell", "SuiSidebarList", "SuiSidebarItem", "SuiList", "SuiListRow", "SuiChip", "SuiBadge",
        "SuiIconButton", "SuiTextField", "SuiSearchField", "SuiEmptyState", "SuiBanner", "SuiToast",
        "SuiToastHost", "SuiDialog", "SuiSheet", "SuiTrail", "SuiShortcutOverlay", "SuiButton",
    } <= names


def test_every_qml_file_is_in_qmldir():
    lines = (MODULE / "qmldir").read_text().splitlines()
    listed = {line.split()[-1] for line in lines[1:] if line.strip()}
    assert listed == {p.name for p in MODULE.glob("*.qml")}
    for line in lines[1:]:
        if line.startswith("internal"):
            assert line.split()[1] in {"SuiFocusRing", "SuiSplitHandle"}, line


@pytest.mark.parametrize("path", CHECKED, ids=lambda p: p.name)
def test_no_colour_literals(path):
    text = strip_comments(path.read_text())
    offenders = [m.group() for m in HEX.finditer(text)]
    offenders += [m.group() for m in COLOUR_FUNCTIONS.finditer(text)]
    for m in STRING.finditer(text):
        value = (m.group(1) if m.group(1) is not None else m.group(2)).strip().lower()
        if value in NAMED:
            offenders.append(m.group())
    assert offenders == [], f"{path.name}: colours must come from SuiTheme"


@pytest.mark.parametrize("path", CHECKED, ids=lambda p: p.name)
def test_every_animation_runs_on_the_theme_duration(path):
    text = strip_comments(path.read_text())
    offenders = []
    for m in ANIMATIONS.finditer(text):
        kind, body = m.group(1), block(text, m.start())
        if kind in {"SmoothedAnimation", "SpringAnimation"}:
            offenders.append(f"{kind}: velocity-based, ignores SuiTheme.duration")
        elif not re.search(r"\bduration:\s*SuiTheme\.duration\b", body):
            offenders.append(f"{kind} {body[:60]!r}")
    for m in re.finditer(r"\b(duration|interval)\s*:\s*([^\n;}]+)", text):
        if m.group(1) == "duration" and "SuiTheme.duration" not in m.group(2):
            offenders.append(m.group())
    assert offenders == [], f"{path.name}: every animation must use SuiTheme.duration"


def test_rules_catch_offenders(tmp_path):
    bad = tmp_path / "Bad.qml"
    bad.write_text(
        'Rectangle { color: "#ff0000"; border.color: "white"; property color c: Qt.rgba(1, 0, 0, 1)\n'
        "  // a comment with #123456 is fine\n"
        "  Behavior on x { NumberAnimation { duration: 200 } } }\n"
    )
    with pytest.raises(AssertionError):
        test_no_colour_literals(bad)
    with pytest.raises(AssertionError):
        test_every_animation_runs_on_the_theme_duration(bad)


# ---- reduced motion at runtime ------------------------------------------------


def walk_objects(window):
    """Every QObject reachable from the window: items (incl. delegates and popup
    content via the overlay) and their QObject children."""
    from shiboken6 import getCppPointer

    seen: dict[int, QObject] = {}

    def add(obj):
        for child in [obj, *obj.findChildren(QObject)]:
            seen.setdefault(getCppPointer(child)[0], child)

    def walk(item):
        add(item)
        for child in item.childItems():
            walk(child)

    add(window)
    walk(window.contentItem())
    return list(seen.values())


def load_gallery(engine, qtbot):
    import sys

    sys.path.insert(0, str(ROOT / "examples"))
    import gallery

    window = track(engine, gallery.load(engine, "light", reduced_motion=False))
    qtbot.waitExposed(window)
    # Open the popups once so their transitions and content exist.
    for name in ("openDialog", "openSheet", "openShortcuts"):
        QMetaObject.invokeMethod(window, name)
        qtbot.wait(50)
        QMetaObject.invokeMethod(window, "closeAll")
        qtbot.wait(300)
    return window


def test_reduced_motion_zeroes_every_transition(engine, qtbot):
    """Transitions and standalone animations (popups, toasts, the shell) report duration 0."""
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    window = load_gallery(engine, qtbot)
    anims = [o for o in walk_objects(window)
             if o.inherits("QQuickAbstractAnimation") and o.property("duration") is not None]
    assert len(anims) >= 8, len(anims)
    assert all(a.property("duration") > 0 for a in anims)
    theme.setProperty("reducedMotion", True)
    assert {a.property("duration") for a in anims} == {0}
    theme.setProperty("reducedMotion", False)
    assert all(a.property("duration") > 0 for a in anims)
    window.close()


def test_reduced_motion_makes_every_behavior_instant(engine, qtbot):
    """Behaviors (colour fades, pane collapse): with reduced motion every animated
    property is at its target right after a theme switch; with motion, some are not."""
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    window = load_gallery(engine, qtbot)
    behaviors = [engine.newQObject(o) for o in walk_objects(window) if o.inherits("QQuickBehavior")]
    assert len(behaviors) >= 30, len(behaviors)
    settled = engine.evaluate(
        "(function (b) { const p = b.targetProperty;"
        " return b.targetValue === undefined || String(p.object[p.name]) === String(b.targetValue) })"
    )

    def animating() -> int:
        return sum(1 for b in behaviors if not settled.call([b]).toBool())

    theme.setProperty("mode", "dark")  # motion on: colours fade over SuiTheme.duration
    assert animating() > 5
    qtbot.waitUntil(lambda: animating() == 0, timeout=2000)
    theme.setProperty("reducedMotion", True)
    theme.setProperty("mode", "light")
    assert animating() == 0
    QMetaObject.invokeMethod(window, "closeAll")
    window.close()
