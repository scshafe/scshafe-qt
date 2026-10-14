"""SuiLevelMeter: live level, zones, peak hold, clip latch, scale and the pinned-level marker."""

from __future__ import annotations

import math

import pytest
from conftest import find, set_theme, spy, visible_rings, window_scene
from PySide6.QtCore import QObject, QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest


def meter_scene(engine, qtbot, props: str = "", width: int = 340):
    window = window_scene(
        engine, qtbot, f'SuiLevelMeter {{ objectName: "m"; x: 20; y: 20; width: {width}; label: "Input level"; {props} }}'
    )
    return window, find(window, "m")


def fill_fraction(window) -> float:
    return find(window, "levelFill").width() / find(window, "bar").width()


@pytest.mark.parametrize(("level", "fraction"), [(-60, 0), (-30, 0.5), (-15, 0.75), (0, 1), (6, 1), (-90, 0),
                                                 (-math.inf, 0)])
def test_fill_follows_the_level(engine, qtbot, level, fraction):
    window, meter = meter_scene(engine, qtbot)
    meter.setProperty("level", level)
    assert fill_fraction(window) == pytest.approx(fraction)
    window.close()


def test_zones_take_the_tone_colours(engine, qtbot, theme):
    window, meter = meter_scene(engine, qtbot, "level: 0; warnLevel: -18; dangerLevel: -6")
    bar = find(window, "bar")
    zones = sorted((z for z in find(window, "levelFill").childItems() if z.objectName() == "zone"), key=lambda z: z.x())
    assert [round(z.x() / bar.width(), 3) for z in zones] == [0, 0.7, 0.9]
    for mode in ("light", "dark"):
        set_theme(engine, mode)
        assert [QColor(z.property("color")) for z in zones] == [
            QColor(theme.property(n)) for n in ("ok", "toneYellow", "toneRed")], mode
    window.close()


def test_value_text_and_silence(engine, qtbot):
    window, meter = meter_scene(engine, qtbot, "level: -18.44")
    assert find(window, "valueText").property("text") == "-18.4 dB"
    meter.setProperty("level", -math.inf)
    assert meter.property("valueText") == "-∞ dB"
    window.close()
    window, meter = meter_scene(engine, qtbot, 'from: 0; to: 1; unit: ""; decimals: 2; warnLevel: 0.7; dangerLevel: 0.9;'
                                               ' level: 0.5')
    assert meter.property("valueText") == "0.50"
    assert fill_fraction(window) == pytest.approx(0.5)
    labels = sorted((i for i in all_items(find(window, "bar")) if i.objectName() == "scaleLabel"),
                    key=lambda i: i.mapToScene(i.boundingRect().topLeft()).x())
    assert [i.property("text") for i in labels] == ["0.0", "0.2", "0.4", "0.6", "0.8", "1.0"]  # the step's digits
    window.close()


def test_peak_holds_then_drops_to_the_level(engine, qtbot, theme):
    window, meter = meter_scene(engine, qtbot, "level: -40")
    marker = find(window, "peakMarker")
    meter.setProperty("level", -6)
    meter.setProperty("level", -20)
    assert meter.property("peak") == pytest.approx(-6)
    assert marker.isVisible()
    assert QColor(marker.property("color")) == QColor(theme.property("toneYellow"))  # -6 is in the warn zone
    bar = find(window, "bar")
    assert marker.x() + marker.width() / 2 == pytest.approx(0.9 * bar.width(), abs=1)
    meter.setProperty("level", -25)  # lower levels do not move a held peak
    assert meter.property("peak") == pytest.approx(-6)
    hold = theme.property("meterPeakHold")
    qtbot.waitUntil(lambda: meter.property("peak") == pytest.approx(-25), timeout=hold + 1000)
    meter.setProperty("level", -30)  # after the hold, the peak follows the level down
    assert meter.property("peak") == pytest.approx(-30)
    window.close()


