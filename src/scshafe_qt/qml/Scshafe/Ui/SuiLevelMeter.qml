// SuiLevelMeter: a live input level (dBFS by default) with peak hold, a
// latched clip lamp and a pinned-level marker.
//
//     SuiLevelMeter { label: "Input level"; level: recorder.levelDb }
//     SuiLevelMeter {
//         label: "Microphone"; level: input.rmsDb
//         pinnedLevel: settings.gateDb; pinnedLabel: "Gate threshold"; pinEditable: true
//         onPinMoved: (level) => settings.gateDb = level
//     }
//
// `level` is in the meter's unit, `from`..`to` (default -60..0 dB; pass a
// linear 0..1 with `from: 0; to: 1; unit: ""`); -Infinity reads as silence.
// The bar reveals three zones: ok (green) below `warnLevel`, warn (yellow)
// up to `dangerLevel`, danger (red) above. The meter draws each level as it
// comes (no smoothing: ballistics are the app's), so nothing in it animates
// and reduced motion changes nothing.
//
// - Peak hold (`peakHold`, default on): `peak` is the highest level of the
//   last SuiTheme.meterPeakHold ms, drawn as a line in its zone's colour;
//   then it drops to the level. `reset()` clears it and the clip lamp.
// - Clip (`showClip`, default on): `clipped` latches when the level reaches
//   `clipLevel` (default `to`) and lights the lamp after the bar until reset().
// - Pinned level (`pinnedLevel`, NaN for none): a marker the app pins (a
//   target or a gate threshold), named `pinnedLabel`. With `pinEditable` it
//   is a Slider the user moves: Tab to it, arrows by `pinStep` (PageUp/Down
//   ten), Home/End, drag it or click the meter; `pinMoved(level)` fires and
//   `pinnedLevel` follows (write it back from onPinMoved).
// - `showScale` draws tick labels every `scaleStep` units (automatic when 0)
//   and `showValue` the level as `valueText` (`decimals`, `unit`).
// - `orientation`: Qt.Horizontal (default) or Qt.Vertical (bottom = `from`).
//
// Accessible: a ProgressBar named by `label` with Qt's value interface (the
// level) and `valueText`, the peak, the pinned level and clipping in its
// description; the editable pin is a Slider.
import QtQuick
import QtQuick.Templates as T

