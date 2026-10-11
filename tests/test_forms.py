"""Form controls: SuiCheckBox, SuiSwitch, SuiRadioButton, SuiSelect, SuiSlider.

The shared contract (both themes, role and name, keyboard ring, pointer focus) is in
test_components.py; this module covers each control's behaviour.
"""

from __future__ import annotations

import pytest
from conftest import find, set_theme, spy, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest

R = QAccessible.Role


def tab(window, times: int = 1) -> None:
    for _ in range(times):
        QTest.keyClick(window, Qt.Key.Key_Tab)


def key(window, k, modifier=Qt.KeyboardModifier.NoModifier) -> None:
    QTest.keyClick(window, k, modifier)


def click(window, item, fx: float = 0.5, fy: float = 0.5) -> None:
    rect = item.boundingRect()
    point = item.mapToScene(rect.topLeft()).toPoint() + QPoint(int(rect.width() * fx), int(rect.height() * fy))
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, point)


def colour(item, prop: str = "color") -> QColor:
    return QColor(item.property(prop))


def qml(engine, obj, expression: str):
    """Evaluate `expression` with `obj` in scope (grouped properties such as border.color,
    which PySide cannot convert)."""
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    context = QQmlEngine.contextForObject(obj) or engine.rootContext()
    expr = QQmlExpression(context, obj, expression)
    value, failed = expr.evaluate()
    assert not failed, expr.error().toString()
    return value


# ---- SuiCheckBox ---------------------------------------------------------------


