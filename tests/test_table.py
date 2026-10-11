"""SuiTable: virtualised rows, sorting, column sizing, selection, keyboard, accessibility."""

from __future__ import annotations

import random
import time

import pytest
from conftest import find, find_item, spy, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest

ROW_H = 32  # SuiTheme.tableRowHeight
CTRL, SHIFT, NONE = Qt.KeyboardModifier.ControlModifier, Qt.KeyboardModifier.ShiftModifier, Qt.KeyboardModifier.NoModifier

COLUMNS = """[
    { key: "name", title: "Take", width: 160 },
    { key: "speaker", title: "Speaker", width: 100 },
    { key: "duration", title: "Duration", width: 110, align: "right", format: (v) => v.toFixed(1) + " s" },
    { key: "score", title: "Score", width: 90, align: "right", tone: (v) => v < 0.3 ? "danger" : "" },
    { key: "note", title: "Note", sortable: false }
]"""


def make_rows(n: int, seed: int = 7) -> list[dict]:
    r = random.Random(seed)
    speakers = ["Ana", "bo", "Cy", "Di"]
    return [{"id": i, "name": f"take-{i:05d}", "speaker": speakers[i % 4], "duration": round(r.random() * 60, 2),
             "score": round(r.random(), 3), "note": "" if i % 5 == 0 else f"note {i % 9}"} for i in range(n)]


def table_scene(engine, qtbot, rows=None, props: str = "", width: int = 640, height: int = 360):
    window = window_scene(
        engine, qtbot,
        f'SuiButton {{ objectName: "before"; text: "Before" }}\n'
        f'SuiTable {{ objectName: "t"; y: 40; width: {width}; height: {height - 40}; label: "Takes";'
        f' columns: {COLUMNS}; {props} }}',
        width=width, height=height,
    )
    table = find(window, "t")
    if rows is not None:
        table.setProperty("rows", rows)
    return window, table


def body(window):
    return find(window, "body")


def row_point(window, table, view_index: int) -> QPoint:
    """Window point in the middle of the row at view_index (it must be in view)."""
    lst = body(window)
    y = table.y() + lst.y() + view_index * ROW_H - lst.property("contentY") + ROW_H / 2
    return QPoint(60, int(y))


def click_row(window, table, view_index: int, modifier=NONE) -> None:
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, modifier, row_point(window, table, view_index))


def plain(value):
    return value.toVariant() if hasattr(value, "toVariant") else value


def view_rows(table) -> list[int]:
    return [int(i) for i in plain(table.property("_order"))]


def rows_of(table) -> list[dict]:
    return plain(table.property("rows"))


def column(table, key: str) -> list:
    rows = rows_of(table)
    return [rows[i][key] for i in view_rows(table)]


def delegates(window) -> list:
    content = body(window).property("contentItem")
    return [i for i in content.childItems() if i.objectName() == "row" and i.isVisible()]


def cells(row_item) -> list:
    out = []

    def walk(item):
        for child in item.childItems():
            if child.objectName() == "cell":
                out.append(child)
            walk(child)

    walk(row_item)
    return sorted(out, key=lambda c: c.x())


def selected(table) -> list[int]:
    return [int(x) for x in plain(table.property("selectedRows"))]


def js(obj, code: str):
    """Evaluate `code` with `obj` in scope (QML functions with optional arguments)."""
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    expression = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    value, _undefined = expression.evaluate()
    assert not expression.hasError(), expression.error().toString()
    return value


# ---- Rows, virtualisation and speed ----------------------------------------------


