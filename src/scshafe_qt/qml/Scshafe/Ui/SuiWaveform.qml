// SuiWaveform: a recording's waveform with trim handles, a playhead and the
// time under the pointer, in frames of the original audio. It draws and
// reports; it never edits audio and never assigns the trim or the playhead.
//
//     SuiWaveform {
//         label: "Take 12"
//         bins: take.bins                     // [min0, max0, min1, max1, ...]
//         frameCount: take.frameCount
//         trimStart: take.trimStart; trimEnd: take.trimEnd
//         playhead: player.playing ? player.frame : -1
//         onTrimChanged: (start, end) => take.setTrim(start, end)
//         onSeekRequested: (frame) => player.seek(frame)
//         onPlayRequested: (frame) => player.playFrom(frame)
//     }
//
// - `bins`: signed extrema as a flat list [min0, max0, min1, max1, ...] in
//   -1..1 (a JS array or a Python list; the owner computes them, about 2,048
//   pairs whatever the length). Values outside -1..1 are clamped. They are
//   drawn min/max per pixel column on a Canvas that repaints only when the
//   bins, the size or the theme change.
// - `frameCount` and `sampleRate` (48000): the original's frames; every frame
//   number here is one of them.
// - The kept frames are `trimStart`..`trimEnd` ([start, end); `trimEnd` 0 or
//   less: to the end); outside them is shaded. Controlled: dragging a handle
//   (with `editable`) shows the new edge in `shownStart` / `shownEnd` and on
//   release emits `trimChanged(start, end)`; write it back from the handler.
// - `playhead`: the frame playing, or -1 for none.
// - `seekRequested(frame)`: pressing or dragging in the waveform, or a key;
//   always within the kept frames. `playRequested(frame)`: a double-click in
//   the kept frames, not on a handle.
// - Keys with the focus on the waveform: Left/Right move 0.1 s from the
//   playhead (or the kept start), Home/End go to the kept edges; ignored with
//   Shift, Ctrl, Alt or Meta.
// - With `editable`, each handle is a Tab stop as well (`trimStartLabel`,
//   `trimEndLabel`): Left/Right move its edge 0.1 s, PageUp/PageDown 1 s,
//   Home/End as far as it goes, each emitting `trimChanged`.
// - Hovering shows a line and the time under the pointer (`hoverFrame`,
//   `hoverText`, m:ss.mmm; while a handle is dragged, its edge's).
//   `placeholderText` shows while there are no bins.
//
// Accessible: a Slider named by `label`, described as "kept X to Y of Z
// seconds", with Qt's value interface in seconds (`value`: the playhead, or
// the kept start; `minimumValue`, `maximumValue`, `stepSize`); its increase
// and decrease actions step like Right and Left. The handles are Sliders over
// their edge's time.
import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T

