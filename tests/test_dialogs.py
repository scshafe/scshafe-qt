"""SuiDialog, SuiSheet, SuiShortcutOverlay (focus trap, Escape, focus return) and
SuiSearchField (the `/` hook, Escape clears)."""

from __future__ import annotations

import pytest
from conftest import find, owner, spy, visible_rings, window_scene
from PySide6.QtCore import QMetaObject, Qt
from PySide6.QtGui import QAccessible
from PySide6.QtTest import QTest

SCENE = """
Column { x: 20; y: 20; spacing: 8
    SuiButton { objectName: "opener"; text: "Open"; onClicked: dlg.open() }
    SuiButton { objectName: "other"; text: "Other" }
}
%s {
    id: dlg; objectName: "dialog"; title: "Always sort this sender?"
    SuiTextField { objectName: "field"; width: 200; label: "Note" }
    actions: [
        SuiButton { objectName: "cancel"; text: "Cancel"; onClicked: dlg.reject() },
        SuiButton { objectName: "ok"; text: "Always"; variant: "primary"; onClicked: dlg.accept() }
    ]
}
"""
INSIDE = {"field", "cancel", "ok"}


def scene(engine, qtbot, kind: str = "SuiDialog"):
    window = window_scene(engine, qtbot, SCENE % kind, 800, 600)
    engine.singletonInstance("Scshafe.Ui", "SuiTheme").setProperty("reducedMotion", True)
    return window, find(window, "dialog")


def open_with_keyboard(window, qtbot, dialog):
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert window.activeFocusItem().objectName() == "opener"
    QTest.keyClick(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: dialog.property("opened"))


def focused(window):
    return owner(window.activeFocusItem(), INSIDE | {"opener", "other"})


@pytest.mark.parametrize("kind", ["SuiDialog", "SuiSheet"])
def test_opening_moves_focus_inside(engine, qtbot, kind):
    window, dialog = scene(engine, qtbot, kind)
    open_with_keyboard(window, qtbot, dialog)
    assert focused(window) == "field"
    window.close()


@pytest.mark.parametrize("kind", ["SuiDialog", "SuiSheet"])
def test_tab_is_trapped_inside(engine, qtbot, kind):
    window, dialog = scene(engine, qtbot, kind)
    open_with_keyboard(window, qtbot, dialog)
    forward = []
    for _ in range(6):
        QTest.keyClick(window, Qt.Key.Key_Tab)
        forward.append(focused(window))
    assert forward == ["cancel", "ok", "field", "cancel", "ok", "field"]
    backward = []
    for _ in range(3):
        QTest.keyClick(window, Qt.Key.Key_Backtab)
        backward.append(focused(window))
    assert backward == ["ok", "cancel", "field"]
    window.close()


