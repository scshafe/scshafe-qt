"""SuiInfoTip: hover opens after a delay and closes after a grace, a click pins it, the
keyboard toggles it, it never takes focus from the app's keys, placement stays in the
window, the markup subset, accessibility."""

from __future__ import annotations

from conftest import find, spy, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible
from PySide6.QtTest import QTest

LEFT = Qt.MouseButton.LeftButton
NONE = Qt.KeyboardModifier.NoModifier
BODY = "Drag a handle to keep part of the take. <b>Save</b> writes the trim."

# An app area that keeps focus and counts its keys (voice-lab's R / Space / Return).
APP = """
FocusScope { objectName: "app"; anchors.fill: parent; focus: true
    property int keys: 0
    property int escapes: 0
    Keys.onPressed: (event) => { if (event.key === Qt.Key_R) { keys++; event.accepted = true } }
    Keys.onEscapePressed: escapes++
    Item { objectName: "appFocus"; focus: true; width: 10; height: 10 }
    %s
}
"""


def tip_scene(engine, qtbot, props: str = "", x: int = 200, y: int = 60, size=(480, 320),
              title: str = '"Trim"', text: str = f'"{BODY}"'):
    window = window_scene(
        engine, qtbot,
        APP % f'SuiInfoTip {{ objectName: "tip"; x: {x}; y: {y}; title: {title}; text: {text}; {props} }}',
        *size,
    )
    return window, find(window, "tip")


def centre(item) -> QPoint:
    return item.mapToScene(item.boundingRect().center()).toPoint()


def popup_item(window):
    return find(window, "infoTipBackground").parentItem()


def hover(window, point: QPoint) -> None:
    QTest.mouseMove(window, point)


# ---- Hover ------------------------------------------------------------------------


