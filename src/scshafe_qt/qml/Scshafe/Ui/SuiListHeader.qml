// SuiListHeader: a compact header for above a list: a search field, an
// optional result count and a filter button (funnel) with a menu of filters.
//
//     SuiListHeader {
//         searchLabel: "Search prompts"
//         filters: [
//             { key: "missing", text: "Missing", section: "Show", exclusive: true },
//             { key: "kept", text: "Kept", section: "Show", exclusive: true },
//             { key: "long", text: "Long-form", section: "Labels" }
//         ]
//         activeFilters: ["long"]
//         resultCount: 12; totalCount: 340
//         onTextEdited: library.setSearch(text)
//         onFilterToggled: (key, active) => library.setFilter(key, active)
//     }
//
// - Search: a compact SuiSearchField (`text`, `searchLabel`, `placeholderText`,
//   `searchField`; `textEdited()` and `cleared()` forwarded). `focusShortcut`
//   ("Ctrl+F": ⌘F on macOS; "" disables) focuses and selects it from anywhere
//   in the window, a text field included; Escape clears it, then propagates.
// - Filters: `filters` (a JS array or a Python list of { key, text, section,
//   exclusive }; options in a section marked `exclusive` are one choice) and
//   `activeFilters` (keys): the header updates it as filters are chosen and the
//   app may set it. `filterToggled(key, active)` for every change (an exclusive
//   choice also reports the option it turns off), `filtersCleared()`,
//   `clearFilters()`. The button is hidden while `filters` is empty; while any
//   filter is active it is tinted and carries the count.
// - The menu: section headers, the options (checked when active), then "Clear
//   filters" (disabled while none is active). It closes after a choice and
//   gives focus back to the button. Keyboard: Space / Return / Down on the
//   button open it at the first option; Up/Down, Space / Return, Escape.
// - Count: `resultCount` (-1: hidden) and `totalCount` show "12" or "12 of 340";
//   `countText` overrides the text.
// - Accessible: a ToolBar named `label`; the filter button is a ButtonMenu named
//   `filterLabel`, described by the active filters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