def test_ten_thousand_rows_are_virtualised(engine, qtbot):
    rows = make_rows(10_000)
    window, table = table_scene(engine, qtbot)
    started = time.perf_counter()
    table.setProperty("rows", rows)
    assigned = time.perf_counter() - started
    assert table.property("rowCount") == 10_000
    lst = body(window)
    # Rows in view plus the view's cache above and below (and a reuse pool): a few
    # dozen delegates, never one per row.
    bound = int((lst.height() + 2 * lst.property("cacheBuffer")) // ROW_H) + 8
    assert len(delegates(window)) <= bound, "only rows near the view exist"
    js(table, "positionViewAtRow(9999)")
    QTest.qWait(10)
    names = {plain(i.property("record"))["name"] for i in delegates(window)}
    assert "take-09999" in names
    assert len(delegates(window)) <= bound
    for step in range(0, 300_000, 7_919):  # scroll through: every frame stays small
        lst.setProperty("contentY", step)
        assert len(delegates(window)) <= bound
    print(f"10k rows assigned from Python in {assigned * 1000:.0f} ms")
    assert assigned < 2.0
    window.close()


def test_sorting_ten_thousand_rows_is_quick(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(10_000))
    timings = {}
    for key in ("name", "duration", "speaker", "score"):
        started = time.perf_counter()
        js(table, f"sortBy('{key}')")
        timings[key] = (time.perf_counter() - started) * 1000
    print("sort 10k rows (ms):", {k: round(v) for k, v in timings.items()})
    assert max(timings.values()) < 500
    durations = column(table, "score")
    assert durations == sorted(durations)
    window.close()


# ---- Sorting ----------------------------------------------------------------------


def test_header_click_sorts_then_reverses(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(50))
    cell = find(window, "headerCell2")  # Duration
    centre = cell.mapToScene(cell.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, NONE, centre)
    assert table.property("sortKey") == "duration"
    assert table.property("sortOrder") == Qt.SortOrder.AscendingOrder.value
    assert column(table, "duration") == sorted(column(table, "duration"))
    assert find_item(cell, "sortIcon").isVisible()
    iface = QAccessible.queryAccessibleInterface(cell)
    assert iface.role() == QAccessible.Role.ColumnHeader
    assert iface.text(QAccessible.Text.Name) == "Duration"
    assert iface.text(QAccessible.Text.Description) == "sorted ascending"
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, NONE, centre)
    assert table.property("sortOrder") == Qt.SortOrder.DescendingOrder.value
    assert column(table, "duration") == sorted(column(table, "duration"), reverse=True)
    assert iface.text(QAccessible.Text.Description) == "sorted descending"
    assert visible_rings(window.contentItem()) == []  # pointer focus: no ring
    note = find(window, "headerCell4")  # not sortable
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, NONE, note.mapToScene(note.boundingRect().center()).toPoint())
    assert table.property("sortKey") == "duration"
    window.close()


def test_sort_semantics_numbers_text_empties_and_ties(engine, qtbot):
    rows = [{"name": "b", "speaker": "x", "duration": 10, "score": 1}, {"name": "B", "speaker": "", "duration": 9, "score": 1},
            {"name": "a", "speaker": "y", "duration": 100, "score": None}, {"name": "c", "speaker": "x", "duration": 9.5,
                                                                             "score": 1}]
    window, table = table_scene(engine, qtbot, rows)
    js(table, "sortBy(\'duration\')")
    assert column(table, "duration") == [9, 9.5, 10, 100]  # numeric, not "10" < "9"
    js(table, "sortBy(\'name\')")
    assert column(table, "name") == ["a", "b", "B", "c"]  # case-insensitive; ties keep the rows' order
    js(table, "sortBy(\'speaker\')")
    assert column(table, "speaker") == ["x", "x", "y", ""]  # empty last
    js(table, "sortBy(\'speaker\')")  # descending: empty still last
    assert column(table, "speaker") == ["y", "x", "x", ""]
    js(table, "sortBy(\'score\')")
    assert [rows_of(table)[i]["name"] for i in view_rows(table)] == ["b", "B", "c", "a"]  # stable; None last
    table.setProperty("sortKey", "")
    assert view_rows(table) == [0, 1, 2, 3]
    window.close()


# ---- Selection ---------------------------------------------------------------------


def test_pointer_selection_multiple(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(30), 'selectionMode: "multiple"; sortKey: "duration"')
    order = view_rows(table)
    click_row(window, table, 2)
    assert selected(table) == [order[2]] and table.property("currentRow") == order[2]
    assert body(window).hasActiveFocus() and visible_rings(window.contentItem()) == []
    click_row(window, table, 5, CTRL)
    assert selected(table) == sorted([order[2], order[5]])
    click_row(window, table, 2, CTRL)  # toggles off; the anchor moves to it, as file managers do
    assert selected(table) == [order[5]]
    click_row(window, table, 8, SHIFT)  # a range in view order, from the anchor (2)
    assert selected(table) == sorted(order[2:9])
    click_row(window, table, 0, CTRL | SHIFT)  # Ctrl+Shift adds the range (anchor 2 to 0)
    assert selected(table) == sorted(order[0:9])
    click_row(window, table, 1)
    assert selected(table) == [order[1]]
    window.close()


def test_pointer_selection_single_and_none(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(20))
    click_row(window, table, 3)
    click_row(window, table, 6, CTRL)  # single: ctrl does not add
    assert selected(table) == [6]
    table.setProperty("selectionMode", "none")
    assert selected(table) == []
    click_row(window, table, 4)
    assert selected(table) == [] and table.property("currentRow") == 4
    window.close()


