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
