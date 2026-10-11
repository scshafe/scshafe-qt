// SuiHistogram: the distribution of a set of values as bars: a SuiChart that
// bins its `values`.
//
//     SuiHistogram { label: "Take durations"; values: durations; xLabel: "Duration (s)" }
//     SuiHistogram {
//         label: "SNR"; values: snr; binWidth: 2; from: 0; to: 40; xLabel: "SNR (dB)"
//         markers: [{ axis: "x", value: meanSnr, label: "Mean" }]
//     }
//
// `values` (numbers; others are left out) are counted into `binCount` equal
// bins (0: automatic, Sturges' rule: log2(n) + 1), or into bins of `binWidth`
// (aligned to multiples of it unless `from` is set; without `to`, as many as
// it takes to hold the largest value), over `from`..`to` (default: the
// values' range; a value equal to `to` goes in the last bin).
// `density: true` shows each bin's share of the values instead of its count.
// `bins` is the result: [{ x0, x1, count, share }]. `tone` colours the bars
// (default bucket 1). Everything else is SuiChart's: axes, markers, the
// readout (the bin under the pointer or the keyboard), accessibility (a Chart
// named by `label`, described by a summary of the distribution).
import QtQuick

SuiChart {
    id: histogram

    property var values: []
    property int binCount: 0
    property real binWidth: NaN
    property real from: NaN
    property real to: NaN
    property bool density: false
    property var tone: 1
    readonly property var bins: _bin()
    readonly property int valueCount: _finiteValues.length

    readonly property var _finiteValues: {
        const out = []
        for (const v of (values || [])) {
            const n = v === null || v === undefined || v === "" ? NaN : Number(v)
            if (isFinite(n))
                out.push(n)
        }
        return out
    }
    function _bin() {
        const v = _finiteValues
        if (v.length === 0)
            return []
        let lo = from, hi = to
        if (isNaN(lo) || isNaN(hi)) {
            let min = Infinity, max = -Infinity
            for (const x of v) {
                if (x < min) min = x
                if (x > max) max = x
            }
            if (isNaN(lo)) lo = min
            if (isNaN(hi)) hi = max
        }
        let width
        if (isFinite(binWidth) && binWidth > 0) {
            width = binWidth
            if (isNaN(from))
                lo = Math.floor(lo / width) * width
            if (isNaN(to))  // bins of the width, until one holds the largest value
                hi = lo + (Math.floor((hi - lo) / width + 1e-9) + 1) * width
        } else {
            if (hi <= lo)
                hi = lo + 1
            width = (hi - lo) / (binCount > 0 ? binCount : Math.ceil(Math.log2(v.length)) + 1)
        }
        if (hi <= lo)
            hi = lo + width
        const k = Math.max(1, Math.ceil((hi - lo) / width - 1e-9))
        const counts = new Array(k).fill(0)
        for (const x of v) {
            if (x < lo || x > hi)
                continue
            counts[Math.min(k - 1, Math.floor((x - lo) / width))]++
        }
        return counts.map((c, i) => ({ x0: lo + i * width, x1: lo + (i + 1) * width, count: c, share: c / v.length }))
    }

    yLabel: density ? "Share" : "Count"
    yMin: 0
    yIntegers: !density
    yFormat: density ? (v) => Math.round(v * 100) + " %" : null
    series: [{
        kind: "bars",
        name: label !== "" ? label : "Values",
        x0: bins.map(b => b.x0),
        x1: bins.map(b => b.x1),
        y: bins.map(b => density ? b.share : b.count),
        tone: tone
    }]
    description: {
        if (bins.length === 0)
            return "No data"
        let top = 0
        for (let i = 1; i < bins.length; ++i)
            if (bins[i].count > bins[top].count) top = i
        const b = bins[top]
        return valueCount + " values in " + bins.length + " bins from " + formatX(bins[0].x0, 1) + " to "
               + formatX(bins[bins.length - 1].x1, 1) + "; the most, " + b.count + ", from " + formatX(b.x0, 1)
               + " to " + formatX(b.x1, 1) + (xLabel !== "" ? "; x: " + xLabel : "")
    }
}
