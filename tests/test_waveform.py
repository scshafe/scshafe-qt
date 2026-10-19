"""SuiWaveform: bins drawn min/max per column, the kept frames and their shading, seeking by
pointer and keys, controlled trim handles (pointer and keyboard), double-click to play, the
hover time, cancelling, accessibility."""

from __future__ import annotations

import time

import pytest
from conftest import find, owner, set_theme, spy, visible_rings, window_scene
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest

RATE = 48000
FRAMES = 2 * RATE  # a two-second take
LEFT = Qt.MouseButton.LeftButton
NONE = Qt.KeyboardModifier.NoModifier


def js(obj, code: str):
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    expression = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    value, _undefined = expression.evaluate()
    assert not expression.hasError(), expression.error().toString()
    return value.toVariant() if hasattr(value, "toVariant") else value


def wave_scene(engine, qtbot, props: str = "", bins: str = "[-0.5, 0.5, -0.25, 0.75]"):
    window = window_scene(
        engine, qtbot,
        'SuiButton { objectName: "before"; text: "Before" }\n'
        f'SuiWaveform {{ objectName: "w"; x: 20; y: 50; width: 610; height: 120; label: "Take 12";'
        f" bins: {bins}; frameCount: {FRAMES}; {props} }}",
        width=650, height=200,
    )
    return window, find(window, "w")


def at(wave, frame: int, y: float | None = None) -> QPoint:
    """The window point over `frame` (mid-height by default)."""
    x = js(wave, f"xAt({frame})")
    return wave.mapToScene(QPoint(0, 0)).toPoint() + QPoint(round(x), round(wave.height() / 2 if y is None else y))


def drag(window, start: QPoint, *points: QPoint) -> None:
    QTest.mousePress(window, LEFT, NONE, start)
    for p in points:
        QTest.mouseMove(window, p)
    QTest.mouseRelease(window, LEFT, NONE, points[-1] if points else start)


def emitted(watcher, since: int = 0) -> list:
    return [list(watcher.at(i)) for i in range(since, watcher.count())]


# ---- Drawing --------------------------------------------------------------------


def test_bins_draw_min_max_per_column_in_both_themes(engine, qtbot, theme):
    # 400 pairs: silence, then full scale (and beyond, clamped), then a lopsided half.
    bins = "[" + ", ".join(["0, 0"] * 100 + ["-1, 1"] * 100 + ["-3, 3"] * 100 + ["-0.5, 0"] * 100) + "]"
    window, wave = wave_scene(engine, qtbot, bins=bins)
    canvas = find(window, "waveformCanvas")
    origin = canvas.mapToScene(canvas.boundingRect().topLeft())
    w, h = canvas.width(), canvas.height()

    def pixel(fx: float, fy: float) -> QColor:
        return window.grabWindow().pixelColor(QPoint(int(origin.x() + fx * w), int(origin.y() + fy * h)))

    for mode in ("light", "dark"):
        set_theme(engine, mode)
        qtbot.waitUntil(lambda: pixel(0.375, 0.02) == QColor(theme.property("accent")))
        accent, field = QColor(theme.property("accent")), QColor(theme.property("field"))
        assert pixel(0.375, 0.98) == accent  # min -1 reaches the bottom
        assert pixel(0.625, 0.02) == accent  # +3 is clamped to the top ...
        above = window.grabWindow().pixelColor(QPoint(int(origin.x() + 0.625 * w), int(origin.y()) - 2))
        assert above != accent  # ... and does not spill out of the plot
        assert pixel(0.125, 0.5) == accent  # silence is still a line at zero
        assert pixel(0.125, 0.3) != accent
        assert pixel(0.875, 0.7) == accent and pixel(0.875, 0.3) != accent  # -0.5..0: below zero only
        assert field != accent
    window.close()


def test_bins_from_python_and_many_pairs_per_pixel(engine, qtbot):
    window, wave = wave_scene(engine, qtbot)
    pairs = 2048
    values = []
    for i in range(pairs):
        peak = 0.9 if i == 1500 else 0.1  # one spike among quiet bins: kept by min/max
        values += [-peak, peak]
    started = time.perf_counter()
    wave.setProperty("bins", values)
    elapsed = time.perf_counter() - started
    assert len(js(wave, "_pairs")) == 2 * pairs
    assert elapsed < 0.5
    canvas = find(window, "waveformCanvas")
    origin = canvas.mapToScene(canvas.boundingRect().topLeft())
    x = int(origin.x() + (1500 + 0.5) / pairs * canvas.width())
    image = window.grabWindow()
    spike_top = int(origin.y() + 0.07 * canvas.height())
    assert any(image.pixelColor(QPoint(x + dx, spike_top)) == image.pixelColor(QPoint(x, int(origin.y() + canvas.height() / 2)))
               for dx in (-1, 0, 1))
    window.close()


