"""SuiProgressBar: determinate progress with an optional cancel."""

from __future__ import annotations

import pytest
from conftest import find, set_theme, spy, visible_rings, window_scene
from PySide6.QtCore import Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest


def bar_scene(engine, qtbot, props: str = ""):
    window = window_scene(engine, qtbot, f'SuiProgressBar {{ objectName: "p"; x: 20; y: 20; width: 300; {props} }}')
    return window, find(window, "p")


def test_fill_follows_the_value_in_its_range(engine, qtbot, theme):
    theme.setProperty("reducedMotion", True)
    window, bar = bar_scene(engine, qtbot, 'label: "Exporting"; from: 0; to: 12; value: 3')
    track, fill = find(window, "track"), find(window, "fill")
    assert bar.property("position") == pytest.approx(0.25)
    assert fill.width() == pytest.approx(track.width() * 0.25)
    bar.setProperty("value", 12)
    assert fill.width() == pytest.approx(track.width())
    bar.setProperty("value", 20)  # clamped to `to`
    assert fill.width() == pytest.approx(track.width())
    window.close()


@pytest.mark.parametrize("reduced", [True, False])
def test_fill_moves_on_the_theme_duration(engine, qtbot, theme, reduced):
    theme.setProperty("reducedMotion", reduced)
    window, bar = bar_scene(engine, qtbot, "value: 0")
    track, fill = find(window, "track"), find(window, "fill")
    bar.setProperty("value", 0.5)
    if reduced:
        assert fill.width() == pytest.approx(track.width() / 2)
    else:
        assert fill.width() < track.width() / 2
        qtbot.waitUntil(lambda: fill.width() == pytest.approx(track.width() / 2), timeout=1000)
    window.close()


def test_value_text_label_and_accessibility(engine, qtbot):
    window, bar = bar_scene(engine, qtbot, 'label: "Transcribing take 3"; value: 0.426')
    assert find(window, "valueText").property("text") == "43 %"
    assert find(window, "label").property("text") == "Transcribing take 3"
    iface = QAccessible.queryAccessibleInterface(bar)
    assert iface.role() == QAccessible.Role.ProgressBar
    assert iface.text(QAccessible.Text.Name) == "Transcribing take 3"
    assert iface.text(QAccessible.Text.Description) == "43 %"
    assert iface.valueInterface().currentValue() == pytest.approx(0.426)
    assert iface.valueInterface().maximumValue() == pytest.approx(1)
    bar.setProperty("valueText", "5 of 12 files")
    assert find(window, "valueText").property("text") == "5 of 12 files"
    assert iface.text(QAccessible.Text.Description) == "5 of 12 files"
    window.close()


def test_bare_bar(engine, qtbot):
    window, bar = bar_scene(engine, qtbot, "showValue: false; value: 0.7")
    assert not find(window, "label").isVisible() and not find(window, "valueText").isVisible()
    assert bar.height() == pytest.approx(find(window, "track").height())
    window.close()


@pytest.mark.parametrize(("tone", "token"), [("accent", "accent"), ("ok", "toneGreen"), ("warn", "toneYellow"),
                                             ("danger", "toneRed")])
def test_tones_colour_the_fill(engine, qtbot, theme, tone, token):
    theme.setProperty("reducedMotion", True)
    window, bar = bar_scene(engine, qtbot, f'value: 0.5; tone: "{tone}"')
    for mode in ("light", "dark"):
        set_theme(engine, mode)
        assert QColor(find(window, "fill").property("color")) == QColor(theme.property(token)), mode
    window.close()


def test_cancel_is_a_named_tab_stop_that_requests_cancel(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { x: 20; y: 20; spacing: 8\n'
        ' SuiProgressBar { objectName: "p"; width: 300; label: "Exporting"; value: 0.4; cancellable: true }\n'
        ' SuiButton { objectName: "after"; text: "After" } }',
    )
    bar, cancel = find(window, "p"), find(window, "cancelButton")
    requested = spy(bar, "cancelRequested()")
    assert QAccessible.queryAccessibleInterface(cancel).text(QAccessible.Text.Name) == "Cancel Exporting"
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert cancel.hasActiveFocus() and len(visible_rings(window.contentItem())) == 1
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert requested.count() == 1
    bar.setProperty("cancellable", False)  # the app stops the task
    assert not cancel.isVisible()
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "after").hasActiveFocus()
    window.close()


def test_no_cancel_no_tab_stop(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { SuiProgressBar { width: 200; value: 0.3 } SuiButton { objectName: "after"; text: "After" } }',
    )
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "after").hasActiveFocus()
    window.close()