def test_clip_latches_until_reset(engine, qtbot, theme):
    window, meter = meter_scene(engine, qtbot, "level: -20")
    lamp = find(window, "clipLamp")
    assert meter.property("clipped") is False
    assert QColor(lamp.property("color")) == QColor(theme.property("borderStrong"))
    meter.setProperty("level", 0)
    meter.setProperty("level", -20)
    assert meter.property("clipped") is True
    assert QColor(lamp.property("color")) == QColor(theme.property("toneRed"))
    assert "clipped" in QAccessible.queryAccessibleInterface(meter).text(QAccessible.Text.Description)
    from PySide6.QtCore import QMetaObject

    QMetaObject.invokeMethod(meter, "reset")
    assert meter.property("clipped") is False and meter.property("peak") == pytest.approx(-20)
    window.close()


def test_accessible_progress_bar_with_level_peak_and_pin(engine, qtbot):
    window, meter = meter_scene(engine, qtbot, 'level: -18; pinnedLevel: -12; pinnedLabel: "Target"')
    iface = QAccessible.queryAccessibleInterface(meter)
    assert iface.role() == QAccessible.Role.ProgressBar
    assert iface.text(QAccessible.Text.Name) == "Input level"
    assert iface.valueInterface().currentValue() == pytest.approx(-18)
    assert iface.valueInterface().minimumValue() == pytest.approx(-60)
    assert iface.valueInterface().maximumValue() == pytest.approx(0)
    assert iface.text(QAccessible.Text.Description) == "-18.0 dB, peak -18.0 dB, Target -12.0 dB"
    window.close()


def test_fixed_pin_marks_the_level_and_takes_no_focus(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { x: 20; y: 20\n'
        ' SuiLevelMeter { objectName: "m"; width: 340; label: "Input"; level: -30; pinnedLevel: -12 }\n'
        ' SuiButton { objectName: "after"; text: "After" } }',
    )
    meter, marker, bar = find(window, "m"), find(window, "pinMarker"), find(window, "bar")
    centre = marker.mapToScene(marker.boundingRect().center()).x()
    assert centre == pytest.approx(bar.mapToScene(bar.boundingRect().topLeft()).x() + 0.8 * bar.width(), abs=1)
    assert not find(window, "pinKnob").isVisible()
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "after").hasActiveFocus()  # not editable: no Tab stop
    meter.setProperty("pinnedLevel", math.nan)
    assert not find(window, "pin").isVisible()
    window.close()


def test_editable_pin_by_keyboard(engine, qtbot):
    window, meter = meter_scene(engine, qtbot, 'level: -30; pinnedLevel: -40; pinnedLabel: "Gate threshold"; pinEditable: true')
    moved = spy(meter, "pinMoved(double)")
    pin = find(window, "pin")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert pin.hasActiveFocus() and len(visible_rings(window.contentItem())) == 1
    iface = QAccessible.queryAccessibleInterface(pin)
    assert iface.role() == QAccessible.Role.Slider
    assert iface.text(QAccessible.Text.Name) == "Gate threshold"
    steps = [(Qt.Key.Key_Right, -39), (Qt.Key.Key_Up, -38), (Qt.Key.Key_Left, -39), (Qt.Key.Key_PageUp, -29),
             (Qt.Key.Key_PageDown, -39), (Qt.Key.Key_End, 0), (Qt.Key.Key_Home, -60)]
    for key, expected in steps:
        QTest.keyClick(window, key)
        assert meter.property("pinnedLevel") == pytest.approx(expected), key
    assert moved.count() == len(steps)
    assert moved.at(moved.count() - 1)[0] == pytest.approx(-60)
    assert iface.text(QAccessible.Text.Description) == "-60.0 dB"
    window.close()


