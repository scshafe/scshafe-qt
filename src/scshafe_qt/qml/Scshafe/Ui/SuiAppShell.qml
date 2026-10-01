// SuiAppShell: the application frame: sidebar | content | inspector.
//
//     SuiAppShell {
//         anchors.fill: parent
//         sidebar: SuiSidebarList { ... }
//         content: SuiList { ... }
//         inspector: SuiTrail { ... }        // optional
//         inspectorOpen: inspectorToggle.checked
//     }
//
// - Each pane fills its slot (`sidebar`, `content`, `inspector`: any Item).
// - The splitters between panes are focusable (Tab): Left/Right resize by
//   `resizeStep` (Shift: 4x), Home/End jump to the minimum/maximum, Enter
//   collapses the pane; dragging resizes too. Widths are clamped to their
//   minimum/maximum and to leave the content at least `contentMinWidth`.
// - `inspectorOpen` (and `sidebarOpen`) collapse a pane: it animates on
//   SuiTheme.duration (instant under reduced motion), leaves the Tab order,
//   and focus inside it moves to the content.
import QtQuick

Item {
    id: shell

    property Item sidebar: null
    property Item content: null
    property Item inspector: null

    property bool sidebarOpen: true
    property bool inspectorOpen: true
    property real sidebarWidth: SuiTheme.sidebarWidth
    property real sidebarMinWidth: SuiTheme.sidebarMinWidth
    property real sidebarMaxWidth: SuiTheme.sidebarMaxWidth
    property real inspectorWidth: SuiTheme.inspectorWidth
    property real inspectorMinWidth: SuiTheme.inspectorMinWidth
    property real inspectorMaxWidth: SuiTheme.inspectorMaxWidth
    property real contentMinWidth: SuiTheme.contentMinWidth
    property int resizeStep: SuiTheme.splitterStep

    property string sidebarLabel: "Sidebar"
    property string contentLabel: "Content"
    property string inspectorLabel: "Inspector"

    function toggleInspector() { inspectorOpen = !inspectorOpen }
    function toggleSidebar() { sidebarOpen = !sidebarOpen }

    readonly property bool hasInspector: inspector !== null
    readonly property real _sidebarRoom: Math.max(sidebarMinWidth,
        width - contentMinWidth - (hasInspector && inspectorOpen ? inspectorWidth : 0))
    readonly property real _inspectorRoom: Math.max(inspectorMinWidth,
        width - contentMinWidth - (sidebarOpen ? sidebarWidth : 0))
    // 1 = open, 0 = collapsed; only these animate (on SuiTheme.duration), so
    // window resizes and splitter moves apply at once.
    property real _sidebarShown: sidebarOpen ? 1 : 0
    property real _inspectorShown: hasInspector && inspectorOpen ? 1 : 0
    Behavior on _sidebarShown { NumberAnimation { duration: SuiTheme.duration; easing.type: Easing.OutCubic } }
    Behavior on _inspectorShown { NumberAnimation { duration: SuiTheme.duration; easing.type: Easing.OutCubic } }

    implicitWidth: sidebarWidth + contentMinWidth + (hasInspector ? inspectorWidth : 0)
    implicitHeight: 480

    function _adopt(item, pane) {
        if (!item)
            return
        item.parent = pane
        item.anchors.fill = pane
    }
    function _contains(ancestor, item) {
        for (let i = item; i; i = i.parent) {
            if (i === ancestor)
                return true
        }
        return false
    }
    function _moveFocusOutOf(pane) {
        const focused = shell.Window.activeFocusItem
        if (focused && _contains(pane, focused) && content)
            content.forceActiveFocus(Qt.OtherFocusReason)
    }
    function _resize(which, size) {
        if (which === "sidebar")
            sidebarWidth = Math.max(sidebarMinWidth, Math.min(size, sidebarMaxWidth, _sidebarRoom))
        else
            inspectorWidth = Math.max(inspectorMinWidth, Math.min(size, inspectorMaxWidth, _inspectorRoom))
    }

    onSidebarChanged: _adopt(sidebar, sidebarPane)
    onContentChanged: _adopt(content, contentPane)
    onInspectorChanged: _adopt(inspector, inspectorPane)
    onSidebarOpenChanged: if (!sidebarOpen) _moveFocusOutOf(sidebarPane)
    onInspectorOpenChanged: if (!inspectorOpen) _moveFocusOutOf(inspectorPane)
    Component.onCompleted: {
        _adopt(sidebar, sidebarPane)
        _adopt(content, contentPane)
        _adopt(inspector, inspectorPane)
    }

    Rectangle {
        anchors.fill: parent
        color: SuiTheme.bg
    }

    Rectangle {
        id: sidebarPane
        objectName: "sidebarPane"
        x: 0
        height: parent.height
        width: Math.round(Math.min(shell.sidebarWidth, shell._sidebarRoom) * shell._sidebarShown)
        visible: width > 0
        enabled: shell.sidebarOpen  // leaves the Tab order as soon as it collapses
        clip: true
        color: SuiTheme.bgElevated
        Accessible.role: Accessible.Pane
        Accessible.name: shell.sidebarLabel
    }

    SuiSplitHandle {
        id: sidebarHandle
        objectName: "sidebarHandle"
        label: "Resize " + shell.sidebarLabel.toLowerCase()
        visible: shell.sidebarOpen && shell.sidebar !== null
        x: sidebarPane.width - width / 2
        z: 2
        height: parent.height
        value: shell.sidebarWidth
        minimum: shell.sidebarMinWidth
        maximum: Math.min(shell.sidebarMaxWidth, shell._sidebarRoom)
        step: shell.resizeStep
        direction: 1
        onResizeRequested: (size) => shell._resize("sidebar", size)
        onCollapseRequested: shell.sidebarOpen = false
    }

    Rectangle {
        id: contentPane
        objectName: "contentPane"
        x: sidebarPane.width
        width: Math.max(0, shell.width - sidebarPane.width - inspectorPane.width)
        height: parent.height
        clip: true
        color: SuiTheme.panel
        Accessible.role: Accessible.Pane
        Accessible.name: shell.contentLabel
    }

    SuiSplitHandle {
        id: inspectorHandle
        objectName: "inspectorHandle"
        label: "Resize " + shell.inspectorLabel.toLowerCase()
        visible: shell.hasInspector && shell.inspectorOpen
        x: inspectorPane.x - width / 2
        z: 2
        height: parent.height
        value: shell.inspectorWidth
        minimum: shell.inspectorMinWidth
        maximum: Math.min(shell.inspectorMaxWidth, shell._inspectorRoom)
        step: shell.resizeStep
        direction: -1
        onResizeRequested: (size) => shell._resize("inspector", size)
        onCollapseRequested: shell.inspectorOpen = false
    }

    Rectangle {
        id: inspectorPane
        objectName: "inspectorPane"
        x: shell.width - width
        height: parent.height
        width: Math.round(Math.min(shell.inspectorWidth, shell._inspectorRoom) * shell._inspectorShown)
        visible: width > 0
        enabled: shell.inspectorOpen
        clip: true
        color: SuiTheme.bgElevated
        Accessible.role: Accessible.Pane
        Accessible.name: shell.inspectorLabel
    }
}
