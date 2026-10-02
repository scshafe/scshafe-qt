// SuiEmptyState: what a pane shows when it has nothing to show.
//
//     SuiEmptyState {
//         iconName: "inbox"; title: "Inbox zero"
//         description: "Nothing is waiting to be sorted."
//         SuiButton { text: "Refresh" }          // optional actions
//     }
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Control {
    id: control

    property string iconName: ""
    property string title: ""
    property string description: ""
    default property alias actions: actionsRow.data

    focusPolicy: Qt.NoFocus
    padding: SuiTheme.spaceXl
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    Accessible.role: Accessible.Grouping
    Accessible.name: title
    Accessible.description: description

    contentItem: Item {
        implicitWidth: Math.min(column.implicitWidth, SuiTheme.dialogWidth)
        implicitHeight: column.implicitHeight
        ColumnLayout {
            id: column
            anchors.centerIn: parent
            width: Math.min(parent.width, SuiTheme.dialogWidth)
            spacing: SuiTheme.spaceSm

            SuiIcon {
                objectName: "icon"
                visible: control.iconName !== ""
                name: control.iconName
                size: SuiTheme.iconSize * 2
                color: SuiTheme.muted
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: SuiTheme.spaceXs
            }
            Text {
                textFormat: Text.PlainText
                objectName: "title"
                text: control.title
                visible: text !== ""
                font.pixelSize: SuiTheme.fontSizeLg
                font.weight: SuiTheme.fontWeightStrong
                color: SuiTheme.textStrong
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Accessible.role: Accessible.Heading
                Accessible.name: text
            }
            Text {
                textFormat: Text.PlainText
                objectName: "description"
                text: control.description
                visible: text !== ""
                font.pixelSize: SuiTheme.fontSizeMd
                color: SuiTheme.muted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Row {
                id: actionsRow
                objectName: "actions"
                spacing: SuiTheme.spaceSm
                visible: children.length > 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: SuiTheme.spaceSm
            }
        }
    }
}