def test_editable_pin_by_pointer(engine, qtbot):
    window, meter = meter_scene(engine, qtbot, "level: -30; pinnedLevel: -40; pinEditable: true")
    moved = spy(meter, "pinMoved(double)")
    bar = find(window, "bar")
    target = bar.mapToScene(bar.boundingRect().topLeft()).toPoint() + QPoint(int(bar.width() * 0.75), 4)
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, target)
    assert meter.property("pinnedLevel") == pytest.approx(-15, abs=0.5)
    assert moved.count() >= 1
    assert find(window, "pin").hasActiveFocus() and visible_rings(window.contentItem()) == []
    marker = find(window, "pinMarker")
    assert marker.mapToScene(marker.boundingRect().center()).x() == pytest.approx(target.x(), abs=1.5)
    meter.setProperty("pinnedLevel", -50)  # the app can still move it after the user did
    assert marker.mapToScene(marker.boundingRect().center()).x() == pytest.approx(
        bar.mapToScene(bar.boundingRect().topLeft()).x() + bar.width() / 6, abs=1.5)
    window.close()


def test_scale_ticks(engine, qtbot):
    window, meter = meter_scene(engine, qtbot, "scaleStep: 12")
    assert list(meter.property("ticks").toVariant()) == [-60, -48, -36, -24, -12, 0]
    labels = sorted((i for i in all_items(find(window, "bar")) if i.objectName() == "scaleLabel"),
                    key=lambda i: i.mapToScene(i.boundingRect().topLeft()).x())
    assert [i.property("text") for i in labels] == ["-60", "-48", "-36", "-24", "-12", "0"]
    bar = find(window, "bar")
    left = bar.mapToScene(bar.boundingRect().topLeft()).x()
    assert labels[0].mapToScene(labels[0].boundingRect().topLeft()).x() >= left - 0.5  # kept inside at the ends
    assert labels[-1].mapToScene(labels[-1].boundingRect().topRight()).x() <= left + bar.width() + 0.5
    meter.setProperty("scaleStep", 0)  # automatic: labels never collide
    xs = sorted(i.mapToScene(i.boundingRect().topLeft()).x() for i in all_items(bar) if i.objectName() == "scaleLabel")
    widths = max(i.width() for i in all_items(bar) if i.objectName() == "scaleLabel")
    assert all(b - a >= widths for a, b in zip(xs, xs[1:], strict=False))
    meter.setProperty("showScale", False)
    assert [i for i in all_items(bar) if i.objectName() == "scaleLabel"] == []
    window.close()


def test_vertical_meter(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'SuiLevelMeter { objectName: "m"; x: 20; y: 20; height: 220; orientation: Qt.Vertical; label: "Input";'
        ' level: -15; pinnedLevel: -30; pinEditable: true }',
    )
    meter, bar, fill = find(window, "m"), find(window, "bar"), find(window, "levelFill")
    assert fill.height() == pytest.approx(0.75 * bar.height())
    assert fill.y() + fill.height() == pytest.approx(bar.height())  # from the bottom
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Up)
    assert meter.property("pinnedLevel") == pytest.approx(-29)
    marker = find(window, "pinMarker")
    centre = marker.mapToScene(marker.boundingRect().center()).y()
    top = bar.mapToScene(bar.boundingRect().topLeft()).y()
    assert centre == pytest.approx(top + (1 - 31 / 60) * bar.height(), abs=1.5)
    window.close()


def test_nothing_in_the_meter_animates(engine, qtbot):
    """Live levels draw as they come: no Behavior or animation (reduced motion has nothing to stop)."""
    window, meter = meter_scene(engine, qtbot, "level: -20; pinnedLevel: -12; pinEditable: true")
    found = [o for o in [meter, *meter.findChildren(QObject)] if o.inherits("QQuickAbstractAnimation")
             or o.inherits("QQuickBehavior")]
    assert found == []
    window.close()


def all_items(root):
    out = [root]
    for child in root.childItems():
        out.extend(all_items(child))
    return out
