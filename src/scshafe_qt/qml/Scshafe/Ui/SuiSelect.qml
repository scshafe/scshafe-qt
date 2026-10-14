// SuiSelect: a drop-down choice of one option (Qt's ComboBox, not editable).
//
//     SuiSelect { label: "Input"; model: ["Desk microphone", "Headset", "Line in"] }
//     SuiSelect {
//         label: "Sample rate"
//         model: [{ text: "44.1 kHz", value: 44100 }, { text: "48 kHz", value: 48000 }]
//         textRole: "text"; valueRole: "value"
//         onActivated: (index) => recorder.rate = currentValue
//     }
//
// The model is a JS array of strings, or of objects with `textRole` /
// `valueRole`, a ListModel or any item model. Qt's ComboBox API: `currentIndex`
// (-1: nothing chosen, `placeholderText` shows), `currentText`, `currentValue`,
// `activated(index)` for user choices, `find()`, `indexOfValue()`.
// Keyboard: Space / Enter opens the list, Up/Down and typing a name move,
// Enter chooses, Escape closes; with the list closed Up/Down change the choice.
// The list (max `SuiTheme.menuMaxHeight`, then it scrolls) fades on
// SuiTheme.duration. Accessible: ComboBox named by `label` (its visible label
// lives outside), described by the current text; options are ListItems.
import QtQuick
import QtQuick.Templates as T

T.ComboBox {
    id: control

    property string label: ""
    property string placeholderText: ""

    readonly property bool _hot: (hovered || visualFocus) && enabled
    readonly property bool _showsPlaceholder: currentIndex < 0 && placeholderText !== ""

    function _optionText(model, modelData) {
        if (textRole === "")
            return modelData
        return Array.isArray(control.model) ? modelData[textRole] : model[textRole]
    }

    // Wide enough for the widest option (ComboBox's WidestText policy measures
    // only TextInput content items) and the placeholder.
    readonly property real _widest: {
        let widest = metrics.advanceWidth(placeholderText)
        for (let i = 0, model = control.model; i < count && model !== undefined; ++i)
            widest = Math.max(widest, metrics.advanceWidth(textAt(i)))
        return Math.ceil(widest)
    }
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            _widest + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    leftPadding: SuiTheme.spaceSm + 2
    rightPadding: SuiTheme.spaceSm + SuiTheme.iconSize + SuiTheme.spaceXs
    topPadding: SuiTheme.spaceXs
    bottomPadding: SuiTheme.spaceXs
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.ComboBox
    Accessible.name: label !== "" ? label : displayText
    Accessible.description: label !== "" ? (_showsPlaceholder ? placeholderText : displayText) : ""

    Component.onCompleted: {
        if (label === "")
            console.warn("SuiSelect has no label (its accessible name)")
    }

    delegate: T.ItemDelegate {
        id: option
        required property var model
        required property int index
        readonly property var modelData: model.modelData
        readonly property bool current: control.currentIndex === index

        width: ListView.view ? ListView.view.width : implicitWidth
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        implicitHeight: SuiTheme.controlHeight
        leftPadding: SuiTheme.spaceSm
        rightPadding: SuiTheme.spaceSm
        spacing: SuiTheme.spaceSm
        text: control._optionText(model, modelData)
        font: control.font
        highlighted: control.highlightedIndex === index
        hoverEnabled: control.hoverEnabled

        Accessible.role: Accessible.ListItem
        Accessible.name: text
        Accessible.selectable: true
        Accessible.selected: current

        contentItem: Row {
            spacing: option.spacing
            SuiIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "check"
                size: SuiTheme.iconSizeSm
                color: SuiTheme.accent
                opacity: option.current ? 1 : 0
            }
            Text {
                textFormat: Text.PlainText
                objectName: "optionText"
                anchors.verticalCenter: parent.verticalCenter
                text: option.text
                font: option.font
                color: option.current ? SuiTheme.textStrong : SuiTheme.text
                elide: Text.ElideRight
                width: option.availableWidth - SuiTheme.iconSizeSm - option.spacing
            }
        }
        background: Rectangle {
            radius: SuiTheme.radiusSm
            color: option.highlighted ? SuiTheme.accentSubtle : option.hovered ? SuiTheme.bgHover : "transparent"
        }
    }

    indicator: SuiIcon {
        objectName: "chevron"
        x: control.width - width - SuiTheme.spaceSm
        y: (control.height - height) / 2
        name: "chevron-down"
        color: control._hot || control.popup.visible ? SuiTheme.text : SuiTheme.muted
    }

    contentItem: Text {
        textFormat: Text.PlainText
        objectName: "valueText"
        text: control._showsPlaceholder ? control.placeholderText : control.displayText
        font: control.font
        color: control._showsPlaceholder ? SuiTheme.muted : SuiTheme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: 140
        implicitHeight: SuiTheme.controlHeight
        radius: SuiTheme.radiusSm
        color: control.down ? SuiTheme.alpha(SuiTheme.accent, 0.08) : SuiTheme.field
        border.width: 1
        border.color: control.popup.visible ? SuiTheme.accent : control._hot ? SuiTheme.borderHover : SuiTheme.fieldBorder
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { visible: control.visualFocus }
    }

    FontMetrics { id: metrics; font: control.font }

    popup: T.Popup {
        objectName: "popup"
        y: control.height + SuiTheme.spaceXs
        // At least the control; wider when an option (check column and padding) needs it.
        width: Math.max(control.width, control._widest + leftPadding + rightPadding
                                       + 3 * SuiTheme.spaceSm + SuiTheme.iconSizeSm)
        implicitHeight: Math.min(contentItem.implicitHeight + topPadding + bottomPadding, SuiTheme.menuMaxHeight)
        padding: SuiTheme.spaceXs
        margins: SuiTheme.spaceSm

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: SuiTheme.duration } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: SuiTheme.duration } }

        contentItem: ListView {
            objectName: "options"
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            Accessible.role: Accessible.List
            Accessible.name: control.label
        }

        background: Rectangle {
            radius: SuiTheme.radiusMd
            color: SuiTheme.popover
            border.width: 1
            border.color: SuiTheme.borderStrong
        }
    }
}