def test_hover_opens_after_the_delay(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    hover(window, QPoint(5, 300))
    hover(window, centre(tip))
    QTest.qWait(150)
    assert tip.property("opened") is False  # infoTipDelay is 400 ms
    qtbot.waitUntil(lambda: tip.property("opened") is True, timeout=2000)
    assert tip.property("_mode") == "hover"
    window.close()


def test_leaving_closes_after_the_grace(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    hover(window, QPoint(5, 300))
    hover(window, centre(tip))
    qtbot.waitUntil(lambda: tip.property("opened") is True, timeout=2000)
    hover(window, QPoint(5, 300))
    assert tip.property("opened") is True  # infoTipCloseDelay is 120 ms
    qtbot.waitUntil(lambda: tip.property("opened") is False, timeout=2000)
    window.close()


def test_leaving_before_the_delay_never_opens(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    hover(window, QPoint(5, 300))
    hover(window, centre(tip))
    QTest.qWait(100)
    hover(window, QPoint(5, 300))
    QTest.qWait(600)
    assert tip.property("opened") is False
    window.close()


def test_moving_into_the_popover_keeps_it_open(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    hover(window, QPoint(5, 300))
    hover(window, centre(tip))
    qtbot.waitUntil(lambda: tip.property("opened") is True, timeout=2000)
    QTest.qWait(150)  # the fade
    popup = popup_item(window)
    hover(window, centre(popup))
    QTest.qWait(500)
    assert tip.property("opened") is True
    hover(window, QPoint(5, 300))
    qtbot.waitUntil(lambda: tip.property("opened") is False, timeout=2000)
    window.close()


# ---- Click --------------------------------------------------------------------------


def test_a_click_pins_it_and_a_second_click_closes_it(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True and tip.property("_mode") == "pinned"
    hover(window, QPoint(5, 300))
    QTest.qWait(500)
    assert tip.property("opened") is True  # pinned: the pointer leaving does not close it
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is False
    window.close()


def test_a_click_outside_closes_a_pinned_tip(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True
    QTest.mouseClick(window, LEFT, NONE, QPoint(5, 300))
    qtbot.waitUntil(lambda: tip.property("opened") is False)
    window.close()


def test_a_click_on_a_hover_opened_tip_pins_it(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    hover(window, QPoint(5, 300))
    hover(window, centre(tip))
    qtbot.waitUntil(lambda: tip.property("opened") is True, timeout=2000)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True and tip.property("_mode") == "pinned"
    window.close()


def test_pointer_use_never_moves_focus(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    app = find(window, "app")
    focus = find(window, "appFocus")
    assert focus.hasActiveFocus()
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True
    assert focus.hasActiveFocus() and not tip.hasActiveFocus()
    QTest.qWait(150)
    QTest.mouseClick(window, LEFT, NONE, centre(popup_item(window)))  # inside the popover
    assert focus.hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_R)
    assert app.property("keys") == 1  # the app's key still reaches the app
    assert tip.property("opened") is True
    assert visible_rings(window.contentItem()) == []
    window.close()


# ---- Keyboard -----------------------------------------------------------------------


def test_keyboard_toggles_it_and_escape_closes(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    app = find(window, "app")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert tip.hasActiveFocus()
    assert len(visible_rings(window.contentItem())) == 1
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert tip.property("opened") is True and tip.property("_mode") == "keyboard"
    assert tip.hasActiveFocus()  # the popover does not take focus
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert tip.property("opened") is False
    assert app.property("escapes") == 0  # Escape closed the tip ...
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert app.property("escapes") == 1  # ... and propagates once it is closed
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert tip.property("opened") is True
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert tip.property("opened") is False
    window.close()


def test_focus_leaving_closes_a_keyboard_opened_tip(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert tip.property("opened") is True
    find(window, "appFocus").forceActiveFocus()
    assert tip.property("opened") is False
    window.close()


def test_modified_keys_pass_through(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Return, Qt.KeyboardModifier.ControlModifier)
    assert tip.property("opened") is False
    window.close()


def test_disabling_closes_it(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True
    tip.setProperty("enabled", False)
    assert tip.property("opened") is False
    window.close()


# ---- Placement ----------------------------------------------------------------------


def placed(window, tip):
    tip.setProperty("_mode", "")
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert tip.property("opened") is True
    QTest.qWait(50)
    return popup_item(window).mapRectToScene(popup_item(window).boundingRect())


def test_it_opens_below_and_flips_above_at_the_bottom_edge(engine, qtbot):
    window, tip = tip_scene(engine, qtbot, y=20)
    rect = placed(window, tip)
    top = tip.mapToScene(QPoint(0, 0)).y()
    assert rect.top() >= top + tip.height()  # below
    assert abs(rect.center().x() - centre(tip).x()) <= 1  # centred on the button
    window.close()

    window, tip = tip_scene(engine, qtbot, y=290)
    rect = placed(window, tip)
    assert rect.bottom() <= tip.mapToScene(QPoint(0, 0)).y()  # flipped above
    window.close()


def test_above_is_honoured_and_flips_below_at_the_top_edge(engine, qtbot):
    window, tip = tip_scene(engine, qtbot, 'placement: "above"', y=200)
    rect = placed(window, tip)
    assert rect.bottom() <= tip.mapToScene(QPoint(0, 0)).y()
    window.close()

    window, tip = tip_scene(engine, qtbot, 'placement: "above"', y=4)
    rect = placed(window, tip)
    assert rect.top() >= tip.mapToScene(QPoint(0, 0)).y() + tip.height()
    window.close()


def test_it_stays_inside_the_window_at_the_right_edge(engine, qtbot):
    window, tip = tip_scene(engine, qtbot, x=455)
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    rect = placed(window, tip)
    assert rect.right() <= window.width() - theme.property("spaceSm") + 1
    assert rect.width() <= theme.property("infoTipMaxWidth") + 2 * theme.property("spaceMd") + 1
    window.close()


# ---- Content and accessibility ------------------------------------------------------


def test_it_is_an_accessible_button_described_by_its_text(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    iface = QAccessible.queryAccessibleInterface(tip)
    assert iface.role() == QAccessible.Role.Button
    assert iface.text(QAccessible.Text.Name) == "About Trim"
    assert iface.text(QAccessible.Text.Description) == (
        "Trim. Drag a handle to keep part of the take. Save writes the trim."
    )
    tip.setProperty("label", "Trim help")
    assert iface.text(QAccessible.Text.Name) == "Trim help"
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    balloon = QAccessible.queryAccessibleInterface(find(window, "infoTipContent"))
    assert balloon.role() == QAccessible.Role.HelpBalloon
    assert balloon.text(QAccessible.Text.Name) == "Trim"
    window.close()


def test_without_a_title_it_is_more_information(engine, qtbot):
    window, tip = tip_scene(engine, qtbot, 'iconName: "help"', title='""')
    iface = QAccessible.queryAccessibleInterface(tip)
    assert iface.text(QAccessible.Text.Name) == "More information"
    assert iface.text(QAccessible.Text.Description).startswith("Drag a handle")
    assert find(window, "icon").property("name") == "help"
    window.close()


def test_the_markup_subset(engine, qtbot):
    window, tip = tip_scene(engine, qtbot)
    body = find(window, "infoTipBody")
    cases = {
        "<b>Save</b> and <strong>keep</strong>": "<b>Save</b> and <b>keep</b>",
        "<em>now</em><br/><code>-12 dB</code>": "<i>now</i><br><tt>-12 dB</tt>",
        "<ul><li>One</li></ul><p>Two</p>": "<ul><li>One</li></ul><p>Two</p>",
        '<a href="https://example.org/a?b=1&c=2" onclick="x()" style="color:red">help</a>':
            '<a href="https://example.org/a?b=1&amp;c=2">help</a>',
        "<a>no href</a>": "&lt;a&gt;no href</a>",
        "<script>x()</script><font color='red'>r</font>":
            "&lt;script&gt;x()&lt;/script&gt;&lt;font color='red'&gt;r&lt;/font&gt;",
        "level < -12 dB & falling, R&amp;D": "level &lt; -12 dB &amp; falling, R&amp;D",
        "two\nlines": "two<br>lines",
        "<B>caps</B>": "<b>caps</b>",
    }
    for source, expected in cases.items():
        tip.setProperty("text", source)
        assert body.property("text") == expected, source
    tip.setProperty("textFormat", 0)  # Text.PlainText: shown as it is
    tip.setProperty("text", "<b>raw</b>")
    assert body.property("text") == "<b>raw</b>"
    iface = QAccessible.queryAccessibleInterface(tip)
    assert iface.text(QAccessible.Text.Description) == "Trim. <b>raw</b>"
    window.close()


def test_a_link_emits_link_activated(engine, qtbot):
    window, tip = tip_scene(engine, qtbot, text='"<a href=\\"https://example.org/help\\">Help</a>"')
    links = spy(tip, "linkActivated(QString)")
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    QTest.qWait(150)
    body = find(window, "infoTipBody")
    QTest.mouseClick(window, LEFT, NONE, body.mapToScene(QPoint(6, int(body.height() / 2))).toPoint())
    assert links.count() == 1 and links.at(0)[0] == "https://example.org/help"
    assert tip.property("opened") is True
    window.close()


def test_it_fades_unless_reduced_motion(engine, qtbot):
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    window, tip = tip_scene(engine, qtbot)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert popup_item(window).opacity() < 1  # fading in over SuiTheme.duration
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    qtbot.waitUntil(lambda: not popup_item(window).isVisible())
    theme.setProperty("reducedMotion", True)
    QTest.mouseClick(window, LEFT, NONE, centre(tip))
    assert popup_item(window).opacity() == 1  # instant
    theme.setProperty("reducedMotion", False)
    window.close()
