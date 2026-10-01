// SuiBadge: a compact count or status pill (unread counts, "new").
//
// `count` >= 0 shows a number (above `max`: "99+"); otherwise `text` shows.
// Tones as SuiChip. Not interactive.
import QtQuick
import QtQuick.Templates as T

T.Control {
    id: control

    property int count: -1
    property int max: 99
    property string text: count >= 0 ? (count > max ? max + "+" : String(count)) : ""
    property var tone: "neutral"

    focusPolicy: Qt.NoFocus
    visible: text !== ""
    implicitWidth: Math.max(SuiTheme.badgeHeight, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: SuiTheme.badgeHeight
    leftPadding: SuiTheme.spaceXs + 2
    rightPadding: SuiTheme.spaceXs + 2
    topPadding: 0
    bottomPadding: 0
    font.pixelSize: SuiTheme.fontSizeXs
    font.weight: SuiTheme.fontWeightBold
    font.features: ({ "tnum": 1 })

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    contentItem: Text {
        objectName: "label"
        text: control.text
        font: control.font
        color: SuiTheme.toneText(control.tone)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        objectName: "background"
        radius: height / 2
        color: SuiTheme.toneFill(control.tone)
        border.width: 1
        border.color: SuiTheme.toneBorder(control.tone)
    }
}