Item {
    id: header

    property string label: "Search and filters"
    property alias text: field.text
    property alias searchLabel: field.label
    property alias placeholderText: field.placeholderText
    property string focusShortcut: "Ctrl+F"
    readonly property alias searchField: field
    signal textEdited()
    signal cleared()

    property var filters: []
    property var activeFilters: []
    property string filterLabel: "Filters"
    property string clearFiltersText: "Clear filters"
    readonly property int filterCount: _active.length
    signal filterToggled(string key, bool active)
    signal filtersCleared()

    property int resultCount: -1
    property int totalCount: -1
    property string countText: resultCount < 0 ? ""
                             : totalCount >= 0 ? resultCount + " of " + totalCount : String(resultCount)

    // JS arrays whatever was assigned (a Python list arrives as a sequence).
    readonly property var _filters: filters ? Array.from(filters).filter(f => f && f.key !== undefined) : []
    readonly property var _active: activeFilters ? Array.from(activeFilters, String) : []
    // The menu's rows: a header before each new section, then the options.
    readonly property var _rows: {
        const rows = []
        let section = ""
        for (const f of _filters) {
            const s = f.section !== undefined ? String(f.section) : ""
            if (s !== section && s !== "")
                rows.push({ header: true, text: s })
            section = s
            rows.push({ header: false, key: String(f.key), text: f.text !== undefined ? String(f.text) : String(f.key) })
        }
        return rows
    }
    readonly property string _activeNames: _filters.filter(f => _active.indexOf(String(f.key)) >= 0)
                                                   .map(f => f.text !== undefined ? String(f.text) : String(f.key))
                                                   .join(", ")

    function isActive(key) { return _active.indexOf(String(key)) >= 0 }
    function clearFilters() {
        if (_active.length === 0)
            return
        const was = _active
        activeFilters = []
        for (const key of was)
            filterToggled(key, false)
        filtersCleared()
    }
    function toggleFilter(key) {
        key = String(key)
        const entry = _filters.find(f => String(f.key) === key)
        if (entry === undefined)
            return
        if (isActive(key)) {
            activeFilters = _active.filter(k => k !== key)
            filterToggled(key, false)
            return
        }
        let off = []
        if (entry.exclusive) {
            const section = entry.section !== undefined ? String(entry.section) : ""
            off = _filters.filter(f => f.exclusive && String(f.key) !== key && isActive(f.key)
                                      && (f.section !== undefined ? String(f.section) : "") === section)
                          .map(f => String(f.key))
        }
        activeFilters = _active.filter(k => off.indexOf(k) < 0).concat([key])
        for (const k of off)
            filterToggled(k, false)
        filterToggled(key, true)
    }
    function openFilters() { _openMenu(false) }
    function _openMenu(fromKeyboard) {
        if (_filters.length === 0)
            return
        filterMenu.y = filterButton.height + SuiTheme.spaceXs
        filterMenu.x = filterButton.width - filterMenu.width
        filterMenu.open()
        if (fromKeyboard)
            filterMenu.currentIndex = _rows.findIndex(r => !r.header)
    }

    implicitWidth: 280
    implicitHeight: SuiTheme.controlHeightSm

    Accessible.role: Accessible.ToolBar
    Accessible.name: label

    RowLayout {
        anchors.fill: parent
        spacing: SuiTheme.spaceXs

        SuiSearchField {
            id: field
            objectName: "listSearch"
            Layout.fillWidth: true
            compact: true
            focusShortcut: header.focusShortcut
            onTextEdited: header.textEdited()
            onCleared: header.cleared()
        }

        SuiText {
            objectName: "resultCount"
            visible: text !== ""
            text: header.countText
            variant: "caption"
            tabular: true
            Layout.leftMargin: SuiTheme.spaceXs
            Layout.rightMargin: SuiTheme.spaceXs
        }

        T.Button {
            id: filterButton
            objectName: "filterButton"
            readonly property bool active: header.filterCount > 0
            readonly property bool _hot: (hovered || visualFocus) && enabled

            visible: header._filters.length > 0
            implicitWidth: SuiTheme.controlHeightSm
            implicitHeight: SuiTheme.controlHeightSm
            padding: (SuiTheme.controlHeightSm - SuiTheme.iconSize) / 2
            focusPolicy: Qt.StrongFocus
            hoverEnabled: true
            opacity: enabled ? 1 : SuiTheme.disabledOpacity

            Accessible.role: Accessible.ButtonMenu
            Accessible.name: header.filterLabel
            Accessible.description: active ? header.filterCount + " active: " + header._activeNames : "None active"
            Accessible.onPressAction: header._openMenu(false)

            onClicked: header._openMenu(false)
            Keys.onPressed: (event) => {
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    return
                switch (event.key) {
                case Qt.Key_Space: case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Down:
                    header._openMenu(true)
                    event.accepted = true
                    break
                }
            }

            contentItem: Item {
                implicitWidth: SuiTheme.iconSize
                implicitHeight: SuiTheme.iconSize
                SuiIcon {
                    objectName: "filterIcon"
                    anchors.centerIn: parent
                    name: "filter"
                    color: filterButton.active || filterMenu.visible ? SuiTheme.accent
                           : filterButton._hot || filterButton.down ? SuiTheme.text : SuiTheme.muted
                    Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
                }
            }

            background: Rectangle {
                objectName: "filterBackground"
                radius: SuiTheme.radiusSm
                border.width: 1
                border.color: filterButton.active ? SuiTheme.alpha(SuiTheme.accent, 0.40)
                              : filterButton._hot || filterMenu.visible ? SuiTheme.alpha(SuiTheme.accent, 0.32) : "transparent"
                color: {
                    const boost = filterButton.down ? 0.06 : 0
                    if (filterButton.active)
                        return SuiTheme.alpha(SuiTheme.accent, 0.14 + boost)
                    if (filterButton._hot || filterButton.down || filterMenu.visible)
                        return SuiTheme.alpha(SuiTheme.accent, 0.08 + boost)
                    return "transparent"
                }
                Behavior on color { ColorAnimation { duration: SuiTheme.duration } }

                SuiFocusRing { visible: filterButton.visualFocus }
            }

            // The active-filter count, on the button's top-right corner.
            Rectangle {
                objectName: "filterBadge"
                visible: filterButton.active
                z: 2
                width: Math.max(height, badgeText.implicitWidth + SuiTheme.spaceXs)
                height: SuiTheme.filterBadgeSize
                radius: height / 2
                x: filterButton.width - width / 2 - SuiTheme.spaceXs / 2
                y: -height / 2 + SuiTheme.spaceXs / 2
                color: SuiTheme.accent
                Accessible.ignored: true
                Text {
                    textFormat: Text.PlainText
                    id: badgeText
                    objectName: "filterBadgeText"
                    anchors.centerIn: parent
                    text: header.filterCount > 99 ? "99+" : String(header.filterCount)
                    font.pixelSize: SuiTheme.fontSizeXs
                    font.weight: SuiTheme.fontWeightBold
                    font.features: ({ "tnum": 1 })
                    color: SuiTheme.accentForeground
                }
            }

            T.Menu {
                id: filterMenu
                objectName: "filterMenu"
                // Focus back to the button, with its ring if the keyboard opened the menu.
                property int _returnReason: Qt.OtherFocusReason

                implicitWidth: Math.max(SuiTheme.menuMinWidth, header._widest + 3 * SuiTheme.spaceSm
                                        + SuiTheme.iconSizeSm + leftPadding + rightPadding)
                implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, SuiTheme.menuMaxHeight)
                padding: SuiTheme.spaceXs
                margins: SuiTheme.spaceSm

                onAboutToShow: _returnReason = filterButton.visualFocus ? Qt.TabFocusReason : Qt.OtherFocusReason
                onClosed: {
                    if (!filterButton.visible || !filterButton.enabled)
                        return
                    filterButton.forceActiveFocus(_returnReason)
                    // Qt may already have handed focus back (OtherFocusReason): restore
                    // the reason for the ring, as SuiDialog does.
                    if (filterButton.activeFocus)
                        filterButton.focusReason = _returnReason
                }

                enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: SuiTheme.duration } }
                exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: SuiTheme.duration } }

                contentItem: ListView {
                    objectName: "filterOptions"
                    implicitHeight: contentHeight
                    model: filterMenu.contentModel
                    currentIndex: filterMenu.currentIndex
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    Accessible.role: Accessible.PopupMenu
                    Accessible.name: header.filterLabel
                }

                background: Rectangle {
                    radius: SuiTheme.radiusMd
                    color: SuiTheme.popover
                    border.width: 1
                    border.color: SuiTheme.borderStrong
                }

                Instantiator {
                    model: header._rows
                    delegate: T.MenuItem {
                        id: option
                        required property var modelData
                        required property int index
                        readonly property bool sectionHeader: modelData.header
                        readonly property bool current: !sectionHeader && header.isActive(modelData.key)
                        objectName: sectionHeader ? "filterSection" : "filterOption_" + modelData.key
                        text: modelData.text
                        enabled: !sectionHeader
                        checkable: !sectionHeader
                        checked: current
                        width: filterMenu.availableWidth
                        implicitHeight: sectionHeader ? SuiTheme.controlHeightSm : SuiTheme.controlHeight
                        leftPadding: SuiTheme.spaceSm
                        rightPadding: SuiTheme.spaceSm
                        font.pixelSize: SuiTheme.fontSizeMd
                        hoverEnabled: true
                        Accessible.role: sectionHeader ? Accessible.Heading : Accessible.MenuItem
                        Accessible.name: text
                        Accessible.checkable: !sectionHeader
                        Accessible.checked: current

                        // The header owns the state: apply the choice, then follow it again.
                        onTriggered: {
                            header.toggleFilter(modelData.key)
                            checked = Qt.binding(() => option.current)
                        }

                        contentItem: Row {
                            spacing: SuiTheme.spaceSm
                            SuiIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !option.sectionHeader
                                name: "check"
                                size: SuiTheme.iconSizeSm
                                color: SuiTheme.accent
                                opacity: option.current ? 1 : 0
                            }
                            Text {
                                textFormat: Text.PlainText
                                objectName: "optionText"
                                anchors.verticalCenter: parent.verticalCenter
                                width: option.availableWidth - (option.sectionHeader ? 0 : SuiTheme.iconSizeSm + parent.spacing)
                                text: option.text
                                elide: Text.ElideRight
                                font.pixelSize: option.sectionHeader ? SuiTheme.fontSizeXs : SuiTheme.fontSizeMd
                                font.weight: option.sectionHeader ? SuiTheme.fontWeightBold : SuiTheme.fontWeightNormal
                                font.capitalization: option.sectionHeader ? Font.AllUppercase : Font.MixedCase
                                color: option.sectionHeader ? SuiTheme.muted : option.current ? SuiTheme.textStrong : SuiTheme.text
                            }
                        }
                        background: Rectangle {
                            radius: SuiTheme.radiusSm
                            color: !option.sectionHeader && (option.highlighted || option.hovered) ? SuiTheme.bgHover : "transparent"
                        }
                    }
                    onObjectAdded: (index, object) => filterMenu.insertItem(index, object)
                    onObjectRemoved: (index, object) => filterMenu.removeItem(object)
                }

                T.MenuSeparator {
                    objectName: "filterSeparator"
                    width: filterMenu.availableWidth
                    implicitHeight: implicitContentHeight + topPadding + bottomPadding
                    topPadding: SuiTheme.spaceXs
                    bottomPadding: SuiTheme.spaceXs
                    contentItem: Rectangle {
                        implicitHeight: 1
                        color: SuiTheme.line
                    }
                }

                T.MenuItem {
                    id: clearItem
                    objectName: "clearFilters"
                    text: header.clearFiltersText
                    enabled: header.filterCount > 0
                    width: filterMenu.availableWidth
                    implicitHeight: SuiTheme.controlHeight
                    leftPadding: SuiTheme.spaceSm + SuiTheme.iconSizeSm + SuiTheme.spaceSm
                    rightPadding: SuiTheme.spaceSm
                    font.pixelSize: SuiTheme.fontSizeMd
                    hoverEnabled: true
                    opacity: enabled ? 1 : SuiTheme.disabledOpacity
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: text
                    onTriggered: header.clearFilters()
                    contentItem: Text {
                        textFormat: Text.PlainText
                        text: clearItem.text
                        font: clearItem.font
                        color: SuiTheme.text
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        radius: SuiTheme.radiusSm
                        color: clearItem.enabled && (clearItem.highlighted || clearItem.hovered) ? SuiTheme.bgHover : "transparent"
                    }
                }
            }
        }
    }

    // The widest option, for the menu's width.
    readonly property real _widest: {
        let widest = metrics.advanceWidth(clearFiltersText)
        for (const r of _rows)
            widest = Math.max(widest, metrics.advanceWidth(r.text))
        return Math.ceil(widest)
    }
    FontMetrics { id: metrics; font.pixelSize: SuiTheme.fontSizeMd }
}
