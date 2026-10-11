"""SuiChart and SuiHistogram: series kinds, axes, gaps and decimation, markers, legend,
the readout by pointer and keyboard, accessibility, binning."""

from __future__ import annotations

import math
import time

import pytest
from conftest import find, find_item, set_theme, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest


def plain(value):
    return value.toVariant() if hasattr(value, "toVariant") else value


def js(obj, code: str):
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    expression = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    value, _undefined = expression.evaluate()
    assert not expression.hasError(), expression.error().toString()
    return plain(value)


def chart_scene(engine, qtbot, props: str, kind: str = "SuiChart", width: int = 480, height: int = 280):
    window = window_scene(
        engine, qtbot,
        f'SuiButton {{ objectName: "before"; text: "Before" }}\n'
        f'{kind} {{ objectName: "c"; y: 40; width: {width}; height: {height}; label: "Pitch"; {props} }}',
        width=width + 20, height=height + 60,
    )
    return window, find(window, "c")


def items(root, name: str) -> list:
    out = []

    def walk(item):
        if item.objectName() == name:
            out.append(item)
        for child in item.childItems():
            walk(child)

    walk(root)
    return out


def to_window(item, x: float, y: float) -> QPoint:
    return item.mapToScene(item.boundingRect().topLeft()).toPoint() + QPoint(round(x), round(y))


LINE = 'series: [{ kind: "line", name: "F0", x: [0, 1, 2, 3, 4], y: [100, 150, 125, 175, 140] }]'


# ---- Axes ----------------------------------------------------------------------------


@pytest.mark.parametrize(
    ("lo", "hi", "nice", "count", "ticks", "lo_hi"),
    # steps of 1, 2, 2.5 or 5 x 10^n, the first at least (hi - lo) / count
    [(0, 10, True, 5, [0, 2, 4, 6, 8, 10], (0, 10)), (0.13, 0.92, True, 4, [0, 0.2, 0.4, 0.6, 0.8, 1], (0, 1)),
     (-37, 3, True, 4, [-40, -30, -20, -10, 0, 10], (-40, 10)),
     (3, 3, True, 4, [1, 2, 3, 4, 5], (1, 5)),  # one value: padded by half of it, then nice
     (0.13, 0.92, False, 4, [0.2, 0.4, 0.6, 0.8], (0.13, 0.92))],  # not nice: the data's own ends
)
def test_nice_axis(engine, qtbot, lo, hi, nice, count, ticks, lo_hi):
    window, chart = chart_scene(engine, qtbot, LINE)
    axis = js(chart, f"_axis({lo}, {hi}, {str(nice).lower()}, {count})")
    assert axis["ticks"] == pytest.approx(ticks)
    assert (axis["min"], axis["max"]) == pytest.approx(lo_hi)
    window.close()


def test_axes_follow_data_explicit_limits_and_formats(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, LINE)
    ylabels = sorted((i for i in items(chart, "yTickLabel")), key=lambda i: -i.y())
    ticks = js(chart, "_yAxis.ticks")
    assert ylabels[0].property("text") == "100" and float(ylabels[-1].property("text")) >= 175  # nice: whole ticks
    assert [i.property("text") for i in ylabels] == [f"{t:g}" for t in ticks]
    assert js(chart, "_xAxis.min") == 0 and js(chart, "_xAxis.max") == 4  # x is exact by default
    chart.setProperty("yMin", 0)
    chart.setProperty("yMax", 200)
    assert js(chart, "_yAxis.min") == 0 and js(chart, "_yAxis.max") == 200
    js(chart, 'yFormat = (v) => v + " Hz"')
    assert max((i for i in items(chart, "yTickLabel")), key=lambda i: -i.y()).property("text") == "200 Hz"
    window.close()


def test_integer_ticks(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, 'yIntegers: true; series: [{ y: [0, 1, 2, 3] }]', height=400)
    assert all(float(t).is_integer() for t in js(chart, "_yAxis.ticks"))
    window.close()


# ---- Series ------------------------------------------------------------------------------


def test_line_maps_points_and_splits_at_gaps(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, 'series: [{ x: [0, 1, 2, 3, 4], y: [0, 10, null, 10, 0] }]; yNice: false')
    segments = js(find(window, "series0"), "line")
    assert len(segments) == 2 and [len(s) for s in segments] == [2, 2]
    plot = find(window, "plot")
    assert segments[0][0].x() == pytest.approx(0) and segments[0][0].y() == pytest.approx(plot.height())
    assert segments[1][1].x() == pytest.approx(plot.width()) and segments[1][0].y() == pytest.approx(0)
    window.close()