def test_keyboard_navigation_and_selection(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(100), 'selectionMode: "multiple"')
    activated = spy(table, "activated(int)")
    QTest.keyClick(window, Qt.Key.Key_Tab)  # the button
    QTest.keyClick(window, Qt.Key.Key_Tab)  # the header
    assert find(window, "headerCell0").hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_Tab)  # the body
    assert body(window).hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert table.property("currentRow") == 0 and selected(table) == [0]
    assert len(visible_rings(window.contentItem())) == 1
    QTest.keyClick(window, Qt.Key.Key_Down, SHIFT)
    QTest.keyClick(window, Qt.Key.Key_Down, SHIFT)
    assert selected(table) == [0, 1, 2]
    QTest.keyClick(window, Qt.Key.Key_Down, CTRL)  # moves without selecting
    assert table.property("currentRow") == 3 and selected(table) == [0, 1, 2]
    QTest.keyClick(window, Qt.Key.Key_Space)  # toggles the current row in
    assert selected(table) == [0, 1, 2, 3]
    QTest.keyClick(window, Qt.Key.Key_End)
    assert table.property("currentRow") == 99 and selected(table) == [99]
    lst = body(window)
    assert lst.property("contentY") > 0  # scrolled to it
    QTest.keyClick(window, Qt.Key.Key_PageUp)
    page = int(lst.height() // ROW_H) - 1
    assert table.property("currentRow") == 99 - page
    QTest.keyClick(window, Qt.Key.Key_Home)
    assert table.property("currentRow") == 0
    QTest.keyClick(window, Qt.Key.Key_A, CTRL)
    assert len(selected(table)) == 100
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert activated.count() == 1 and activated.at(0) == [0]
    window.close()


def test_double_click_activates_the_row(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(20), 'sortKey: "duration"')
    activated = spy(table, "activated(int)")
    QTest.mouseDClick(window, Qt.MouseButton.LeftButton, NONE, row_point(window, table, 3))
    assert activated.count() == 1 and activated.at(0) == [view_rows(table)[3]]
    window.close()


def test_selection_survives_sorting_and_keyed_new_rows(engine, qtbot):
    rows = make_rows(40)
    window, table = table_scene(engine, qtbot, rows, 'selectionMode: "multiple"; rowKey: "id"')
    js(table, "select([3, 7, 11])")
    js(table, "setCurrentRow(7)")
    js(table, "sortBy(\'duration\')")
    assert selected(table) == [3, 7, 11] and table.property("currentRow") == 7  # rows, not positions
    current_item = body(window).property("currentItem")
    assert plain(current_item.property("record"))["id"] == 7
    shuffled = rows[:]
    random.Random(1).shuffle(shuffled)
    table.setProperty("rows", shuffled + [{"id": 999, "name": "new", "duration": 1.0, "score": 0.5}])
    ids = [rows_of(table)[i]["id"] for i in selected(table)]
    assert sorted(ids) == [3, 7, 11]
    assert rows_of(table)[table.property("currentRow")]["id"] == 7
    table.setProperty("rowKey", "")
    table.setProperty("rows", rows)  # without a key, a new array clears them
    assert selected(table) == [] and table.property("currentRow") == -1
    window.close()


# ---- Columns -------------------------------------------------------------------------


def test_drag_resizes_and_double_click_resets(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(10))
    resized = spy(table, "columnResized(QString,double)")
    cell = find(window, "headerCell0")
    handle = find(window, "resizeHandle0")
    start = handle.mapToScene(handle.boundingRect().center()).toPoint()
    QTest.mousePress(window, Qt.MouseButton.LeftButton, NONE, start)
    for dx in range(0, 61, 10):
        QTest.mouseMove(window, start + QPoint(dx, 0))
    QTest.mouseRelease(window, Qt.MouseButton.LeftButton, NONE, start + QPoint(60, 0))
    assert cell.width() == pytest.approx(220, abs=2)
    assert resized.count() >= 1 and resized.at(resized.count() - 1)[0] == "name"
    assert plain(table.property("columnWidths"))["name"] == pytest.approx(cell.width(), abs=0.5)
    assert table.property("sortKey") == ""  # a press on the edge does not sort
    assert cells(delegates(window)[0])[0].width() == pytest.approx(cell.width())  # the body follows the header
    QTest.mouseDClick(window, Qt.MouseButton.LeftButton, NONE, handle.mapToScene(handle.boundingRect().center()).toPoint())
    assert cell.width() == pytest.approx(160)
    assert "name" not in plain(table.property("columnWidths"))
    window.close()


def test_widths_clamp_restore_and_fill(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(5), "columnWidths: ({ speaker: 10, score: 5000 })")
    assert find(window, "headerCell1").width() == 48  # SuiTheme.tableMinColumnWidth
    assert find(window, "headerCell3").width() == 960  # SuiTheme.tableMaxColumnWidth
    table.setProperty("columnWidths", {})
    widths = [find(window, f"headerCell{i}").width() for i in range(5)]
    assert widths[:4] == [160, 100, 110, 90]
    assert sum(widths) == pytest.approx(body(window).width())  # the last column fills the view
    window.close()


def test_header_keyboard_moves_sorts_and_resizes(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(20))
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    first = find(window, "headerCell0")
    assert first.hasActiveFocus()
    rings = visible_rings(window.contentItem())
    assert len(rings) == 1 and rings[0].parentItem() is first
    QTest.keyClick(window, Qt.Key.Key_Right)
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert find(window, "headerCell2").hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_Return)
    assert table.property("sortKey") == "duration"
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert table.property("sortOrder") == Qt.SortOrder.DescendingOrder.value
    QTest.keyClick(window, Qt.Key.Key_Right, CTRL)
    assert find(window, "headerCell2").width() == 110 + 16  # SuiTheme.splitterStep
    QTest.keyClick(window, Qt.Key.Key_Left, CTRL | SHIFT)
    assert find(window, "headerCell2").width() == 110 + 16 - 64
    QTest.keyClick(window, Qt.Key.Key_End)
    assert find(window, "headerCell4").hasActiveFocus()
    window.close()


