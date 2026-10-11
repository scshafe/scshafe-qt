// SuiCheckBox: a labelled checkbox (the native counterpart of @scshafe/ui's
// CheckboxField): the box, its label beside it and optional help text under
// the label.
//
//     SuiCheckBox { text: "Normalise loudness"; description: "Every take to -23 LUFS"; checked: true }
//     SuiCheckBox { text: "All takes"; tristate: true; checkState: Qt.PartiallyChecked }
//     SuiCheckBox { label: "Select take 3" }      // no visible text: `label` names it
//
// Qt's CheckBox: `checked`, `checkState`, `tristate`, `toggled()` (user
// changes) and `clicked()`; Space or a click anywhere on it toggles. The box
// is the accent with an `accentForeground` mark when checked (a dash when
// partially checked) and shows the focus ring for keyboard focus. Accessible:
// CheckBox named by `text` (else `label`), described by `description`.
import QtQuick
import QtQuick.Templates as T

T.CheckBox {
    id: control

    property string description: ""
    property string label: ""

    readonly property bool _hot: (hovered || visualFocus) && enabled
    readonly property bool _on: checkState !== Qt.Unchecked

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    spacing: SuiTheme.spaceSm
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.CheckBox
    Accessible.name: text !== "" ? text : label
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: checked

    indicator: Rectangle {
        objectName: "box"
        x: control.leftPadding
        y: control.topPadding + content.indicatorY
        implicitWidth: SuiTheme.indicatorSize
        implicitHeight: SuiTheme.indicatorSize
        radius: SuiTheme.checkboxRadius
        color: control._on ? (control._hot ? SuiTheme.accentHover : SuiTheme.accent)
               : control.down ? SuiTheme.alpha(SuiTheme.accent, 0.14)
               : control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.06) : SuiTheme.field
        border.width: 1
        border.color: control._on ? color : control._hot ? SuiTheme.borderHover : SuiTheme.fieldBorder
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        SuiIcon {
            objectName: "checkMark"
            anchors.centerIn: parent
            visible: control.checkState === Qt.Checked
            name: "check"
            size: SuiTheme.indicatorSize - 2
            color: SuiTheme.accentForeground
        }
        Rectangle {
            objectName: "partialMark"
            anchors.centerIn: parent
            visible: control.checkState === Qt.PartiallyChecked
            width: SuiTheme.indicatorSize / 2
            height: SuiTheme.focusRingWidth
            radius: height / 2
            color: SuiTheme.accentForeground
        }
        SuiFocusRing { targetRadius: SuiTheme.checkboxRadius; visible: control.visualFocus }
    }

    contentItem: SuiToggleLabel {
        id: content
        control: control
        indicatorWidth: control.indicator.width
        indicatorHeight: control.indicator.height
        text: control.text
        description: control.description
    }
}
