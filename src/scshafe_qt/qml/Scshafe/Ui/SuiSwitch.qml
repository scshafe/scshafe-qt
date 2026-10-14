// SuiSwitch: an on/off switch with a label and optional help text, for
// settings that apply at once (a checkbox is for choices submitted later).
//
//     SuiSwitch { text: "Monitor input"; description: "Hear the microphone while recording" }
//
// Qt's Switch: `checked`, `toggled()` (user changes), `clicked()`; Space or a
// click toggles and the thumb can be dragged. On: an accent track with an
// `accentForeground` thumb; the thumb slides on SuiTheme.duration (instant
// under reduced motion). Accessible: Qt reports a switch as a CheckBox (checked =
// on), named by `text` (else `label`), described by `description`.
import QtQuick
import QtQuick.Templates as T

T.Switch {
    id: control

    property string description: ""
    property string label: ""

    readonly property bool _hot: (hovered || visualFocus) && enabled

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    spacing: SuiTheme.spaceSm
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.CheckBox
    Accessible.name: text !== "" ? text : label
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: checked

    indicator: Rectangle {
        objectName: "track"
        x: control.leftPadding
        y: control.topPadding + content.indicatorY
        implicitWidth: SuiTheme.switchWidth
        implicitHeight: SuiTheme.switchHeight
        radius: height / 2
        color: control.checked ? (control._hot ? SuiTheme.accentHover : SuiTheme.accent)
               : control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.06) : SuiTheme.field
        border.width: 1
        border.color: control.checked ? color : control._hot ? SuiTheme.borderHover : SuiTheme.fieldBorder
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        Rectangle {
            objectName: "thumb"
            readonly property real inset: (parent.height - height) / 2
            x: inset + control.visualPosition * (parent.width - width - 2 * inset)
            y: inset
            width: SuiTheme.switchThumbSize
            height: SuiTheme.switchThumbSize
            radius: width / 2
            color: control.checked ? SuiTheme.accentForeground : SuiTheme.muted
            Behavior on x {
                enabled: !control.pressed  // follow a drag directly
                NumberAnimation { duration: SuiTheme.duration; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        }
        SuiFocusRing { targetRadius: height / 2; visible: control.visualFocus }
    }

    contentItem: SuiToggleLabel {
        id: content
        control: control
        indicatorWidth: control.indicator.width
        indicatorHeight: control.indicator.height
        text: control.text
        description: control.description
    }
}
