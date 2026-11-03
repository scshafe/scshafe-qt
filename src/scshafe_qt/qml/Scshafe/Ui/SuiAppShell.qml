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
// - `sidebarHideable`: the sidebar is docked (`sidebarOpen`) or hidden. A pin
//   button in its top-right corner (`pinLabel`) docks and hides it. While it is
//   hidden, the pointer resting in a SuiTheme.sidebarRevealSize square at the
//   content's top-left (from `sidebarRevealTop`, which defaults to the safe
//   area's top: below a macOS title bar the content extends under, never over
//   the traffic lights) for SuiTheme.sidebarRevealDelay slides it in as an
//   overlay that does not move the content (`sidebarRevealed`). It stays while
//   the pointer is over it and slides away SuiTheme.sidebarHideDelay after the
//   pointer leaves.
// - `sidebarShortcut` (e.g. "Ctrl+Meta+S", ⌃⌘S on macOS; "" = none) calls
//   toggleSidebar() from anywhere in the window.
// - `settingsCategory` (non-empty) keeps `sidebarOpen` and `sidebarWidth` in
//   QtCore Settings (the app sets its organization and application names, or
//   `settingsLocation`): restored on load, written on change.
import QtQuick
import QtCore

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

    property bool sidebarHideable: false
    property string sidebarShortcut: ""
    property real sidebarRevealTop: SafeArea.margins.top
    readonly property bool sidebarRevealed: _revealed && !sidebarOpen
    property string settingsCategory: ""
    property url settingsLocation: ""

    property string sidebarLabel: "Sidebar"
    property string contentLabel: "Content"
    property string inspectorLabel: "Inspector"
    property string pinLabel: "Pin sidebar"

    function toggleInspector() { inspectorOpen = !inspectorOpen }
    function toggleSidebar() { sidebarOpen = !sidebarOpen }

    readonly property bool hasInspector: inspector !== null
    readonly property real _sidebarRoom: Math.max(sidebarMinWidth,
        width - contentMinWidth - (hasInspector && inspectorOpen ? inspectorWidth : 0))
    readonly property real _inspectorRoom: Math.max(inspectorMinWidth,
        width - contentMinWidth - (sidebarOpen ? sidebarWidth : 0))
    readonly property real _sidebarPaneWidth: Math.round(Math.min(sidebarWidth, _sidebarRoom))
    property bool _revealed: false
    property bool _ready: false  // no animation while settings restore
    // 1 = open, 0 = collapsed; only these animate (on SuiTheme.duration), so
    // window resizes and splitter moves apply at once. The content follows
    // _sidebarShown (docked); the sidebar pane follows _sidebarPaneShown
    // (docked or revealed), so docking a revealed sidebar moves only the content.
    property real _sidebarShown: sidebarOpen ? 1 : 0
    property real _sidebarPaneShown: sidebarOpen || _revealed ? 1 : 0
    property real _inspectorShown: hasInspector && inspectorOpen ? 1 : 0
    Behavior on _sidebarShown {
        enabled: shell._ready
        NumberAnimation { duration: SuiTheme.duration; easing.type: Easing.OutCubic }
    }
    Behavior on _sidebarPaneShown {
        enabled: shell._ready
        NumberAnimation { duration: SuiTheme.duration * (shell.sidebarRevealed ? 2 : 1); easing.type: Easing.OutCubic }
    }
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
    function _conceal() {
        hideTimer.stop()
        if (!_revealed)
            return
        if (!sidebarOpen)
            _moveFocusOutOf(sidebarPane)  // before the pane is disabled
        _revealed = false
    }
    function _pointerLeft() {
        if (sidebarRevealed && !paneHover.hovered && !zoneHover.hovered)
            hideTimer.restart()
    }
    function _restore(settings) {
        const open = settings.value("sidebarOpen", sidebarOpen)
        sidebarOpen = open === true || open === "true"
        const width = Number(settings.value("sidebarWidth", sidebarWidth))
        if (isFinite(width) && width > 0)
            sidebarWidth = Math.max(sidebarMinWidth, Math.min(width, sidebarMaxWidth))
    }

    onSidebarChanged: _adopt(sidebar, sidebarPane)
    onContentChanged: _adopt(content, contentPane)
    onInspectorChanged: _adopt(inspector, inspectorPane)
    onSidebarOpenChanged: {
        if (sidebarOpen) {
            _revealed = false  // docked where it was revealed: the content moves, the sidebar stays
            hideTimer.stop()
        } else {
            _moveFocusOutOf(sidebarPane)
        }
        if (settingsLoader.item)
            settingsLoader.item.setValue("sidebarOpen", sidebarOpen)
    }
    onSidebarWidthChanged: if (settingsLoader.item) settingsLoader.item.setValue("sidebarWidth", sidebarWidth)
    onSidebarHideableChanged: if (!sidebarHideable) _conceal()
    onInspectorOpenChanged: if (!inspectorOpen) _moveFocusOutOf(inspectorPane)
    Component.onCompleted: {
        _adopt(sidebar, sidebarPane)
        _adopt(content, contentPane)
        _adopt(inspector, inspectorPane)
        if (settingsLoader.item)
            _restore(settingsLoader.item)
        _ready = true
    }

    Loader {
        id: settingsLoader
        objectName: "settingsLoader"
        active: shell.settingsCategory !== ""
        sourceComponent: Settings {
            category: shell.settingsCategory
            location: shell.settingsLocation
        }
        onLoaded: if (shell._ready) shell._restore(item)
    }

    Shortcut {
        sequence: shell.sidebarShortcut
        enabled: shell.sidebarShortcut !== "" && shell.sidebar !== null && shell.visible
        context: Qt.WindowShortcut
        onActivated: shell.toggleSidebar()
    }

    Timer {
        id: revealTimer
        interval: SuiTheme.sidebarRevealDelay
        onTriggered: {
            if (zoneHover.hovered && shell.sidebarHideable && !shell.sidebarOpen && shell.sidebar !== null)
                shell._revealed = true
        }
    }
    Timer {
        id: hideTimer
        interval: SuiTheme.sidebarHideDelay
        onTriggered: shell._conceal()
    }

    Rectangle {
        anchors.fill: parent
        color: SuiTheme.bg
    }

    // The revealed sidebar's edge over the content: a line and a soft shadow.
    Rectangle {
        objectName: "sidebarOverlayShadow"
        x: sidebarPane.x + sidebarPane.width
        z: 3
        width: SuiTheme.spaceSm
        height: parent.height
        visible: !shell.sidebarOpen && sidebarPane.visible
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: SuiTheme.shadowColor }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    Rectangle {
        id: sidebarPane
        objectName: "sidebarPane"
        x: Math.round(-width * (1 - shell._sidebarPaneShown))
        z: 3  // over the content when revealed
        height: parent.height
        width: shell._sidebarPaneWidth
        visible: shell._sidebarPaneShown > 0 && shell.sidebar !== null
        enabled: shell.sidebarOpen || shell._revealed  // leaves the Tab order as soon as it collapses
        clip: true
        color: SuiTheme.bg  // opaque under bgElevated, for the overlay
        Accessible.role: Accessible.Pane
        Accessible.name: shell.sidebarLabel

        Rectangle {
            anchors.fill: parent
            color: SuiTheme.bgElevated
        }
        Rectangle {
            objectName: "sidebarOverlayEdge"
            anchors.right: parent.right
            width: 1
            height: parent.height
            z: 2
            visible: !shell.sidebarOpen
            color: SuiTheme.borderStrong
        }

        HoverHandler {
            id: paneHover
            onHoveredChanged: {
                if (hovered)
                    hideTimer.stop()
                else
                    shell._pointerLeft()
            }
        }

        SuiIconButton {
            id: pin
            objectName: "sidebarPin"
            z: 1  // over the adopted sidebar
            visible: shell.sidebarHideable
            anchors.top: parent.top
            anchors.topMargin: shell.SafeArea.margins.top + SuiTheme.spaceXs
            anchors.right: parent.right
            anchors.rightMargin: SuiTheme.spaceXs
            label: shell.pinLabel
            icon.name: "pin"
            checkable: true
            checked: shell.sidebarOpen
            // The shell owns the state: apply the toggle, then follow it again.
            onToggled: {
                shell.sidebarOpen = checked
                checked = Qt.binding(() => shell.sidebarOpen)
            }
        }
    }

    SuiSplitHandle {
        id: sidebarHandle
        objectName: "sidebarHandle"
        label: "Resize " + shell.sidebarLabel.toLowerCase()
        visible: shell.sidebarOpen && shell.sidebar !== null
        x: contentPane.x - width / 2
        z: 4
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
        x: Math.round(shell._sidebarPaneWidth * shell._sidebarShown)
        width: Math.max(0, shell.width - x - inspectorPane.width)
        height: parent.height
        clip: true
        color: SuiTheme.panel
        Accessible.role: Accessible.Pane
        Accessible.name: shell.contentLabel
    }

    // The hidden sidebar's hot zone: hover only, so the content under it keeps
    // its clicks and hover.
    Item {
        objectName: "sidebarRevealZone"
        x: 0
        y: shell.sidebarRevealTop
        z: 4
        width: SuiTheme.sidebarRevealSize
        height: SuiTheme.sidebarRevealSize
        visible: shell.sidebarHideable && !shell.sidebarOpen && shell.sidebar !== null
        HoverHandler {
            id: zoneHover
            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop()
                    if (!shell._revealed)
                        revealTimer.restart()
                } else {
                    revealTimer.stop()
                    shell._pointerLeft()
                }
            }
        }
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
