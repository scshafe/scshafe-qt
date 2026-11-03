"""SuiListHeader: the compact search field (⌘F from anywhere, Escape clears), the filter
menu by pointer and keyboard (toggling, exclusive sections, Clear), the active tint and
count badge, the result count, accessibility; and SuiSearchField's compact size."""

from __future__ import annotations

from conftest import find, spy, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest

LEFT = Qt.MouseButton.LeftButton
NONE = Qt.KeyboardModifier.NoModifier
CTRL = Qt.KeyboardModifier.ControlModifier

FILTERS = """[
    { key: "missing", text: "Missing", section: "Show", exclusive: true },
    { key: "kept", text: "Kept", section: "Show", exclusive: true },
    { key: "long", text: "Long-form", section: "Labels" },
    { key: "noisy", text: "Noisy", section: "Labels" }
]"""


def header_scene(engine, qtbot, props: str = ""):
    window = window_scene(
        engine, qtbot,
        'SuiTextField { objectName: "other"; x: 20; y: 200; width: 160; label: "Note" }\n'
        f'SuiListHeader {{ objectName: "h"; x: 20; y: 20; width: 360; searchLabel: "Search prompts";'
        f" filters: {FILTERS}; {props} }}",
    )
    return window, find(window, "h")


def js(obj, code: str):
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    expression = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    value, _undefined = expression.evaluate()
    assert not expression.hasError(), expression.error().toString()
    return value


def active(header) -> list:
    value = header.property("activeFilters")
    return list(value.toVariant() if hasattr(value, "toVariant") else value)


def centre(item) -> QPoint:
    return item.mapToScene(item.boundingRect().center()).toPoint()


def menu_open(window) -> bool:
    return find(window, "filterOptions").isVisible()


def option(window, key: str):
    return find(window, "filterOption_" + key)


def choose(window, qtbot, key: str) -> None:
    """Open the menu with the pointer and click the option."""
    QTest.mouseClick(window, LEFT, NONE, centre(find(window, "filterButton")))
    qtbot.waitUntil(lambda: menu_open(window))
    QTest.qWait(150)  # the fade
    QTest.mouseClick(window, LEFT, NONE, centre(option(window, key)))
    qtbot.waitUntil(lambda: not menu_open(window))


# ---- Sizes and search ---------------------------------------------------------------


def test_everything_is_compact(engine, qtbot, theme):
    window, header = header_scene(engine, qtbot)
    small = theme.property("controlHeightSm")
    assert header.height() == small
    search, button = find(window, "listSearch"), find(window, "filterButton")
    assert search.height() == small and search.property("compact") is True
    assert (button.width(), button.height()) == (small, small)
    assert search.property("font").pixelSize() == theme.property("fontSizeSm")
    assert find(search, "searchIcon").property("size") == theme.property("iconSizeSm")
    window.close()


def test_a_standalone_search_field_keeps_its_size(engine, qtbot, theme):
    window = window_scene(engine, qtbot, 'SuiSearchField { objectName: "s" } SuiTextField { objectName: "t"; y: 40; compact: true; label: "x" }')
    assert find(window, "s").height() == theme.property("controlHeight")
    assert find(window, "t").height() == theme.property("controlHeightSm")
    window.close()


def test_cmd_f_focuses_the_search_from_a_text_field(engine, qtbot):
    window, header = header_scene(engine, qtbot, 'text: "ada"')
    other = find(window, "other")
    other.forceActiveFocus(Qt.FocusReason.MouseFocusReason)
    QTest.keyClick(window, Qt.Key.Key_F, CTRL)  # ⌘F on macOS (Qt maps Ctrl to Command)
    search = find(window, "listSearch")
    assert search.hasActiveFocus()
    assert search.property("selectedText") == "ada"
    edited, cleared = spy(header, "textEdited()"), spy(header, "cleared()")
    QTest.keyClick(window, Qt.Key.Key_B)
    assert header.property("text") == "b" and edited.count() == 1
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert header.property("text") == "" and cleared.count() == 1
    window.close()


