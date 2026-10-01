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
