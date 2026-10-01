// SuiTrail: a vertical list of steps with a connecting line, e.g. how a
// message was sorted (rule -> model -> escalation -> result).
//
//     SuiTrail {
//         label: "Sort trail"
//         steps: [
//             { title: "Sender rules", outcome: "no match", via: "whitelist" },
//             { title: "Classifier", outcome: "Receipts", outcomeTone: "bucket3",
//               detail: "0.91 confidence", via: "model" },
//             { title: "Auditor", outcome: "disputed", outcomeTone: "warn",
//               warning: "Auditor disagreed: Newsletters" }
//         ]
//     }
//
// Each step: `title`, `outcome` (a chip; `outcomeTone` as SuiChip's tone),
// `detail` (wrapping text), `via` (a monospace tag: which rule, model or
// person decided), `warning` (true, or a message: a warning marker on the
// node and the message in the warn tone). `steps` is a JS array or a
// ListModel with those roles. Read-only: not in the Tab order; assistive
// technology reads it as a list of steps.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Control {
    id: control

    property var steps: []
    property string label: "Trail"

    readonly property int stepCount: repeater.count

    focusPolicy: Qt.NoFocus
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    padding: 0

    Accessible.role: Accessible.List
    Accessible.name: label

    contentItem: Column {
        spacing: 0
        Repeater {
            id: repeater
            model: control.steps
            delegate: Item {
                id: step
                objectName: "step" + index
                readonly property var entry: (typeof modelData === "object" && modelData !== null) ? modelData : model
                readonly property string title: entry.title !== undefined ? String(entry.title) : ""
                readonly property string outcome: entry.outcome !== undefined ? String(entry.outcome) : ""
                readonly property var outcomeTone: entry.outcomeTone !== undefined ? entry.outcomeTone : "neutral"
                readonly property string detail: entry.detail !== undefined ? String(entry.detail) : ""
                readonly property string via: entry.via !== undefined ? String(entry.via) : ""
                readonly property var warningValue: entry.warning !== undefined ? entry.warning : false
                readonly property bool warned: warningValue === true || (typeof warningValue === "string" && warningValue !== "")
                readonly property string warningText: typeof warningValue === "string" ? warningValue : ""
                readonly property bool last: index === repeater.count - 1
                readonly property int gutter: SuiTheme.iconSize + SuiTheme.spaceSm

                width: control.availableWidth
                implicitHeight: body.implicitHeight + (last ? 0 : SuiTheme.spaceMd)
                height: implicitHeight

                Accessible.role: Accessible.ListItem
                Accessible.name: (index + 1) + ". " + title + (outcome !== "" ? ": " + outcome : "")
                Accessible.description: [detail, via !== "" ? "via " + via : "",
                                         warned ? "Warning" + (warningText !== "" ? ": " + warningText : "") : ""]
                                        .filter(s => s !== "").join(". ")

                // Connector to the next step.
                Rectangle {
                    objectName: "connector"
                    visible: !step.last
                    x: step.gutter / 2 - width / 2 - SuiTheme.spaceSm / 2
                    y: SuiTheme.iconSize + 2
                    width: 1
                    height: step.height - y + 2
                    color: SuiTheme.line
                }
                // Node: a ring, or the warning marker.
                Item {
                    objectName: "node"
                    width: SuiTheme.iconSize
                    height: SuiTheme.iconSize
                    Rectangle {
                        visible: !step.warned
                        anchors.centerIn: parent
                        width: SuiTheme.statusDotSize + 2
                        height: width
                        radius: width / 2
                        color: SuiTheme.panel
                        border.width: SuiTheme.focusRingWidth
                        border.color: step.outcomeTone === "neutral" ? SuiTheme.fieldBorder : SuiTheme.toneBase(step.outcomeTone)
                    }
                    SuiIcon {
                        objectName: "warningMarker"
                        visible: step.warned
                        anchors.centerIn: parent
                        name: "warning"
                        color: SuiTheme.toneText("warn")
                    }
                }

                ColumnLayout {
                    id: body
                    x: step.gutter
                    width: step.width - step.gutter
                    spacing: SuiTheme.spaceXs

                    Flow {
                        spacing: SuiTheme.spaceSm
                        Layout.fillWidth: true
                        Text {
                            objectName: "title"
                            text: step.title
                            font.pixelSize: SuiTheme.fontSizeMd
                            font.weight: SuiTheme.fontWeightStrong
                            color: SuiTheme.textStrong
                            height: SuiTheme.chipHeight
                            verticalAlignment: Text.AlignVCenter
                        }
                        SuiChip {
                            objectName: "outcome"
                            visible: step.outcome !== ""
                            text: step.outcome
                            tone: step.outcomeTone
                        }
                        Rectangle {
                            objectName: "via"
                            visible: step.via !== ""
                            width: viaText.implicitWidth + 2 * SuiTheme.spaceXs + 2
                            height: SuiTheme.chipHeight
                            radius: SuiTheme.radiusSm - 2
                            color: SuiTheme.codeBg
                            border.width: 1
                            border.color: SuiTheme.line
                            Text {
                                id: viaText
                                anchors.centerIn: parent
                                text: "via " + step.via
                                font.family: SuiTheme.monoFamily
                                font.pixelSize: SuiTheme.fontSizeXs
                                color: SuiTheme.muted
                            }
                        }
                    }
                    Text {
                        objectName: "detail"
                        visible: text !== ""
                        text: step.detail
                        font.pixelSize: SuiTheme.fontSizeMd
                        color: SuiTheme.muted
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                    Text {
                        objectName: "warning"
                        visible: step.warningText !== ""
                        text: step.warningText
                        font.pixelSize: SuiTheme.fontSizeMd
                        font.weight: SuiTheme.fontWeightStrong
                        color: SuiTheme.toneText("warn")
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
