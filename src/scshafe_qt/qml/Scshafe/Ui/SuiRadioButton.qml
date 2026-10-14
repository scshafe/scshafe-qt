// SuiRadioButton: one choice of an exclusive group, with a label and optional
// help text.
//
//     Column {
//         SuiRadioButton { text: "16 kHz" }
//         SuiRadioButton { text: "44.1 kHz" }
//         SuiRadioButton { text: "48 kHz"; checked: true }
//     }
//
// The group is Qt's: radio buttons with the same parent are exclusive
// (`autoExclusive`), or put them in a `ButtonGroup` (QtQuick.Templates). The
// group behaves as one control, as browsers do: Tab reaches only its checked
// button (or the first, when none is checked), and the arrow keys move to the
// next or previous button and check it (wrapping), emitting `toggled()`.
// Space checks the focused button. Accessible: RadioButton named by `text`
// (else `label`), described by `description`; name the group with a Grouping
// around it (e.g. a SuiText section heading and Accessible.name on the Column).
import QtQuick
import QtQuick.Templates as T

T.RadioButton {
    id: control

    property string description: ""
    property string label: ""
    readonly property bool _suiRadio: true

    readonly property bool _hot: (hovered || visualFocus) && enabled
    readonly property var _group: T.ButtonGroup.group

    // The buttons of this one's group, in order, that can take focus.
    function _peers() {
        let all
        if (_group)
            all = _group.buttons
        else if (autoExclusive && parent)
            all = Array.prototype.filter.call(parent.children, c => c._suiRadio === true || c === control)
        else
            all = [control]
        return Array.prototype.filter.call(all, b => b === control || (b.visible && b.enabled))
    }
    readonly property bool _tabStop: {
        const peers = _peers()
        const on = peers.find(b => b.checked)
        return on !== undefined ? on === control : peers[0] === control
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    padding: 0
    spacing: SuiTheme.spaceSm
    focusPolicy: _tabStop ? Qt.StrongFocus : Qt.ClickFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.RadioButton
    Accessible.name: text !== "" ? text : label
    Accessible.description: description
    Accessible.checkable: true
    Accessible.checked: checked

    Keys.onPressed: (event) => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        let delta = 0
        switch (event.key) {
        case Qt.Key_Down: case Qt.Key_Right: delta = 1; break
        case Qt.Key_Up: case Qt.Key_Left: delta = -1; break
        default: return
        }
        const peers = control._peers()
        const i = peers.indexOf(control)
        if (peers.length < 2 || i < 0)
            return
        const next = peers[(i + delta + peers.length) % peers.length]
        next.forceActiveFocus(Qt.TabFocusReason)
        if (!next.checked) {
            next.checked = true
            next.toggled()
        }
        event.accepted = true
    }

    indicator: Rectangle {
        objectName: "circle"
        x: control.leftPadding
        y: control.topPadding + content.indicatorY
        implicitWidth: SuiTheme.indicatorSize
        implicitHeight: SuiTheme.indicatorSize
        radius: width / 2
        color: control.checked ? (control._hot ? SuiTheme.accentHover : SuiTheme.accent)
               : control.down ? SuiTheme.alpha(SuiTheme.accent, 0.14)
               : control._hot ? SuiTheme.alpha(SuiTheme.accent, 0.06) : SuiTheme.field
        border.width: 1
        border.color: control.checked ? color : control._hot ? SuiTheme.borderHover : SuiTheme.fieldBorder
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        Rectangle {
            objectName: "dot"
            anchors.centerIn: parent
            visible: control.checked
            width: SuiTheme.indicatorSize / 2 - 2
            height: width
            radius: width / 2
            color: SuiTheme.accentForeground
        }
        SuiFocusRing { targetRadius: width / 2; visible: control.visualFocus }
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
