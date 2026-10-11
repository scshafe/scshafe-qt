// Internal: a themed scroll bar for Flickables (SuiTable's body), attached as
// `T.ScrollBar.vertical: SuiScrollBar {}` / `T.ScrollBar.horizontal`.
//
// Shown while the content overflows (AsNeeded); the thumb is a muted pill, at
// least SuiTheme.space2xl long, that thickens and darkens on hover and while
// dragged (on SuiTheme.duration). Not a Tab stop: the view it scrolls has the
// keys.
import QtQuick
import QtQuick.Templates as T

T.ScrollBar {
    id: control

    readonly property bool _hot: hovered || pressed
    readonly property real _length: horizontal ? width : height

    implicitWidth: horizontal ? 0 : SuiTheme.scrollBarSize
    implicitHeight: horizontal ? SuiTheme.scrollBarSize : 0
    padding: SuiTheme.focusRingWidth
    minimumSize: _length > 0 ? Math.min(1, SuiTheme.space2xl / _length) : 0
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    policy: T.ScrollBar.AsNeeded
    visible: size < 1 && policy !== T.ScrollBar.AlwaysOff

    Accessible.role: Accessible.ScrollBar

    contentItem: Item {
        implicitWidth: control.horizontal ? 0 : SuiTheme.scrollBarSize - 2 * control.padding
        implicitHeight: control.horizontal ? SuiTheme.scrollBarSize - 2 * control.padding : 0
        Rectangle {
            objectName: "thumb"
            readonly property real full: control.horizontal ? parent.height : parent.width
            property real thickness: control._hot ? full : full / 2
            Behavior on thickness { NumberAnimation { duration: SuiTheme.duration } }
            x: control.horizontal ? 0 : parent.width - width
            y: control.horizontal ? parent.height - height : 0
            width: control.horizontal ? parent.width : thickness
            height: control.horizontal ? thickness : parent.height
            radius: thickness / 2
            color: SuiTheme.alpha(SuiTheme.muted, control.pressed ? 0.8 : control._hot ? 0.6 : 0.4)
            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        }
    }
}