T.Control {
    id: wave

    property string label: "Waveform"
    property var bins: []
    property int frameCount: 0
    property int sampleRate: 48000
    property int trimStart: 0
    property int trimEnd: 0
    property int playhead: -1
    property bool editable: true
    property string placeholderText: ""
    property string trimStartLabel: "Trim start"
    property string trimEndLabel: "Trim end"

    signal seekRequested(int frame)
    signal trimChanged(int start, int end)
    signal playRequested(int frame)

    readonly property bool hasAudio: frameCount > 0
    readonly property int shownStart: _dragStart >= 0 ? _dragStart : _start
    readonly property int shownEnd: _dragEnd >= 0 ? _dragEnd : _end
    readonly property int hoverFrame: _drag === "start" ? shownStart : _drag === "end" ? shownEnd : _hoverFrame
    readonly property string hoverText: hoverFrame >= 0 && hasAudio ? formatTime(hoverFrame) : ""

    // Qt's accessible value interface reads these (seconds).
    readonly property real value: (playhead >= 0 ? Math.min(playhead, frameCount) : shownStart) / _rate
    readonly property real minimumValue: 0
    readonly property real maximumValue: frameCount / _rate
    readonly property real stepSize: 0.1

    // "m:ss.mmm" for a frame.
    function formatTime(frame) {
        const ms = Math.round(frame * 1000 / _rate)
        const seconds = Math.floor(ms / 1000) % 60
        return Math.floor(ms / 60000) + ":" + String(seconds).padStart(2, "0") + "."
               + String(ms % 1000).padStart(3, "0")
    }
    // Frames <-> x in the waveform's coordinates.
    function xAt(frame) {
        return _inset + (hasAudio ? frame / frameCount : 0) * _plotWidth
    }
    function frameAt(x) {
        return hasAudio ? Math.round(Math.max(0, Math.min(1, (x - _inset) / _plotWidth)) * frameCount) : 0
    }

    // ---- State ------------------------------------------------------------------
    readonly property real _rate: Math.max(1, sampleRate)
    readonly property int _step: Math.max(1, Math.floor(sampleRate / 10))
    // The kept frames as given, clamped to the clip.
    readonly property int _start: hasAudio ? Math.max(0, Math.min(trimStart, frameCount - 1)) : 0
    readonly property int _end: !hasAudio ? 0 : trimEnd > 0 ? Math.max(_start + 1, Math.min(trimEnd, frameCount)) : frameCount
    // Bins as numbers in -1..1, min <= max.
    readonly property var _pairs: {
        const b = bins || []
        const n = Math.floor(b.length / 2)
        const out = new Array(2 * n)
        for (let i = 0; i < n; ++i) {
            let lo = Number(b[2 * i]), hi = Number(b[2 * i + 1])
            lo = isFinite(lo) ? Math.max(-1, Math.min(1, lo)) : 0
            hi = isFinite(hi) ? Math.max(-1, Math.min(1, hi)) : 0
            out[2 * i] = Math.min(lo, hi)
            out[2 * i + 1] = Math.max(lo, hi)
        }
        return out
    }

    property string _drag: ""      // "", "start", "end" (a handle) or "seek"
    property real _grab: 0         // pointer offset from the grabbed edge, so it doesn't jump
    property int _dragStart: -1
    property int _dragEnd: -1
    property int _lastSeek: -1
    property int _hoverFrame: -1
    property string _hoverHandle: ""
    property bool _keyboard: false // keys since the last press: the ring shows (:focus-visible)

    function _keptFrame(frame) {
        return Math.max(shownStart, Math.min(frame, shownEnd))
    }
    function _seek(frame) {
        const kept = _keptFrame(frame)
        _lastSeek = kept
        seekRequested(kept)
    }
    // The handle a press at x grabs, within reach of its edge: the nearer one;
    // when both edges share a pixel, the side of the press (start left of it).
    function _handleAt(x) {
        if (!hasAudio || !editable)
            return ""
        const s = xAt(shownStart), e = xAt(shownEnd)
        const ds = Math.abs(x - s), de = Math.abs(x - e)
        if (Math.min(ds, de) > SuiTheme.waveformHandleReach)
            return ""
        if (Math.round(s) === Math.round(e))
            return x < s - 1 ? "start" : "end"
        return ds < de ? "start" : "end"
    }
    function _hover(x, y) {
        const inside = hasAudio && x >= _inset && x <= _inset + _plotWidth && y >= 0 && y <= height
        _hoverFrame = inside ? frameAt(x) : -1
        _hoverHandle = inside ? _handleAt(x) : ""
    }
    function _press(x, y) {
        _keyboard = false
        // The waveform itself, not a handle that had the focus (T.Control is a focus scope).
        startHandle.focus = false
        endHandle.focus = false
        forceActiveFocus(Qt.MouseFocusReason)
        const handle = _handleAt(x)
        _grab = 0
        _lastSeek = -1
        if (handle !== "") {
            const anchor = xAt(handle === "start" ? shownStart : shownEnd)
            if (Math.abs(x - anchor) > 1)
                _grab = x - anchor
        }
        _drag = handle !== "" ? handle : "seek"
        _dragTo(x)
        _hover(x, y)
    }
    function _dragTo(x) {
        const frame = frameAt(x - _grab)
        if (_drag === "start")
            _dragStart = Math.max(0, Math.min(frame, shownEnd - 1))
        else if (_drag === "end")
            _dragEnd = Math.min(frameCount, Math.max(frame, shownStart + 1))
        else if (_drag === "seek" && _keptFrame(frame) !== _lastSeek)
            _seek(frame)
    }
    function _release(x) {
        if (_drag === "")
            return
        _dragTo(x)
        const trimming = _drag !== "seek"
        const start = shownStart, end = shownEnd
        _cancel()
        if (trimming && (start !== _start || end !== _end))
            trimChanged(start, end)
    }
    function _cancel() {
        _drag = ""
        _dragStart = -1
        _dragEnd = -1
        _grab = 0
    }
    function _reset() {
        _cancel()
        _hoverFrame = -1
        _hoverHandle = ""
    }
    // A handle's keys and accessible actions: move its edge, keep at least one frame.
    function _moveEdge(atStart, frame) {
        if (!hasAudio || !editable)
            return
        const start = atStart ? Math.max(0, Math.min(frame, shownEnd - 1)) : shownStart
        const end = atStart ? shownEnd : Math.min(frameCount, Math.max(frame, shownStart + 1))
        if (start !== _start || end !== _end)
            trimChanged(start, end)
    }

    onFrameCountChanged: _reset()
    onBinsChanged: _reset()
    onEnabledChanged: if (!enabled) _reset()
    onEditableChanged: if (!editable && _drag !== "seek") _reset()
    onActiveFocusChanged: if (!activeFocus) _keyboard = false

    // ---- Geometry ---------------------------------------------------------------
    // The plot leaves half a grip each side, so a handle at either end shows whole.
    readonly property real _inset: SuiTheme.waveformHandleWidth / 2 + 1
    readonly property real _plotWidth: Math.max(1, width - 2 * _inset)
    readonly property real _vpad: SuiTheme.spaceXs
    readonly property real _plotHeight: Math.max(1, height - 2 * _vpad)
    readonly property bool _ringShown: activeFocus && (visualFocus || _keyboard)
                                       && !startHandle.activeFocus && !endHandle.activeFocus

    // ---- Control ----------------------------------------------------------------
    implicitWidth: 600
    implicitHeight: 120
    padding: 0
    focusPolicy: hasAudio ? Qt.TabFocus : Qt.NoFocus
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: hasAudio ? "kept " + (shownStart / _rate).toFixed(2) + " to " + (shownEnd / _rate).toFixed(2)
                                       + " of " + (frameCount / _rate).toFixed(2) + " seconds"
                                     : placeholderText !== "" ? placeholderText : "No audio"
    Accessible.onIncreaseAction: if (hasAudio) _seek((playhead >= 0 ? playhead : shownStart) + _step)
    Accessible.onDecreaseAction: if (hasAudio) _seek((playhead >= 0 ? playhead : shownStart) - _step)

    Keys.onPressed: (event) => {
        if (!hasAudio || (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return
        const from = playhead >= 0 ? playhead : shownStart
        switch (event.key) {
        case Qt.Key_Left: _seek(from - _step); break
        case Qt.Key_Right: _seek(from + _step); break
        case Qt.Key_Home: _seek(shownStart); break
        case Qt.Key_End: _seek(shownEnd); break
        default: return
        }
        _keyboard = true
        event.accepted = true
    }

    background: Rectangle {
        objectName: "waveformBackground"
        radius: SuiTheme.radiusSm
        color: SuiTheme.field
        border.width: 1
        border.color: SuiTheme.line

        SuiFocusRing { visible: wave._ringShown }
    }

    // The zero line, then the waveform.
    Rectangle {
        objectName: "zeroLine"
        visible: wave._pairs.length > 0
        x: wave._inset
        y: Math.round(wave._vpad + wave._plotHeight / 2)
        width: wave._plotWidth
        height: 1
        color: SuiTheme.line
    }
    Canvas {
        id: canvas
        objectName: "waveformCanvas"
        x: wave._inset
        y: wave._vpad
        width: wave._plotWidth
        height: wave._plotHeight
        readonly property var paintKey: [wave._pairs, width, height, SuiTheme.accent]
        onPaintKeyChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const pairs = wave._pairs
            const n = pairs.length / 2
            if (n === 0)
                return
            // One rectangle per pixel column (or per bin when bins are wider), min to max,
            // on whole pixels so neighbouring columns don't blend at their seams.
            const columns = Math.max(1, Math.min(n, Math.round(width)))
            const w = width / columns
            const mid = height / 2
            ctx.fillStyle = SuiTheme.accent
            for (let c = 0; c < columns; ++c) {
                const a = Math.floor(c * n / columns)
                const b = Math.max(a + 1, Math.floor((c + 1) * n / columns))
                let lo = 1, hi = -1
                for (let i = a; i < b; ++i) {
                    lo = Math.min(lo, pairs[2 * i])
                    hi = Math.max(hi, pairs[2 * i + 1])
                }
                const left = Math.round(c * w), right = Math.round((c + 1) * w)
                const top = Math.floor(mid - hi * mid), bottom = Math.ceil(mid - lo * mid)
                ctx.fillRect(left, top, right - left, Math.max(1, bottom - top))
            }
        }
    }

    // Outside the kept frames: shaded.
    Rectangle {
        objectName: "shadeStart"
        visible: wave.hasAudio
        x: wave._inset
        y: wave._vpad
        width: Math.max(0, wave.xAt(wave.shownStart) - wave._inset)
        height: wave._plotHeight
        color: SuiTheme.backdrop
    }
    Rectangle {
        objectName: "shadeEnd"
        visible: wave.hasAudio
        x: wave.xAt(wave.shownEnd)
        y: wave._vpad
        width: Math.max(0, wave._inset + wave._plotWidth - x)
        height: wave._plotHeight
        color: SuiTheme.backdrop
    }

    // A trim edge: a line the plot's height and a grip; with `editable`, a Tab stop.
    component Handle: T.Control {
        id: handle
        property bool atStart: true
        readonly property string side: atStart ? "start" : "end"
        readonly property int edge: atStart ? wave.shownStart : wave.shownEnd
        readonly property bool hot: wave._drag === side || (wave._drag === "" && wave._hoverHandle === side)
        // Qt's accessible value interface (seconds).
        readonly property real value: edge / wave._rate
        readonly property real minimumValue: atStart ? 0 : (wave.shownStart + 1) / wave._rate
        readonly property real maximumValue: atStart ? (wave.shownEnd - 1) / wave._rate : wave.frameCount / wave._rate
        readonly property real stepSize: 0.1

        visible: wave.hasAudio
        focusPolicy: wave.hasAudio && wave.editable ? Qt.TabFocus : Qt.NoFocus
        x: wave.xAt(edge) - width / 2
        y: wave._vpad
        width: SuiTheme.waveformHandleWidth
        height: wave._plotHeight
        padding: 0

        Accessible.role: Accessible.Slider
        Accessible.name: atStart ? wave.trimStartLabel : wave.trimEndLabel
        Accessible.description: wave.formatTime(edge)
        Accessible.ignored: !wave.editable
        Accessible.onIncreaseAction: wave._moveEdge(atStart, edge + wave._step)
        Accessible.onDecreaseAction: wave._moveEdge(atStart, edge - wave._step)

        Keys.onPressed: (event) => {
            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                return
            let frame
            switch (event.key) {
            case Qt.Key_Left: case Qt.Key_Down: frame = edge - wave._step; break
            case Qt.Key_Right: case Qt.Key_Up: frame = edge + wave._step; break
            case Qt.Key_PageDown: frame = edge - Math.round(wave._rate); break
            case Qt.Key_PageUp: frame = edge + Math.round(wave._rate); break
            case Qt.Key_Home: frame = 0; break
            case Qt.Key_End: frame = wave.frameCount; break
            default: return
            }
            wave._moveEdge(atStart, frame)
            event.accepted = true
        }

        Rectangle {
            objectName: "edgeLine"
            // Read-only, an edge at the clip's end marks nothing.
            visible: wave.editable || (handle.atStart ? handle.edge > 0 : handle.edge < wave.frameCount)
            x: (parent.width - width) / 2
            width: SuiTheme.chartLineWidth
            height: parent.height
            color: handle.hot ? SuiTheme.accentHover : SuiTheme.accent
        }
        Rectangle {
            id: grip
            objectName: "grip"
            visible: wave.editable
            width: parent.width
            height: Math.min(SuiTheme.waveformHandleHeight, parent.height)
            y: (parent.height - height) / 2
            radius: SuiTheme.radiusSm - 1
            color: handle.hot ? SuiTheme.accentHover : SuiTheme.accent
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 2
                    Rectangle {
                        width: 1
                        height: grip.height / 2
                        color: SuiTheme.accentForeground
                    }
                }
            }
            SuiFocusRing { targetRadius: grip.radius; visible: handle.visualFocus }
        }
    }
    Handle { id: startHandle; objectName: "trimStartHandle"; atStart: true }
    Handle { id: endHandle; objectName: "trimEndHandle"; atStart: false }

    Rectangle {
        objectName: "playhead"
        visible: wave.hasAudio && wave.playhead >= 0
        x: wave.xAt(Math.min(Math.max(0, wave.playhead), wave.frameCount)) - width / 2
        y: wave._vpad
        width: SuiTheme.chartLineWidth
        height: wave._plotHeight
        color: SuiTheme.toneRed
    }

    // The time under the pointer: a dashed line and the time beside it.
    Item {
        id: readout
        objectName: "hoverReadout"
        visible: wave.hoverText !== ""
        x: wave.xAt(wave.hoverFrame)
        y: wave._vpad
        height: wave._plotHeight
        Shape {
            ShapePath {
                strokeColor: SuiTheme.text
                strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [SuiTheme.spaceXs, SuiTheme.spaceXs - 1]
                fillColor: "transparent"
                startX: 0.5
                startY: 0
                PathLine { x: 0.5; y: readout.height }
            }
        }
        Rectangle {
            objectName: "hoverTime"
            readonly property real room: wave._inset + wave._plotWidth - readout.x - SuiTheme.spaceSm
            x: room >= width ? SuiTheme.spaceSm : -width - SuiTheme.spaceSm
            y: SuiTheme.spaceXs
            width: hoverLabel.implicitWidth + 2 * SuiTheme.spaceSm
            height: hoverLabel.implicitHeight + SuiTheme.spaceXs
            radius: SuiTheme.radiusSm
            color: SuiTheme.popover
            border.width: 1
            border.color: SuiTheme.borderStrong
            SuiText {
                id: hoverLabel
                anchors.centerIn: parent
                text: wave.hoverText
                variant: "small"
                tabular: true
                Accessible.ignored: true
            }
        }
    }

    SuiText {
        objectName: "placeholder"
        visible: wave._pairs.length === 0 && wave.placeholderText !== ""
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 2 * SuiTheme.spaceLg)
        horizontalAlignment: Text.AlignHCenter
        text: wave.placeholderText
        tone: "muted"
        elide: Text.ElideRight
        Accessible.ignored: true
    }

    // Every press, drag and hover, above the handles: a press within reach of
    // an edge grabs its handle, anywhere else seeks.
    MouseArea {
        id: pointer
        objectName: "waveformArea"
        anchors.fill: parent
        enabled: wave.hasAudio
        hoverEnabled: true
        preventStealing: true
        cursorShape: wave._hoverHandle !== "" || wave._drag === "start" || wave._drag === "end"
                     ? Qt.SizeHorCursor : Qt.CrossCursor
        onPressed: (mouse) => wave._press(mouse.x, mouse.y)
        onPositionChanged: (mouse) => {
            if (pressed)
                wave._dragTo(mouse.x)
            wave._hover(mouse.x, mouse.y)
        }
        onReleased: (mouse) => {
            wave._release(mouse.x)
            wave._hover(mouse.x, mouse.y)
        }
        onCanceled: wave._cancel()
        onExited: if (!pressed) wave._hover(-1, -1)
        onDoubleClicked: (mouse) => {
            if (wave._handleAt(mouse.x) !== "")
                return
            const frame = wave.frameAt(mouse.x)
            if (frame >= wave.shownStart && frame < wave.shownEnd)
                wave.playRequested(frame)
        }
    }
}