T.ProgressBar {
    id: meter

    property string label: ""
    property real level: from
    property string unit: "dB"
    property int decimals: 1
    property real warnLevel: -12
    property real dangerLevel: -3
    property bool showScale: true
    property real scaleStep: 0
    property bool showValue: true
    property string valueText: _format(level)
    property int orientation: Qt.Horizontal

    property bool peakHold: true
    readonly property real peak: _peak
    property bool showClip: true
    property real clipLevel: to
    readonly property bool clipped: _clipped

    property real pinnedLevel: NaN
    property string pinnedLabel: "Pinned level"
    property bool pinEditable: false
    property real pinStep: 1
    signal pinMoved(real level)

    readonly property bool horizontal: orientation === Qt.Horizontal
    readonly property bool hasPin: !isNaN(pinnedLevel)

    function reset() {
        _peak = _finite(level)
        _clipped = false
        holdTimer.stop()
    }
    // The zone colour of a level.
    function zoneColor(v) {
        return v >= dangerLevel ? SuiTheme.toneRed : v >= warnLevel ? SuiTheme.toneYellow : SuiTheme.ok
    }
    // 0..1 along the meter (clamped).
    function fractionOf(v) {
        return to === from ? 0 : Math.max(0, Math.min(1, (_finite(v) - from) / (to - from)))
    }

    property real _peak: from
    property bool _clipped: false
    property bool _ready: false  // properties settle in any order: track levels once complete
    Component.onCompleted: {
        _ready = true
        _peak = _finite(level)
        _clipped = level >= clipLevel
    }
    function _finite(v) { return isFinite(v) ? v : (v > 0 ? to : from) }
    function _format(v) {
        const n = isFinite(v) ? Number(v).toFixed(decimals) : (v < 0 ? "-∞" : "∞")
        return unit !== "" ? n + " " + unit : n
    }

    onLevelChanged: {
        if (!_ready)
            return
        if (level >= clipLevel)
            _clipped = true
        if (!peakHold)
            return
        const v = _finite(level)
        if (v >= _peak) {
            _peak = v
            holdTimer.restart()
        } else if (!holdTimer.running) {
            _peak = v
        }
    }
    Timer {
        id: holdTimer
        interval: SuiTheme.meterPeakHold
        onTriggered: meter._peak = meter._finite(meter.level)
    }

    // ---- Geometry ---------------------------------------------------------
    readonly property real _thickness: SuiTheme.meterThickness
    // Room the pin marker needs on the cross axis before the bar (its knob when editable).
    readonly property real _lead: hasPin && pinEditable ? SuiTheme.meterPinSize : SuiTheme.spaceXs / 2
    readonly property real _lampRoom: showClip ? _thickness + SuiTheme.spaceXs : 0
    readonly property real _valueRoom: showValue ? Math.ceil(Math.max(valueMetrics.advanceWidth(_format(from)),
                                                                      valueMetrics.advanceWidth(_format(to)),
                                                                      valueMetrics.advanceWidth(_format(-Infinity))))
                                                   + SuiTheme.spaceSm : 0
    readonly property real _tick: SuiTheme.spaceXs
    readonly property real _scaleRoom: showScale ? (horizontal ? _tick + scaleMetrics.height
                                                               : _tick + SuiTheme.spaceXs + _scaleLabelWidth) : 0
    // Label room from the range's widest label at the most digits a step can need
    // (measuring the chosen step's labels would make the step depend on itself).
    readonly property int _rangeDecimals: scaleStep > 0 ? _decimalsOf(scaleStep)
                                                        : Math.abs(to - from) <= 1 ? 2 : Math.abs(to - from) <= 10 ? 1 : 0
    readonly property real _scaleLabelWidth: Math.ceil(Math.max(scaleMetrics.advanceWidth(Number(from).toFixed(_rangeDecimals)),
                                                                scaleMetrics.advanceWidth(Number(to).toFixed(_rangeDecimals))))
    // Scale ticks: multiples of scaleStep (or the smallest "nice" step that keeps labels apart).
    readonly property real _step: {
        if (scaleStep > 0)
            return scaleStep
        const length = horizontal ? bar.width : bar.height
        const room = (horizontal ? _scaleLabelWidth : scaleMetrics.height) + SuiTheme.spaceMd
        const span = Math.abs(to - from)
        if (length <= 0 || span <= 0)
            return span || 1
        for (const s of [0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 3, 5, 6, 10, 12, 20, 24, 30, 50, 60, 100])
            if (span / s * room <= length)
                return s
        return span
    }
    readonly property var ticks: {
        const out = []
        const lo = Math.min(from, to), hi = Math.max(from, to)
        const first = Math.ceil(lo / _step - 1e-9) * _step
        for (let v = first; v <= hi + 1e-9 && out.length < 200; v += _step)
            out.push(Math.round(v / _step) * _step)
        return out
    }
    function _decimalsOf(step) {
        for (let d = 0; d < 6; ++d)
            if (Math.abs(Math.round(step * Math.pow(10, d)) - step * Math.pow(10, d)) < 1e-6)
                return d
        return 6
    }
    function _scaleText(v) {
        return Number(v).toFixed(_decimalsOf(_step))
    }

    from: -60
    to: 0
    value: _finite(level)
    implicitWidth: horizontal ? 240 : Math.max(_lead + _thickness + SuiTheme.spaceXs / 2 + _scaleRoom,
                                               showValue ? _valueRoom - SuiTheme.spaceSm : 0)
    implicitHeight: horizontal ? _lead + _thickness + SuiTheme.spaceXs / 2 + _scaleRoom
                               : 160 + (showValue ? valueMetrics.height + SuiTheme.spaceXs : 0)
    padding: 0
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    Accessible.role: Accessible.ProgressBar
    Accessible.name: label
    Accessible.description: [valueText,
                             peakHold ? "peak " + _format(_peak) : "",
                             hasPin ? pinnedLabel + " " + _format(pinnedLevel) : "",
                             _clipped ? "clipped" : ""].filter(s => s !== "").join(", ")

    FontMetrics { id: valueMetrics; font: valueLabel.font }
    FontMetrics { id: scaleMetrics; font.pixelSize: SuiTheme.fontSizeXs; font.features: ({ "tnum": 1 }) }

    contentItem: Item {
        // The bar: along the main axis it leaves room for the lamp and the value.
        Item {
            id: bar
            objectName: "bar"
            x: meter.horizontal ? 0 : meter._lead
            y: meter.horizontal ? meter._lead : meter._lampRoom
            width: meter.horizontal ? Math.max(0, parent.width - meter._lampRoom - meter._valueRoom) : meter._thickness
            height: meter.horizontal ? meter._thickness
                                     : Math.max(0, parent.height - meter._lampRoom
                                                   - (meter.showValue ? valueLabel.height + SuiTheme.spaceXs : 0))

            Rectangle {
                objectName: "track"
                anchors.fill: parent
                color: SuiTheme.borderStrong
            }

            // The level reveals the zones.
            Item {
                id: levelClip
                objectName: "levelFill"
                clip: true
                width: meter.horizontal ? meter.fractionOf(meter.level) * bar.width : bar.width
                height: meter.horizontal ? bar.height : meter.fractionOf(meter.level) * bar.height
                y: meter.horizontal ? 0 : bar.height - height

                Repeater {
                    model: 3  // ok, warn, danger
                    Rectangle {
                        required property int index
                        readonly property real a: meter.fractionOf([meter.from, meter.warnLevel, meter.dangerLevel][index])
                        readonly property real b: meter.fractionOf([meter.warnLevel, meter.dangerLevel, meter.to][index])
                        objectName: "zone"
                        color: index === 0 ? SuiTheme.ok : index === 1 ? SuiTheme.toneYellow : SuiTheme.toneRed
                        x: meter.horizontal ? a * bar.width : 0
                        width: meter.horizontal ? Math.max(0, b - a) * bar.width : bar.width
                        // Vertical: zones stack up from the bottom; levelClip's bottom is the bar's.
                        y: meter.horizontal ? 0 : levelClip.height - b * bar.height
                        height: meter.horizontal ? bar.height : Math.max(0, b - a) * bar.height
                    }
                }
            }

            Rectangle {
                objectName: "peakMarker"
                visible: meter.peakHold && meter._peak > meter.from
                readonly property real f: meter.fractionOf(meter._peak)
                color: meter.zoneColor(meter._peak)
                x: meter.horizontal ? Math.min(bar.width - width, Math.max(0, f * bar.width - width / 2)) : 0
                y: meter.horizontal ? 0 : Math.min(bar.height - height, Math.max(0, (1 - f) * bar.height - height / 2))
                width: meter.horizontal ? SuiTheme.focusRingWidth : bar.width
                height: meter.horizontal ? bar.height : SuiTheme.focusRingWidth
            }

            // Scale: ticks and labels on the far side of the bar.
            Repeater {
                model: meter.showScale ? meter.ticks : []
                Item {
                    required property real modelData
                    readonly property real f: meter.fractionOf(modelData)
                    x: meter.horizontal ? f * bar.width : bar.width
                    y: meter.horizontal ? bar.height : (1 - f) * bar.height
                    Rectangle {
                        width: meter.horizontal ? 1 : meter._tick
                        height: meter.horizontal ? meter._tick : 1
                        x: meter.horizontal ? -0.5 : 0
                        y: meter.horizontal ? 0 : -0.5
                        color: SuiTheme.fieldBorder
                    }
                    SuiText {
                        objectName: "scaleLabel"
                        text: meter._scaleText(modelData)
                        variant: "small"
                        tabular: true
                        Accessible.ignored: true
                        // Centred on the tick, kept inside the bar's extent at the ends.
                        x: meter.horizontal ? Math.max(-parent.x, Math.min(bar.width - parent.x - width, -width / 2))
                                            : meter._tick + SuiTheme.spaceXs
                        y: meter.horizontal ? meter._tick
                                            : Math.max(-parent.y, Math.min(bar.height - parent.y - height, -height / 2))
                    }
                }
            }
        }

        Rectangle {
            objectName: "clipLamp"
            visible: meter.showClip
            width: meter._thickness
            height: meter._thickness
            radius: width / 2
            x: meter.horizontal ? bar.x + bar.width + SuiTheme.spaceXs : bar.x
            y: meter.horizontal ? bar.y : 0
            color: meter._clipped ? SuiTheme.toneRed : SuiTheme.borderStrong
        }

        SuiText {
            id: valueLabel
            objectName: "valueText"
            visible: meter.showValue
            text: meter.valueText
            tone: "muted"
            tabular: true
            horizontalAlignment: meter.horizontal ? Text.AlignRight : Text.AlignHCenter
            width: meter.horizontal ? meter._valueRoom - SuiTheme.spaceSm : implicitWidth
            x: meter.horizontal ? parent.width - width : (parent.width - width) / 2
            y: meter.horizontal ? bar.y + (bar.height - height) / 2 : bar.y + bar.height + SuiTheme.spaceXs
            Accessible.ignored: true
        }

        // The pinned level: a marker across the bar; with pinEditable, a Slider
        // whose handle (a line and a knob) the user moves. It spans the bar plus
        // half a handle at each end, so the handle's centre sits on the level.
        T.Slider {
            id: pin
            objectName: "pin"
            visible: meter.hasPin
            enabled: meter.pinEditable
            orientation: meter.orientation
            from: meter.from
            to: meter.to
            value: meter.hasPin ? meter.pinnedLevel : meter.from
            stepSize: 0
            live: true
            padding: 0
            focusPolicy: meter.pinEditable ? Qt.StrongFocus : Qt.NoFocus
            readonly property real knob: meter.pinEditable ? SuiTheme.meterPinSize : SuiTheme.focusRingWidth
            x: meter.horizontal ? bar.x - knob / 2 : 0
            y: meter.horizontal ? 0 : bar.y - knob / 2
            width: meter.horizontal ? bar.width + knob : bar.x + bar.width + SuiTheme.spaceXs / 2
            height: meter.horizontal ? bar.y + bar.height + SuiTheme.spaceXs / 2 : bar.height + knob

            Accessible.role: Accessible.Slider
            Accessible.name: meter.pinnedLabel
            Accessible.description: meter._format(meter.pinnedLevel)
            Accessible.ignored: !meter.pinEditable

            function _set(v) {
                const before = meter.pinnedLevel
                const clamped = Math.max(Math.min(meter.from, meter.to), Math.min(Math.max(meter.from, meter.to), v))
                if (clamped === before)
                    return
                meter.pinnedLevel = clamped
                meter.pinMoved(clamped)
            }
            onMoved: {
                _set(value)
                value = Qt.binding(() => meter.hasPin ? meter.pinnedLevel : meter.from)
            }
            Keys.onPressed: (event) => {
                if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                    return
                const up = meter.from <= meter.to ? 1 : -1
                const step = meter.pinStep > 0 ? meter.pinStep : Math.abs(meter.to - meter.from) / 100
                switch (event.key) {
                case Qt.Key_Right: case Qt.Key_Up: _set(meter.pinnedLevel + up * step); break
                case Qt.Key_Left: case Qt.Key_Down: _set(meter.pinnedLevel - up * step); break
                case Qt.Key_PageUp: _set(meter.pinnedLevel + up * 10 * step); break
                case Qt.Key_PageDown: _set(meter.pinnedLevel - up * 10 * step); break
                case Qt.Key_Home: _set(meter.from); break
                case Qt.Key_End: _set(meter.to); break
                default: return
                }
                event.accepted = true
            }

            background: Item {}
            handle: Item {
                objectName: "pinMarker"
                implicitWidth: meter.horizontal ? pin.knob : pin.width
                implicitHeight: meter.horizontal ? pin.height : pin.knob
                // From the pinned level itself (the slider's own value may be clamped to
                // its range while the bindings settle).
                readonly property real f: meter.fractionOf(meter.pinnedLevel)
                x: meter.horizontal ? f * (pin.width - width) : 0
                y: meter.horizontal ? 0 : (1 - f) * (pin.height - height)

                Rectangle {  // a halo in the surface colour sets the line off the fill
                    color: SuiTheme.panel
                    x: pinLine.x - 1
                    y: pinLine.y - 1
                    width: pinLine.width + 2
                    height: pinLine.height + 2
                }
                Rectangle {  // the line across the bar
                    id: pinLine
                    objectName: "pinLine"
                    color: pin.pressed || pin.hovered ? SuiTheme.accentHover : SuiTheme.accent
                    x: meter.horizontal ? (parent.width - width) / 2 : bar.x - SuiTheme.spaceXs / 2
                    y: meter.horizontal ? bar.y - SuiTheme.spaceXs / 2 : (parent.height - height) / 2
                    width: meter.horizontal ? SuiTheme.focusRingWidth : bar.width + SuiTheme.spaceXs
                    height: meter.horizontal ? bar.height + SuiTheme.spaceXs : SuiTheme.focusRingWidth
                }
                Rectangle {  // the knob before the bar, when the user can move it
                    objectName: "pinKnob"
                    visible: meter.pinEditable
                    width: SuiTheme.meterPinSize
                    height: SuiTheme.meterPinSize
                    radius: width / 2
                    y: meter.horizontal ? 0 : (parent.height - height) / 2
                    color: SuiTheme.panel
                    border.width: SuiTheme.focusRingWidth
                    border.color: pin.pressed || pin.hovered ? SuiTheme.accentHover : SuiTheme.accent
                    SuiFocusRing { targetRadius: width / 2; visible: pin.visualFocus }
                }
            }
        }
    }
}