def test_checkbox_space_and_pointer_toggle(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiCheckBox { objectName: "c"; x: 20; y: 20; text: "Normalise loudness" }')
    box = find(window, "c")
    toggled = spy(box, "toggled()")
    tab(window)
    assert box.hasActiveFocus() and box.property("visualFocus")
    key(window, Qt.Key.Key_Space)
    assert box.property("checked") is True and toggled.count() == 1
    click(window, find(window, "label"))  # the label is part of the control
    assert box.property("checked") is False and toggled.count() == 2
    window.close()


def test_checkbox_draws_the_accent_and_the_mark(engine, qtbot, theme):
    window = window_scene(engine, qtbot, 'SuiCheckBox { objectName: "c"; x: 40; y: 40; text: "Take 3" }')
    box, square, mark = find(window, "c"), find(window, "box"), find(window, "checkMark")
    QTest.mouseMove(window, QPoint(300, 300))  # not hovered
    theme.setProperty("reducedMotion", True)
    for mode in ("light", "dark"):
        set_theme(engine, mode)
        box.setProperty("checked", False)
        assert QColor(qml(engine, square, "border.color")) == colour(theme, "fieldBorder")  # 3:1 boundary
        assert not mark.isVisible()
        box.setProperty("checked", True)
        assert colour(square) == colour(theme, "accent")
        assert mark.isVisible() and colour(mark) == colour(theme, "accentForeground")
    window.close()


def test_checkbox_tristate_cycles_through_partial(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiCheckBox { objectName: "c"; text: "All takes"; tristate: true }')
    box = find(window, "c")
    tab(window)
    states = []
    for _ in range(3):
        key(window, Qt.Key.Key_Space)
        states.append(box.property("checkState"))
    assert states == [Qt.CheckState.PartiallyChecked, Qt.CheckState.Checked, Qt.CheckState.Unchecked]
    box.setProperty("checkState", Qt.CheckState.PartiallyChecked.value)
    assert find(window, "partialMark").isVisible() and not find(window, "checkMark").isVisible()
    window.close()


def test_checkbox_accessible_state_description_and_label(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { SuiCheckBox { objectName: "c"; text: "Normalise"; description: "Every take to -23 LUFS" }'
        ' SuiCheckBox { objectName: "bare"; label: "Select take 3" } }',
    )
    iface = QAccessible.queryAccessibleInterface(find(window, "c"))
    assert iface.text(QAccessible.Text.Description) == "Every take to -23 LUFS"
    assert not iface.state().checked
    find(window, "c").setProperty("checked", True)
    assert iface.state().checked
    bare = find(window, "bare")
    assert QAccessible.queryAccessibleInterface(bare).text(QAccessible.Text.Name) == "Select take 3"
    assert bare.width() == pytest.approx(bare.property("indicator").width())  # no text: just the box
    window.close()


# ---- SuiSwitch -----------------------------------------------------------------


@pytest.mark.parametrize("reduced", [True, False])
def test_switch_toggles_and_slides(engine, qtbot, theme, reduced):
    theme.setProperty("reducedMotion", reduced)
    window = window_scene(engine, qtbot, 'SuiSwitch { objectName: "s"; x: 20; y: 20; text: "Monitor input" }')
    switch, thumb, track = find(window, "s"), find(window, "thumb"), find(window, "track")
    off_x = thumb.x()
    tab(window)
    key(window, Qt.Key.Key_Space)
    assert switch.property("checked") is True
    end = track.width() - thumb.width() - thumb.property("inset")
    if reduced:
        assert thumb.x() == pytest.approx(end)  # instant
    else:
        assert thumb.x() < end  # still sliding
        qtbot.waitUntil(lambda: thumb.x() == pytest.approx(end), timeout=1000)
    assert thumb.x() > off_x
    assert colour(track) == colour(theme, "accentHover")  # focused (keyboard): the hover accent
    assert colour(thumb) == colour(theme, "accentForeground")
    assert QAccessible.queryAccessibleInterface(switch).state().checked
    window.close()


# ---- SuiRadioButton --------------------------------------------------------------

RADIOS = """
SuiButton { objectName: "before"; text: "Before" }
Column { objectName: "group"
    SuiRadioButton { objectName: "r0"; text: "16 kHz" }
    SuiRadioButton { objectName: "r1"; text: "44.1 kHz"; checked: true }
    SuiRadioButton { objectName: "r2"; text: "48 kHz" }
}
SuiButton { objectName: "after"; text: "After" }
"""


def radio_scene(engine, qtbot, body=RADIOS):
    return window_scene(engine, qtbot, f"Column {{ x: 20; y: 20; spacing: 4\n{body}\n}}")


def test_radio_group_is_one_tab_stop_on_the_checked_button(engine, qtbot):
    window = radio_scene(engine, qtbot)
    tab(window)
    assert find(window, "before").hasActiveFocus()
    tab(window)
    assert find(window, "r1").hasActiveFocus()
    tab(window)
    assert find(window, "after").hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_Backtab)
    assert find(window, "r1").hasActiveFocus()
    window.close()


def test_radio_arrows_move_and_check_with_wrap(engine, qtbot):
    window = radio_scene(engine, qtbot)
    radios = [find(window, f"r{i}") for i in range(3)]
    toggled = spy(radios[2], "toggled()")
    radios[1].forceActiveFocus(Qt.FocusReason.TabFocusReason)
    key(window, Qt.Key.Key_Down)
    assert radios[2].hasActiveFocus() and radios[2].property("checked") is True
    assert radios[1].property("checked") is False  # exclusive
    assert toggled.count() == 1
    assert len(visible_rings(window.contentItem())) == 1
    key(window, Qt.Key.Key_Right)  # wraps to the first
    assert radios[0].hasActiveFocus() and radios[0].property("checked") is True
    key(window, Qt.Key.Key_Up)  # wraps back to the last
    assert radios[2].property("checked") is True
    window.close()


def test_radio_first_is_the_tab_stop_when_none_is_checked(engine, qtbot):
    window = radio_scene(engine, qtbot, RADIOS.replace('; checked: true', ''))
    tab(window, 2)
    assert find(window, "r0").hasActiveFocus()
    tab(window)
    assert find(window, "after").hasActiveFocus()
    window.close()


def test_radio_button_group_across_parents(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'T.ButtonGroup { id: rates }\n'
        'Row { x: 20; y: 20; spacing: 20\n'
        ' SuiRadioButton { objectName: "a"; text: "Mono"; T.ButtonGroup.group: rates; checked: true }\n'
        ' Item { width: 10; height: 10 }\n'
        ' Column { SuiRadioButton { objectName: "b"; text: "Stereo"; T.ButtonGroup.group: rates } } }',
        imports="import QtQuick.Templates as T",
    )
    a, b = find(window, "a"), find(window, "b")
    a.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    key(window, Qt.Key.Key_Down)
    assert b.property("checked") is True and a.property("checked") is False and b.hasActiveFocus()
    window.close()


def test_radio_accessible(engine, qtbot):
    window = radio_scene(engine, qtbot)
    iface = QAccessible.queryAccessibleInterface(find(window, "r1"))
    assert iface.role() == R.RadioButton
    assert iface.text(QAccessible.Text.Name) == "44.1 kHz"
    assert iface.state().checked and iface.state().checkable
    window.close()


# ---- SuiSelect -------------------------------------------------------------------

SELECT = ('SuiSelect { objectName: "s"; x: 20; y: 20; label: "Input";'
          ' model: ["Desk microphone", "Headset", "Line in"] }')


def test_select_keyboard_opens_moves_and_chooses(engine, qtbot):
    window = window_scene(engine, qtbot, SELECT)
    select = find(window, "s")
    activated = spy(select, "activated(int)")
    popup = find(window, "popup")
    tab(window)
    key(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: popup.property("opened"))
    key(window, Qt.Key.Key_Down)
    key(window, Qt.Key.Key_Down)
    key(window, Qt.Key.Key_Return)
    qtbot.waitUntil(lambda: not popup.property("visible"))
    assert select.property("currentIndex") == 2 and select.property("currentText") == "Line in"
    assert activated.count() == 1 and activated.at(0) == [2]
    key(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: popup.property("opened"))
    key(window, Qt.Key.Key_Up)
    key(window, Qt.Key.Key_Escape)  # closes without choosing
    qtbot.waitUntil(lambda: not popup.property("visible"))
    assert select.property("currentIndex") == 2 and activated.count() == 1
    key(window, Qt.Key.Key_Up)  # closed: arrows change the choice
    assert select.property("currentIndex") == 1 and activated.count() == 2
    assert select.hasActiveFocus()
    window.close()


def test_select_pointer_choice(engine, qtbot):
    window = window_scene(engine, qtbot, SELECT, height=320)
    select = find(window, "s")
    click(window, select)
    popup = find(window, "popup")
    qtbot.waitUntil(lambda: popup.property("opened"))
    options = find(window, "options")
    qtbot.waitUntil(lambda: options.property("count") == 3)
    row = next(i for i in options.property("contentItem").childItems() if i.property("text") == "Headset")
    click(window, row)
    qtbot.waitUntil(lambda: not popup.property("visible"))
    assert select.property("currentText") == "Headset"
    window.close()


def test_select_accessible_name_description_and_placeholder(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'SuiSelect { objectName: "s"; label: "Sample rate"; placeholderText: "Choose a rate"; currentIndex: -1;'
        ' model: [{ text: "44.1 kHz", value: 44100 }, { text: "48 kHz", value: 48000 }];'
        ' textRole: "text"; valueRole: "value" }',
    )
    select = find(window, "s")
    iface = QAccessible.queryAccessibleInterface(select)
    assert iface.role() == R.ComboBox
    assert iface.text(QAccessible.Text.Name) == "Sample rate"
    assert iface.text(QAccessible.Text.Description) == "Choose a rate"
    value = find(window, "valueText")
    assert value.property("text") == "Choose a rate"
    assert QColor(value.property("color")) == QColor(engine.singletonInstance("Scshafe.Ui", "SuiTheme").property("muted"))
    select.setProperty("currentIndex", 1)
    assert select.property("currentValue") == 48000
    assert value.property("text") == "48 kHz"
    assert iface.text(QAccessible.Text.Description) == "48 kHz"
    window.close()


def test_select_is_as_wide_as_its_widest_option(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { SuiSelect { objectName: "s"; label: "Input"; currentIndex: 1;'
        ' model: ["Desk microphone (USB, 48 kHz)", "Line in"] }\n'
        ' Text { objectName: "probe"; text: "Desk microphone (USB, 48 kHz)"; font.pixelSize: SuiTheme.fontSizeMd } }',
    )
    select, probe = find(window, "s"), find(window, "probe")
    assert select.property("implicitWidth") >= probe.property("implicitWidth") + select.property("leftPadding")
    window.close()


@pytest.mark.qt_log_level_fail("CRITICAL")
def test_select_and_slider_warn_without_a_label(engine, qtbot, qtlog):
    window = window_scene(engine, qtbot, 'Column { SuiSelect { model: ["a"] } SuiSlider {} }')
    messages = [r.message for r in qtlog.records]
    assert any("SuiSelect has no label" in m for m in messages), messages
    assert any("SuiSlider has no label" in m for m in messages), messages
    window.close()


# ---- SuiSlider -------------------------------------------------------------------


def slider_scene(engine, qtbot, props: str):
    window = window_scene(engine, qtbot, f'SuiSlider {{ objectName: "s"; x: 20; y: 20; width: 300; label: "Gain"; {props} }}')
    return window, find(window, "s")


def test_slider_keys_step_page_and_ends(engine, qtbot):
    window, slider = slider_scene(engine, qtbot, "from: -24; to: 24; stepSize: 0.5; value: 0")
    moved = spy(slider, "moved()")
    tab(window)
    key(window, Qt.Key.Key_Right)
    assert slider.property("value") == pytest.approx(0.5)
    key(window, Qt.Key.Key_Up)
    assert slider.property("value") == pytest.approx(1.0)
    key(window, Qt.Key.Key_Left)
    assert slider.property("value") == pytest.approx(0.5)
    key(window, Qt.Key.Key_PageUp)
    assert slider.property("value") == pytest.approx(5.5)
    key(window, Qt.Key.Key_PageDown)
    assert slider.property("value") == pytest.approx(0.5)
    key(window, Qt.Key.Key_End)
    assert slider.property("value") == pytest.approx(24)
    key(window, Qt.Key.Key_Right)  # at the end: no change, no moved()
    key(window, Qt.Key.Key_Home)
    assert slider.property("value") == pytest.approx(-24)
    assert moved.count() == 7
    window.close()


def test_slider_without_a_step_moves_one_percent(engine, qtbot):
    window, slider = slider_scene(engine, qtbot, "from: 0; to: 200; value: 100")
    tab(window)
    key(window, Qt.Key.Key_Right)
    assert slider.property("value") == pytest.approx(102)
    window.close()


def test_slider_value_text_unit_decimals_and_accessibility(engine, qtbot):
    window, slider = slider_scene(engine, qtbot, 'from: -24; to: 24; stepSize: 0.5; value: 6; unit: "dB"; showValue: true')
    assert slider.property("decimals") == 1
    assert slider.property("valueText") == "6.0 dB"
    label = find(window, "valueText")
    assert label.isVisible() and label.property("text") == "6.0 dB"
    iface = QAccessible.queryAccessibleInterface(slider)
    assert iface.role() == R.Slider
    assert iface.text(QAccessible.Text.Name) == "Gain"
    assert iface.text(QAccessible.Text.Description) == "6.0 dB"
    assert iface.valueInterface().currentValue() == pytest.approx(6)
    track = find(window, "track")
    right = track.mapToScene(track.boundingRect().topRight()).x()
    assert right < label.mapToScene(label.boundingRect().topLeft()).x()  # the value sits beside the track
    width = slider.property("valueWidth")
    slider.setProperty("value", -23.5)
    assert slider.property("valueWidth") == width  # the track does not move with the value
    window.close()


def test_slider_vertical_up_increases(engine, qtbot):
    window = window_scene(
        engine, qtbot, 'SuiSlider { objectName: "s"; x: 20; y: 20; height: 160; label: "Mix"; orientation: Qt.Vertical; value: 0.5 }',
    )
    slider = find(window, "s")
    handle = find(window, "handle")
    y = handle.y()
    tab(window)
    key(window, Qt.Key.Key_Up)
    assert slider.property("value") == pytest.approx(0.51)
    assert handle.y() < y  # up the track
    window.close()


def test_slider_pointer_sets_the_value(engine, qtbot):
    window, slider = slider_scene(engine, qtbot, "from: 0; to: 100; stepSize: 1; value: 0")
    moved = spy(slider, "moved()")
    track = find(window, "track")
    click(window, track, 0.75, 0.5)
    assert slider.property("value") == pytest.approx(75, abs=1)
    assert moved.count() >= 1
    assert slider.hasActiveFocus() and visible_rings(window.contentItem()) == []
    window.close()