def test_dense_lines_are_reduced_per_pixel_column_keeping_extremes(engine, qtbot):
    n = 100_000
    window, chart = chart_scene(engine, qtbot, "series: []")
    y = [math.sin(i / 50) * (1 + (i % 997 == 0) * 3) for i in range(n)]  # rare spikes
    started = time.perf_counter()
    chart.setProperty("series", [{"kind": "line", "y": y}])
    window.grabWindow()
    elapsed = time.perf_counter() - started
    segments = js(find(window, "series0"), "line")
    points = sum(len(s) for s in segments)
    plot = find(window, "plot")
    assert points <= 4 * plot.width() + 8, points
    ys = [p.y() for s in segments for p in s]
    assert min(ys) == pytest.approx(js(chart, f"sy({max(y)})"), abs=0.01)  # the spikes survive
    assert max(ys) == pytest.approx(js(chart, f"sy({min(y)})"), abs=0.01)
    print(f"100,000-point line: set and drawn in {elapsed * 1000:.0f} ms, {points} vertices")
    assert elapsed < 3
    window.close()


def test_area_and_band_fill_polygons(engine, qtbot):
    window, chart = chart_scene(
        engine, qtbot,
        'series: [{ kind: "area", y: [1, 2, 3], baseline: 0 }, { kind: "band", lower: [0, 1, 1], upper: [2, 3, 4] }]',
    )
    area = js(find(window, "series0"), "fill")
    assert len(area) == 1 and len(area[0]) == 5  # three points and two baseline corners
    base = js(chart, "sy(0)")
    assert area[0][3].y() == pytest.approx(base) and area[0][4].y() == pytest.approx(base)
    band = js(find(window, "series1"), "fill")
    assert len(band) == 1 and len(band[0]) == 6  # upper forward, lower back
    assert band[0][0].y() == pytest.approx(js(chart, "sy(2)")) and band[0][5].y() == pytest.approx(js(chart, "sy(0)"))
    window.close()


def test_series_colours_follow_tones_and_themes(engine, qtbot, theme):
    window, chart = chart_scene(
        engine, qtbot,
        'series: [{ name: "a", y: [1, 2] }, { name: "b", y: [2, 1] }, { name: "c", kind: "scatter", y: [1, 1], tone: "danger" }]',
    )
    for mode in ("light", "dark"):
        set_theme(engine, mode)
        colours = [QColor(c) for c in [js(chart, f"_data[{i}].color") for i in range(3)]]
        assert colours == [QColor(theme.property("bucket1")), QColor(theme.property("bucket2")),
                           QColor(theme.property("toneRed"))], mode
    window.close()


def test_scatter_paints_its_points(engine, qtbot, theme):
    window, chart = chart_scene(engine, qtbot, 'series: [{ kind: "scatter", x: [0, 5, 10], y: [0, 5, 10], size: 10 }]')
    QTest.qWait(50)
    plot = find(window, "plot")
    centre = to_window(plot, js(chart, "sx(5)"), js(chart, "sy(5)"))
    pixel = window.grabWindow().pixelColor(centre)
    expected = QColor(theme.property("bucket1"))
    assert abs(pixel.red() - expected.red()) < 12 and abs(pixel.blue() - expected.blue()) < 12, pixel.name()
    window.close()


def test_bars(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, 'series: [{ kind: "bars", x0: [0, 1, 2], x1: [1, 2, 3], y: [4, 0, 2] }]')
    bars = sorted(items(chart, "bar"), key=lambda b: b.x())
    assert len(bars) == 3
    assert bars[1].height() == 0
    assert bars[0].height() == pytest.approx(2 * bars[2].height(), abs=1)
    assert bars[0].y() + bars[0].height() == pytest.approx(js(chart, "sy(0)"), abs=0.5)
    window.close()


# ---- Markers, legend, empty --------------------------------------------------------------


def test_markers_and_legend(engine, qtbot):
    window, chart = chart_scene(
        engine, qtbot,
        'series: [{ name: "F0", y: [100, 200] }, { name: "Energy", kind: "area", y: [120, 140] }];'
        ' markers: [{ axis: "y", value: 180, label: "Target" }, { axis: "x", value: 0.5, label: "Cut", tone: "danger" }]',
    )
    labels = sorted(i.property("text") for i in items(chart, "markerLabel"))
    assert labels == ["Cut", "Target"]
    assert find(window, "legend").isVisible()
    assert sorted(i.property("text") for i in items(chart, "legendLabel")) == ["Energy", "F0"]
    chart.setProperty("series", [{"name": "F0", "y": [1, 2]}])
    assert not find(window, "legend").isVisible()  # one series: no legend
    window.close()


def test_no_data(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, "series: []")
    assert find(window, "noData").isVisible()
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert not chart.hasActiveFocus()  # nothing to inspect: not a Tab stop
    assert QAccessible.queryAccessibleInterface(chart).text(QAccessible.Text.Description) == "No data"
    window.close()


# ---- Readout -------------------------------------------------------------------------------


