"""SuiText: the type styles (SuiTheme.textStyles, generated from gen_tokens.TEXT_STYLES)
as a component: sizes, weights, tracking, caps, colour roles, leading, headings."""

from __future__ import annotations

import gen_tokens
import pytest
from conftest import create, find, set_theme, window_scene
from test_tokens import plain
from PySide6.QtGui import QAccessible, QColor, QFont

STYLES = {name: dict(zip(gen_tokens.TEXT_STYLE_KEYS, style, strict=True)) for name, *style in gen_tokens.TEXT_STYLES}
WEIGHTS = {"fontWeightNormal": QFont.Weight.Normal, "fontWeightStrong": QFont.Weight.DemiBold,
           "fontWeightBold": QFont.Weight.Bold}


def test_theme_carries_the_generator_styles(theme):
    styles = plain(theme.property("textStyles"))
    assert plain(theme.property("textVariants")) == [s[0] for s in gen_tokens.TEXT_STYLES]
    assert set(styles) == set(STYLES)
    for name, spec in STYLES.items():
        got = styles[name]
        assert got["size"] == theme.property(spec["size"]), name
        assert got["weight"] == theme.property(spec["weight"]), name
        for key in ("tracking", "caps", "leading", "tone", "heading", "mono"):
            expected = pytest.approx(spec[key]) if isinstance(spec[key], float) else spec[key]
            assert got[key] == expected, (name, key)


def test_the_web_mapping_and_the_scale_order():
    """title/heading/subheading/section are the web's h1/h2/h3/h4-h6; label and caption its Label and
    Description (components.css: 20/16/14/13 px, 12 px). Headings shrink down the list."""
    sizes = {n: s["size"] for n, s in STYLES.items()}
    assert (sizes["title"], sizes["heading"], sizes["subheading"], sizes["section"]) == (
        "fontSize2xl", "fontSizeLg", "fontSizeBase", "fontSizeMd")
    assert sizes["label"] == sizes["caption"] == "fontSizeSm"
    assert STYLES["section"]["caps"] and STYLES["label"]["caps"]
    assert [n for n, s in STYLES.items() if s["heading"]] == ["display", "title", "heading", "subheading", "section"]


@pytest.mark.parametrize("variant", [s[0] for s in gen_tokens.TEXT_STYLES])
def test_each_variant_takes_its_style(engine, qtbot, theme, variant):
    window = window_scene(engine, qtbot, f'SuiText {{ objectName: "t"; text: "Take 3"; variant: "{variant}" }}')
    text = find(window, "t")
    spec = STYLES[variant]
    font = text.property("font")
    size = theme.property(spec["size"])
    assert font.pixelSize() == size
    assert font.weight() == WEIGHTS[spec["weight"]]
    assert font.letterSpacing() == pytest.approx(spec["tracking"] * size, abs=1 / 64)  # QFont: 1/64 px steps
    assert font.capitalization() == (QFont.Capitalization.AllUppercase if spec["caps"]
                                     else QFont.Capitalization.MixedCase)
    if spec["mono"]:
        assert font.family() == theme.property("monoFamily")
    role = {"strong": "textStrong", "muted": "muted", "default": "text"}[spec["tone"]]
    assert QColor(text.property("color")) == QColor(theme.property(role))
    iface = QAccessible.queryAccessibleInterface(text)
    assert iface.role() == (QAccessible.Role.Heading if spec["heading"] else QAccessible.Role.StaticText)
    assert iface.text(QAccessible.Text.Name) == "Take 3"  # caps are drawn, the name keeps the text
    window.close()


@pytest.mark.parametrize(
    ("tone", "role"),
    [("default", "text"), ("strong", "textStrong"), ("muted", "muted"), ("accent", "accent"),
     ("info", "toneBlueText"), ("ok", "toneGreenText"), ("warn", "toneYellowText"), ("danger", "toneRedText"),
     ("bucket2", "bucket2Text"), (5, "bucket5Text")],
)
def test_tone_overrides_the_variant_colour(engine, qtbot, theme, tone, role):
    value = f'"{tone}"' if isinstance(tone, str) else tone
    window = window_scene(engine, qtbot, f'SuiText {{ objectName: "t"; text: "x"; variant: "label"; tone: {value} }}')
    for mode in ("light", "dark"):
        set_theme(engine, mode)
        assert QColor(find(window, "t").property("color")) == QColor(theme.property(role)), mode
    window.close()


def test_unknown_variant_is_body(engine, theme):
    obj = create(engine, 'import QtQuick\nimport Scshafe.Ui\nSuiText { text: "x"; variant: "jumbo" }')
    assert obj.property("font").pixelSize() == theme.property("fontSizeMd")
    assert plain(obj.property("style"))["tone"] == "default"


def test_leading_applies_to_wrapped_text(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { SuiText { objectName: "one"; text: "Take 3"; variant: "caption" }\n'
        ' SuiText { objectName: "wrapped"; width: 90; wrapMode: Text.Wrap; variant: "caption";'
        ' text: "Recorded at 48 kHz on the desk microphone, gain 12 dB" } }',
    )
    one, wrapped = find(window, "one"), find(window, "wrapped")
    assert one.property("lineHeight") == 1  # a single line keeps its natural height
    assert wrapped.property("lineCount") >= 3
    assert wrapped.property("lineHeight") == round(12 * 1.5)  # caption: 12 px at CSS line-height 1.5
    assert wrapped.height() == pytest.approx(wrapped.property("lineCount") * 18, abs=1)
    window.close()


def test_tabular_figures(engine):
    obj = create(engine, 'import QtQuick\nimport Scshafe.Ui\nSuiText { text: "-12.4 dB"; tabular: true }')
    assert obj.property("font").featureValue(QFont.Tag("tnum")) == 1


def test_markup_is_shown_literally(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiText { objectName: "t"; text: "<b>bold</b>"; variant: "title" }')
    text = find(window, "t")
    assert text.property("text") == "<b>bold</b>"
    assert text.property("lineCount") == 1
    assert text.property("contentWidth") > 60  # the tags are drawn, not interpreted
    window.close()
