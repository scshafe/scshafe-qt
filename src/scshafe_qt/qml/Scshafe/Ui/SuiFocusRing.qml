// Internal: the keyboard focus ring every interactive component draws
// (the native `:focus-visible` outline). The owner decides when it shows
// (`visible: control.visualFocus` or the list's keyboard flag).
//
// - outside (default): around the target at focusRingOffset, like
//   `outline-offset: 2px`;
// - inset: inside the target's edge, for rows inside a clipping list.
import QtQuick

Rectangle {
    id: ring
    objectName: "focusRing"

    property Item target: parent
    property real targetRadius: SuiTheme.radiusSm
    property bool inset: false

    readonly property int _outset: SuiTheme.focusRingOffset + SuiTheme.focusRingWidth

    anchors.fill: target
    anchors.margins: inset ? 0 : -_outset
    radius: inset ? targetRadius : targetRadius + _outset
    color: "transparent"
    border.width: SuiTheme.focusRingWidth
    border.color: SuiTheme.focusRing
    z: 1000
    Accessible.ignored: true
}
