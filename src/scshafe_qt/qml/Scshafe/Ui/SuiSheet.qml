// SuiSheet: a modal panel that slides in from an edge (default the right):
// details, editors, settings. A SuiDialog in every other respect: title,
// actions, focus trap, Escape closes, focus returns to the opener.
//
//     SuiSheet { id: rules; title: "Rules for sender"; edge: Qt.RightEdge; ... }
import QtQuick
import QtQuick.Templates as T

SuiDialog {
    id: control

    // Qt.RightEdge (default), Qt.LeftEdge or Qt.BottomEdge.
    property int edge: Qt.RightEdge
    // 0 = off-screen, 1 = in place; animated on open and close.
    property real slide: 1

    readonly property bool _horizontal: edge !== Qt.BottomEdge
    readonly property real _parentWidth: parent ? parent.width : width
    readonly property real _parentHeight: parent ? parent.height : height

    anchors.centerIn: undefined
    width: _horizontal ? Math.min(SuiTheme.sheetWidth, _parentWidth) : _parentWidth
    height: _horizontal ? _parentHeight : Math.min(implicitHeight, _parentHeight * 0.8)
    x: edge === Qt.LeftEdge ? -width * (1 - slide)
       : edge === Qt.RightEdge ? _parentWidth - width * slide : 0
    y: edge === Qt.BottomEdge ? _parentHeight - height * slide : 0

    enter: Transition {
        NumberAnimation { property: "slide"; from: 0; to: 1; duration: SuiTheme.duration * 2; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "slide"; from: 1; to: 0; duration: SuiTheme.duration; easing.type: Easing.InCubic }
    }

    background: Rectangle {
        objectName: "background"
        color: SuiTheme.panel
        border.width: 1
        border.color: SuiTheme.borderStrong
    }
}
