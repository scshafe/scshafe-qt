// SuiIconButton: an icon-only button (the native `.sui-icon-button`).
//
// `label` is required: it is the accessible name (an icon alone says nothing to
// a screen reader). The icon is a built-in SuiIcon name (`icon.name`) or an
// image (`icon.source`, tinted). `checkable` makes it a toggle (e.g. the
// inspector toggle); checked draws the accent.
//
//     SuiIconButton { icon.name: "close"; label: "Dismiss"; onClicked: banner.dismiss() }
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: control

    required property string label
    // "ghost" (default: no border until hovered) | "default" (field surface + border).
    property string variant: "ghost"
    property int iconSize: SuiTheme.iconSize

    text: label
    display: T.AbstractButton.IconOnly
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    padding: (SuiTheme.controlHeight - iconSize) / 2
    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight, implicitContentHeight + topPadding + bottomPadding)
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    Accessible.role: checkable ? Accessible.CheckBox : Accessible.Button
    Accessible.name: label
    Accessible.checkable: checkable
    Accessible.checked: checked
    Accessible.onPressAction: control.click()

    readonly property bool _hot: (hovered || visualFocus) && enabled

    Component.onCompleted: {
        if (icon.name === "" && icon.source.toString() === "")
            console.warn("SuiIconButton", JSON.stringify(label), "has no icon (icon.name or icon.source)")
    }

    contentItem: Item {
        implicitWidth: control.iconSize
        implicitHeight: control.iconSize
        SuiIcon {
            objectName: "icon"
            anchors.centerIn: parent
            name: control.icon.name
            source: control.icon.source
            size: control.iconSize
            color: control.checked ? SuiTheme.accent : control._hot || control.down ? SuiTheme.text : SuiTheme.muted
            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        }
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: SuiTheme.controlHeight
        implicitHeight: SuiTheme.controlHeight
        radius: SuiTheme.radiusSm
        border.width: 1
        border.color: control.variant === "default" ? (control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.40) : SuiTheme.line)
                      : control._hot || control.checked ? SuiTheme.alpha(SuiTheme.accent, 0.32) : "transparent"
        color: {
            const boost = control.down ? 0.06 : 0
            if (control.checked)
                return SuiTheme.alpha(SuiTheme.accent, 0.14 + boost)
            if (control._hot || control.down)
                return SuiTheme.alpha(SuiTheme.accent, 0.08 + boost)
            return control.variant === "default" ? SuiTheme.field : "transparent"
        }
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { visible: control.visualFocus }
    }
}