@pytest.mark.parametrize("kind", ["SuiDialog", "SuiSheet"])
def test_escape_rejects_and_returns_focus_with_the_ring(engine, qtbot, kind):
    window, dialog = scene(engine, qtbot, kind)
    rejected = spy(dialog, "rejected()")
    open_with_keyboard(window, qtbot, dialog)
    QTest.keyClick(window, Qt.Key.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert rejected.count() == 1
    opener = find(window, "opener")
    assert opener.hasActiveFocus()
    assert opener.property("visualFocus") is True  # opened from the keyboard: ring comes back
    assert len(visible_rings(window.contentItem())) == 1
    window.close()


def test_accept_closes_and_returns_focus(engine, qtbot):
    window, dialog = scene(engine, qtbot)
    accepted = spy(dialog, "accepted()")
    open_with_keyboard(window, qtbot, dialog)
    find(window, "ok").forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert accepted.count() == 1
    assert find(window, "opener").hasActiveFocus()
    window.close()


def test_pointer_opened_dialog_returns_focus_without_ring(engine, qtbot):
    window, dialog = scene(engine, qtbot)
    opener = find(window, "opener")
    centre = opener.mapToScene(opener.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    qtbot.waitUntil(lambda: dialog.property("opened"))
    QTest.keyClick(window, Qt.Key.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert opener.hasActiveFocus()
    assert opener.property("visualFocus") is False
    window.close()


def test_explicit_opener_receives_focus(engine, qtbot):
    window, dialog = scene(engine, qtbot)
    other = find(window, "other")
    dialog.setProperty("opener", other)
    find(window, "opener").forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QMetaObject.invokeMethod(dialog, "open")
    qtbot.waitUntil(lambda: dialog.property("opened"))
    QTest.keyClick(window, Qt.Key.Key_Escape)
    qtbot.waitUntil(lambda: not dialog.property("visible"))
    assert other.hasActiveFocus()
    window.close()


@pytest.mark.parametrize("kind", ["SuiDialog", "SuiSheet"])
def test_dialog_is_an_accessible_dialog(engine, qtbot, kind):
    """Role Dialog named by the title (Qt names it once accessibility is active, as with a screen reader)."""
    QAccessible.setActive(True)
    try:
        window, dialog = scene(engine, qtbot, kind)
        open_with_keyboard(window, qtbot, dialog)
        item, dialog_iface = find(window, "field"), None
        while item is not None and dialog_iface is None:
            iface = QAccessible.queryAccessibleInterface(item)
            if iface is not None and iface.role() == QAccessible.Role.Dialog:
                dialog_iface = iface
            item = item.parentItem()
        assert dialog_iface is not None, "no Dialog role above the content"
        assert dialog_iface.text(QAccessible.Text.Name) == "Always sort this sender?"
        window.close()
    finally:
        QAccessible.setActive(False)


def test_sheet_slides_in_from_the_right(engine, qtbot):
    window, dialog = scene(engine, qtbot, "SuiSheet")
    open_with_keyboard(window, qtbot, dialog)
    assert dialog.property("width") == 400
    assert dialog.property("x") == 800 - 400
    assert dialog.property("height") == 600
    window.close()


# ---- SuiShortcutOverlay ----------------------------------------------------

OVERLAY = """
SuiTextField { objectName: "field"; x: 20; y: 20; width: 200; label: "Note" }
SuiButton { objectName: "button"; x: 20; y: 60; text: "Go" }
SuiShortcutOverlay {
    objectName: "overlay"
    shortcuts: [
        { group: "Navigation", keys: ["j"], description: "Next message" },
        { group: "Navigation", keys: "k", description: "Previous message" },
        { group: "Sorting", keys: ["1", "8"], separator: "–", description: "Sort into a bucket" }
    ]
}
"""


def overlay_scene(engine, qtbot):
    window = window_scene(engine, qtbot, OVERLAY, 800, 600)
    engine.singletonInstance("Scshafe.Ui", "SuiTheme").setProperty("reducedMotion", True)
    return window, find(window, "overlay")


def test_question_mark_toggles_the_overlay(engine, qtbot):
    window, overlay = overlay_scene(engine, qtbot)
    button = find(window, "button")
    button.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, "?")
    qtbot.waitUntil(lambda: overlay.property("opened"))
    names = []

    def walk(item):
        if item.objectName() == "shortcutDescription":
            names.append(item.property("text"))
        for child in item.childItems():
            walk(child)

    walk(window.contentItem())
    assert names == ["Next message", "Previous message", "Sort into a bucket"]
    QTest.keyClick(window, Qt.Key.Key_Escape)
    qtbot.waitUntil(lambda: not overlay.property("visible"))
    assert button.hasActiveFocus()
    window.close()


def test_question_mark_types_into_a_text_field(engine, qtbot):
    window, overlay = overlay_scene(engine, qtbot)
    field = find(window, "field")
    field.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, "?")
    QTest.qWait(50)
    assert not overlay.property("visible")
    assert field.property("text") == "?"
    window.close()


def test_overlay_entries_are_accessible(engine, qtbot):
    window, overlay = overlay_scene(engine, qtbot)
    QMetaObject.invokeMethod(overlay, "open")
    qtbot.waitUntil(lambda: overlay.property("opened"))
    items = []

    def walk(item):
        iface = QAccessible.queryAccessibleInterface(item)
        if iface is not None and iface.role() == QAccessible.Role.ListItem:
            items.append(iface.text(QAccessible.Text.Name))
        for child in item.childItems():
            walk(child)

    walk(window.contentItem())
    assert items == ["j: Next message", "k: Previous message", "1 – 8: Sort into a bucket"]
    window.close()


# ---- SuiSearchField --------------------------------------------------------

SEARCH = """
SuiSearchField { objectName: "search"; x: 20; y: 20; width: 240 }
SuiButton { objectName: "button"; x: 20; y: 60; text: "Go" }
SuiTextField { objectName: "other"; x: 20; y: 100; width: 200; label: "Other" }
"""


def test_slash_focuses_search_and_fires_the_hook(engine, qtbot):
    window = window_scene(engine, qtbot, SEARCH)
    search = find(window, "search")
    hook = spy(search, "focusRequested()")
    find(window, "button").forceActiveFocus(Qt.FocusReason.TabFocusReason)
    search.setProperty("text", "ada")
    QTest.keyClick(window, "/")
    assert hook.count() == 1
    assert search.hasActiveFocus()
    assert search.property("selectedText") == "ada"
    assert search.property("text") == "ada"  # the slash is not typed
    window.close()


def test_slash_in_another_field_is_text(engine, qtbot):
    window = window_scene(engine, qtbot, SEARCH)
    search, other = find(window, "search"), find(window, "other")
    hook = spy(search, "focusRequested()")
    other.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, "/")
    assert hook.count() == 0
    assert other.property("text") == "/"
    window.close()


def test_escape_clears_then_propagates(engine, qtbot):
    window = window_scene(engine, qtbot, SEARCH)
    search = find(window, "search")
    cleared = spy(search, "cleared()")
    search.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    for ch in "relay":
        QTest.keyClick(window, ch)
    assert find(window, "clearButton").isVisible()
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert search.property("text") == "" and cleared.count() == 1
    assert not find(window, "clearButton").isVisible()
    QTest.keyClick(window, Qt.Key.Key_Escape)  # empty: not handled, nothing to clear
    assert cleared.count() == 1
    window.close()


def test_clear_button(engine, qtbot):
    window = window_scene(engine, qtbot, SEARCH)
    search = find(window, "search")
    search.setProperty("text", "relay")
    clear = find(window, "clearButton")
    iface = QAccessible.queryAccessibleInterface(clear)
    assert iface.text(QAccessible.Text.Name) == "Clear search"
    centre = clear.mapToScene(clear.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert search.property("text") == ""
    assert search.hasActiveFocus()
    window.close()


def test_clear_button_is_not_a_tab_stop(engine, qtbot):
    window = window_scene(engine, qtbot, SEARCH)
    find(window, "search").setProperty("text", "x")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "search").hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "button").hasActiveFocus()
    window.close()
