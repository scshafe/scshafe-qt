#!/usr/bin/env python3
"""Generate the Scshafe.Ui theme singleton (SuiTheme.qml) from @scshafe/ui's token registry.

Pipeline (stdlib only; Node is needed only for --refresh):

    @scshafe/ui ./tokens export (lib/tokens.js) or src/tokens.ts
        -- node, --refresh -->  tokens/sui-tokens.json   (committed snapshot)
        -- this script     -->  src/scshafe_qt/qml/Scshafe/Ui/SuiTheme.qml  (committed)

Usage:
    python tools/gen_tokens.py                 # regenerate SuiTheme.qml from the snapshot
    python tools/gen_tokens.py --refresh       # re-read the registry, rewrite snapshot + QML
    python tools/gen_tokens.py --check         # fail if the QML or the snapshot is stale

The registry is located with --from DIR, else $SCSHAFE_UI_DIR, else a sibling
checkout ../scshafe-ui. DIR is either a source checkout of scshafe-ui or an
installed package (node_modules/@scshafe/ui). --check compares the snapshot with
the registry when one is found and says it skipped that comparison otherwise
(GitHub-hosted CI cannot read the private package); --require-source turns the
skip into a failure.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / "tokens" / "sui-tokens.json"
MODULE_DIR = ROOT / "src" / "scshafe_qt" / "qml" / "Scshafe" / "Ui"
THEME_QML = MODULE_DIR / "SuiTheme.qml"
QMLDIR = MODULE_DIR / "qmldir"
SINGLETON_LINE = "singleton SuiTheme 1.0 SuiTheme.qml"
PACKAGE_NAME = "@scshafe/ui"
SNAPSHOT_SCHEMA = 1

# --------------------------------------------------------------------------
# Registry extraction (Node)
# --------------------------------------------------------------------------

_NODE_DUMP = r"""
const { pathToFileURL } = await import("node:url");
const m = await import(pathToFileURL(process.argv[1]).href);
process.stdout.write(JSON.stringify({
  tokens: m.SUI_TOKENS,
  reducedMotionDuration: m.SUI_REDUCED_MOTION_DURATION,
}));
"""

TOKEN_KEYS = ("name", "light", "dark", "themed", "category", "role", "description")


class GenError(Exception):
    pass


def _node_dump(file: Path) -> dict:
    cmd = ["node", "--no-warnings"]
    if file.suffix == ".ts":
        cmd.append("--experimental-strip-types")
    cmd += ["--input-type=module", "-e", _NODE_DUMP, str(file)]
    try:
        out = subprocess.run(cmd, check=True, capture_output=True, text=True)
    except FileNotFoundError as exc:
        raise GenError("node is required to read the registry (--refresh / source check)") from exc
    except subprocess.CalledProcessError as exc:
        raise GenError(f"node could not load {file}:\n{exc.stderr}") from exc
    raw = json.loads(out.stdout)
    tokens = [{key: tok.get(key) for key in TOKEN_KEYS} for tok in raw["tokens"]]
    return {"tokens": tokens, "reducedMotionDuration": raw["reducedMotionDuration"]}


def find_source(explicit: str | None) -> Path | None:
    candidates = [explicit, os.environ.get("SCSHAFE_UI_DIR"), str(ROOT.parent / "scshafe-ui")]
    for cand in candidates:
        if cand and (Path(cand) / "package.json").is_file():
            return Path(cand).resolve()
        if cand == explicit and explicit:
            raise GenError(f"--from {explicit}: no package.json there")
    return None


def read_registry(src: Path) -> dict:
    pkg = json.loads((src / "package.json").read_text())
    if pkg.get("name") != PACKAGE_NAME:
        raise GenError(f"{src} is {pkg.get('name')!r}, not {PACKAGE_NAME}")
    export = pkg.get("exports", {}).get("./tokens", {})
    export_file = export.get("default") if isinstance(export, dict) else export
    files = []
    if export_file and (src / export_file).is_file():
        files.append(src / export_file)
    if (src / "src" / "tokens.ts").is_file():
        files.append(src / "src" / "tokens.ts")
    if not files:
        raise GenError(f"{src}: neither the ./tokens export nor src/tokens.ts exists (build it?)")
    dumps = [_node_dump(f) for f in files]
    if len(dumps) == 2 and dumps[0] != dumps[1]:
        raise GenError(
            f"{files[0]} differs from {files[1]}: the built export is stale; "
            "run `pnpm run build` in scshafe-ui first"
        )
    used = files[0]
    data = dumps[0]
    source = {
        "package": PACKAGE_NAME,
        "version": pkg["version"],
        "file": used.relative_to(src).as_posix(),
        "fileSha256": hashlib.sha256(used.read_bytes()).hexdigest(),
    }
    if (src / ".git").exists():
        try:
            head = subprocess.run(
                ["git", "-C", str(src), "rev-parse", "HEAD"], check=True, capture_output=True, text=True
            ).stdout.strip()
            source["commit"] = head
        except (OSError, subprocess.CalledProcessError):
            pass
    return {
        "schema": SNAPSHOT_SCHEMA,
        "source": source,
        "registryHash": registry_hash(data),
        "reducedMotionDuration": data["reducedMotionDuration"],
        "tokens": data["tokens"],
    }


def registry_hash(data: dict) -> str:
    canonical = {"reducedMotionDuration": data["reducedMotionDuration"], "tokens": data["tokens"]}
    blob = json.dumps(canonical, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return "sha256:" + hashlib.sha256(blob.encode()).hexdigest()


def load_snapshot() -> dict:
    snap = json.loads(SNAPSHOT.read_text())
    if snap.get("schema") != SNAPSHOT_SCHEMA:
        raise GenError(f"{SNAPSHOT}: unknown schema {snap.get('schema')}")
    if registry_hash(snap) != snap["registryHash"]:
        raise GenError(f"{SNAPSHOT}: registryHash does not match its tokens (hand-edited?)")
    return snap


def dump_snapshot(snap: dict) -> str:
    return json.dumps(snap, indent=2, ensure_ascii=False) + "\n"


# --------------------------------------------------------------------------
# CSS value parsing (shared with the tests)
# --------------------------------------------------------------------------

_HEX = re.compile(r"^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$")
_RGBA = re.compile(r"^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$")
_VAR = re.compile(r"^var\((--sui-[a-z0-9-]+)\)$")
_PX = re.compile(r"^(-?[\d.]+)px$")
_TIME = re.compile(r"^([\d.]+)(ms|s)$")
_SHADOW = re.compile(r"^(-?[\d.]+)(?:px)?\s+(-?[\d.]+)(?:px)?\s+([\d.]+)(?:px)?(?:\s+(-?[\d.]+)(?:px)?)?\s+(rgba?\(.*\)|#[0-9a-fA-F]+)$")


@dataclass(frozen=True)
class Rgba:
    r: int
    g: int
    b: int
    a: float


@dataclass(frozen=True)
class Shadow:
    x: float
    y: float
    blur: float
    spread: float
    color: Rgba


@dataclass(frozen=True)
class Ref:
    name: str


def parse_color(value: str) -> Rgba | None:
    value = value.strip()
    if m := _HEX.match(value):
        h = m.group(1)
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        return Rgba(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0)
    if m := _RGBA.match(value):
        a = m.group(4)
        return Rgba(int(m.group(1)), int(m.group(2)), int(m.group(3)), float(a) if a is not None else 1.0)
    return None


def parse_value(value: str):
    """Return Ref | Rgba | Shadow | ("px", n) | ("ms", n) | ("string", s)."""
    value = value.strip()
    if m := _VAR.match(value):
        return Ref(m.group(1))
    if (c := parse_color(value)) is not None:
        return c
    if m := _PX.match(value):
        return ("px", _num(m.group(1)))
    if m := _TIME.match(value):
        n = float(m.group(1)) * (1000 if m.group(2) == "s" else 1)
        return ("ms", _num(str(n)))
    if m := _SHADOW.match(value):
        color = parse_color(m.group(5))
        if color is not None:
            return Shadow(
                float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4) or 0), color
            )
    return ("string", value)


def _num(text: str) -> int | float:
    f = float(text)
    return int(f) if f.is_integer() else f


def qml_name(css_name: str) -> str:
    """--sui-text-strong -> textStrong; --sui-space-2xl -> space2xl."""
    parts = css_name.removeprefix("--sui-").split("-")
    return parts[0] + "".join(p[:1].upper() + p[1:] for p in parts[1:])


# --------------------------------------------------------------------------
# QML rendering
# --------------------------------------------------------------------------


def _fmt_num(n: float) -> str:
    return str(int(n)) if float(n).is_integer() else repr(float(n))


def _qml_color(c: Rgba) -> str:
    if c.a == 1.0:
        return f'"#{c.r:02x}{c.g:02x}{c.b:02x}"'
    return f"Qt.rgba({c.r} / 255, {c.g} / 255, {c.b} / 255, {_fmt_num(c.a)})"


def _qml_type(parsed, by_name: dict, seen=()) -> str:
    if isinstance(parsed, Ref):
        if parsed.name in seen:
            raise GenError(f"reference cycle at {parsed.name}")
        target = by_name[parsed.name]
        return _qml_type(parse_value(target["light"]), by_name, (*seen, parsed.name))
    if isinstance(parsed, Rgba):
        return "color"
    if isinstance(parsed, Shadow):
        return "var"
    kind = parsed[0]
    if kind in ("px", "ms"):
        return "int" if isinstance(parsed[1], int) else "real"
    return "string"


def _qml_expr(parsed, by_name: dict) -> str:
    if isinstance(parsed, Ref):
        if parsed.name not in by_name:
            raise GenError(f"unknown token reference {parsed.name}")
        return f"theme.{qml_name(parsed.name)}"
    if isinstance(parsed, Rgba):
        return _qml_color(parsed)
    if isinstance(parsed, Shadow):
        return (
            f"({{ offsetX: {_fmt_num(parsed.x)}, offsetY: {_fmt_num(parsed.y)}, "
            f"blur: {_fmt_num(parsed.blur)}, spread: {_fmt_num(parsed.spread)}, "
            f"color: {_qml_color(parsed.color)} }})"
        )
    kind, val = parsed
    if kind in ("px", "ms"):
        return _fmt_num(val)
    return json.dumps(val)


_HEADER = """\
// GENERATED by tools/gen_tokens.py from the {package} token registry. Do not edit:
// change the registry in scshafe-ui, then run `uv run python tools/gen_tokens.py --refresh`.
//
// Source:   {package} {version} ({file}, sha256 {file_sha}){commit}
// Registry: {registry_hash} ({count} tokens)
//
// Every registry token is a property here, named in camelCase without the prefix
// (--sui-text-strong -> textStrong). Themed tokens switch with `dark`; lengths are
// logical pixels (CSS px), durations milliseconds, shadows
// {{ offsetX, offsetY, blur, spread, color }}. `registry` maps CSS names to properties.
pragma Singleton
import QtQuick

