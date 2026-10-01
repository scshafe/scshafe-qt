// SuiBanner: an inline status message across a pane (the native `.sui-banner`).
//
//     SuiBanner {
//         tone: "warn"; title: "Endpoint held"
//         text: "Deliveries to Receipts are paused."
//         dismissible: true
//         SuiButton { text: "Resume"; variant: "secondary" }   // optional actions
//     }
//
// `tone`: "info" | "ok" | "warn" | "danger". `dismiss()` (and the close button
// when `dismissible`) hides it and emits `dismissed()`; set `open: true` to
// show it again. warn/danger are alerts for assistive technology.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Control {
    id: control

    property string tone: "info"
    property string title: ""
    property string text: ""
    property bool dismissible: false
    property bool open: true
    default property alias actions: actionsRow.data
    signal dismissed()

    function dismiss() {
        if (!open)
            return
        open = false
        dismissed()
    }

    readonly property string iconName: tone === "danger" ? "danger" : tone === "warn" ? "warning"
                                       : tone === "ok" ? "check" : "info"

    visible: open
    focusPolicy: Qt.NoFocus
    padding: SuiTheme.spaceMd
    topPadding: SuiTheme.spaceSm + 2
    bottomPadding: SuiTheme.spaceSm + 2
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    Accessible.role: tone === "warn" || tone === "danger" ? Accessible.AlertMessage : Accessible.Grouping
    Accessible.name: title !== "" ? title : text
    Accessible.description: title !== "" ? text : ""

    contentItem: RowLayout {
        spacing: SuiTheme.spaceSm
        SuiIcon {
            objectName: "icon"
            name: control.iconName
            color: SuiTheme.toneText(control.tone)
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 1
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Text {
                objectName: "title"
                visible: text !== ""
                text: control.title
                font.pixelSize: SuiTheme.fontSizeMd
                font.weight: SuiTheme.fontWeightStrong
                color: SuiTheme.toneText(control.tone)
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                objectName: "body"
                visible: text !== ""
                text: control.text
                font.pixelSize: SuiTheme.fontSizeMd
                color: SuiTheme.text
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        Row {
            id: actionsRow
            objectName: "actions"
            spacing: SuiTheme.spaceSm
            visible: children.length > 0
            Layout.alignment: Qt.AlignVCenter
        }
        SuiIconButton {
            objectName: "dismissButton"
            visible: control.dismissible
            label: "Dismiss"
            icon.name: "close"
            Layout.alignment: Qt.AlignTop
            onClicked: control.dismiss()
        }
    }

    background: Rectangle {
        objectName: "background"
        radius: SuiTheme.radiusMd
        color: SuiTheme.toneFill(control.tone)
        border.width: 1
        border.color: SuiTheme.toneBorder(control.tone)
    }
}