def test_the_canvas_repaints_only_for_bins_size_and_theme(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 4800; playhead: 9600")
    canvas = find(window, "waveformCanvas")
    painted = spy(canvas, "paint(QRect)")
    QTest.qWait(50)
    before = painted.count()
    wave.setProperty("playhead", 20000)
    wave.setProperty("trimStart", 9600)
    QTest.mouseMove(window, at(wave, 30000))
    QTest.qWait(50)
    assert painted.count() == before
    wave.setProperty("bins", [-0.1, 0.1])
    qtbot.waitUntil(lambda: painted.count() > before)
    window.close()


def test_placeholder_without_bins(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, 'placeholderText: "Record a take"', bins="[]")
    placeholder = find(window, "placeholder")
    assert placeholder.isVisible() and placeholder.property("text") == "Record a take"
    assert not find(window, "zeroLine").isVisible()
    wave.setProperty("frameCount", 0)
    iface = QAccessible.queryAccessibleInterface(wave)
    assert iface.text(QAccessible.Text.Description) == "Record a take"
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert not wave.hasActiveFocus()  # nothing to seek: not a Tab stop
    wave.setProperty("bins", [-0.5, 0.5])
    assert not placeholder.isVisible()
    window.close()


# ---- The kept frames ---------------------------------------------------------------


@pytest.mark.parametrize(
    ("start", "end", "shown"),
    [(0, 0, (0, FRAMES)), (12000, 84000, (12000, 84000)), (-5, FRAMES + 99, (0, FRAMES)),
     (FRAMES + 10, 0, (FRAMES - 1, FRAMES)), (50000, 40000, (50000, 50001))],
)
def test_the_trim_is_clamped_to_the_clip(engine, qtbot, start, end, shown):
    window, wave = wave_scene(engine, qtbot, f"trimStart: {start}; trimEnd: {end}")
    assert (wave.property("shownStart"), wave.property("shownEnd")) == shown
    window.close()


def test_outside_the_kept_frames_is_shaded(engine, qtbot, theme):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000", bins="[-1, 1]")
    shade_start, shade_end = find(window, "shadeStart"), find(window, "shadeEnd")
    inset = js(wave, "_inset")
    assert shade_start.x() == pytest.approx(inset)
    assert shade_start.width() == pytest.approx(js(wave, "xAt(24000)") - inset)
    assert shade_end.x() == pytest.approx(js(wave, "xAt(72000)"))
    assert shade_end.x() + shade_end.width() == pytest.approx(wave.width() - inset)
    assert QColor(shade_start.property("color")) == QColor(theme.property("backdrop"))
    image = window.grabWindow()
    kept = image.pixelColor(at(wave, 48000, 30))
    excluded = image.pixelColor(at(wave, 12000, 30))
    assert kept == QColor(theme.property("accent")) and excluded != kept
    wave.setProperty("trimStart", 0)
    wave.setProperty("trimEnd", 0)
    assert shade_start.width() == 0 and shade_end.width() == 0
    window.close()


def test_playhead_line(engine, qtbot, theme):
    window, wave = wave_scene(engine, qtbot, "playhead: -1")
    line = find(window, "playhead")
    assert not line.isVisible()
    wave.setProperty("playhead", 36000)
    assert line.isVisible()
    assert line.x() + line.width() / 2 == pytest.approx(js(wave, "xAt(36000)"))
    assert QColor(line.property("color")) == QColor(theme.property("toneRed"))
    wave.setProperty("playhead", FRAMES * 3)  # past the end: drawn at the end
    assert line.x() + line.width() / 2 == pytest.approx(js(wave, "xAt(%d)" % FRAMES))
    window.close()


# ---- Seeking --------------------------------------------------------------------------


def test_press_and_drag_seek_within_the_kept_frames(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    seeks = spy(wave, "seekRequested(int)")
    trims = spy(wave, "trimChanged(int,int)")
    drag(window, at(wave, 48000))
    assert emitted(seeks) == [[pytest.approx(48000, abs=100)]]
    assert wave.hasActiveFocus() and visible_rings(window.contentItem()) == []  # pointer focus: no ring
    drag(window, at(wave, 6000))  # in the shaded start: the kept start
    assert emitted(seeks, 1) == [[24000]]
    right = wave.mapToScene(QPoint(0, 0)).toPoint() + QPoint(int(wave.width()) + 15, 60)
    drag(window, at(wave, 48000), at(wave, 60000), right)  # scrub, then past the end
    frames = [args[0] for args in emitted(seeks, 2)]
    assert frames[0] == pytest.approx(48000, abs=100) and frames[1] == pytest.approx(60000, abs=100)
    assert frames[-1] == 72000
    assert len(frames) == len(set(frames))  # no repeats while the frame stays the same
    assert trims.count() == 0
    window.close()


def test_keys_seek_a_tenth_of_a_second_and_to_the_edges(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    seeks = spy(wave, "seekRequested(int)")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert wave.hasActiveFocus()
    rings = visible_rings(window.contentItem())
    assert len(rings) == 1 and owner(rings[0], {"w", "trimStartHandle"}) == "w"
    QTest.keyClick(window, Qt.Key.Key_Right)  # no playhead: from the kept start
    QTest.keyClick(window, Qt.Key.Key_Left)
    wave.setProperty("playhead", 70000)
    QTest.keyClick(window, Qt.Key.Key_Right)  # clamped to the kept end
    QTest.keyClick(window, Qt.Key.Key_Left)
    QTest.keyClick(window, Qt.Key.Key_Home)
    QTest.keyClick(window, Qt.Key.Key_End)
    for modifier in (Qt.KeyboardModifier.ShiftModifier, Qt.KeyboardModifier.ControlModifier,
                     Qt.KeyboardModifier.AltModifier):
        QTest.keyClick(window, Qt.Key.Key_Right, modifier)
    assert [a[0] for a in emitted(seeks)] == [28800, 24000, 72000, 65200, 24000, 72000]
    window.close()


def test_keys_after_a_click_show_the_ring(engine, qtbot):
    """:focus-visible: a press focuses without the ring; the next key shows it; a press hides it."""
    window, wave = wave_scene(engine, qtbot)
    drag(window, at(wave, 48000))
    assert wave.hasActiveFocus() and visible_rings(window.contentItem()) == []
    QTest.keyClick(window, Qt.Key.Key_Right)
    assert len(visible_rings(window.contentItem())) == 1
    drag(window, at(wave, 48000))
    assert visible_rings(window.contentItem()) == []
    window.close()


# ---- Trimming by pointer ------------------------------------------------------------


def test_dragging_a_handle_is_controlled(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    seeks = spy(wave, "seekRequested(int)")
    trims = spy(wave, "trimChanged(int,int)")
    QTest.mousePress(window, LEFT, NONE, at(wave, 24000))
    QTest.mouseMove(window, at(wave, 36000))
    assert wave.property("shownStart") == pytest.approx(36000, abs=100)  # shown while dragged ...
    assert wave.property("trimStart") == 24000                          # ... never assigned
    assert trims.count() == 0
    QTest.mouseRelease(window, LEFT, NONE, at(wave, 36000))
    assert trims.count() == 1
    start, end = trims.at(0)
    assert start == pytest.approx(36000, abs=100) and end == 72000
    assert wave.property("shownStart") == 24000  # the owner did not write it back
    assert seeks.count() == 0
    window.close()


def test_the_owner_writes_the_trim_back(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        f'SuiWaveform {{ id: w; objectName: "w"; x: 20; y: 50; width: 610; height: 120; bins: [-0.5, 0.5];'
        f" frameCount: {FRAMES}; trimStart: 24000; trimEnd: 72000;"
        " onTrimChanged: (start, end) => { trimStart = start; trimEnd = end } }",
        width=650, height=200,
    )
    wave = find(window, "w")
    drag(window, at(wave, 72000), at(wave, 60000))
    assert wave.property("trimEnd") == pytest.approx(60000, abs=100)
    assert wave.property("shownEnd") == wave.property("trimEnd")
    window.close()


def test_handles_never_cross(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    trims = spy(wave, "trimChanged(int,int)")
    drag(window, at(wave, 24000), at(wave, 90000))
    drag(window, at(wave, 72000), at(wave, 1000))
    assert emitted(trims) == [[71999, 72000], [24000, 24001]]
    window.close()


def test_a_grab_beside_the_edge_does_not_jump(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    trims = spy(wave, "trimChanged(int,int)")
    beside = at(wave, 24000) + QPoint(10, 0)  # within reach, not on the edge
    drag(window, beside)
    assert trims.count() == 0  # released where it was grabbed: nothing moved
    drag(window, beside, beside + QPoint(50, 0))
    expected = js(wave, "frameAt(xAt(24000) + 50)")
    assert emitted(trims) == [[pytest.approx(expected, abs=1), 72000]]
    window.close()


def test_coincident_handles_open_either_way(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 48000; trimEnd: 48001")
    trims = spy(wave, "trimChanged(int,int)")
    edge = at(wave, 48000)
    drag(window, edge - QPoint(6, 0), edge - QPoint(80, 0))  # left of the shared pixel: the start
    drag(window, edge, edge + QPoint(80, 0))                   # on it: the end
    (s1, e1), (s2, e2) = emitted(trims)
    assert s1 < 48000 and e1 == 48001
    assert s2 == 48000 and e2 > 48001
    window.close()


def test_read_only_seeks_but_does_not_trim(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000; editable: false")
    seeks = spy(wave, "seekRequested(int)")
    trims = spy(wave, "trimChanged(int,int)")
    drag(window, at(wave, 24000), at(wave, 36000))
    assert trims.count() == 0 and seeks.count() >= 1
    assert not find(window, "grip").isVisible()
    assert find(window, "edgeLine").isVisible()  # the kept edges still show
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert not find(window, "trimStartHandle").hasActiveFocus()  # handles are not Tab stops
    window.close()


def test_disabling_or_a_new_take_cancels_a_drag(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    trims = spy(wave, "trimChanged(int,int)")
    seeks = spy(wave, "seekRequested(int)")
    QTest.mousePress(window, LEFT, NONE, at(wave, 24000))
    QTest.mouseMove(window, at(wave, 36000))
    wave.setProperty("enabled", False)
    assert wave.property("shownStart") == 24000
    QTest.mouseRelease(window, LEFT, NONE, at(wave, 36000))
    drag(window, at(wave, 48000))  # disabled: nothing
    wave.setProperty("enabled", True)
    QTest.mousePress(window, LEFT, NONE, at(wave, 72000))
    QTest.mouseMove(window, at(wave, 60000))
    wave.setProperty("frameCount", FRAMES + 1)  # a new take
    assert wave.property("shownEnd") == 72000
    QTest.mouseRelease(window, LEFT, NONE, at(wave, 60000))
    assert trims.count() == 0 and seeks.count() == 0
    window.close()


# ---- Trimming by keyboard -----------------------------------------------------------


def test_handles_are_tab_stops_with_keys(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        f'SuiWaveform {{ objectName: "w"; x: 20; y: 50; width: 610; height: 120; bins: [-0.5, 0.5];'
        f" frameCount: {FRAMES}; trimStart: 24000; trimEnd: 72000;"
        " onTrimChanged: (start, end) => { trimStart = start; trimEnd = end } }",
        width=650, height=200,
    )
    wave = find(window, "w")
    trims = spy(wave, "trimChanged(int,int)")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    start = find(window, "trimStartHandle")
    assert start.hasActiveFocus()
    rings = visible_rings(window.contentItem())
    assert len(rings) == 1 and owner(rings[0], {"trimStartHandle", "w"}) == "trimStartHandle"
    for key in (Qt.Key.Key_Right, Qt.Key.Key_Left, Qt.Key.Key_PageUp, Qt.Key.Key_PageUp, Qt.Key.Key_Home):
        QTest.keyClick(window, key)
    QTest.keyClick(window, Qt.Key.Key_Right, Qt.KeyboardModifier.ControlModifier)  # ignored
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "trimEndHandle").hasActiveFocus()
    QTest.keyClick(window, Qt.Key.Key_PageDown)
    QTest.keyClick(window, Qt.Key.Key_End)
    QTest.keyClick(window, Qt.Key.Key_End)  # already there: nothing
    QTest.keyClick(window, Qt.Key.Key_Home)
    # Right, Left, PageUp (stops a frame before the end), PageUp (no further), Home; then the end
    # handle: PageDown, End, End (already there), Home (stops a frame after the start).
    assert emitted(trims) == [[28800, 72000], [24000, 72000], [71999, 72000], [0, 72000],
                              [0, 24000], [0, FRAMES], [0, 1]]
    window.close()


def test_a_press_moves_focus_from_a_handle_to_the_waveform(engine, qtbot):
    window, wave = wave_scene(engine, qtbot)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert find(window, "trimStartHandle").hasActiveFocus()
    drag(window, at(wave, 48000))
    assert window.activeFocusItem() is not None and window.activeFocusItem().objectName() == "w"
    assert visible_rings(window.contentItem()) == []
    window.close()


# ---- Playing, hovering --------------------------------------------------------------


def test_double_click_plays_in_the_kept_frames_only(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    plays = spy(wave, "playRequested(int)")
    QTest.mouseDClick(window, LEFT, NONE, at(wave, 48000))
    assert emitted(plays) == [[pytest.approx(48000, abs=100)]]
    QTest.mouseDClick(window, LEFT, NONE, at(wave, 6000))   # shaded
    QTest.mouseDClick(window, LEFT, NONE, at(wave, 72000))  # on a handle
    assert plays.count() == 1
    window.close()


def test_hover_shows_the_time_without_seeking(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000")
    seeks = spy(wave, "seekRequested(int)")
    readout = find(window, "hoverReadout")
    assert not readout.isVisible() and wave.property("hoverFrame") == -1
    x = js(wave, "_inset") + js(wave, "_plotWidth") * 0.75  # 1.5 s
    QTest.mouseMove(window, QPoint(5, 190))  # Qt drops a move to where the cursor already is
    QTest.mouseMove(window, wave.mapToScene(QPoint(0, 0)).toPoint() + QPoint(round(x), 60))
    qtbot.waitUntil(lambda: wave.property("hoverFrame") >= 0)  # hover arrives with the next frame
    frame = wave.property("hoverFrame")
    assert frame == pytest.approx(72000, abs=100)
    assert wave.property("hoverText") == js(wave, f"formatTime({frame})")
    assert readout.isVisible() and readout.x() == pytest.approx(js(wave, f"xAt({frame})"))
    assert js(wave, "formatTime(72000)") == "0:01.500"
    assert js(wave, "formatTime(48000 * 75 + 24)") == "1:15.001"
    assert seeks.count() == 0
    QTest.mouseMove(window, QPoint(5, 190))  # out of the waveform
    qtbot.waitUntil(lambda: wave.property("hoverFrame") == -1)
    assert not readout.isVisible()
    # While a handle is dragged, the readout follows its edge.
    QTest.mousePress(window, LEFT, NONE, at(wave, 24000) + QPoint(8, 0))
    QTest.mouseMove(window, at(wave, 36000) + QPoint(8, 0))
    assert wave.property("hoverFrame") == wave.property("shownStart")
    QTest.mouseRelease(window, LEFT, NONE, at(wave, 36000) + QPoint(8, 0))
    window.close()


# ---- Accessibility --------------------------------------------------------------------


def test_accessible_slider_with_seconds(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000; playhead: -1")
    iface = QAccessible.queryAccessibleInterface(wave)
    assert iface.role() == QAccessible.Role.Slider
    assert iface.text(QAccessible.Text.Name) == "Take 12"
    assert iface.text(QAccessible.Text.Description) == "kept 0.50 to 1.50 of 2.00 seconds"
    value = iface.valueInterface()
    assert value.currentValue() == pytest.approx(0.5)  # no playhead: the kept start
    assert (value.minimumValue(), value.maximumValue()) == (pytest.approx(0), pytest.approx(2))
    wave.setProperty("playhead", 60000)
    assert value.currentValue() == pytest.approx(1.25)
    handle = QAccessible.queryAccessibleInterface(find(window, "trimEndHandle"))
    assert handle.role() == QAccessible.Role.Slider
    assert handle.text(QAccessible.Text.Name) == "Trim end"
    assert handle.text(QAccessible.Text.Description) == "0:01.500"
    assert handle.valueInterface().currentValue() == pytest.approx(1.5)
    window.close()


def test_accessible_actions_step_like_the_keys(engine, qtbot):
    window, wave = wave_scene(engine, qtbot, "trimStart: 24000; trimEnd: 72000; playhead: 48000")
    seeks = spy(wave, "seekRequested(int)")
    trims = spy(wave, "trimChanged(int,int)")
    from PySide6.QtGui import QAccessibleActionInterface

    actions = QAccessible.queryAccessibleInterface(wave).actionInterface()
    actions.doAction(QAccessibleActionInterface.increaseAction())
    actions.doAction(QAccessibleActionInterface.decreaseAction())
    handle = QAccessible.queryAccessibleInterface(find(window, "trimStartHandle")).actionInterface()
    handle.doAction(QAccessibleActionInterface.increaseAction())
    assert emitted(seeks) == [[52800], [43200]]
    assert emitted(trims) == [[28800, 72000]]
    window.close()
