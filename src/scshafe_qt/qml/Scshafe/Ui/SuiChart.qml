// SuiChart: an x/y chart of line, area, band, scatter and bar series, drawn
// with Qt Quick Shapes (lines, areas, bands) and Canvas (scatter), with nice
// axes, reference markers, a legend and a readout.
//
//     SuiChart {
//         label: "Pitch, take 12"; xLabel: "Time (s)"; yLabel: "F0 (Hz)"
//         series: [
//             { kind: "band", name: "Range", x: t, lower: f0lo, upper: f0hi },
//             { kind: "line", name: "F0", x: t, y: f0 },
//             { kind: "scatter", name: "Onsets", x: onsetT, y: onsetF0, tone: "warn" }
//         ]
//         markers: [{ axis: "y", value: 180, label: "Target" }]
//     }
//
// A series is an object (from QML or a Python dict; columns are JS arrays or
// Python lists of numbers):
// - kind: "line" (default) | "area" (filled down to `baseline`, default 0) |
//   "band" (between `lower` and `upper`) | "scatter" | "bars" (from `x0` to
//   `x1` at height `y`, as SuiHistogram makes);
// - x (default 0, 1, 2, ...), y, lower, upper, x0, x1; a null or NaN value
//   breaks a line, area or band;
// - name (legend and readout), tone (a bucket number or name, or a status
//   tone; default: bucket 1, 2, ... by position), size (scatter diameter).
// Lines and areas with far more points than pixels are drawn min/max per
// pixel column, so 100,000-point series stay quick.
//
// Axes: automatic from the data (and markers) unless `xMin`/`xMax`/`yMin`/
// `yMax` are set; `yNice` (default) and `xNice` extend an automatic range to
// whole ticks; `yIntegers` keeps y ticks whole. `xFormat` / `yFormat`
// (function(value) -> string) format ticks and the readout. `xGrid` / `yGrid` draw grid lines. Markers ({ axis: "x" |
// "y", value, label, tone }) are dashed reference lines. The legend shows
// when two or more series have names (`showLegend`).
//
// Readout (`inspectable`, default on): hovering the plot shows a crosshair and
// each series' value at that x (the nearest point for scatter, the bin for
// bars). The chart is a Tab stop: Left/Right step through the x values of the
// first series (PageUp/PageDown ten, Home/End), each step announced to
// assistive technology; Escape hides it. `inspectedX` is the x shown (NaN
// for none). Nothing animates.
//
// Accessible: Chart named by `label`, described by `description` (default: a
// summary of the series and their ranges).
import QtQuick
import QtQuick.Shapes
import QtQuick.Templates as T

