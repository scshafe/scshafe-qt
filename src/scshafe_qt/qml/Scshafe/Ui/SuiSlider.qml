// SuiSlider: choose a number in a range by dragging or with the keys.
//
//     SuiSlider { label: "Input gain"; from: -24; to: 24; stepSize: 0.5; value: 6; unit: "dB"; showValue: true }
//     SuiSlider { label: "Mix"; orientation: Qt.Vertical; height: 120 }
//
// Qt's Slider: `from`, `to`, `value`, `stepSize`, `snapMode`, `live`,
// `orientation`, `moved()` (every user change: pointer or keys; prefer it to
// onValueChanged for writing back) and `pressed`.
// Keyboard: arrows move one step (`stepSize`, else 1 % of the range),
// PageUp/PageDown ten, Home/End to `from`/`to`; Right/Up increase.
// `valueText` (the value with `decimals` and `unit`; bind it to show something
// else) is drawn beside the track when `showValue` (in `valueWidth`), and is
// the accessible description. Accessible: Slider named by `label`, with Qt's value interface.
import QtQuick
import QtQuick.Templates as T

T.Slider {
    id: control

    property string label: ""
    property string unit: ""
    property bool showValue: false
    // Digits after the point: from stepSize (0.5 -> 1), else from the range.
    property int decimals: stepSize > 0 ? Math.max(0, Math.ceil(-Math.log10(stepSize) - 1e-9))
                                        : Math.abs(to - from) <= 1 ? 2 : Math.abs(to - from) <= 10 ? 1 : 0
    property string valueText: _format(value)
    // Room for valueText beside the track: the wider of the two ends (digits are
    // tabular), so the track does not move as the value changes. Set it when
    // valueText is bound to something wider.
    property real valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth(_format(from)),
                                                 valueMetrics.advanceWidth(_format(to))))

    readonly property bool _hot: (hovered || visualFocus || pressed) && enabled
    readonly property real _inset: SuiTheme.sliderHandleSize / 2
    readonly property real _keyStep: stepSize > 0 ? stepSize : Math.abs(to - from) / 100
    readonly property real _valueWidth: showValue ? valueWidth + SuiTheme.spaceSm : 0

    function _format(v) {
        const n = Number(v).toFixed(decimals)
        return unit !== "" ? n + " " + unit : n
    }
    function _setFromKey(v) {
        const before = value
        value = Math.max(Math.min(from, to), Math.min(Math.max(from, to), v))
        if (value !== before)
            moved()
    }

    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitHandleWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitHandleHeight + topPadding + bottomPadding)
    // Half a handle on every side, so the handle stays inside at the ends. (Side
    // paddings must not read `padding`: T.Control then reports a binding loop.)
    leftPadding: _inset
    topPadding: _inset
    rightPadding: horizontal ? _inset + _valueWidth : _inset
    bottomPadding: horizontal ? _inset : _inset + (showValue ? valueLabel.implicitHeight + SuiTheme.spaceXs : 0)
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: valueText

    Component.onCompleted: {
        if (label === "")
            console.warn("SuiSlider has no label (its accessible name)")
    }

    Keys.onPressed: (event) => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const up = from <= to ? 1 : -1
        switch (event.key) {
        case Qt.Key_Right: case Qt.Key_Up: _setFromKey(value + up * _keyStep); break
        case Qt.Key_Left: case Qt.Key_Down: _setFromKey(value - up * _keyStep); break
        case Qt.Key_PageUp: _setFromKey(value + up * 10 * _keyStep); break
        case Qt.Key_PageDown: _setFromKey(value - up * 10 * _keyStep); break
        case Qt.Key_Home: _setFromKey(from); break
        case Qt.Key_End: _setFromKey(to); break
        default: return
        }
        event.accepted = true
    }

    FontMetrics { id: valueMetrics; font: valueLabel.font }

    background: Item {
        objectName: "background"
        implicitWidth: control.horizontal ? 200 : SuiTheme.sliderHandleSize
        implicitHeight: control.horizontal ? SuiTheme.sliderHandleSize : 200
        x: control.leftPadding
        y: control.topPadding
        width: control.availableWidth
        height: control.availableHeight

        Rectangle {
            objectName: "track"
            x: control.horizontal ? 0 : (parent.width - width) / 2
            y: control.horizontal ? (parent.height - height) / 2 : 0
            width: control.horizontal ? parent.width : SuiTheme.sliderTrackHeight
            height: control.horizontal ? SuiTheme.sliderTrackHeight : parent.height
            radius: SuiTheme.sliderTrackHeight / 2
            color: SuiTheme.borderStrong

            Rectangle {
                objectName: "fill"
                x: 0
                y: control.horizontal ? 0 : parent.height - height
                width: control.horizontal ? control.visualPosition * parent.width : parent.width
                height: control.horizontal ? parent.height : (1 - control.visualPosition) * parent.height
                radius: parent.radius
                color: control._hot ? SuiTheme.accentHover : SuiTheme.accent
            }
        }
    }

    handle: Rectangle {
        objectName: "handle"
        x: control.leftPadding + (control.horizontal ? control.visualPosition * control.availableWidth - width / 2
                                                     : (control.availableWidth - width) / 2)
        y: control.topPadding + (control.horizontal ? (control.availableHeight - height) / 2
                                                    : control.visualPosition * control.availableHeight - height / 2)
        implicitWidth: SuiTheme.sliderHandleSize
        implicitHeight: SuiTheme.sliderHandleSize
        radius: width / 2
        color: SuiTheme.panel
        border.width: SuiTheme.focusRingWidth
        border.color: control._hot ? SuiTheme.accentHover : SuiTheme.accent
        Behavior on border.color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { targetRadius: width / 2; visible: control.visualFocus }
    }

    SuiText {
        id: valueLabel
        objectName: "valueText"
        visible: control.showValue
        x: control.horizontal ? control.width - control._valueWidth + SuiTheme.spaceSm : (control.width - width) / 2
        y: control.horizontal ? (control.height - height) / 2 : control.height - height
        text: control.valueText
        tabular: true
        Accessible.ignored: true
    }
}
