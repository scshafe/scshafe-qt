// SuiToast: a transient notification card. Usually created by SuiToastHost
// (`host.show(...)`); usable on its own.
//
// `timeout` ms (0: stays until dismissed) counts only while the pointer is
// off the toast and focus is outside it; then `dismissRequested()` fires, as
// it does for the close button and Escape. `actionText` adds a button that
// emits `actionTriggered()` and then dismisses.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Control {
    id: control

    property string tone: "info"
    property string title: ""
    property string text: ""
    property string actionText: ""
    property int timeout: SuiTheme.toastTimeout
    signal actionTriggered()
    signal dismissRequested()

    readonly property bool focusWithin: closeButton.activeFocus || actionButton.activeFocus
    readonly property bool paused: hovered || focusWithin
    readonly property string iconName: tone === "danger" ? "danger" : tone === "warn" ? "warning"
                                       : tone === "ok" ? "check" : "info"

    focusPolicy: Qt.NoFocus
    hoverEnabled: true
    implicitWidth: SuiTheme.toastWidth
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    leftPadding: SuiTheme.spaceMd + SuiTheme.focusRingWidth + 1
    rightPadding: SuiTheme.spaceSm
    topPadding: SuiTheme.spaceSm + 2
    bottomPadding: SuiTheme.spaceSm + 2

    Accessible.role: Accessible.AlertMessage
    Accessible.name: title !== "" ? title : text
    Accessible.description: title !== "" ? text : ""

    Keys.onEscapePressed: control.dismissRequested()

    Timer {
        objectName: "timer"
        interval: control.timeout
        running: control.timeout > 0 && control.visible && !control.paused
        onTriggered: control.dismissRequested()
    }

    contentItem: RowLayout {
        spacing: SuiTheme.spaceSm
        SuiIcon {
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
                color: SuiTheme.textStrong
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
        SuiButton {
            id: actionButton
            objectName: "actionButton"
            visible: control.actionText !== ""
            text: control.actionText
            variant: "ghost"
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                control.actionTriggered()
                control.dismissRequested()
            }
        }
        SuiIconButton {
            id: closeButton
            objectName: "closeButton"
            label: "Dismiss notification"
            icon.name: "close"
            Layout.alignment: Qt.AlignTop
            onClicked: control.dismissRequested()
        }
    }

    background: Rectangle {
        objectName: "background"
        radius: SuiTheme.radiusMd
        color: SuiTheme.popover
        border.width: 1
        border.color: SuiTheme.borderStrong
        Rectangle {  // tone stripe
            objectName: "stripe"
            x: 1
            y: 1
            width: SuiTheme.focusRingWidth + 1
            height: parent.height - 2
            radius: width / 2
            color: SuiTheme.toneBase(control.tone)
        }
    }
}