def test_horizontal_scrolling_keeps_the_header_aligned(engine, qtbot):
    window, table = table_scene(engine, qtbot, make_rows(20), width=360)
    lst = body(window)
    assert lst.property("contentWidth") > lst.width()
    lst.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.keyClick(window, Qt.Key.Key_Right)
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert lst.property("contentX") > 0
    header_row = find(window, "headerCell0").parentItem()
    assert header_row.x() == pytest.approx(-lst.property("contentX"))
    assert find(window, "horizontalScrollBar").isVisible()
    window.close()


# ---- Cells and accessibility ------------------------------------------------------------


def test_cells_format_tone_and_alignment(engine, qtbot, theme):
    rows = [{"name": "take-1", "speaker": "Ana", "duration": 12.345, "score": 0.1, "note": "<b>x</b>"}]
    window, table = table_scene(engine, qtbot, rows)
    row = cells(delegates(window)[0])
    assert [c.property("text") for c in row] == ["take-1", "Ana", "12.3 s", "0.1", "<b>x</b>"]
    assert QColor(row[3].property("color")) == QColor(theme.property("toneRedText"))  # tone(): danger
    assert QColor(row[0].property("color")) == QColor(theme.property("text"))
    assert js(row[2], "horizontalAlignment === Text.AlignRight") is True
    assert row[4].property("lineCount") == 1 and row[4].property("contentWidth") > 30  # markup shown as text
    window.close()


def test_accessibility(engine, qtbot):
    rows = [{"name": "take-1", "speaker": "Ana", "duration": 12.0, "score": 0.9, "note": "ok"}]
    window, table = table_scene(engine, qtbot, rows)
    iface = QAccessible.queryAccessibleInterface(table)
    assert iface.role() == QAccessible.Role.Table and iface.text(QAccessible.Text.Name) == "Takes"
    row = delegates(window)[0]
    row_iface = QAccessible.queryAccessibleInterface(row)
    assert row_iface.role() == QAccessible.Role.ListItem
    assert row_iface.text(QAccessible.Text.Name) == "Take: take-1, Speaker: Ana, Duration: 12.0 s, Score: 0.9, Note: ok"
    assert not row_iface.state().selected
    js(table, "select([0])")
    assert row_iface.state().selected
    window.close()


def test_empty_table_shows_the_placeholder(engine, qtbot):
    window, table = table_scene(engine, qtbot, [], 'placeholderText: "No takes yet"')
    placeholder = find(window, "placeholder")
    assert placeholder.isVisible() and placeholder.property("text") == "No takes yet"
    table.setProperty("rows", make_rows(3))
    assert not placeholder.isVisible()
    window.close()