def test_the_focus_shortcut_can_change_or_go(engine, qtbot):
    window, header = header_scene(engine, qtbot, 'focusShortcut: ""')
    find(window, "other").forceActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_F, CTRL)
    assert not find(window, "listSearch").hasActiveFocus()
    window.close()


# ---- The filter menu ------------------------------------------------------------------


def test_the_menu_by_pointer_toggles_a_filter(engine, qtbot):
    window, header = header_scene(engine, qtbot)
    toggled = spy(header, "filterToggled(QString,bool)")
    choose(window, qtbot, "long")
    assert active(header) == ["long"]
    assert [list(toggled.at(i)) for i in range(toggled.count())] == [["long", True]]
    choose(window, qtbot, "long")
    assert active(header) == []
    assert list(toggled.at(1)) == ["long", False]
    assert visible_rings(window.contentItem()) == []  # pointer use: no ring
    window.close()


def test_an_exclusive_section_is_one_choice(engine, qtbot):
    window, header = header_scene(engine, qtbot, 'activeFilters: ["missing", "long"]')
    toggled = spy(header, "filterToggled(QString,bool)")
    js(header, 'toggleFilter("kept")')
    assert sorted(active(header)) == ["kept", "long"]
    assert [list(toggled.at(i)) for i in range(toggled.count())] == [["missing", False], ["kept", True]]
    js(header, 'toggleFilter("noisy")')  # a non-exclusive section adds
    assert sorted(active(header)) == ["kept", "long", "noisy"]
    window.close()


def test_the_menu_by_keyboard(engine, qtbot):
    window, header = header_scene(engine, qtbot)
    button = find(window, "filterButton")
    button.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    assert len(visible_rings(window.contentItem())) == 1
    QTest.keyClick(window, Qt.Key.Key_Down)
    qtbot.waitUntil(lambda: menu_open(window))
    assert find(window, "filterOptions").property("currentIndex") == 1  # the first option, past "Show"
    QTest.keyClick(window, Qt.Key.Key_Down)  # Kept
    QTest.keyClick(window, Qt.Key.Key_Return)
    qtbot.waitUntil(lambda: not menu_open(window))
    assert active(header) == ["kept"]
    assert button.hasActiveFocus()  # back on the button, with its ring
    qtbot.waitUntil(lambda: len(visible_rings(window.contentItem())) == 1)
    QTest.keyClick(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: menu_open(window))
    QTest.keyClick(window, Qt.Key.Key_Escape)
    qtbot.waitUntil(lambda: not menu_open(window))
    assert active(header) == ["kept"]
    assert button.hasActiveFocus()
    window.close()


def test_clear_filters(engine, qtbot):
    window, header = header_scene(engine, qtbot, 'activeFilters: ["kept", "noisy"]')
    toggled, cleared = spy(header, "filterToggled(QString,bool)"), spy(header, "filtersCleared()")
    choose(window, qtbot, "noisy")  # off
    QTest.mouseClick(window, LEFT, NONE, centre(find(window, "filterButton")))
    qtbot.waitUntil(lambda: menu_open(window))
    QTest.qWait(150)
    clear = find(window, "clearFilters")
    assert clear.isEnabled()
    QTest.mouseClick(window, LEFT, NONE, centre(clear))
    qtbot.waitUntil(lambda: not menu_open(window))
    assert active(header) == []
    assert cleared.count() == 1
    assert list(toggled.at(toggled.count() - 1)) == ["kept", False]
    QTest.mouseClick(window, LEFT, NONE, centre(find(window, "filterButton")))
    qtbot.waitUntil(lambda: menu_open(window))
    assert not find(window, "clearFilters").isEnabled()  # nothing to clear
    window.close()


