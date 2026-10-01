"""Token parity: SuiTheme carries every @scshafe/ui registry token, in both themes."""

from __future__ import annotations

import json

import gen_tokens
import pytest
from conftest import ROOT
from gen_tokens import Ref, Rgba, Shadow, parse_value, qml_name
from PySide6.QtGui import QColor

SNAPSHOT = json.loads((ROOT / "tokens" / "sui-tokens.json").read_text())
TOKENS = SNAPSHOT["tokens"]
BY_NAME = {t["name"]: t for t in TOKENS}


def resolve(name: str, theme_name: str):
    """The registry value of `name` in `theme_name`, following var() references."""
    seen = []
    value = parse_value(BY_NAME[name][theme_name])
    while isinstance(value, Ref):
        assert value.name not in seen, f"cycle {seen}"
        seen.append(value.name)
        value = parse_value(BY_NAME[value.name][theme_name])
    return value


def plain(value):
    """A comparable Python value for a QML property (QJSValue objects, QColor)."""
    if hasattr(value, "toVariant"):
        value = value.toVariant()
    if isinstance(value, dict):
        return {k: plain(v) for k, v in value.items()}
    if isinstance(value, QColor):
        return value.name(QColor.NameFormat.HexArgb)
    return value


def assert_color(actual, expected: Rgba, label: str):
    color = QColor(actual)
    assert (color.red(), color.green(), color.blue()) == (expected.r, expected.g, expected.b), label
    assert color.alphaF() == pytest.approx(expected.a, abs=1 / 255), label


def assert_token(theme, token, theme_name):
    label = f"{token['name']} ({theme_name})"
    actual = theme.property(qml_name(token["name"]))
    expected = resolve(token["name"], theme_name)
    if token["name"] == "--sui-duration":
        assert actual == expected[1], label
    elif isinstance(expected, Rgba):
        assert_color(actual, expected, label)
    elif isinstance(expected, Shadow):
        actual = plain(actual)
        assert (actual["offsetX"], actual["offsetY"], actual["blur"], actual["spread"]) == (
            expected.x,
            expected.y,
            expected.blur,
            expected.spread,
        ), label
        assert_color(actual["color"], expected.color, label)
    else:
        kind, value = expected
        assert actual == value, f"{label}: {actual!r} != {value!r} ({kind})"


def test_snapshot_is_the_registry_shape():
    assert SNAPSHOT["source"]["package"] == "@scshafe/ui"
    assert len(TOKENS) >= 42
    assert all(t["name"].startswith("--sui-") for t in TOKENS)
    assert gen_tokens.registry_hash(SNAPSHOT) == SNAPSHOT["registryHash"]


def test_generated_qml_is_current():
    expected = gen_tokens.render_qml(SNAPSHOT)
    assert gen_tokens.THEME_QML.read_text() == expected, "run `uv run python tools/gen_tokens.py`"
    assert gen_tokens.check_qmldir() == []


def test_snapshot_matches_live_registry():
    source = gen_tokens.find_source(None)
    if source is None:
        pytest.skip("no @scshafe/ui checkout or package found (set SCSHAFE_UI_DIR)")
    try:
        live = gen_tokens.read_registry(source)
    except gen_tokens.GenError as exc:
        pytest.skip(f"registry not readable here: {exc}")
    assert live["registryHash"] == SNAPSHOT["registryHash"], "run gen_tokens.py --refresh"
    assert live["source"]["version"] == SNAPSHOT["source"]["version"]


def test_provenance_and_registry_map(theme):
    assert theme.property("registryVersion") == SNAPSHOT["source"]["version"]
    assert theme.property("registryHash") == SNAPSHOT["registryHash"]
    mapping = plain(theme.property("registry"))
    assert mapping == {t["name"]: qml_name(t["name"]) for t in TOKENS}


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_every_token_in_both_themes(theme, theme_name):
    theme.setProperty("mode", theme_name)
    assert theme.property("dark") is (theme_name == "dark")
    missing = [t["name"] for t in TOKENS if theme.property(qml_name(t["name"])) is None]
    assert missing == []
    for token in TOKENS:
        assert_token(theme, token, theme_name)


def test_themed_tokens_differ_between_themes(theme):
    """Guards against a theme switch that silently does nothing."""
    values = {}
    for mode in ("light", "dark"):
        theme.setProperty("mode", mode)
        values[mode] = {t["name"]: plain(theme.property(qml_name(t["name"]))) for t in TOKENS}
    for token in TOKENS:
        if token["light"] != token["dark"]:
            assert values["light"][token["name"]] != values["dark"][token["name"]], token["name"]


@pytest.mark.parametrize(
    ("css", "expected"),
    [
        ("#0a4f99", Rgba(10, 79, 153, 1.0)),
        ("#fff", Rgba(255, 255, 255, 1.0)),
        ("rgba(15, 23, 42, 0.035)", Rgba(15, 23, 42, 0.035)),
        ("var(--sui-blue)", Ref("--sui-blue")),
        ("6px", ("px", 6)),
        ("120ms", ("ms", 120)),
        ("0s", ("ms", 0)),
        ("0 10px 34px rgba(0, 0, 0, 0.22)", Shadow(0, 10, 34, 0, Rgba(0, 0, 0, 0.22))),
        ("ui-monospace, Menlo, monospace", ("string", "ui-monospace, Menlo, monospace")),
    ],
)
def test_css_value_parser(css, expected):
    assert parse_value(css) == expected


