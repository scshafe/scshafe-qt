// SuiProgressBar: the determinate progress of a task, with an optional cancel.
//
//     SuiProgressBar { label: "Transcribing take 3"; value: job.fraction }
//     SuiProgressBar {
//         label: "Exporting"; from: 0; to: job.total; value: job.done
//         valueText: job.done + " of " + job.total + " files"
//         cancellable: !job.cancelling
//         onCancelRequested: job.cancel()
//     }
//
// Qt's ProgressBar: `from`, `to` (default 0..1), `value`, `position` (0..1).
// Determinate only (`indeterminate` is not drawn: show a label instead).
// `label` (above the bar, and the accessible name) and `valueText` (beside it:
// the percentage by default, tabular) show unless `showLabel` / `showValue` are
// false. `tone`: "accent" (default) | "ok" | "warn" | "danger" colours the
// fill. The fill moves on SuiTheme.duration (instant under reduced motion).
// `cancellable` adds a cancel button beside the label and bar (a Tab stop
// named `cancelLabel`) that emits `cancelRequested()`; the app stops the task and
// clears `cancellable` (or removes the bar). Accessible: ProgressBar named by
// `label`, described by `valueText`, with Qt's value interface.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.ProgressBar {
    id: control

    property string label: ""
    property bool showLabel: true
    property bool showValue: true
    property string valueText: Math.round(position * 100) + " %"
    property string tone: "accent"
    property bool cancellable: false
    property string cancelLabel: label !== "" ? "Cancel " + label : "Cancel"
    signal cancelRequested()

    readonly property bool _header: (showLabel && label !== "") || showValue

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: valueText

    contentItem: RowLayout {
        spacing: SuiTheme.spaceSm

        ColumnLayout {
            spacing: SuiTheme.spaceXs
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 240

            RowLayout {
                visible: control._header
                spacing: SuiTheme.spaceSm
                Layout.fillWidth: true
                SuiText {
                    objectName: "label"
                    visible: control.showLabel && control.label !== ""
                    text: control.label
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Accessible.ignored: true
                }
                Item { visible: !(control.showLabel && control.label !== ""); Layout.fillWidth: true }
                SuiText {
                    objectName: "valueText"
                    visible: control.showValue
                    text: control.valueText
                    tone: "muted"
                    tabular: true
                    Accessible.ignored: true
                }
            }

            Rectangle {
                objectName: "track"
                Layout.fillWidth: true
                implicitHeight: SuiTheme.progressHeight
                radius: height / 2
                color: SuiTheme.borderStrong

                Rectangle {
                    objectName: "fill"
                    height: parent.height
                    width: control.visualPosition * parent.width
                    radius: parent.radius
                    color: control.tone === "accent" ? SuiTheme.accent : SuiTheme.toneBase(control.tone)
                    Behavior on width { NumberAnimation { duration: SuiTheme.duration; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
                }
            }
        }

        SuiIconButton {
            objectName: "cancelButton"
            visible: control.cancellable
            label: control.cancelLabel
            icon.name: "close"
            Layout.alignment: Qt.AlignVCenter
            onClicked: control.cancelRequested()
        }
    }
}
