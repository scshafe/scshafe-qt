// SuiButton: the native counterpart of @scshafe/ui's `.sui-button`.
//
// The Q1 component pattern:
// - built on QtQuick.Templates (behaviour, focus and accessibility from Qt; no
//   platform style), drawn only with SuiTheme tokens: no colour literals;
// - keyboard-focusable (Tab), activated with Space / Enter / Return;
// - a visible focus ring (`focusRing`, focusRingWidth / focusRingOffset outside
//   the control) shown for keyboard focus only (visualFocus = :focus-visible);
// - an accessible role and name (the text, or `Accessible.name` for icon-only
//   buttons);
// - every transition on SuiTheme.duration, which is 0 under reduced motion.
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: control

    // "default" | "primary" | "secondary" | "ghost" (the web variants).
    property string variant: "default"

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    leftPadding: variant === "ghost" ? SuiTheme.spaceXs + 2 : SuiTheme.controlPaddingX
    rightPadding: leftPadding
    topPadding: variant === "ghost" ? SuiTheme.spaceXs : SuiTheme.controlPaddingY
    bottomPadding: topPadding
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    font.pixelSize: SuiTheme.fontSizeMd
    font.weight: variant === "primary" ? SuiTheme.fontWeightBold : SuiTheme.fontWeightStrong

    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: control.click()

    readonly property bool _hot: (hovered || visualFocus) && enabled

    contentItem: Text {
        objectName: "label"
        text: control.text
        font: control.font
        color: control.variant === "ghost" && !control._hot ? SuiTheme.muted : SuiTheme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: 64
        implicitHeight: 28
        radius: SuiTheme.radiusSm
        border.width: 1
        border.color: {
            switch (control.variant) {
            case "primary": return SuiTheme.alpha(SuiTheme.accent, 0.56)
            case "secondary": return SuiTheme.borderStrong
            case "ghost": return control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.32) : "transparent"
            default: return control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.40) : SuiTheme.line
            }
        }
        color: {
            const pressedBoost = control.down ? 0.06 : 0
            switch (control.variant) {
            case "primary": return SuiTheme.alpha(SuiTheme.accent, (control._hot ? 0.20 : 0.14) + pressedBoost)
            case "secondary": return control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.08 + pressedBoost) : SuiTheme.tint
            case "ghost": return control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.06 + pressedBoost) : "transparent"
            default: return control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.08 + pressedBoost) : SuiTheme.field
            }
        }
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        // Keyboard focus ring: outside the control like `outline-offset: 2px`.
        Rectangle {
            objectName: "focusRing"
            visible: control.visualFocus
            anchors.fill: parent
            anchors.margins: -(SuiTheme.focusRingOffset + SuiTheme.focusRingWidth)
            radius: parent.radius + SuiTheme.focusRingOffset + SuiTheme.focusRingWidth
            color: "transparent"
            border.width: SuiTheme.focusRingWidth
            border.color: SuiTheme.focusRing
        }
    }
}
