"""SuiList and SuiSidebarList: keyboard navigation, the hook signals, activation."""

from __future__ import annotations

import pytest
from conftest import find, spy, visible_rings, window_scene
from PySide6.QtCore import Qt
from PySide6.QtGui import QAccessible
from PySide6.QtTest import QTest

LIST = """
ListModel { id: msgs
    ListElement { sender: "Ada"; subject: "Engines"; time: "09:41"; unread: true }
    ListElement { sender: "Grace"; subject: "Relays"; time: "09:12"; unread: false }
    ListElement { sender: "Alan"; subject: "Machines"; time: "08:00"; unread: false }
    ListElement { sender: "Edsger"; subject: "Goto"; time: "07:30"; unread: false }
}
SuiButton { objectName: "before"; text: "Before" }
SuiList { objectName: "list"; y: 40; width: 360; height: 240; label: "Messages"; model: msgs
    %s
    delegate: SuiListRow { objectName: "row" + index; width: ListView.view.width
        title: model.sender; subtitle: model.subject; meta: model.time; unread: model.unread
        SuiChip { objectName: "chip" + index; text: "b"; tone: index + 1 } } }
SuiButton { objectName: "after"; y: 290; text: "After" }
"""

SIDEBAR = """
SuiSidebarList { objectName: "sidebar"; width: 240; height: 300; label: "Mailboxes"; %s
    model: [
        { section: "Mailboxes", text: "Unsorted", iconName: "inbox", count: 12, status: "ok" },
        { section: "Mailboxes", text: "Archive", iconName: "archive", enabled: false },
        { section: "Buckets", text: "Receipts", iconName: "tag", count: 3, status: "held" },
        { section: "Buckets", text: "Bills", iconName: "tag", count: 1, status: "failing" }
    ] }
SuiButton { objectName: "after"; y: 310; text: "After" }
"""


def list_scene(engine, qtbot, extra: str = ""):
    window = window_scene(engine, qtbot, LIST % extra, 400, 340)
    QTest.keyClick(window, Qt.Key.Key_Tab)  # Before
    QTest.keyClick(window, Qt.Key.Key_Tab)  # the list
    lst = find(window, "list")
    assert lst.hasActiveFocus()
    return window, lst


def key(window, k, text=""):
    QTest.keyClick(window, k, Qt.KeyboardModifier.NoModifier)