def test_qml_names():
    assert qml_name("--sui-text-strong") == "textStrong"
    assert qml_name("--sui-space-2xl") == "space2xl"
    assert qml_name("--sui-tone-green-text") == "toneGreenText"


def test_check_fails_on_a_stale_file(tmp_path, monkeypatch, capsys):
    stale = tmp_path / "SuiTheme.qml"
    stale.write_text(gen_tokens.THEME_QML.read_text().replace("#1b2533", "#000000"))
    monkeypatch.setattr(gen_tokens, "THEME_QML", stale)
    monkeypatch.setenv("SCSHAFE_UI_DIR", str(tmp_path / "absent"))
    monkeypatch.setattr(gen_tokens, "ROOT", tmp_path)  # no sibling ../scshafe-ui either
    assert gen_tokens.main(["--check"]) == 1
    assert "is stale" in capsys.readouterr().err
    assert gen_tokens.main(["--check", "--require-source"]) == 1
    assert "registry source not found" in capsys.readouterr().err


# ---------------------------------------------------------------------------
# Native-only tokens (tools/gen_tokens.py NATIVE-ONLY section)
# ---------------------------------------------------------------------------

TEXT_MIN = 4.5  # WCAG 2.2 1.4.3
UI_MIN = 3.0  # WCAG 2.2 1.4.11 (dots, swatches)
BUCKETS = gen_tokens.NATIVE_BUCKETS
STATUS_TONES = {"info": "blue", "ok": "green", "warn": "yellow", "danger": "red"}


def _channel(v: float) -> float:
    c = v / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance(c: Rgba) -> float:
    return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


def contrast(a: Rgba, b: Rgba) -> float:
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def over(top: Rgba, bottom: Rgba) -> Rgba:
    """Paint a translucent colour over an opaque one (sRGB, as Qt and browsers paint)."""
    assert bottom.a == 1
    mix = lambda t, b: t * top.a + b * (1 - top.a)  # noqa: E731
    return Rgba(mix(top.r, bottom.r), mix(top.g, bottom.g), mix(top.b, bottom.b), 1.0)


def at(c: Rgba, amount: float) -> Rgba:
    return Rgba(c.r, c.g, c.b, c.a * amount)


def oklab(c: Rgba) -> tuple[float, float, float]:
    r, g, b = (_channel(v) for v in (c.r, c.g, c.b))
    lms = (
        0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
        0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
        0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b,
    )
    l_, m_, s_ = (x ** (1 / 3) for x in lms)
    return (
        0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
    )


def by_role(role: str) -> list[str]:
    return [t["name"] for t in TOKENS if t["role"] == role]


def surfaces(theme_name: str) -> list[tuple[str, Rgba]]:
    """Every surface, translucent ones composited over the page and panel backgrounds."""
    bases = [(n, resolve(n, theme_name)) for n in ("--sui-bg", "--sui-panel")]
    out = []
    for name in by_role("surface"):
        value = resolve(name, theme_name)
        if value.a == 1:
            out.append((name, value))
        else:
            out.extend((f"{name} over {bn}", over(value, bv)) for bn, bv in bases)
    return out


def grounds(theme_name: str) -> list[tuple[str, Rgba]]:
    """Where a chip can sit: every surface, and every overlay (selection, hover, tint) on it."""
    base = surfaces(theme_name)
    tinted = [
        (f"{o} on {sn}", over(resolve(o, theme_name), sv)) for o in by_role("overlay") for sn, sv in base
    ]
    return base + tinted


