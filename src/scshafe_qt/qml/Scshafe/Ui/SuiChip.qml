// SuiChip: a small labelled pill (the native `.sui-badge` / `.sui-chip`).
//
// `tone`: "neutral" (default) | "info" | "ok" | "warn" | "danger" |
// "bucket1".."bucket8" (or a bucket number). Text is the tone's text colour on
// the tone's tint (SuiTheme.toneFill), contrast-checked >= 4.5:1 in both themes
// over every surface. `dot` adds a leading tone dot; `iconName` a SuiIcon.
// Not interactive: put it in a button or row for actions.
import QtQuick
import QtQuick.Templates as T

T.Control {
    id: control

    property string text: ""
    property var tone: "neutral"
    property bool dot: false
    property string iconName: ""

    focusPolicy: Qt.NoFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(SuiTheme.chipHeight, implicitContentHeight + topPadding + bottomPadding)
    leftPadding: SuiTheme.spaceSm
    rightPadding: SuiTheme.spaceSm
    topPadding: 0
    bottomPadding: 0
    font.pixelSize: SuiTheme.fontSizeSm
    font.weight: SuiTheme.fontWeightStrong

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    contentItem: Row {
        spacing: SuiTheme.spaceXs
        Rectangle {
            objectName: "dot"
            visible: control.dot
            width: SuiTheme.statusDotSize - 2
            height: width
            radius: width / 2
            color: SuiTheme.toneBase(control.tone)
            anchors.verticalCenter: parent.verticalCenter
        }
        SuiIcon {
            visible: control.iconName !== ""
            name: control.iconName
            size: SuiTheme.iconSizeSm
            color: SuiTheme.toneText(control.tone)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            objectName: "label"
            text: control.text
            font: control.font
            color: SuiTheme.toneText(control.tone)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        objectName: "background"
        radius: height / 2
        color: SuiTheme.toneFill(control.tone)
        border.width: 1
        border.color: SuiTheme.toneBorder(control.tone)
    }
}
