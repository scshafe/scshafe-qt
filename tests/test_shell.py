"""SuiAppShell: panes, keyboard and pointer resizing, collapsing the inspector."""

from __future__ import annotations

from conftest import find, owner, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible
from PySide6.QtTest import QTest

SHELL = """
SuiAppShell { objectName: "shell"; anchors.fill: parent; %s
    sidebar: Item { objectName: "side"; SuiButton { objectName: "sideButton"; text: "Side" } }
    content: Item { objectName: "main"; SuiButton { objectName: "mainButton"; text: "Main" } }
    inspector: Item { objectName: "insp"; SuiButton { objectName: "inspButton"; text: "Inspect" } }
}
"""
NAMES = {"sideButton", "sidebarHandle", "mainButton", "inspectorHandle", "inspButton"}


def shell_scene(engine, qtbot, extra: str = "", width: int = 1000):
    window = window_scene(engine, qtbot, SHELL % extra, width, 400)
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    theme.setProperty("reducedMotion", True)  # widths settle immediately
    return window, find(window, "shell")


def focused(window) -> str | None:
    return owner(window.activeFocusItem(), NAMES)


def test_panes_fill_their_slots(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    side, main, insp = find(window, "sidebarPane"), find(window, "contentPane"), find(window, "inspectorPane")
    assert side.width() == 232 and insp.width() == 320
    assert main.x() == 232 and main.width() == 1000 - 232 - 320
    assert find(window, "side").width() == side.width()
    for pane, name in ((side, "Sidebar"), (main, "Content"), (insp, "Inspector")):
        iface = QAccessible.queryAccessibleInterface(pane)
        assert iface.role() == QAccessible.Role.Pane and iface.text(QAccessible.Text.Name) == name
    window.close()


def test_focus_order_runs_through_the_splitters(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    order = []
    for _ in range(5):
        QTest.keyClick(window, Qt.Key.Key_Tab)
        order.append(focused(window))
    assert order == ["sideButton", "sidebarHandle", "mainButton", "inspectorHandle", "inspButton"]
    QTest.keyClick(window, Qt.Key.Key_Backtab)
    assert focused(window) == "inspectorHandle"
    window.close()


def test_splitter_is_an_accessible_separator(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    iface = QAccessible.queryAccessibleInterface(find(window, "sidebarHandle"))
    assert iface.role() == QAccessible.Role.Separator
    assert iface.text(QAccessible.Text.Name) == "Resize sidebar"
    assert iface.text(QAccessible.Text.Description) == "232 pixels wide"
    window.close()


def test_keyboard_resizing(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert focused(window) == "sidebarHandle"
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert shell.property("sidebarWidth") == 232 + 16
    QTest.keyClick(window, Qt.Key.Key_Left, Qt.KeyboardModifier.ShiftModifier)
    assert shell.property("sidebarWidth") == 232 + 16 - 64
    QTest.keyClick(window, Qt.Key.Key_Home)
    assert shell.property("sidebarWidth") == 160
    QTest.keyClick(window, Qt.Key.Key_Left)
    assert shell.property("sidebarWidth") == 160  # clamped at the minimum
    QTest.keyClick(window, Qt.Key.Key_End)
    assert shell.property("sidebarWidth") == 400
    assert find(window, "sidebarPane").width() == 400
    QTest.keyClick(window, Qt.Key.Key_Home)
    # The inspector handle grows its pane leftwards.
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert focused(window) == "inspectorHandle"
    QTest.keyClick(window, Qt.Key.Key_Left)
    assert shell.property("inspectorWidth") == 320 + 16
    window.close()


def test_content_keeps_its_minimum_width(engine, qtbot):
    window, shell = shell_scene(engine, qtbot, width=900)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_End)
    # 900 - contentMinWidth 280 - inspector 320 = 300 < sidebarMaxWidth 400
    assert shell.property("sidebarWidth") == 300
    assert find(window, "contentPane").width() == 280
    window.close()


def test_dragging_the_splitter(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    handle = find(window, "sidebarHandle")
    start = handle.mapToScene(handle.boundingRect().center()).toPoint()
    QTest.mousePress(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start)
    for dx in range(0, 61, 10):
        QTest.mouseMove(window, start + QPoint(dx, 0))
    QTest.mouseRelease(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, start + QPoint(60, 0))
    assert 232 + 40 <= shell.property("sidebarWidth") <= 232 + 60
    window.close()


def test_collapsing_the_inspector(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    find(window, "inspButton").forceActiveFocus(Qt.FocusReason.TabFocusReason)
    shell.setProperty("inspectorOpen", False)
    qtbot.waitUntil(lambda: find(window, "inspectorPane").width() == 0)
    assert not find(window, "inspectorPane").isVisible()
    assert not find(window, "inspectorHandle").isVisible()
    assert find(window, "contentPane").width() == 1000 - 232
    # Focus inside the collapsed pane moves to the content; the pane leaves the Tab order.
    assert owner(window.activeFocusItem(), {"main", "insp"}) == "main"
    seen = set()
    for _ in range(6):
        QTest.keyClick(window, Qt.Key.Key_Tab)
        seen.add(focused(window))
    assert "inspButton" not in seen and "inspectorHandle" not in seen
    shell.setProperty("inspectorOpen", True)
    qtbot.waitUntil(lambda: find(window, "inspectorPane").width() == 320)
    window.close()


def test_enter_on_a_splitter_collapses_its_pane(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    find(window, "inspectorHandle").forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert shell.property("inspectorOpen") is False
    window.close()


def test_collapse_animates_unless_reduced_motion(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    theme.setProperty("reducedMotion", False)
    pane = find(window, "inspectorPane")
    shell.setProperty("inspectorOpen", False)
    assert pane.width() > 0  # animating over SuiTheme.duration
    qtbot.waitUntil(lambda: pane.width() == 0, timeout=2000)
    theme.setProperty("reducedMotion", True)
    shell.setProperty("inspectorOpen", True)
    assert pane.width() == 320  # instant
    window.close()


# ---- The hideable sidebar ----------------------------------------------------------

LEFT = Qt.MouseButton.LeftButton
NONE = Qt.KeyboardModifier.NoModifier
FAR = QPoint(600, 300)  # over the content, away from the hot zone and the sidebar


def hideable_scene(engine, qtbot, extra: str = ""):
    window, shell = shell_scene(engine, qtbot, "sidebarHideable: true; " + extra)
    QTest.mouseMove(window, FAR)
    return window, shell


def centre(item) -> QPoint:
    return item.mapToScene(item.boundingRect().center()).toPoint()


def reveal(window, shell, qtbot, at: QPoint = QPoint(5, 5)):
    QTest.mouseMove(window, at)
    qtbot.waitUntil(lambda: shell.property("sidebarRevealed") is True, timeout=2000)


def test_the_pin_hides_and_docks_the_sidebar(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot)
    pin = find(window, "sidebarPin")
    iface = QAccessible.queryAccessibleInterface(pin)
    assert iface.role() == QAccessible.Role.CheckBox and iface.text(QAccessible.Text.Name) == "Pin sidebar"
    assert pin.isVisible() and iface.state().checked
    QTest.mouseClick(window, LEFT, NONE, centre(pin))
    assert shell.property("sidebarOpen") is False
    assert find(window, "contentPane").x() == 0
    assert not find(window, "sidebarPane").isVisible()
    assert pin.property("checked") is False  # follows the shell again
    reveal(window, shell, qtbot)
    QTest.mouseMove(window, centre(pin))
    QTest.mouseClick(window, LEFT, NONE, centre(pin))
    assert shell.property("sidebarOpen") is True and shell.property("sidebarRevealed") is False
    assert find(window, "contentPane").x() == 232
    assert pin.property("checked") is True
    window.close()


def test_the_pin_is_only_there_when_hideable(engine, qtbot):
    window, shell = shell_scene(engine, qtbot)
    assert not find(window, "sidebarPin").isVisible()
    window.close()


def test_the_hot_zone_reveals_an_overlay_without_moving_the_content(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    content, pane = find(window, "contentPane"), find(window, "sidebarPane")
    assert content.x() == 0 and content.width() == 1000 - 320
    assert not pane.isVisible()
    QTest.mouseMove(window, QPoint(5, 5))
    QTest.qWait(50)
    assert shell.property("sidebarRevealed") is False  # sidebarRevealDelay is 150 ms
    qtbot.waitUntil(lambda: shell.property("sidebarRevealed") is True, timeout=2000)
    assert pane.isVisible() and pane.x() == 0 and pane.width() == 232
    assert content.x() == 0 and content.width() == 1000 - 320  # no reflow
    assert pane.z() > content.z()
    assert find(window, "sidebarOverlayEdge").isVisible()
    assert not find(window, "sidebarHandle").isVisible()  # no resizing an overlay
    assert shell.property("sidebarOpen") is False
    # The overlay takes the pointer: its button works.
    side = find(window, "sideButton")
    QTest.mouseMove(window, centre(side))
    QTest.mouseClick(window, LEFT, NONE, centre(side))
    assert side.hasActiveFocus()
    window.close()


def test_the_overlay_stays_while_hovered_and_slides_away_after(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    reveal(window, shell, qtbot)
    QTest.mouseMove(window, QPoint(120, 200))  # over the overlay, away from the zone
    QTest.qWait(700)
    assert shell.property("sidebarRevealed") is True
    QTest.mouseMove(window, FAR)
    QTest.qWait(100)
    assert shell.property("sidebarRevealed") is True  # sidebarHideDelay is 400 ms
    qtbot.waitUntil(lambda: shell.property("sidebarRevealed") is False, timeout=2000)
    assert not find(window, "sidebarPane").isVisible()
    window.close()


def test_leaving_the_zone_before_the_delay_does_not_reveal(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    QTest.mouseMove(window, QPoint(5, 5))
    QTest.qWait(40)
    QTest.mouseMove(window, FAR)
    QTest.qWait(400)
    assert shell.property("sidebarRevealed") is False
    window.close()


def test_the_hot_zone_starts_at_sidebar_reveal_top(engine, qtbot):
    """Below a title bar the content extends under (macOS): never over the traffic lights."""
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false; sidebarRevealTop: 40")
    zone = find(window, "sidebarRevealZone")
    assert (zone.x(), zone.y(), zone.width(), zone.height()) == (0, 40, 24, 24)
    QTest.mouseMove(window, QPoint(5, 5))  # where the traffic lights would be
    QTest.qWait(400)
    assert shell.property("sidebarRevealed") is False
    reveal(window, shell, qtbot, QPoint(5, 50))
    window.close()


def test_the_zone_defaults_to_the_safe_area_top(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    assert shell.property("sidebarRevealTop") == 0  # an ordinary window: no title bar inside
    window.close()


def test_no_hot_zone_unless_hideable(engine, qtbot):
    window, shell = shell_scene(engine, qtbot, "sidebarOpen: false")
    assert not find(window, "sidebarRevealZone").isVisible()
    QTest.mouseMove(window, QPoint(5, 5))
    QTest.qWait(400)
    assert shell.property("sidebarRevealed") is False
    window.close()


def test_the_shortcut_toggles_docked_and_hidden(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, 'sidebarShortcut: "Ctrl+Shift+S"')
    ctrl_shift = Qt.KeyboardModifier.ControlModifier | Qt.KeyboardModifier.ShiftModifier
    QTest.keyClick(window, Qt.Key.Key_S, ctrl_shift)
    assert shell.property("sidebarOpen") is False
    QTest.keyClick(window, Qt.Key.Key_S, ctrl_shift)
    assert shell.property("sidebarOpen") is True
    QTest.keyClick(window, Qt.Key.Key_S, ctrl_shift)
    reveal(window, shell, qtbot)
    QTest.keyClick(window, Qt.Key.Key_S, ctrl_shift)  # from the overlay: docks it
    assert shell.property("sidebarOpen") is True and shell.property("sidebarRevealed") is False
    window.close()


def test_a_hidden_sidebar_leaves_the_tab_order(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    seen = set()
    for _ in range(6):
        QTest.keyClick(window, Qt.Key.Key_Tab)
        seen.add(focused(window))
    assert "sideButton" not in seen and "sidebarHandle" not in seen
    window.close()


def test_focus_leaves_a_concealed_overlay(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    reveal(window, shell, qtbot)
    side = find(window, "sideButton")
    QTest.mouseMove(window, centre(side))
    side.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.mouseMove(window, FAR)
    qtbot.waitUntil(lambda: shell.property("sidebarRevealed") is False, timeout=2000)
    assert owner(window.activeFocusItem(), {"main", "side"}) == "main"
    window.close()


def test_docking_from_the_overlay_moves_only_the_content(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    reveal(window, shell, qtbot)
    pane, content = find(window, "sidebarPane"), find(window, "contentPane")
    theme.setProperty("reducedMotion", False)
    shell.setProperty("sidebarOpen", True)
    xs, contents = set(), []
    for _ in range(8):
        xs.add(pane.x())
        contents.append(content.x())
        QTest.qWait(20)
    assert xs == {0}  # the sidebar stays where it was revealed
    assert contents[0] < 232
    qtbot.waitUntil(lambda: content.x() == 232, timeout=2000)
    window.close()


def test_the_overlay_slides_unless_reduced_motion(engine, qtbot):
    window, shell = hideable_scene(engine, qtbot, "sidebarOpen: false")
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    pane = find(window, "sidebarPane")
    theme.setProperty("reducedMotion", False)
    reveal(window, shell, qtbot)
    assert pane.x() < 0  # sliding in over SuiTheme.duration * 2
    qtbot.waitUntil(lambda: pane.x() == 0, timeout=2000)
    QTest.mouseMove(window, FAR)
    qtbot.waitUntil(lambda: shell.property("sidebarRevealed") is False, timeout=2000)
    theme.setProperty("reducedMotion", True)
    reveal(window, shell, qtbot)
    assert pane.x() == 0  # instant
    window.close()


def test_settings_keep_the_sidebar_state(engine, qtbot, tmp_path):
    from PySide6.QtCore import QMetaObject, QUrl

    location = QUrl.fromLocalFile(str(tmp_path / "shell.ini")).toString()
    extra = f'settingsCategory: "shell"; settingsLocation: "{location}"'
    window, shell = hideable_scene(engine, qtbot, extra)
    assert shell.property("sidebarOpen") is True  # nothing stored yet
    shell.setProperty("sidebarWidth", 300)
    shell.setProperty("sidebarOpen", False)
    QMetaObject.invokeMethod(find(window, "settingsLoader").property("item"), "sync")
    stored = (tmp_path / "shell.ini").read_text()
    assert "[shell]" in stored and "sidebarOpen=false" in stored and "sidebarWidth=300" in stored
    window.close()

    window, shell = hideable_scene(engine, qtbot, extra)
    assert shell.property("sidebarOpen") is False
    assert shell.property("sidebarWidth") == 300
    assert not find(window, "sidebarPane").isVisible()  # restored without animating
    assert find(window, "contentPane").x() == 0
    window.close()