def test_hover_readout_shows_each_series_at_x(engine, qtbot):
    window, chart = chart_scene(
        engine, qtbot,
        'xLabel: "Time (s)"; series: [{ name: "F0", x: [0, 1, 2, 3, 4], y: [100, 150, 125, 175, 140] },'
        ' { kind: "band", name: "Range", x: [0, 1, 2, 3, 4], lower: [90, 140, 115, 165, 130], upper: [110, 160, 135, 185, 150] }]',
    )
    plot = find(window, "plot")
    readout = find(window, "readout")
    assert not readout.isVisible()
    QTest.mouseMove(window, to_window(plot, js(chart, "sx(2.9)"), 20))
    qtbot.waitUntil(readout.isVisible)
    assert chart.property("inspectedX") == pytest.approx(2.9, abs=0.02)
    assert chart.property("readoutText") == "Time (s): 2.90, F0 175.0, Range 165.0–185.0"
    QTest.mouseMove(window, QPoint(2, 2))  # leave the plot
    qtbot.waitUntil(lambda: not readout.isVisible())
    window.close()


def test_scatter_readout_picks_the_point_under_the_pointer(engine, qtbot):
    window, chart = chart_scene(
        engine, qtbot, 'series: [{ kind: "scatter", name: "Takes", x: [0, 1, 2], y: [5, 9, 1] }]; yNice: false; yMin: 0; yMax: 10',
    )
    plot = find(window, "plot")
    QTest.mouseMove(window, to_window(plot, js(chart, "sx(1)") + 2, js(chart, "sy(9)") - 1))
    qtbot.waitUntil(lambda: chart.property("readoutText") != "")
    assert chart.property("readoutText").endswith("Takes 9.0")
    window.close()


def test_keyboard_readout_steps_through_x(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, 'xLabel: "t"; ' + LINE)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert chart.hasActiveFocus() and chart.property("visualFocus")
    assert len(visible_rings(window.contentItem())) == 1
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert chart.property("inspectedX") == 0
    assert chart.property("readoutText") == "t: 0.00, F0 100.0"
    QTest.keyClick(window, Qt.Key.Key_Right)
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert chart.property("inspectedX") == 2
    QTest.keyClick(window, Qt.Key.Key_End)
    assert chart.property("inspectedX") == 4
    QTest.keyClick(window, Qt.Key.Key_PageDown)
    assert chart.property("inspectedX") == 0
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert math.isnan(chart.property("inspectedX"))
    window.close()


def test_accessible_chart_with_summary(engine, qtbot):
    window, chart = chart_scene(engine, qtbot, 'xLabel: "Time (s)"; yLabel: "F0 (Hz)"; ' + LINE)
    iface = QAccessible.queryAccessibleInterface(chart)
    assert iface.role() == QAccessible.Role.Chart
    assert iface.text(QAccessible.Text.Name) == "Pitch"
    assert iface.text(QAccessible.Text.Description) == "F0: line, 5 points, 100 to 175; x: Time (s); y: F0 (Hz)"
    chart.setProperty("description", "Pitch rises then falls.")
    assert iface.text(QAccessible.Text.Description) == "Pitch rises then falls."
    window.close()


# ---- SuiHistogram ---------------------------------------------------------------------------


def histogram(engine, qtbot, props: str):
    return chart_scene(engine, qtbot, props, kind="SuiHistogram")


def counts(chart) -> list[int]:
    return [int(b["count"]) for b in plain(chart.property("bins"))]


def test_histogram_bins_by_count_width_and_range(engine, qtbot):
    window, chart = histogram(engine, qtbot, "values: [0, 1, 1, 2, 3, 3, 3, 4, null, NaN, \"x\"]")
    assert chart.property("valueCount") == 8
    bins = plain(chart.property("bins"))
    assert len(bins) == math.ceil(math.log2(8)) + 1  # Sturges
    assert sum(counts(chart)) == 8 and bins[-1]["x1"] == pytest.approx(4)  # 4 is in the last bin
    chart.setProperty("binCount", 2)
    assert counts(chart) == [3, 5]
    chart.setProperty("binCount", 0)
    chart.setProperty("binWidth", 2)  # [0, 2), [2, 4), [4, 6): the largest value gets a bin
    assert [(b["x0"], b["x1"]) for b in plain(chart.property("bins"))] == [(0, 2), (2, 4), (4, 6)]
    assert counts(chart) == [3, 4, 1]
    chart.setProperty("from", 1)
    chart.setProperty("to", 3)  # out-of-range values are left out
    assert counts(chart) == [6]
    window.close()


def test_histogram_density_counts_axis_and_description(engine, qtbot):
    window, chart = histogram(engine, qtbot, 'xLabel: "Duration (s)"; values: [1, 2, 2, 3, 3, 3, 4, 4]; binWidth: 1; from: 1; to: 5')
    assert counts(chart) == [1, 2, 3, 2]
    assert all(float(t).is_integer() for t in js(chart, "_yAxis.ticks"))
    assert chart.property("description") == (
        "8 values in 4 bins from 1.0 to 5.0; the most, 3, from 3.0 to 4.0; x: Duration (s)")
    chart.setProperty("density", True)
    assert sum(js(chart, "series[0].y")) == pytest.approx(1)
    assert items(chart, "yTickLabel")[-1].property("text").endswith("%")
    chart.setProperty("density", False)
    js(chart, "_inspect(3.5)")
    assert chart.property("readoutText") == "Pitch 3.0–4.0: 3"
    window.close()
