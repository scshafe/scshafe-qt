// SuiKbd: a keyboard-key badge (the native `.sui-kbd`), for shortcut hints.
import QtQuick
import QtQuick.Templates as T

T.Control {
    id: control

    property string text: ""

    focusPolicy: Qt.NoFocus
    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    leftPadding: SuiTheme.spaceXs + 1
    rightPadding: leftPadding
    topPadding: 1
    bottomPadding: 1 + 1  // the raised bottom edge
    font.family: SuiTheme.monoFamily
    font.pixelSize: SuiTheme.fontSizeXs

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    contentItem: Text {
        textFormat: Text.PlainText
        text: control.text
        font: control.font
        color: SuiTheme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: SuiTheme.badgeHeight
        radius: SuiTheme.radiusSm - 2
        color: SuiTheme.tint
        border.width: 1
        border.color: SuiTheme.borderStrong
        Rectangle {  // raised bottom edge, like the web kbd's inset shadow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 1
            color: SuiTheme.line
        }
    }
}
