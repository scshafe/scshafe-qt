// SuiSidebarList: the navigation list of an app shell's sidebar.
//
//     SuiSidebarList {
//         label: "Buckets"
//         model: [
//             { section: "Inbox", text: "Unsorted", iconName: "inbox", count: 12, status: "ok" },
//             { section: "Buckets", text: "Receipts", iconName: "tag", count: 3, status: "held" },
//         ]
//         onActivated: (index) => app.showBucket(index)
//     }
//
// The model is a JS array of objects or a ListModel with the roles `text`,
// `iconName`, `count`, `status`, `section` (optional), `enabled` (optional).
// Consecutive entries with the same `section` share a header.
//
// Keyboard: Tab focuses the list (its current entry; one Tab stop), Up/Down
// (and Home/End, PageUp/PageDown) move, Enter/Return/Space activate:
// `selectedIndex` follows and `activated(index)` fires. A pointer click
// activates as well. The ring shows on the current entry after keyboard use.
import QtQuick

ListView {
    id: list

    property string label: "Sidebar"
    property int selectedIndex: -1
    signal activated(int index)

    // :focus-visible for the list: true after keyboard use, false after a pointer press.
    property bool keyboardInteraction: true
    property bool _pointerFocus: false

    function entry(index) {
        if (index < 0 || index >= count)
            return null
        if (model && typeof model.get === "function")
            return model.get(index)  // ListModel
        return model && model.length !== undefined ? model[index] : null
    }
    function isEnabled(index) {
        const e = entry(index)
        return e === null || e.enabled === undefined || e.enabled
    }
    function moveCurrent(delta) {
        let i = currentIndex
        for (let n = 0; n < count; ++n) {
            i = Math.max(0, Math.min(count - 1, i + delta))
            if (isEnabled(i))
                break
            if (i === 0 || i === count - 1)
                return
        }
        if (isEnabled(i)) {
            currentIndex = i
            positionViewAtIndex(i, ListView.Contain)
        }
    }
    function activate(index) {
        if (index < 0 || index >= count || !isEnabled(index))
            return
        currentIndex = index
        selectedIndex = index
        activated(index)
    }

    activeFocusOnTab: true
    keyNavigationEnabled: false
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: 1
    currentIndex: selectedIndex

    Accessible.role: Accessible.List
    Accessible.name: label

    onSelectedIndexChanged: currentIndex = selectedIndex
    onActiveFocusChanged: {
        if (activeFocus) {
            if (!_pointerFocus)
                keyboardInteraction = true
            _pointerFocus = false
            if (currentIndex < 0 && count > 0)
                currentIndex = Math.max(0, selectedIndex)
        }
    }

    Keys.onPressed: (event) => {
        const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
        if (!plain)
            return
        const page = Math.max(1, Math.floor(height / SuiTheme.rowHeight) - 1)
        switch (event.key) {
        case Qt.Key_Down: moveCurrent(1); break
        case Qt.Key_Up: moveCurrent(-1); break
        case Qt.Key_Home: currentIndex = -1; moveCurrent(1); break
        case Qt.Key_End: currentIndex = count; moveCurrent(-1); break
        case Qt.Key_PageDown: moveCurrent(page); break
        case Qt.Key_PageUp: moveCurrent(-page); break
        case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: activate(currentIndex); break
        default: return
        }
        keyboardInteraction = true
        event.accepted = true
    }

    section.property: "section"
    section.criteria: ViewSection.FullString
    section.delegate: Text {
        required property string section
        objectName: "sectionHeader"
        width: ListView.view ? ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin : implicitWidth
        text: section
        visible: section !== ""
        height: section !== "" ? implicitHeight : 0
        topPadding: SuiTheme.spaceMd
        bottomPadding: SuiTheme.spaceXs
        leftPadding: SuiTheme.spaceSm
        font.pixelSize: SuiTheme.fontSizeXs
        font.weight: SuiTheme.fontWeightBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.4
        color: SuiTheme.muted
        Accessible.role: Accessible.Heading
        Accessible.name: section
    }

    delegate: SuiSidebarItem {
        id: item
        readonly property var entry: (typeof modelData === "object" && modelData !== null) ? modelData : model
        width: ListView.view ? ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin : implicitWidth
        text: entry.text !== undefined ? entry.text : ""
        iconName: entry.iconName !== undefined ? entry.iconName : ""
        count: entry.count !== undefined ? entry.count : -1
        status: entry.status !== undefined ? entry.status : "none"
        enabled: entry.enabled === undefined || entry.enabled
        focusPolicy: Qt.NoFocus
        selected: index === list.selectedIndex
        keyboardFocus: ListView.isCurrentItem && list.activeFocus && list.keyboardInteraction
        onPointerPressed: {
            list.keyboardInteraction = false
            list._pointerFocus = true
            list.currentIndex = index
            list.forceActiveFocus(Qt.MouseFocusReason)
        }
        // Space on the focused entry clicks it (AbstractButton); mark it as keyboard use.
        Keys.onPressed: (event) => { list.keyboardInteraction = true; event.accepted = false }
        onClicked: list.activate(index)
    }
}