QtObject {{
    id: theme

    // ---- Theme selection ------------------------------------------------
    // "system" follows the OS colour scheme (Qt.styleHints.colorScheme);
    // "light" and "dark" pin a theme. Any other value behaves as "system".
    property string mode: "system"
    // The OS scheme, bound to Qt.styleHints.colorScheme. Apps leave it alone; tests
    // assign it to simulate the OS (the offscreen platform always reports Unknown).
    property int systemColorScheme: Qt.styleHints.colorScheme
    readonly property bool systemDark: systemColorScheme === Qt.ColorScheme.Dark
    readonly property bool dark: mode === "dark" || (mode !== "light" && systemDark)
    readonly property string themeName: dark ? "dark" : "light"

    // Reduced motion. Qt 6.8 exposes no OS reduced-motion preference (QStyleHints
    // has none, and Qt 6.10's QAccessibilityHints only carries contrastPreference),
    // so the application sets this explicitly; when true every duration is {reduced_ms}.
    property bool reducedMotion: false

    // ---- Provenance -----------------------------------------------------
    readonly property string registryVersion: {version_json}
    readonly property string registryHash: {registry_hash_json}
"""

_NATIVE = """
    // ---- Native extensions (not in the registry) --------------------------
    // Values the web library writes as literals in components.css; kept here so
    // native components share them. Changing one is a scshafe-qt change.
    readonly property int focusRingWidth: 2       // :focus-visible outline width
    readonly property int focusRingOffset: 2      // :focus-visible outline-offset
    readonly property real disabledOpacity: 0.48  // .sui-button:disabled
    readonly property int controlPaddingX: 10     // .sui-button padding
    readonly property int controlPaddingY: 6
    // Type scale (pixel sizes the stylesheets use) and weights.
    readonly property int fontSizeXs: 11
    readonly property int fontSizeSm: 12
    readonly property int fontSizeMd: 13
    readonly property int fontSizeBase: 14
    readonly property int fontSizeLg: 16
    readonly property int fontSizeXl: 18
    readonly property int fontSize2xl: 20
    readonly property int fontSize3xl: 24
    readonly property int fontWeightNormal: Font.Normal
    readonly property int fontWeightStrong: Font.DemiBold  // 600
    readonly property int fontWeightBold: Font.Bold        // 700

    // `color` at `amount` of its opacity: CSS color-mix(in srgb, c N%, transparent).
    function alpha(c, amount) {
        return Qt.rgba(c.r, c.g, c.b, c.a * amount)
    }
}
"""


def render_qml(snap: dict) -> str:
    tokens = snap["tokens"]
    by_name = {t["name"]: t for t in tokens}
    src = snap["source"]
    commit = f", commit {src['commit'][:12]}" if src.get("commit") else ""
    reduced = parse_value(snap["reducedMotionDuration"])
    if not (isinstance(reduced, tuple) and reduced[0] == "ms"):
        raise GenError(f"reducedMotionDuration {snap['reducedMotionDuration']!r} is not a time")
    out = [
        _HEADER.format(
            package=src["package"],
            version=src["version"],
            file=src["file"],
            file_sha=src["fileSha256"][:16],
            commit=commit,
            registry_hash=snap["registryHash"],
            count=len(tokens),
            reduced_ms=_fmt_num(reduced[1]),
            version_json=json.dumps(src["version"]),
            registry_hash_json=json.dumps(snap["registryHash"]),
        )
    ]
    section = None
    for tok in tokens:
        cat = tok["category"]
        if cat != section:
            section = cat
            out.append(f"\n    // ---- {cat} " + "-" * max(4, 66 - len(cat)) + "\n")
        name = qml_name(tok["name"])
        light, dark = parse_value(tok["light"]), parse_value(tok["dark"])
        typ = _qml_type(light, by_name)
        if _qml_type(dark, by_name) != typ:
            raise GenError(f"{tok['name']}: light and dark values have different types")
        lexpr, dexpr = _qml_expr(light, by_name), _qml_expr(dark, by_name)
        if tok["name"] == "--sui-duration":
            expr = f"reducedMotion ? {_fmt_num(reduced[1])} : {lexpr}"
        elif lexpr == dexpr:
            expr = lexpr
        else:
            expr = f"dark ? {dexpr} : {lexpr}"
        out.append(f"    // {tok['name']}: {tok['description']}\n")
        out.append(f"    readonly property {typ} {name}: {expr}\n")
    out.append("\n    // CSS custom property -> property name, for tooling and tests.\n")
    out.append("    readonly property var registry: ({\n")
    out.append(",\n".join(f'        "{t["name"]}": "{qml_name(t["name"])}"' for t in tokens))
    out.append("\n    })\n")
    out.append(_NATIVE)
    return "".join(out)


def _rel(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def check_qmldir() -> list[str]:
    lines = QMLDIR.read_text().splitlines() if QMLDIR.is_file() else []
    if SINGLETON_LINE not in lines:
        return [f"{_rel(QMLDIR)} lacks `{SINGLETON_LINE}`"]
    return []


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="fail if generated files are stale")
    mode.add_argument("--refresh", action="store_true", help="re-read the registry into the snapshot")
    ap.add_argument("--from", dest="source", metavar="DIR", help="scshafe-ui checkout or installed package")
    ap.add_argument("--require-source", action="store_true", help="with --check: fail if no registry is found")
    args = ap.parse_args(argv)

    try:
        if args.refresh:
            src = find_source(args.source)
            if src is None:
                raise GenError("no registry found: pass --from DIR or set SCSHAFE_UI_DIR")
            snap = read_registry(src)
            SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
            SNAPSHOT.write_text(dump_snapshot(snap))
            THEME_QML.write_text(render_qml(snap))
            print(f"refreshed from {src} ({snap['source']['version']}, {len(snap['tokens'])} tokens)")
            for problem in check_qmldir():
                print(f"warning: {problem}", file=sys.stderr)
            return 0

        snap = load_snapshot()
        expected = render_qml(snap)
        if not args.check:
            THEME_QML.write_text(expected)
            print(f"wrote {_rel(THEME_QML)} ({len(snap['tokens'])} tokens)")
            return 0

        problems = check_qmldir()
        if not THEME_QML.is_file() or THEME_QML.read_text() != expected:
            problems.append(f"{_rel(THEME_QML)} is stale: run `uv run python tools/gen_tokens.py`")
        src = find_source(args.source)
        if src is None:
            msg = "registry source not found (no --from, $SCSHAFE_UI_DIR or ../scshafe-ui)"
            if args.require_source:
                problems.append(msg)
            else:
                print(f"note: {msg}; snapshot-vs-registry comparison skipped")
        else:
            live = read_registry(src)
            if live["registryHash"] != snap["registryHash"] or live["source"]["version"] != snap["source"]["version"]:
                problems.append(
                    f"snapshot is stale: {src} is {live['source']['version']} {live['registryHash']}, "
                    f"snapshot has {snap['source']['version']} {snap['registryHash']}: run --refresh"
                )
            else:
                print(f"registry {src} matches the snapshot ({live['source']['version']}, {live['registryHash']})")
        if problems:
            for p in problems:
                print(f"error: {p}", file=sys.stderr)
            return 1
        print(f"ok: SuiTheme.qml is current ({len(snap['tokens'])} tokens, {snap['registryHash']})")
        return 0
    except GenError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
