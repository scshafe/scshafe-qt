"""Theme selection (system / light / dark) and reduced motion."""

from __future__ import annotations

import pytest
from conftest import create
from PySide6.QtCore import Qt
from PySide6.QtGui import QColor

LIGHT_TEXT, DARK_TEXT = QColor("#1b2533"), QColor("#eff6ff")


def scheme(value: Qt.ColorScheme) -> int:
    return value.value


def test_default_mode_is_system(theme):
    assert theme.property("mode") == "system"


@pytest.mark.parametrize(
    ("mode", "os_scheme", "dark"),
    [
        ("system", Qt.ColorScheme.Light, False),
        ("system", Qt.ColorScheme.Dark, True),
        ("system", Qt.ColorScheme.Unknown, False),  # no OS preference -> light
        ("light", Qt.ColorScheme.Dark, False),  # explicit override beats the OS
        ("dark", Qt.ColorScheme.Light, True),
        ("bogus", Qt.ColorScheme.Dark, True),  # unknown modes behave as system
    ],
)
def test_mode_and_system_scheme(theme, mode, os_scheme, dark):
    theme.setProperty("systemColorScheme", scheme(os_scheme))
    theme.setProperty("mode", mode)
    assert theme.property("dark") is dark
    assert theme.property("themeName") == ("dark" if dark else "light")
    assert QColor(theme.property("text")) == (DARK_TEXT if dark else LIGHT_TEXT)


def test_system_scheme_is_bound_to_style_hints(qapp, theme):
    # The offscreen platform reports Unknown and ignores setColorScheme, so the
    # binding is checked against whatever the platform reports.
    assert theme.property("systemColorScheme") == scheme(qapp.styleHints().colorScheme())


def test_switching_updates_bindings_live(engine):
    obj = create(
        engine,
        "import QtQuick\nimport Scshafe.Ui\n"
        "Rectangle { color: SuiTheme.bg; property color fg: SuiTheme.text }",
    )
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    theme.setProperty("mode", "light")
    assert QColor(obj.property("color")) == QColor("#f6f8fb")
    theme.setProperty("mode", "dark")
    assert QColor(obj.property("color")) == QColor("#08111f")
    assert QColor(obj.property("fg")) == DARK_TEXT
    theme.setProperty("mode", "system")
    theme.setProperty("systemColorScheme", scheme(Qt.ColorScheme.Light))
    assert QColor(obj.property("fg")) == LIGHT_TEXT


def test_reduced_motion_zeroes_durations(engine):
    obj = create(
        engine,
        "import QtQuick\nimport Scshafe.Ui\n"
        "Item { property alias animDuration: anim.duration; ColorAnimation { id: anim; duration: SuiTheme.duration } }",
    )
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    assert theme.property("duration") == 120
    assert obj.property("animDuration") == 120
    theme.setProperty("reducedMotion", True)
    assert theme.property("duration") == 0
    assert obj.property("animDuration") == 0
    theme.setProperty("reducedMotion", False)
    assert obj.property("animDuration") == 120


def test_spacing_radius_and_type_scale(theme):
    assert [theme.property(n) for n in ("spaceXs", "spaceSm", "spaceMd", "spaceLg", "spaceXl", "space2xl")] == [
        4, 8, 12, 16, 24, 32,
    ]
    assert theme.property("radius") == theme.property("radiusMd") == 8
    sizes = [theme.property(f"fontSize{s}") for s in ("Xs", "Sm", "Md", "Base", "Lg", "Xl", "2xl", "3xl")]
    assert sizes == sorted(sizes) and len(set(sizes)) == len(sizes)
