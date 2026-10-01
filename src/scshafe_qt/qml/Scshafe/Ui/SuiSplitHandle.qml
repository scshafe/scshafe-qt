// Internal: a resizable splitter between two SuiAppShell panes (the
// focusable "window splitter" pattern).
//
// Keyboard: Left/Right resize by `step` (Shift: 4x), Home/End jump to the
// minimum/maximum, Enter/Return asks to collapse the pane. Pointer: drag.
import QtQuick
import QtQuick.Templates as T

T.Control {
    id: handle

    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 0
    property int step: SuiTheme.splitterStep
    // +1: moving right grows the pane (a left pane); -1: shrinks it (a right pane).
    property int direction: 1
    readonly property bool dragging: drag.active
    signal resizeRequested(real size)
    signal collapseRequested()

    function _request(v) { resizeRequested(Math.max(minimum, Math.min(maximum, v))) }

    implicitWidth: SuiTheme.splitterHandleWidth
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.Separator
    Accessible.name: label
    Accessible.description: Math.round(value) + " pixels wide"
    Accessible.focusable: true

    Keys.onPressed: (event) => {
        const amount = step * ((event.modifiers & Qt.ShiftModifier) ? 4 : 1)
        switch (event.key) {
        case Qt.Key_Left: handle._request(handle.value - amount * handle.direction); break
        case Qt.Key_Right: handle._request(handle.value + amount * handle.direction); break
        case Qt.Key_Home: handle._request(handle.minimum); break
        case Qt.Key_End: handle._request(handle.maximum); break
        case Qt.Key_Return: case Qt.Key_Enter: handle.collapseRequested(); break
        default: return
        }
        event.accepted = true
    }

    HoverHandler { cursorShape: Qt.SplitHCursor }

    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
        property real startValue: 0
        onActiveChanged: {
            if (active) {
                startValue = handle.value
                handle.forceActiveFocus(Qt.MouseFocusReason)
            }
        }
        onActiveTranslationChanged: if (active) handle._request(startValue + activeTranslation.x * handle.direction)
    }

    background: Item {
        Rectangle {
            objectName: "line"
            anchors.horizontalCenter: parent.horizontalCenter
            width: handle.hovered || handle.dragging || handle.visualFocus ? SuiTheme.focusRingWidth : 1
            height: parent.height
            color: handle.hovered || handle.dragging || handle.visualFocus ? SuiTheme.borderHover : SuiTheme.line
            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        }
        SuiFocusRing { inset: true; targetRadius: SuiTheme.radiusSm; visible: handle.visualFocus }
    }
}
