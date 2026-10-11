// SuiTable: a sortable, virtualised data table with resizable columns and row
// selection, for many rows (10,000 scroll and sort smoothly).
//
//     SuiTable {
//         label: "Takes"
//         columns: [
//             { key: "name", title: "Take", width: 220 },
//             { key: "speaker", title: "Speaker" },
//             { key: "duration", title: "Duration", width: 90, align: "right",
//               format: (v) => v.toFixed(1) + " s" },
//             { key: "score", title: "Score", width: 80, align: "right",
//               tone: (v) => v < 0.5 ? "danger" : "" }
//         ]
//         rows: takes                   // a JS array of objects (or a Python list of dicts)
//         rowKey: "id"                  // keeps the selection when `rows` is replaced
//         selectionMode: "multiple"
//         onActivated: (row) => openTake(rows[row])
//     }
//
// Rows are `rows[i]` objects; a column shows `row[key]`, through
// `format(value, row)` when given, in the `tone(value, row)` colour when given.
// Column fields: key (required), title, width (SuiTheme.tableColumnWidth),
// minWidth / maxWidth (SuiTheme.tableMinColumnWidth / tableMaxColumnWidth),
// align ("left" | "right" | "center"; right-aligned cells use tabular digits),
// sortable (true), resizable (true), format, tone. The last column stretches
// to fill the view (`fillLastColumn`).
//
// Row numbers in the API (`currentRow`, `selectedRows`, `activated(row)`,
// `select()`, ...) are indices into `rows`, whatever the sort.
//
// - Sorting: `sortKey` ("" = the order of `rows`) and `sortOrder`
//   (Qt.AscendingOrder / Qt.DescendingOrder); a header click or Enter/Space on
//   a header sorts by that column, again to reverse. Numbers compare as
//   numbers, other values as case-insensitive text, empty values last; ties
//   keep the order of `rows`. `sortBy(key[, order])`.
// - Columns: drag a header's right edge to resize, double-click it to reset;
//   on a focused header Ctrl+Left/Right (Cmd on macOS) resize by
//   SuiTheme.splitterStep (Shift: x4). `columnWidths` ({ key: width }) holds
//   the user's widths (restore it from settings); `columnResized(key, width)`.
// - Selection (`selectionMode` "none" | "single" | "multiple"): click selects;
//   Ctrl+click toggles, Shift+click selects a range (multiple). Keyboard on the
//   body: Up/Down, PageUp/PageDown, Home/End move (and select; with Shift a
//   range, with Ctrl without selecting), Space toggles, Ctrl+A selects all,
//   Enter / double-click emit `activated(row)`, Left/Right scroll sideways.
// - Focus: the header is one Tab stop (Left/Right move between columns), the
//   body another (focus on the current row); the ring shows after keyboard use.
//   `forceActiveFocus()` on the table focuses the body.
// - Accessible: Table named by `label`; ColumnHeaders named by their title and
//   described by the sort; rows are ListItems named "Title: value, ..." with
//   their selected state.
import QtQuick
import QtQuick.Templates as T