def test_bucket_palette_shape():
    assert len(BUCKETS) == 8
    assert len({b[0] for b in BUCKETS}) == 8
    for name, light, dark in BUCKETS:
        for value in (*light, *dark):
            assert gen_tokens.parse_color(value) is not None, (name, value)


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_native_tokens_in_both_themes(theme, theme_name):
    theme.setProperty("mode", theme_name)
    index = 1 if theme_name == "dark" else 0
    for i, (name, light, dark) in enumerate(BUCKETS, start=1):
        base, text = (light, dark)[index]
        assert_color(theme.property(f"bucket{i}"), gen_tokens.parse_color(base), f"bucket{i} {name}")
        assert_color(theme.property(f"bucket{i}Text"), gen_tokens.parse_color(text), f"bucket{i}Text {name}")
    assert theme.property("bucketCount") == 8
    assert plain(theme.property("bucketNames")) == [b[0] for b in BUCKETS]
    assert theme.property("toneTint") == pytest.approx(gen_tokens.TONE_TINT)
    assert theme.property("toneBorderAmount") == pytest.approx(gen_tokens.TONE_BORDER)


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_bucket_text_contrast_on_its_chip(theme_name):
    """Bucket text reaches 4.5:1 on its chip fill (base at TONE_TINT) over every ground."""
    failures, lowest = [], {}
    index = 1 if theme_name == "dark" else 0
    for name, *values in BUCKETS:
        base, text = (gen_tokens.parse_color(v) for v in values[index])
        ratios = []
        for label, ground in grounds(theme_name):
            ratio = contrast(text, over(at(base, gen_tokens.TONE_TINT), ground))
            ratios.append(ratio)
            if ratio < TEXT_MIN:
                failures.append(f"{theme_name}: {name} text on its chip on {label} = {ratio:.2f}:1")
        lowest[name] = round(min(ratios), 2)
    print(f"{theme_name} bucket text, lowest ratio on any ground:", lowest)
    assert failures == []


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_bucket_base_reaches_3_to_1_on_surfaces(theme_name):
    """The base is a dot / swatch indicator: 3:1 against every surface."""
    index = 1 if theme_name == "dark" else 0
    failures = []
    for name, *values in BUCKETS:
        base = gen_tokens.parse_color(values[index][0])
        for label, ground in surfaces(theme_name):
            if (ratio := contrast(base, ground)) < UI_MIN:
                failures.append(f"{theme_name}: {name} base on {label} = {ratio:.2f}:1")
    assert failures == []


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_bucket_tones_are_distinct(theme_name):
    """Pairwise OKLab distance between bucket bases (and texts) stays clearly visible."""
    index = 1 if theme_name == "dark" else 0
    for part, minimum in ((0, 0.07), (1, 0.05)):
        colours = [(b[0], oklab(gen_tokens.parse_color(b[1 + index][part]))) for b in BUCKETS]
        for i, (na, a) in enumerate(colours):
            for nb, b in colours[i + 1 :]:
                d = sum((x - y) ** 2 for x, y in zip(a, b, strict=True)) ** 0.5
                assert d >= minimum, f"{theme_name}: {na} and {nb} {'text' if part else 'base'} too close ({d:.3f})"


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_status_tone_text_contrast_on_its_chip(theme_name):
    """Status chips (info/ok/warn/danger) reuse the registry tones: 4.5:1 over every ground."""
    failures = []
    for tone, hue in STATUS_TONES.items():
        base = resolve(f"--sui-tone-{hue}", theme_name)
        text = resolve(f"--sui-tone-{hue}-text", theme_name)
        for label, ground in grounds(theme_name):
            if (ratio := contrast(text, over(at(base, gen_tokens.TONE_TINT), ground))) < TEXT_MIN:
                failures.append(f"{theme_name}: {tone} on {label} = {ratio:.2f}:1")
        # Neutral chips: --sui-text on --sui-tint.
    for label, ground in grounds(theme_name):
        fill = over(resolve("--sui-tint", theme_name), ground)
        if (ratio := contrast(resolve("--sui-text", theme_name), fill)) < TEXT_MIN:
            failures.append(f"{theme_name}: neutral on {label} = {ratio:.2f}:1")
    assert failures == []


@pytest.mark.parametrize("theme_name", ["light", "dark"])
def test_tone_helpers_follow_the_theme(engine, theme_name):
    from conftest import create

    obj = create(
        engine,
        "import QtQuick\nimport Scshafe.Ui\nQtObject {\n"
        "  property color b3: SuiTheme.toneBase('bucket3'); property color b3t: SuiTheme.toneText(3)\n"
        "  property color warn: SuiTheme.toneText('warn'); property color neutral: SuiTheme.toneText('neutral')\n"
        "  property color fill: SuiTheme.toneFill('danger'); property color neutralFill: SuiTheme.toneFill('x')\n"
        "  property color held: SuiTheme.statusColor('held'); property color none: SuiTheme.statusColor('none')\n"
        "  property int bad: SuiTheme.bucketNumber('bucket9') }",
    )
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    theme.setProperty("mode", theme_name)
    index = 1 if theme_name == "dark" else 0
    green = BUCKETS[2][1 + index]
    assert_color(obj.property("b3"), gen_tokens.parse_color(green[0]), "toneBase(bucket3)")
    assert_color(obj.property("b3t"), gen_tokens.parse_color(green[1]), "toneText(3)")
    assert_color(obj.property("warn"), resolve("--sui-tone-yellow-text", theme_name), "warn")
    assert_color(obj.property("neutral"), resolve("--sui-text", theme_name), "neutral")
    assert_color(obj.property("fill"), at(resolve("--sui-tone-red", theme_name), gen_tokens.TONE_TINT), "fill")
    assert_color(obj.property("neutralFill"), resolve("--sui-tint", theme_name), "neutral fill")
    assert_color(obj.property("held"), resolve("--sui-tone-yellow", theme_name), "held dot")
    assert QColor(obj.property("none")).alpha() == 0
    assert obj.property("bad") == 0


def test_monospace_family(theme):
    assert theme.property("platformName") in ("linux", "macos", "windows")
    candidates = plain(theme.property("monoCandidates"))
    family = theme.property("monoFamily")
    assert family in candidates or family == gen_tokens.MONO_FALLBACK
