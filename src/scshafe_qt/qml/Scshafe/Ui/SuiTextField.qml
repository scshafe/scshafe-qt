// SuiTextField: a single-line text input (the native `.sui-input`).
//
// The focus ring shows whenever the field has focus, from the keyboard or the
// pointer: browsers match `:focus-visible` on text inputs for both, because
// the caret alone is a weak indicator. `label` is the accessible name when the
// field has no visible label (falls back to the placeholder).
import QtQuick
import QtQuick.Templates as T

T.TextField {
    id: control

    property string label: ""

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding,
                            placeholder.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    leftPadding: SuiTheme.spaceSm
    rightPadding: SuiTheme.spaceSm
    topPadding: SuiTheme.spaceXs
    bottomPadding: SuiTheme.spaceXs
    verticalAlignment: TextInput.AlignVCenter
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    font.pixelSize: SuiTheme.fontSizeMd
    color: SuiTheme.text
    selectionColor: SuiTheme.alpha(SuiTheme.accent, 0.32)
    selectedTextColor: SuiTheme.textStrong
    placeholderTextColor: SuiTheme.muted

    Accessible.role: Accessible.EditableText
    Accessible.name: label !== "" ? label : placeholderText
    Accessible.editable: true

    Text {
        textFormat: Text.PlainText
        id: placeholder
        objectName: "placeholder"
        x: control.leftPadding
        y: control.topPadding
        width: control.width - (control.leftPadding + control.rightPadding)
        height: control.height - (control.topPadding + control.bottomPadding)
        text: control.placeholderText
        font: control.font
        color: control.placeholderTextColor
        verticalAlignment: control.verticalAlignment
        elide: Text.ElideRight
        visible: !control.length && !control.preeditText
        Accessible.ignored: true
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: 200
        implicitHeight: SuiTheme.controlHeight
        radius: SuiTheme.radiusSm
        color: SuiTheme.field
        border.width: 1
        border.color: control.activeFocus ? SuiTheme.accent
                      : control.hovered ? SuiTheme.borderHover : SuiTheme.fieldBorder
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { visible: control.activeFocus }
    }
}
