// Internal: the content of a toggle (SuiCheckBox, SuiRadioButton, SuiSwitch):
// room for the indicator, the label beside it (centred on the indicator's first
// line) and optional help text under the label, as the web's CheckboxField lays
// them out. The toggle draws its indicator at `indicatorY`.
import QtQuick

Item {
    id: root

    property Item control: parent
    property real indicatorWidth: 0
    property real indicatorHeight: 0
    property string text: ""
    property string description: ""

    readonly property bool _hasText: text !== ""
    readonly property bool _hasHelp: description !== ""
    readonly property real _textX: indicatorWidth + (_hasText || _hasHelp ? control.spacing : 0)
    readonly property real _firstLine: Math.max(indicatorHeight, _hasText ? label.implicitHeight : 0)
    // Where the toggle puts its indicator (relative to this item).
    readonly property real indicatorY: (_firstLine - indicatorHeight) / 2

    implicitWidth: _textX + Math.max(_hasText ? label.implicitWidth : 0, _hasHelp ? help.implicitWidth : 0)
    implicitHeight: _firstLine + (_hasHelp ? SuiTheme.spaceXs / 2 + help.implicitHeight : 0)

    SuiText {
        id: label
        objectName: "label"
        visible: root._hasText
        x: root._textX
        y: (root._firstLine - height) / 2
        width: Math.max(0, root.width - x)
        text: root.text
        font.pixelSize: root.control.font.pixelSize
        color: SuiTheme.text
        wrapMode: Text.Wrap
        Accessible.ignored: true  // the toggle is named by its text
    }
    SuiText {
        id: help
        objectName: "description"
        visible: root._hasHelp
        x: root._textX
        y: root._firstLine + SuiTheme.spaceXs / 2
        width: Math.max(0, root.width - x)
        text: root.description
        variant: "caption"
        wrapMode: Text.Wrap
        Accessible.ignored: true  // the toggle's accessible description
    }
}