T.Control {
    id: chart

    property string label: ""
    property string description: ""
    property var series: []
    property var markers: []
    property string xLabel: ""
    property string yLabel: ""
    property real xMin: NaN
    property real xMax: NaN
    property real yMin: NaN
    property real yMax: NaN
    property bool xNice: false
    property bool yNice: true
    property bool yIntegers: false  // whole-number y ticks (counts)
    property var xFormat: null
    property var yFormat: null
    property bool xGrid: false
    property bool yGrid: true
    property bool showLegend: true
    property bool inspectable: true
    readonly property real inspectedX: _inspectX
    readonly property string readoutText: _readout.text

    // ---- Data -----------------------------------------------------------------
    function _num(v) {
        return v === null || v === undefined || v === "" ? NaN : Number(v)
    }
    function _column(values, n) {
        const out = new Array(n)
        for (let i = 0; i < n; ++i)
            out[i] = _num(values[i])
        return out
    }
    // Series with numeric columns, a kind, a name and a colour.
    readonly property var _data: {
        const out = []
        const list = series ? series : []
        for (let i = 0; i < list.length; ++i) {
            const s = list[i]
            if (!s)
                continue
            const kind = s.kind !== undefined ? String(s.kind) : "line"
            let n = 0
            if (kind === "bars")
                n = s.y ? s.y.length : 0
            else if (kind === "band")
                n = Math.min(s.lower ? s.lower.length : 0, s.upper ? s.upper.length : 0)
            else
                n = s.y ? s.y.length : 0
            const x = s.x ? _column(s.x, n) : Array.from({ length: n }, (_, k) => k)
            const tone = s.tone !== undefined ? s.tone : (i % SuiTheme.bucketCount) + 1
            out.push({
                kind: kind,
                name: s.name !== undefined ? String(s.name) : "",
                tone: tone,
                color: SuiTheme.toneBase(tone),
                n: n,
                x: kind === "bars" ? [] : x,
                y: s.y ? _column(s.y, n) : [],
                lower: kind === "band" ? _column(s.lower, n) : [],
                upper: kind === "band" ? _column(s.upper, n) : [],
                x0: kind === "bars" ? _column(s.x0 || [], n) : [],
                x1: kind === "bars" ? _column(s.x1 || [], n) : [],
                baseline: s.baseline !== undefined ? Number(s.baseline) : 0,
                size: s.size !== undefined ? Number(s.size) : SuiTheme.chartPointSize,
                sorted: kind !== "bars" && _isSorted(x)
            })
        }
        return out
    }
    function _isSorted(x) {
        for (let i = 1; i < x.length; ++i)
            if (x[i] < x[i - 1])
                return false
        return true
    }
    readonly property var _extent: {
        let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity
        const growX = (v) => { if (isFinite(v)) { x0 = Math.min(x0, v); x1 = Math.max(x1, v) } }
        const growY = (v) => { if (isFinite(v)) { y0 = Math.min(y0, v); y1 = Math.max(y1, v) } }
        for (const s of _data) {
            if (s.kind === "bars") {
                for (let i = 0; i < s.n; ++i) { growX(s.x0[i]); growX(s.x1[i]); growY(s.y[i]) }
                growY(0)
                continue
            }
            for (let i = 0; i < s.n; ++i) {
                growX(s.x[i])
                if (s.kind === "band") { growY(s.lower[i]); growY(s.upper[i]) }
                else growY(s.y[i])
            }
            if (s.kind === "area" && s.n > 0)
                growY(s.baseline)
        }
        for (const m of (markers || [])) {
            if (m && m.axis === "x") growX(Number(m.value))
            else if (m) growY(Number(m.value))
        }
        return { x0: x0, x1: x1, y0: y0, y1: y1 }
    }
    readonly property bool hasData: _data.some(s => s.n > 0)

    // ---- Axes -----------------------------------------------------------------
    // A "nice" axis over lo..hi with about `count` ticks: { min, max, step, ticks, decimals }.
    function _axis(lo, hi, nice, count, integers) {
        if (!isFinite(lo) || !isFinite(hi)) {
            lo = 0
            hi = 1
        }
        if (hi === lo) {
            const pad = lo === 0 ? 1 : Math.abs(lo) / 2
            lo -= pad
            hi += pad
        }
        const raw = (hi - lo) / Math.max(1, count)
        const magnitude = Math.pow(10, Math.floor(Math.log10(raw)))
        let step = magnitude
        for (const f of [1, 2, 2.5, 5, 10]) {
            step = f * magnitude
            if (step >= raw)
                break
        }
        if (integers && step < 1)
            step = 1
        const min = nice ? Math.floor(lo / step + 1e-9) * step : lo
        const max = nice ? Math.ceil(hi / step - 1e-9) * step : hi
        const ticks = []
        for (let v = Math.ceil(min / step - 1e-9) * step; v <= max + step * 1e-9 && ticks.length < 100; v += step)
            ticks.push(Math.round(v / step) * step)
        const decimals = Math.max(0, Math.min(6, -Math.floor(Math.log10(step) + 1e-9) + (String(step / magnitude).indexOf(".") >= 0 ? 1 : 0)))
        return { min: min, max: max, step: step, ticks: ticks, decimals: decimals }
    }
    readonly property var _yAxis: _axis(isNaN(yMin) ? _extent.y0 : yMin, isNaN(yMax) ? _extent.y1 : yMax,
                                        yNice && (isNaN(yMin) || isNaN(yMax)), Math.max(2, Math.floor(_plotHeight / 40)),
                                        yIntegers)
    readonly property var _xAxis: _axis(isNaN(xMin) ? _extent.x0 : xMin, isNaN(xMax) ? _extent.x1 : xMax,
                                        xNice && (isNaN(xMin) || isNaN(xMax)), Math.max(2, Math.floor(_plotWidth / 90)))
    // Tick labels; `extra` digits for readouts, which fall between ticks.
    function formatX(v, extra) {
        return typeof xFormat === "function" ? String(xFormat(v)) : Number(v).toFixed(_xAxis.decimals + (extra || 0))
    }
    function formatY(v, extra) {
        return typeof yFormat === "function" ? String(yFormat(v)) : Number(v).toFixed(_yAxis.decimals + (extra || 0))
    }

    // ---- Geometry ---------------------------------------------------------------
    readonly property real _tick: SuiTheme.chartTickLength
    readonly property real _gap: SuiTheme.spaceXs
    readonly property real _labelHeight: tickMetrics.height
    readonly property real _titleHeight: titleMetrics.height
    readonly property bool _legendShown: showLegend && _data.filter(s => s.name !== "").length >= 2
    readonly property real _top: _legendShown ? legend.implicitHeight + SuiTheme.spaceSm : _labelHeight / 2
    readonly property real _bottom: _tick + _gap + _labelHeight + (xLabel !== "" ? _gap + _titleHeight : 0)
    readonly property real _plotHeight: Math.max(0, height - _top - _bottom)
    readonly property real _left: {
        let widest = 0
        for (const v of _yAxis.ticks)
            widest = Math.max(widest, tickMetrics.advanceWidth(formatY(v)))
        return Math.ceil(widest) + _tick + _gap + (yLabel !== "" ? _titleHeight + _gap : 0)
    }
    // A little room on the right; the x tick labels are kept inside the chart (measuring
    // the last one would make the x axis depend on itself).
    readonly property real _right: SuiTheme.spaceSm
    readonly property real _plotWidth: Math.max(0, width - _left - _right)
    // Data -> plot pixels.
    function sx(x) { return (x - _xAxis.min) / (_xAxis.max - _xAxis.min) * _plotWidth }
    function sy(y) { return _plotHeight - (y - _yAxis.min) / (_yAxis.max - _yAxis.min) * _plotHeight }
    function dataX(px) { return _xAxis.min + px / Math.max(1, _plotWidth) * (_xAxis.max - _xAxis.min) }

    // Polyline segments of (x, value) for a series column, split at gaps and
    // reduced to min/max per pixel column when there are many more points than pixels.
    function _segments(s, values) {
        const segments = []
        let current = []
        const dense = s.n > 4 * Math.max(1, _plotWidth)
        let column = NaN, lo = null, hi = null, first = null, last = null
        const flush = () => {
            if (first === null)
                return
            current.push(first)
            if (lo !== first && lo !== last) current.push(lo)
            if (hi !== first && hi !== last && hi !== lo) current.push(hi)
            if (last !== first) current.push(last)
            first = lo = hi = last = null
        }
        for (let i = 0; i < s.n; ++i) {
            const v = values[i], x = s.x[i]
            if (!isFinite(v) || !isFinite(x)) {
                flush()
                if (current.length > 0) segments.push(current)
                current = []
                column = NaN
                continue
            }
            const p = Qt.point(sx(x), sy(v))
            if (!dense) {
                current.push(p)
                continue
            }
            const c = Math.floor(p.x)
            if (c !== column) {
                flush()
                column = c
            }
            if (first === null) { first = lo = hi = last = p; continue }
            if (p.y < lo.y) lo = p
            if (p.y > hi.y) hi = p
            last = p
        }
        flush()
        if (current.length > 0)
            segments.push(current)
        return segments
    }

    // ---- Readout --------------------------------------------------------------
    property real _inspectX: NaN
    property int _scatterHit: -1      // series index of a scatter point under the pointer
    property int _scatterPoint: -1
    // The x positions the keyboard steps through: the first series' x (or bin centres).
    readonly property var _steps: {
        const s = _data.find(d => d.n > 0)
        if (!s)
            return []
        const xs = s.kind === "bars" ? s.x0.map((x0, i) => (x0 + s.x1[i]) / 2) : s.x.filter(v => isFinite(v))
        return s.sorted || s.kind === "bars" ? xs : xs.slice().sort((a, b) => a - b)
    }
    function _nearest(s, x) {
        if (s.n === 0)
            return -1
        if (s.sorted) {
            let lo = 0, hi = s.n - 1
            while (hi - lo > 1) {
                const mid = (lo + hi) >> 1
                if (s.x[mid] < x) lo = mid
                else hi = mid
            }
            return Math.abs(s.x[lo] - x) <= Math.abs(s.x[hi] - x) ? lo : hi
        }
        let best = -1, d = Infinity
        for (let i = 0; i < s.n; ++i) {
            const e = Math.abs(s.x[i] - x)
            if (e < d) { d = e; best = i }
        }
        return best
    }
    readonly property var _readout: {
        const x = _inspectX
        if (!isFinite(x))
            return { text: "", rows: [], title: "" }
        const rows = []
        for (let k = 0; k < _data.length; ++k) {
            const s = _data[k]
            let value = "", px = NaN, py = NaN
            if (s.kind === "bars") {
                const i = s.x0.findIndex((x0, j) => x >= x0 && x <= s.x1[j])
                if (i < 0)
                    continue
                value = formatX(s.x0[i], 1) + "–" + formatX(s.x1[i], 1) + ": " + formatY(s.y[i])
            } else if (s.kind === "scatter") {
                const i = k === _scatterHit ? _scatterPoint : -1
                if (i < 0)
                    continue
                value = formatY(s.y[i], 1)
                px = sx(s.x[i])
                py = sy(s.y[i])
            } else {
                const i = _nearest(s, x)
                if (i < 0)
                    continue
                if (s.kind === "band") {
                    if (!isFinite(s.lower[i]) || !isFinite(s.upper[i]))
                        continue
                    value = formatY(s.lower[i], 1) + "–" + formatY(s.upper[i], 1)
                } else {
                    if (!isFinite(s.y[i]))
                        continue
                    value = formatY(s.y[i], 1)
                    px = sx(s.x[i])
                    py = sy(s.y[i])
                }
            }
            rows.push({ name: s.name !== "" ? s.name : "Series " + (k + 1), value: value, color: s.color, px: px, py: py })
        }
        const bars = _data.length > 0 && _data.every(s => s.kind === "bars")
        const title = bars ? "" : (xLabel !== "" ? xLabel + ": " : "") + formatX(x, 2)
        return { title: title, rows: rows,
                 text: (title !== "" ? [title] : []).concat(rows.map(r => r.name + " " + r.value)).join(", ") }
    }
    function _inspect(x) {
        _inspectX = x
    }
    function _step(delta) {
        const steps = _steps
        if (steps.length === 0)
            return
        let i
        if (!isFinite(_inspectX)) {
            i = delta >= 0 ? 0 : steps.length - 1
        } else {
            let at = 0
            for (let k = 1; k < steps.length; ++k)
                if (Math.abs(steps[k] - _inspectX) < Math.abs(steps[at] - _inspectX)) at = k
            i = Math.max(0, Math.min(steps.length - 1, at + delta))
        }
        _scatterHit = -1
        _inspect(steps[i])
        _announce(_readout.text)
    }
    function _announce(message) {
        try {
            chart.Accessible.announce(message, Accessible.Polite)
        } catch (e) {
            // Accessible.announce is Qt 6.8+; older engines stay silent.
        }
    }

    // ---- Control --------------------------------------------------------------
    implicitWidth: 480
    implicitHeight: 280
    padding: 0
    focusPolicy: inspectable && hasData ? Qt.TabFocus : Qt.NoFocus
    hoverEnabled: inspectable
    font.pixelSize: SuiTheme.fontSizeXs

    Accessible.role: Accessible.Chart
    Accessible.name: label
    Accessible.description: description !== "" ? description : _summary()
    function _summary() {
        if (!hasData)
            return "No data"
        const parts = _data.filter(s => s.n > 0).map(s => {
            const values = s.kind === "band" ? s.lower.concat(s.upper) : s.y
            const finite = values.filter(v => isFinite(v))
            const lo = finite.length ? Math.min.apply(null, finite) : NaN
            const hi = finite.length ? Math.max.apply(null, finite) : NaN
            const what = s.kind === "bars" ? s.n + " bars" : s.n + (s.n === 1 ? " point" : " points")
            return (s.name !== "" ? s.name + ": " : "") + s.kind + ", " + what
                   + (finite.length ? ", " + formatY(lo) + " to " + formatY(hi) : "")
        })
        return parts.join("; ") + (xLabel !== "" ? "; x: " + xLabel : "") + (yLabel !== "" ? "; y: " + yLabel : "")
    }

    Keys.onPressed: (event) => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        switch (event.key) {
        case Qt.Key_Right: case Qt.Key_Up: chart._step(1); break
        case Qt.Key_Left: case Qt.Key_Down: chart._step(-1); break
        case Qt.Key_PageUp: chart._step(10); break
        case Qt.Key_PageDown: chart._step(-10); break
        case Qt.Key_Home: chart._inspectX = NaN; chart._step(1); break
        case Qt.Key_End: chart._inspectX = NaN; chart._step(-1); break
        case Qt.Key_Escape:
            if (!isFinite(chart._inspectX))
                return
            chart._inspectX = NaN
            break
        default:
            return
        }
        event.accepted = true
    }
    onActiveFocusChanged: if (!activeFocus && !plotHover.hovered) _inspectX = NaN

    FontMetrics { id: tickMetrics; font.pixelSize: SuiTheme.fontSizeXs; font.features: ({ "tnum": 1 }) }
    FontMetrics { id: titleMetrics; font.pixelSize: SuiTheme.fontSizeSm }

    contentItem: Item {
        // Legend
        Flow {
            id: legend
            objectName: "legend"
            visible: chart._legendShown
            x: chart._left
            width: Math.max(0, chart._plotWidth)
            spacing: SuiTheme.spaceMd
            Repeater {
                model: chart._legendShown ? chart._data.filter(s => s.name !== "") : []
                Row {
                    required property var modelData
                    spacing: SuiTheme.spaceXs
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: SuiTheme.statusDotSize
                        height: modelData.kind === "line" ? SuiTheme.chartLineWidth : SuiTheme.statusDotSize
                        radius: modelData.kind === "scatter" ? width / 2 : 0
                        color: modelData.kind === "band" ? SuiTheme.alpha(modelData.color, SuiTheme.chartFillAlpha * 2)
                                                         : modelData.color
                    }
                    SuiText {
                        objectName: "legendLabel"
                        text: modelData.name
                        variant: "small"
                        tone: "default"
                        Accessible.ignored: true
                    }
                }
            }
        }

        // Axis titles
        SuiText {
            objectName: "yTitle"
            visible: chart.yLabel !== ""
            text: chart.yLabel
            variant: "caption"
            rotation: -90
            transformOrigin: Item.Center
            x: chart._titleHeight / 2 - width / 2
            y: chart._top + chart._plotHeight / 2 - height / 2
            Accessible.ignored: true
        }
        SuiText {
            objectName: "xTitle"
            visible: chart.xLabel !== ""
            text: chart.xLabel
            variant: "caption"
            x: chart._left + (chart._plotWidth - width) / 2
            y: chart._top + chart._plotHeight + chart._tick + chart._gap + chart._labelHeight + chart._gap
            Accessible.ignored: true
        }

        // Tick labels and marks
        Repeater {
            model: chart._yAxis.ticks
            SuiText {
                required property real modelData
                objectName: "yTickLabel"
                text: chart.formatY(modelData)
                variant: "small"
                tabular: true
                x: chart._left - chart._tick - chart._gap - width
                y: chart._top + chart.sy(modelData) - height / 2
                Accessible.ignored: true
            }
        }
        Repeater {
            model: chart._xAxis.ticks
            SuiText {
                required property real modelData
                objectName: "xTickLabel"
                text: chart.formatX(modelData)
                variant: "small"
                tabular: true
                x: Math.max(0, Math.min(chart.width - width, chart._left + chart.sx(modelData) - width / 2))
                y: chart._top + chart._plotHeight + chart._tick + chart._gap
                Accessible.ignored: true
            }
        }

        // The plot: grid, series, markers and the readout, clipped to the axes.
        Item {
            id: plot
            objectName: "plot"
            x: chart._left
            y: chart._top
            width: chart._plotWidth
            height: chart._plotHeight

            Item {
                anchors.fill: parent
                clip: true

                Repeater {
                    model: chart.yGrid ? chart._yAxis.ticks : []
                    Rectangle {
                        required property real modelData
                        y: Math.round(chart.sy(modelData))
                        width: plot.width
                        height: 1
                        color: SuiTheme.line
                    }
                }
                Repeater {
                    model: chart.xGrid ? chart._xAxis.ticks : []
                    Rectangle {
                        required property real modelData
                        x: Math.round(chart.sx(modelData))
                        width: 1
                        height: plot.height
                        color: SuiTheme.line
                    }
                }

                Repeater {
                    model: chart._data
                    delegate: Item {
                        id: seriesItem
                        required property var modelData
                        required property int index
                        readonly property string kind: modelData.kind
                        readonly property bool shaped: kind === "line" || kind === "area" || kind === "band"
                        objectName: "series" + index
                        anchors.fill: parent

                        // Geometry follows the data, the axes and the plot size.
                        readonly property var line: {
                            plot.width; plot.height; chart._xAxis; chart._yAxis
                            return kind === "line" || kind === "area" ? chart._segments(modelData, modelData.y) : []
                        }
                        readonly property var fill: {
                            plot.width; plot.height; chart._xAxis; chart._yAxis
                            if (kind === "area") {
                                const base = chart.sy(modelData.baseline)
                                return line.map(seg => seg.concat([Qt.point(seg[seg.length - 1].x, base),
                                                                   Qt.point(seg[0].x, base)]))
                            }
                            if (kind === "band") {
                                const upper = chart._segments(modelData, modelData.upper)
                                const lower = chart._segments(modelData, modelData.lower)
                                const out = []
                                for (let i = 0; i < Math.min(upper.length, lower.length); ++i)
                                    out.push(upper[i].concat(lower[i].slice().reverse()))
                                return out
                            }
                            return []
                        }

                        Shape {
                            objectName: "shape"
                            visible: seriesItem.shaped
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: "transparent"
                                strokeWidth: 0
                                fillColor: seriesItem.kind === "line" ? "transparent"
                                           : SuiTheme.alpha(seriesItem.modelData.color, SuiTheme.chartFillAlpha)
                                PathMultiline { paths: seriesItem.fill }
                            }
                            ShapePath {
                                strokeColor: seriesItem.modelData.color
                                strokeWidth: SuiTheme.chartLineWidth
                                fillColor: "transparent"
                                joinStyle: ShapePath.RoundJoin
                                capStyle: ShapePath.RoundCap
                                PathMultiline { paths: seriesItem.line }
                            }
                        }

                        Canvas {
                            id: scatter
                            objectName: "scatter"
                            visible: seriesItem.kind === "scatter"
                            anchors.fill: parent
                            readonly property var paintKey: [plot.width, plot.height, chart._xAxis, chart._yAxis,
                                                             seriesItem.modelData]
                            onPaintKeyChanged: if (visible) requestPaint()
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                const s = seriesItem.modelData
                                if (s.kind !== "scatter")
                                    return
                                const r = s.size / 2
                                ctx.fillStyle = s.color
                                ctx.beginPath()
                                for (let i = 0; i < s.n; ++i) {
                                    if (!isFinite(s.x[i]) || !isFinite(s.y[i]))
                                        continue
                                    const px = chart.sx(s.x[i]), py = chart.sy(s.y[i])
                                    ctx.moveTo(px + r, py)
                                    ctx.arc(px, py, r, 0, 2 * Math.PI)
                                }
                                ctx.fill()
                            }
                        }

                        Repeater {
                            model: seriesItem.kind === "bars" ? seriesItem.modelData.n : 0
                            Rectangle {
                                required property int index
                                readonly property var s: seriesItem.modelData
                                // (Not left/right/top/bottom: those are Item's anchor lines.)
                                readonly property real fromX: chart.sx(s.x0[index])
                                readonly property real toX: chart.sx(s.x1[index])
                                readonly property real fromY: chart.sy(Math.max(0, s.y[index]))
                                readonly property real toY: chart.sy(Math.min(0, s.y[index]))
                                readonly property bool hot: isFinite(chart._inspectX) && chart._inspectX >= s.x0[index]
                                                            && chart._inspectX <= s.x1[index]
                                objectName: "bar"
                                // Whole pixels, with a one-pixel gap between bars wide enough for it.
                                readonly property bool gap: toX - fromX > 3
                                x: Math.round(fromX) + (gap ? 1 : 0)
                                width: Math.max(1, Math.round(toX) - Math.round(fromX) - (gap ? 1 : 0))
                                y: fromY
                                height: Math.max(0, toY - fromY)
                                color: hot ? SuiTheme.alpha(s.color, 0.8) : s.color
                            }
                        }
                    }
                }

                // Markers: dashed reference lines with their label.
                Repeater {
                    model: chart.markers || []
                    Item {
                        id: marker
                        required property var modelData
                        readonly property bool vertical: modelData.axis === "x"
                        readonly property real at: vertical ? chart.sx(Number(modelData.value)) : chart.sy(Number(modelData.value))
                        readonly property color colour: modelData.tone !== undefined ? SuiTheme.toneBase(modelData.tone)
                                                                                      : SuiTheme.muted
                        objectName: "marker"
                        anchors.fill: parent
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: marker.colour
                                strokeWidth: 1
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [SuiTheme.spaceXs, SuiTheme.spaceXs - 1]
                                fillColor: "transparent"
                                startX: marker.vertical ? marker.at : 0
                                startY: marker.vertical ? 0 : marker.at
                                PathLine {
                                    x: marker.vertical ? marker.at : plot.width
                                    y: marker.vertical ? plot.height : marker.at
                                }
                            }
                        }
                        SuiText {
                            objectName: "markerLabel"
                            visible: text !== ""
                            text: marker.modelData.label !== undefined ? String(marker.modelData.label) : ""
                            variant: "small"
                            color: marker.colour
                            x: marker.vertical ? Math.min(plot.width - width, marker.at + SuiTheme.spaceXs) : plot.width - width
                            y: marker.vertical ? 0 : Math.max(0, marker.at - height)
                            Accessible.ignored: true
                        }
                    }
                }
            }

            // Axes and ticks, outside the clip.
            Rectangle { y: plot.height; width: plot.width; height: 1; color: SuiTheme.borderStrong }
            Rectangle { x: -1; width: 1; height: plot.height + 1; color: SuiTheme.borderStrong }
            Repeater {
                model: chart._xAxis.ticks
                Rectangle {
                    required property real modelData
                    x: Math.round(chart.sx(modelData))
                    y: plot.height
                    width: 1
                    height: chart._tick
                    color: SuiTheme.borderStrong
                }
            }
            Repeater {
                model: chart._yAxis.ticks
                Rectangle {
                    required property real modelData
                    x: -chart._tick
                    y: Math.round(chart.sy(modelData))
                    width: chart._tick
                    height: 1
                    color: SuiTheme.borderStrong
                }
            }

            // Readout: crosshair, points and the values.
            Item {
                objectName: "readout"
                anchors.fill: parent
                visible: isFinite(chart._inspectX) && chart._readout.rows.length > 0
                readonly property real at: chart.sx(chart._inspectX)

                Rectangle {
                    x: Math.round(parent.at)
                    width: 1
                    height: plot.height
                    color: SuiTheme.borderHover
                }
                Repeater {
                    model: chart._readout.rows.filter(r => isFinite(r.px))
                    Rectangle {
                        required property var modelData
                        x: modelData.px - width / 2
                        y: modelData.py - height / 2
                        width: SuiTheme.statusDotSize + 2
                        height: width
                        radius: width / 2
                        color: SuiTheme.panel
                        border.width: SuiTheme.focusRingWidth
                        border.color: modelData.color
                    }
                }
                Rectangle {
                    objectName: "tooltip"
                    readonly property real room: plot.width - parent.at - SuiTheme.spaceMd
                    x: room >= width ? parent.at + SuiTheme.spaceSm : Math.max(0, parent.at - width - SuiTheme.spaceSm)
                    y: SuiTheme.spaceXs
                    width: tooltipColumn.implicitWidth + 2 * SuiTheme.spaceSm
                    height: tooltipColumn.implicitHeight + 2 * SuiTheme.spaceXs
                    radius: SuiTheme.radiusSm
                    color: SuiTheme.popover
                    border.width: 1
                    border.color: SuiTheme.borderStrong
                    Column {
                        id: tooltipColumn
                        x: SuiTheme.spaceSm
                        y: SuiTheme.spaceXs
                        spacing: 2
                        SuiText {
                            objectName: "readoutTitle"
                            visible: text !== ""
                            text: chart._readout.title
                            variant: "small"
                            tabular: true
                            Accessible.ignored: true
                        }
                        Repeater {
                            model: chart._readout.rows
                            Row {
                                required property var modelData
                                spacing: SuiTheme.spaceXs
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: SuiTheme.statusDotSize
                                    height: width
                                    radius: width / 2
                                    color: modelData.color
                                }
                                SuiText {
                                    text: modelData.name + "  " + modelData.value
                                    variant: "small"
                                    tone: "default"
                                    tabular: true
                                    Accessible.ignored: true
                                }
                            }
                        }
                    }
                }
            }

            HoverHandler {
                id: plotHover
                enabled: chart.inspectable
                onPointChanged: {
                    if (!hovered)
                        return
                    const p = point.position
                    // A scatter point under the pointer, else the x under it.
                    chart._scatterHit = -1
                    chart._scatterPoint = -1
                    let best = SuiTheme.chartPointSize * SuiTheme.chartPointSize
                    for (let k = 0; k < chart._data.length; ++k) {
                        const s = chart._data[k]
                        if (s.kind !== "scatter")
                            continue
                        for (let i = 0; i < s.n; ++i) {
                            const dx = chart.sx(s.x[i]) - p.x, dy = chart.sy(s.y[i]) - p.y
                            const d = dx * dx + dy * dy
                            if (d <= best) {
                                best = d
                                chart._scatterHit = k
                                chart._scatterPoint = i
                            }
                        }
                    }
                    chart._inspect(chart._scatterHit >= 0 ? chart._data[chart._scatterHit].x[chart._scatterPoint]
                                                         : chart.dataX(p.x))
                }
                onHoveredChanged: if (!hovered && !chart.activeFocus) chart._inspectX = NaN
            }

            SuiFocusRing {
                targetRadius: 0
                visible: chart.visualFocus
            }
        }

        SuiText {
            objectName: "noData"
            visible: !chart.hasData
            anchors.centerIn: plot
            text: "No data"
            tone: "muted"
            Accessible.ignored: true
        }
    }
}