def test_list_is_one_tab_stop(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    assert window.activeFocusItem().objectName() == "row0"  # the current row holds focus (a11y)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert window.activeFocusItem().objectName() == "after"
    QTest.keyClick(window, Qt.Key.Key_Backtab)
    assert lst.hasActiveFocus()
    window.close()


@pytest.mark.parametrize(("down", "up"), [(Qt.Key.Key_Down, Qt.Key.Key_Up), (Qt.Key.Key_J, Qt.Key.Key_K)])
def test_navigation_keys_emit_hooks_and_move(engine, qtbot, down, up):
    window, lst = list_scene(engine, qtbot)
    nxt, prev = spy(lst, "nextRequested()"), spy(lst, "previousRequested()")
    QTest.keyClick(window, down)
    QTest.keyClick(window, down)
    assert nxt.count() == 2 and lst.property("currentIndex") == 2
    QTest.keyClick(window, up)
    assert prev.count() == 1 and lst.property("currentIndex") == 1
    assert window.activeFocusItem().objectName() == "row1"
    assert len(visible_rings(window.contentItem())) == 1
    window.close()


def test_navigation_clamps_at_the_ends(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_Up)
    assert lst.property("currentIndex") == 0
    QTest.keyClick(window, Qt.Key.Key_End)
    assert lst.property("currentIndex") == 3
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert lst.property("currentIndex") == 3
    QTest.keyClick(window, Qt.Key.Key_Home)
    assert lst.property("currentIndex") == 0
    window.close()


def test_auto_navigate_off_leaves_moves_to_the_app(engine, qtbot):
    window, lst = list_scene(engine, qtbot, "autoNavigate: false")
    nxt = spy(lst, "nextRequested()")
    QTest.keyClick(window, Qt.Key.Key_J)
    assert nxt.count() == 1
    assert lst.property("currentIndex") == 0  # the app decides
    window.close()


def test_vim_keys_can_be_turned_off(engine, qtbot):
    window, lst = list_scene(engine, qtbot, "vimKeys: false")
    nxt = spy(lst, "nextRequested()")
    QTest.keyClick(window, Qt.Key.Key_J)
    assert nxt.count() == 0 and lst.property("currentIndex") == 0
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert nxt.count() == 1 and lst.property("currentIndex") == 1
    window.close()


def test_modified_keys_are_left_alone(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_J, Qt.KeyboardModifier.ControlModifier)
    assert lst.property("currentIndex") == 0
    window.close()


def test_enter_activates_the_selection(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    activated = spy(lst, "activated(int)")
    QTest.keyClick(window, Qt.Key.Key_Down)
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert activated.count() == 1 and activated.at(0) == [1]
    window.close()


def test_selection_functions_for_app_shortcuts(engine, qtbot):
    from PySide6.QtCore import QMetaObject

    window = window_scene(engine, qtbot, LIST % "", 400, 340)
    lst = find(window, "list")
    QMetaObject.invokeMethod(lst, "selectLast")
    assert lst.property("currentIndex") == 3
    QMetaObject.invokeMethod(lst, "selectPrevious")
    assert lst.property("currentIndex") == 2
    QMetaObject.invokeMethod(lst, "selectFirst")
    assert lst.property("currentIndex") == 0
    window.close()


def test_pointer_selects_and_double_click_activates(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    activated = spy(lst, "activated(int)")
    row = find(window, "row2")
    centre = row.mapToScene(row.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert lst.property("currentIndex") == 2
    assert visible_rings(window.contentItem()) == []
    QTest.mouseDClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert activated.count() >= 1 and activated.at(activated.count() - 1) == [2]
    window.close()


def test_rows_expose_state_to_accessibility(engine, qtbot):
    window, lst = list_scene(engine, qtbot)
    row0 = QAccessible.queryAccessibleInterface(find(window, "row0"))
    row1 = QAccessible.queryAccessibleInterface(find(window, "row1"))
    assert row0.role() == QAccessible.Role.ListItem
    assert row0.text(QAccessible.Text.Name) == "Unread, Ada, Engines, 09:41"
    assert row0.state().selected and row0.state().selectable
    assert not row1.state().selected
    assert find(window, "chip0").property("text") == "b"  # the trailing slot
    window.close()


# ---- SuiSidebarList --------------------------------------------------------


def sidebar_scene(engine, qtbot, extra: str = "selectedIndex: 0"):
    window = window_scene(engine, qtbot, SIDEBAR % extra, 260, 360)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    sidebar = find(window, "sidebar")
    assert sidebar.hasActiveFocus()
    return window, sidebar


def test_sidebar_arrows_skip_disabled_entries(engine, qtbot):
    window, sidebar = sidebar_scene(engine, qtbot)
    assert sidebar.property("currentIndex") == 0
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert sidebar.property("currentIndex") == 2  # "Archive" is disabled
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert sidebar.property("currentIndex") == 3
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert sidebar.property("currentIndex") == 3
    QTest.keyClick(window, Qt.Key.Key_Up)
    QTest.keyClick(window, Qt.Key.Key_Up)
    assert sidebar.property("currentIndex") == 0
    window.close()


@pytest.mark.parametrize("activate", [Qt.Key.Key_Return, Qt.Key.Key_Enter, Qt.Key.Key_Space])
def test_sidebar_enter_activates(engine, qtbot, activate):
    window, sidebar = sidebar_scene(engine, qtbot)
    spied = spy(sidebar, "activated(int)")
    QTest.keyClick(window, Qt.Key.Key_End)
    assert sidebar.property("selectedIndex") == 0  # moving does not select
    QTest.keyClick(window, activate)
    assert spied.count() == 1 and spied.at(0) == [3]
    assert sidebar.property("selectedIndex") == 3
    window.close()


def test_sidebar_focus_starts_at_the_selection(engine, qtbot):
    window, sidebar = sidebar_scene(engine, qtbot, "selectedIndex: 2")
    assert sidebar.property("currentIndex") == 2
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert window.activeFocusItem().objectName() == "after"
    window.close()


def test_sidebar_click_activates_without_ring(engine, qtbot):
    window, sidebar = sidebar_scene(engine, qtbot)
    spied = spy(sidebar, "activated(int)")
    headers = []

    def walk(item):
        if item.objectName() == "sectionHeader" and item.isVisible():
            headers.append(item.property("text"))
        for c in item.childItems():
            walk(c)

    walk(sidebar)
    assert sorted(headers) == ["Buckets", "Mailboxes"]
    QTest.keyClick(window, Qt.Key.Key_End)
    item = sidebar.property("currentItem")
    centre = item.mapToScene(item.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert spied.count() == 1 and spied.at(0) == [3]
    assert visible_rings(window.contentItem()) == []
    window.close()