FocusScope {
    id: table

    property string label: ""
    property var columns: []
    property var rows: []
    property string rowKey: ""
    property string sortKey: ""
    property int sortOrder: Qt.AscendingOrder
    property string selectionMode: "single"
    property var columnWidths: ({})
    property bool resizableColumns: true
    property bool fillLastColumn: true
    property string placeholderText: "No rows"

    readonly property int rowCount: rows ? rows.length : 0
    readonly property int currentRow: _current
    readonly property var selectedRows: {
        _revision
        return Object.keys(_sel).map(Number).sort((a, b) => a - b)
    }

    signal activated(int row)
    signal columnResized(string key, real width)

    // ---- API ----------------------------------------------------------------
    function sortBy(key, order) {
        _batch = true
        sortOrder = order !== undefined ? order
                  : key === sortKey && sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder
        sortKey = key
        _batch = false
        _resort()
    }
    function setCurrentRow(row) {
        if (row < 0 || row >= _order.length)
            return
        _setCurrentView(_rank[row])
        list.positionViewAtIndex(_rank[row], ListView.Contain)
    }
    function positionViewAtRow(row, mode) {
        if (row >= 0 && row < _order.length)
            list.positionViewAtIndex(_rank[row], mode === undefined ? ListView.Contain : mode)
    }
    function isSelected(row) { return _sel[row] === true }
    function select(rowList) {
        if (selectionMode === "none")
            return
        const out = {}
        for (const r of rowList) {
            if (r >= 0 && r < _order.length) {
                out[r] = true
                if (selectionMode === "single")
                    break
            }
        }
        _sel = out
        _bump()
    }
    function selectAll() {
        if (selectionMode !== "multiple")
            return
        const out = {}
        for (let r = 0; r < _order.length; ++r)
            out[r] = true
        _sel = out
        _bump()
    }
    function clearSelection() {
        _sel = {}
        _bump()
    }
    function columnWidth(key) {
        const i = columns.findIndex(c => c.key === key)
        return i < 0 ? 0 : _widths[i]
    }
    function setColumnWidth(key, width) {
        const column = columns.find(c => c.key === key)
        if (!column)
            return
        const w = Math.round(Math.max(_minWidth(column), Math.min(_maxWidth(column), width)))
        if (columnWidths[key] === w)
            return
        const next = Object.assign({}, columnWidths)
        next[key] = w
        columnWidths = next
        columnResized(key, w)
    }
    function resetColumnWidth(key) {
        if (columnWidths[key] === undefined)
            return
        const next = Object.assign({}, columnWidths)
        delete next[key]
        columnWidths = next
        columnResized(key, columnWidth(key))
    }
    // The text a cell shows (format applied).
    function cellText(row, column) {
        const c = typeof column === "number" ? columns[column] : columns.find(x => x.key === column)
        const r = rows[row]
        if (!c || r === undefined || r === null)
            return ""
        return _format(c, r)
    }

    // ---- Internals ------------------------------------------------------------
    property var _order: []    // view index -> row
    property var _rank: []     // row -> view index
    property var _sel: ({})    // row -> true
    property int _revision: 0
    property int _current: -1
    property int _anchor: -1   // row a Shift range starts from
    property bool _batch: false
    property var _previousRows: []

    function _bump() { _revision++ }
    function _minWidth(c) { return c.minWidth !== undefined ? c.minWidth : SuiTheme.tableMinColumnWidth }
    function _maxWidth(c) { return c.maxWidth !== undefined ? c.maxWidth : SuiTheme.tableMaxColumnWidth }
    function _baseWidth(c) {
        const w = columnWidths[c.key] !== undefined ? columnWidths[c.key]
                : c.width !== undefined ? c.width : SuiTheme.tableColumnWidth
        return Math.max(_minWidth(c), Math.min(_maxWidth(c), w))
    }
    readonly property var _widths: {
        const out = columns.map(c => _baseWidth(c))
        const used = out.reduce((a, b) => a + b, 0)
        if (fillLastColumn && out.length > 0 && list.width > used)
            out[out.length - 1] += list.width - used
        return out
    }
    readonly property real _contentWidth: _widths.reduce((a, b) => a + b, 0)
    function _format(c, r) {
        const v = r[c.key]
        if (typeof c.format === "function")
            return String(c.format(v, r))
        return v === undefined || v === null ? "" : String(v)
    }
    function _tone(c, r) {
        return typeof c.tone === "function" ? c.tone(r[c.key], r) || "" : ""
    }
    function _rowName(r) {
        if (r === undefined || r === null)
            return ""
        return columns.map(c => (c.title !== undefined ? c.title : c.key) + ": " + _format(c, r)).join(", ")
    }

    function _resort() {
        // Not rowCount: in onRowsChanged its binding may not have updated yet.
        const n = rows ? rows.length : 0
        const order = new Array(n)
        for (let i = 0; i < n; ++i)
            order[i] = i
        if (sortKey !== "" && n > 1) {
            // 0: number, 1: text, 2: empty (always last)
            const kind = new Array(n)
            const key = new Array(n)
            for (let i = 0; i < n; ++i) {
                const r = rows[i]
                const v = r !== null && r !== undefined ? r[sortKey] : undefined
                if (v === undefined || v === null || v === "" || (typeof v === "number" && isNaN(v))) {
                    kind[i] = 2
                    key[i] = 0
                } else if (typeof v === "number" || typeof v === "boolean") {
                    kind[i] = 0
                    key[i] = Number(v)
                } else {
                    kind[i] = 1
                    key[i] = String(v).toLowerCase()
                }
            }
            const dir = sortOrder === Qt.DescendingOrder ? -1 : 1
            order.sort((a, b) => {
                const ka = kind[a], kb = kind[b]
                if (ka !== kb)
                    return ka === 2 ? 1 : kb === 2 ? -1 : dir * (ka - kb)
                if (ka !== 2) {
                    const x = key[a], y = key[b]
                    if (x < y)
                        return -dir
                    if (x > y)
                        return dir
                }
                return a - b
            })
        }
        const rank = new Array(n)
        for (let i = 0; i < n; ++i)
            rank[order[i]] = i
        const current = _current
        _batch = true
        _order = order
        _rank = rank
        list.currentIndex = current >= 0 && current < n ? rank[current] : -1
        _batch = false
        if (list.currentIndex >= 0)
            list.positionViewAtIndex(list.currentIndex, ListView.Contain)
    }

    // New rows: keep the selection, current row and anchor by rowKey; without
    // one, clear them (the indices may name other rows now).
    function _rowsReplaced() {
        const old = _previousRows
        const fresh = rows ? rows : []
        let sel = {}
        let current = -1
        let anchor = -1
        if (rowKey !== "" && old.length > 0) {
            const where = {}
            for (let i = 0; i < fresh.length; ++i) {
                const r = fresh[i]
                if (r !== null && r !== undefined)
                    where[r[rowKey]] = i
            }
            const find = (oldRow) => {
                const r = old[oldRow]
                const i = r !== null && r !== undefined ? where[r[rowKey]] : undefined
                return i === undefined ? -1 : i
            }
            for (const k of Object.keys(_sel)) {
                const i = find(Number(k))
                if (i >= 0)
                    sel[i] = true
            }
            current = _current >= 0 ? find(_current) : -1
            anchor = _anchor >= 0 ? find(_anchor) : -1
        }
        _previousRows = fresh
        _sel = sel
        _anchor = anchor
        _current = current
        _bump()
        _resort()
    }

    onRowsChanged: _rowsReplaced()
    onSortKeyChanged: if (!_batch) _resort()
    onSortOrderChanged: if (!_batch) _resort()
    onSelectionModeChanged: {
        if (selectionMode === "none")
            clearSelection()
        else if (selectionMode === "single" && selectedRows.length > 1)
            select([_current >= 0 ? _current : selectedRows[0]])
    }
    Component.onCompleted: _rowsReplaced()

    function _setCurrentView(viewIndex) {
        list.currentIndex = viewIndex
    }
    // Move to a view index from the keyboard or a pointer press, with modifiers.
    function _moveTo(viewIndex, modifiers, pointer) {
        if (viewIndex < 0 || viewIndex >= _order.length)
            return
        const row = _order[viewIndex]
        const shift = (modifiers & Qt.ShiftModifier) !== 0
        const ctrl = (modifiers & Qt.ControlModifier) !== 0
        _setCurrentView(viewIndex)
        list.positionViewAtIndex(viewIndex, ListView.Contain)
        if (selectionMode === "single") {
            _sel = {}
            _sel[row] = true
            _anchor = row
        } else if (selectionMode === "multiple") {
            if (shift && _anchor >= 0 && _anchor < _order.length) {
                const from = Math.min(_rank[_anchor], viewIndex), to = Math.max(_rank[_anchor], viewIndex)
                const out = ctrl ? Object.assign({}, _sel) : {}
                for (let i = from; i <= to; ++i)
                    out[_order[i]] = true
                _sel = out
            } else if (ctrl) {
                if (pointer) {
                    const out = Object.assign({}, _sel)
                    if (out[row])
                        delete out[row]
                    else
                        out[row] = true
                    _sel = out
                    _anchor = row
                }
            } else {
                _sel = {}
                _sel[row] = true
                _anchor = row
            }
        }
        _bump()
    }
    function _toggleCurrent() {
        if (_current < 0 || selectionMode === "none")
            return
        if (selectionMode === "single") {
            _sel = {}
            _sel[_current] = true
        } else {
            const out = Object.assign({}, _sel)
            if (out[_current])
                delete out[_current]
            else
                out[_current] = true
            _sel = out
        }
        _anchor = _current
        _bump()
    }
    function _rowPressed(viewIndex, modifiers) {
        list.keyboardInteraction = false
        list._pointerFocus = true
        list.forceActiveFocus(Qt.MouseFocusReason)
        _moveTo(viewIndex, modifiers, true)
    }
    function _headerActivated(index) {
        const c = columns[index]
        if (c && c.sortable !== false)
            sortBy(c.key)
    }

    implicitWidth: 480
    implicitHeight: 320
    clip: true

    Accessible.role: Accessible.Table
    Accessible.name: label

    // ---- Header ---------------------------------------------------------------
    FocusScope {
        id: header
        objectName: "header"
        width: parent.width
        height: SuiTheme.tableRowHeight
        activeFocusOnTab: columns.length > 0
        clip: true

        property int focusColumn: 0
        property bool keyboardInteraction: true
        property bool _pointerFocus: false

        Accessible.role: Accessible.Row
        Accessible.name: "Column headers"

        onActiveFocusChanged: {
            if (activeFocus) {
                if (!_pointerFocus)
                    keyboardInteraction = true
                _pointerFocus = false
                focusColumn = Math.max(0, Math.min(table.columns.length - 1, focusColumn))
            }
        }
        function _focusColumn(i) {
            focusColumn = Math.max(0, Math.min(table.columns.length - 1, i))
            // Keep the focused header in view.
            let left = 0
            for (let k = 0; k < focusColumn; ++k)
                left += table._widths[k]
            const right = left + table._widths[focusColumn]
            if (left < list.contentX)
                list.contentX = left
            else if (right > list.contentX + list.width)
                list.contentX = Math.min(Math.max(0, table._contentWidth - list.width), right - list.width)
        }

        Keys.onPressed: (event) => {
            const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0
            const column = table.columns[header.focusColumn]
            if (!column)
                return
            if (ctrl && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                if (!table.resizableColumns || column.resizable === false)
                    return
                const step = SuiTheme.splitterStep * (shift ? 4 : 1) * (event.key === Qt.Key_Left ? -1 : 1)
                table.setColumnWidth(column.key, table._baseWidth(column) + step)
            } else if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) {
                return
            } else {
                switch (event.key) {
                case Qt.Key_Left: header._focusColumn(header.focusColumn - 1); break
                case Qt.Key_Right: header._focusColumn(header.focusColumn + 1); break
                case Qt.Key_Home: header._focusColumn(0); break
                case Qt.Key_End: header._focusColumn(table.columns.length - 1); break
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: table._headerActivated(header.focusColumn); break
                default: return
                }
            }
            header.keyboardInteraction = true
            event.accepted = true
        }

        Rectangle {
            anchors.fill: parent
            color: SuiTheme.panel
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: SuiTheme.borderStrong
        }

        Row {
            id: headerRow
            x: -list.contentX
            height: parent.height

            Repeater {
                model: table.columns
                delegate: Item {
                    id: headerCell
                    required property var modelData
                    required property int index
                    readonly property bool sorted: table.sortKey !== "" && table.sortKey === modelData.key
                    readonly property bool sortable: modelData.sortable !== false
                    readonly property bool resizable: table.resizableColumns && modelData.resizable !== false
                    readonly property string title: modelData.title !== undefined ? modelData.title : modelData.key

                    objectName: "headerCell" + index
                    width: table._widths[index] !== undefined ? table._widths[index] : 0
                    height: header.height
                    z: table.columns.length - index  // a resize handle overlaps the next cell
                    focus: index === header.focusColumn
                    activeFocusOnTab: false

                    Accessible.role: Accessible.ColumnHeader
                    Accessible.name: title
                    Accessible.description: sorted ? (table.sortOrder === Qt.DescendingOrder ? "sorted descending"
                                                                                             : "sorted ascending") : ""
                    Accessible.focusable: true
                    Accessible.onPressAction: table._headerActivated(index)

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 1
                        color: headerHover.hovered && headerCell.sortable ? SuiTheme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
                    }

                    Row {
                        id: titleRow
                        x: modelData.align === "right" ? parent.width - width - SuiTheme.spaceMd
                           : modelData.align === "center" ? (parent.width - width) / 2 : SuiTheme.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: SuiTheme.spaceXs
                        layoutDirection: modelData.align === "right" ? Qt.RightToLeft : Qt.LeftToRight
                        Text {
                            textFormat: Text.PlainText
                            objectName: "headerTitle"
                            text: headerCell.title
                            width: Math.min(implicitWidth, headerCell.width - 2 * SuiTheme.spaceMd
                                            - (sortIcon.visible ? sortIcon.width + titleRow.spacing : 0))
                            elide: Text.ElideRight
                            font.pixelSize: SuiTheme.fontSizeMd
                            font.weight: SuiTheme.fontWeightStrong
                            color: SuiTheme.textStrong
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        SuiIcon {
                            id: sortIcon
                            objectName: "sortIcon"
                            visible: headerCell.sorted
                            name: table.sortOrder === Qt.DescendingOrder ? "chevron-down" : "chevron-up"
                            size: SuiTheme.iconSizeSm
                            color: SuiTheme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    HoverHandler { id: headerHover }
                    TapHandler {
                        gesturePolicy: TapHandler.WithinBounds
                        onTapped: (eventPoint) => {
                            // Presses on a resize handle belong to it.
                            const x = eventPoint.position.x
                            const zone = SuiTheme.splitterHandleWidth / 2
                            if (x > headerCell.width - zone && headerCell.resizable)
                                return
                            const previous = table.columns[headerCell.index - 1]
                            if (x < zone && previous && table.resizableColumns && previous.resizable !== false)
                                return
                            header.keyboardInteraction = false
                            header._pointerFocus = true
                            header.focusColumn = headerCell.index
                            header.forceActiveFocus(Qt.MouseFocusReason)
                            table._headerActivated(headerCell.index)
                        }
                    }

                    Item {
                        objectName: "resizeHandle" + headerCell.index
                        visible: headerCell.resizable
                        x: parent.width - width / 2
                        width: SuiTheme.splitterHandleWidth
                        height: parent.height
                        readonly property bool hot: resizeHover.hovered || resizeDrag.active

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: SuiTheme.spaceSm
                            height: parent.height - 2 * SuiTheme.spaceSm
                            width: parent.hot ? SuiTheme.focusRingWidth : 1
                            color: parent.hot ? SuiTheme.accent : SuiTheme.borderStrong
                            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
                        }
                        HoverHandler { id: resizeHover; cursorShape: Qt.SplitHCursor }
                        DragHandler {
                            id: resizeDrag
                            target: null
                            yAxis.enabled: false
                            cursorShape: Qt.SplitHCursor
                            property real startWidth: 0
                            onActiveChanged: if (active) startWidth = table._baseWidth(headerCell.modelData)
                            onActiveTranslationChanged: {
                                if (active)
                                    table.setColumnWidth(headerCell.modelData.key, startWidth + activeTranslation.x)
                            }
                        }
                        TapHandler {
                            onDoubleTapped: table.resetColumnWidth(headerCell.modelData.key)
                        }
                    }

                    SuiFocusRing {
                        inset: true
                        targetRadius: 0
                        visible: headerCell.activeFocus && header.keyboardInteraction
                    }
                }
            }
        }
    }

    // ---- Body -----------------------------------------------------------------
    ListView {
        id: list
        objectName: "body"
        y: header.height
        width: parent.width
        height: parent.height - header.height
        model: table._order.length
        focus: true  // the scope's default: forceActiveFocus() on the table lands here
        clip: true
        reuseItems: true
        activeFocusOnTab: true
        keyNavigationEnabled: false
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickDirection
        contentWidth: Math.max(width, table._contentWidth)
        currentIndex: -1

        // :focus-visible for the body: true after keyboard use, false after a pointer press.
        property bool keyboardInteraction: true
        property bool _pointerFocus: false

        Accessible.role: Accessible.List
        Accessible.name: table.label

        T.ScrollBar.vertical: SuiScrollBar { objectName: "verticalScrollBar" }
        T.ScrollBar.horizontal: SuiScrollBar { objectName: "horizontalScrollBar" }

        onCurrentIndexChanged: {
            if (!table._batch)
                table._current = currentIndex >= 0 && currentIndex < table._order.length ? table._order[currentIndex] : -1
        }
        onCountChanged: {
            // An integer model resets the current index; restore it from the current row.
            const want = table._current >= 0 && table._current < table._rank.length ? table._rank[table._current] : -1
            if (currentIndex !== want) {
                table._batch = true
                currentIndex = want
                table._batch = false
            }
        }
        onActiveFocusChanged: {
            if (activeFocus) {
                if (!_pointerFocus)
                    keyboardInteraction = true
                _pointerFocus = false
            }
        }

        Keys.onPressed: (event) => {
            const mods = event.modifiers
            if (mods & (Qt.AltModifier | Qt.MetaModifier))
                return
            const ctrl = (mods & Qt.ControlModifier) !== 0
            const n = table._order.length
            const i = currentIndex
            const page = Math.max(1, Math.floor(height / SuiTheme.tableRowHeight) - 1)
            let target = -1
            switch (event.key) {
            case Qt.Key_Down: target = Math.min(n - 1, i + 1); break
            case Qt.Key_Up: target = i < 0 ? 0 : Math.max(0, i - 1); break
            case Qt.Key_PageDown: target = Math.min(n - 1, Math.max(0, i) + page); break
            case Qt.Key_PageUp: target = Math.max(0, i - page); break
            case Qt.Key_Home: target = 0; break
            case Qt.Key_End: target = n - 1; break
            case Qt.Key_Space: table._toggleCurrent(); break
            case Qt.Key_Return: case Qt.Key_Enter:
                if (table._current >= 0)
                    table.activated(table._current)
                break
            case Qt.Key_Left:
                contentX = Math.max(0, contentX - SuiTheme.tableColumnWidth / 2)
                break
            case Qt.Key_Right:
                contentX = Math.max(0, Math.min(contentWidth - width, contentX + SuiTheme.tableColumnWidth / 2))
                break
            case Qt.Key_A:
                if (!ctrl || table.selectionMode !== "multiple")
                    return
                table.selectAll()
                break
            default:
                return
            }
            if (target >= 0)
                table._moveTo(target, mods, false)
            keyboardInteraction = true
            event.accepted = true
        }

        delegate: Item {
            id: rowItem
            required property int index
            readonly property int row: index < table._order.length ? table._order[index] : -1
            readonly property var record: row >= 0 ? table.rows[row] : null
            readonly property bool selected: {
                table._revision
                return row >= 0 && table._sel[row] === true
            }
            readonly property bool current: ListView.isCurrentItem

            objectName: "row"
            width: list.contentWidth
            height: SuiTheme.tableRowHeight

            Accessible.role: Accessible.ListItem
            Accessible.name: table._rowName(record)
            Accessible.selectable: table.selectionMode !== "none"
            Accessible.selected: selected
            Accessible.onPressAction: table._moveTo(index, Qt.NoModifier, true)

            Rectangle {
                anchors.fill: parent
                color: rowItem.selected ? SuiTheme.accentSubtle : rowHover.hovered ? SuiTheme.bgHover : "transparent"
            }
            Rectangle {  // selection bar
                visible: rowItem.selected
                width: SuiTheme.focusRingWidth + 1
                height: parent.height
                x: list.contentX
                color: SuiTheme.accent
            }
            Rectangle {  // divider
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: SuiTheme.line
            }

            Row {
                height: parent.height
                Repeater {
                    model: table.columns.length
                    delegate: Text {
                        textFormat: Text.PlainText
                        required property int index
                        readonly property var column: table.columns[index]
                        objectName: "cell"
                        width: table._widths[index] !== undefined ? table._widths[index] : 0
                        height: parent.height
                        leftPadding: SuiTheme.spaceMd
                        rightPadding: SuiTheme.spaceMd
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: column.align === "right" ? Text.AlignRight
                                             : column.align === "center" ? Text.AlignHCenter : Text.AlignLeft
                        elide: Text.ElideRight
                        text: rowItem.record ? table._format(column, rowItem.record) : ""
                        font.pixelSize: SuiTheme.fontSizeMd
                        font.features: column.align === "right" ? ({ "tnum": 1 }) : ({})
                        color: {
                            const tone = rowItem.record ? table._tone(column, rowItem.record) : ""
                            return tone !== "" ? SuiTheme.textColor(tone)
                                               : rowItem.selected ? SuiTheme.textStrong : SuiTheme.text
                        }
                    }
                }
            }

            HoverHandler { id: rowHover }
            TapHandler {
                id: rowTap
                gesturePolicy: TapHandler.WithinBounds
                onTapped: table._rowPressed(rowItem.index, rowTap.point.modifiers)
                onDoubleTapped: if (rowItem.row >= 0) table.activated(rowItem.row)
            }

            SuiFocusRing {
                inset: true
                targetRadius: 0
                visible: rowItem.current && list.activeFocus && list.keyboardInteraction
            }
        }
    }

    SuiText {
        objectName: "placeholder"
        visible: table.rowCount === 0 && table.placeholderText !== ""
        x: (list.width - width) / 2
        y: list.y + (list.height - height) / 2
        text: table.placeholderText
        tone: "muted"
    }
}