def test_options_show_their_state_and_sections(engine, qtbot):
    window, header = header_scene(engine, qtbot, 'activeFilters: ["long"]')
    QTest.mouseClick(window, LEFT, NONE, centre(find(window, "filterButton")))
    qtbot.waitUntil(lambda: menu_open(window))
    long_iface = QAccessible.queryAccessibleInterface(option(window, "long"))
    assert long_iface.role() == QAccessible.Role.MenuItem and long_iface.state().checked
    assert not QAccessible.queryAccessibleInterface(option(window, "noisy")).state().checked
    menu = find(window, "filterOptions")
    sections = [i for i in menu.property("contentItem").childItems() if i.objectName() == "filterSection"]
    assert [find(s, "optionText").property("text") for s in sections] == ["Show", "Labels"]
    assert all(not s.isEnabled() for s in sections)  # skipped by the keyboard
    window.close()


# ---- The active indicator, the count, accessibility -----------------------------------


def test_an_active_filter_tints_the_button_and_shows_the_count(engine, qtbot, theme):
    window, header = header_scene(engine, qtbot)
    button, icon, badge = find(window, "filterButton"), find(window, "filterIcon"), find(window, "filterBadge")
    assert not badge.isVisible()
    assert QColor(icon.property("color")) == QColor(theme.property("muted"))
    iface = QAccessible.queryAccessibleInterface(button)
    assert iface.role() == QAccessible.Role.ButtonMenu and iface.text(QAccessible.Text.Name) == "Filters"
    assert iface.text(QAccessible.Text.Description) == "None active"
    header.setProperty("activeFilters", ["missing", "noisy"])
    qtbot.waitUntil(lambda: QColor(icon.property("color")) == QColor(theme.property("accent")))
    assert badge.isVisible() and find(window, "filterBadgeText").property("text") == "2"
    assert header.property("filterCount") == 2
    assert iface.text(QAccessible.Text.Description) == "2 active: Missing, Noisy"
    # The badge sits on the button's top-right corner, inside the window.
    rect = badge.mapRectToScene(badge.boundingRect())
    corner = button.mapToScene(button.boundingRect().topRight())
    assert abs(rect.center().x() - corner.x()) <= theme.property("spaceXs")
    assert abs(rect.center().y() - corner.y()) <= theme.property("spaceXs")
    window.close()


def test_no_filters_no_button(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiListHeader { objectName: "h"; width: 300 }')
    assert not find(window, "filterButton").isVisible()
    window.close()


def test_python_lists_work(engine, qtbot):
    window, header = header_scene(engine, qtbot)
    header.setProperty("filters", [{"key": "a", "text": "A"}, {"key": "b", "text": "B", "section": "More"}])
    header.setProperty("activeFilters", ["b"])
    assert header.property("filterCount") == 1
    iface = QAccessible.queryAccessibleInterface(find(window, "filterButton"))
    assert iface.text(QAccessible.Text.Description) == "1 active: B"
    window.close()


def test_the_result_count(engine, qtbot):
    window, header = header_scene(engine, qtbot)
    count = find(window, "resultCount")
    assert not count.isVisible()
    header.setProperty("resultCount", 12)
    assert count.isVisible() and count.property("text") == "12"
    header.setProperty("totalCount", 340)
    assert count.property("text") == "12 of 340"
    assert QAccessible.queryAccessibleInterface(count).text(QAccessible.Text.Name) == "12 of 340"
    header.setProperty("countText", "12 prompts")
    assert count.property("text") == "12 prompts"
    window.close()


def test_the_header_is_a_named_toolbar(engine, qtbot):
    window, header = header_scene(engine, qtbot)
    iface = QAccessible.queryAccessibleInterface(header)
    assert iface.role() == QAccessible.Role.ToolBar
    assert iface.text(QAccessible.Text.Name) == "Search and filters"
    search = QAccessible.queryAccessibleInterface(find(window, "listSearch"))
    assert search.text(QAccessible.Text.Name) == "Search prompts"
    window.close()
