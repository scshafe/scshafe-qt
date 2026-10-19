# scshafe-qt

The SCSHAFE native component library: the QML module **`Scshafe.Ui`** (Qt Quick) for
Python + PySide6 desktop apps, themed from the same token registry as the web library
`@scshafe/ui`, so web and native share one source of truth for colour, spacing, radii,
type and motion.

- Distribution `scshafe-qt`, import `scshafe_qt`, QML module `Scshafe.Ui`.
- Qt **6.11** through `PySide6-Essentials` 6.11.x (6.11.2). Open-source Qt patch
  releases track the current minor (6.8 LTS patches for open source ended at
  6.8.3), so the library follows the current minor; 6.12 comes when PySide6 6.12
  ships.
- Python **3.12, 3.13 and 3.14** (`requires-python >=3.12`, from 0.2.0; 0.1.x needed
  3.14). CI tests all three. The PySide6 6.11 wheels are abi3 for CPython 3.10+ and
  declare `requires-python <3.15`, so a newer Python waits for a PySide6 that supports it.
- Status: **0.9.0**: `SuiTheme` (tokens), the v0.1 component set, `SuiText`
  (typography), the form controls, `SuiProgressBar`, `SuiLevelMeter`, `SuiTable`,
  `SuiChart`, `SuiHistogram` and `SuiWaveform` below.
- **Untrusted text is safe to pass:** every component renders caller strings as plain text
  (`textFormat: Text.PlainText`); markup is shown literally and never fetches anything.
  0.1.0 rendered HTML-looking strings as rich text (fixed in 0.1.1; upgrade).

## Install (consumers)

From [PyPI](https://pypi.org/project/scshafe-qt/) (from 0.1.2), on Python 3.12 or later
(3.14 only before 0.2.0):

```sh
uv add scshafe-qt            # or: pip install scshafe-qt
```

Minor releases add components and keep the existing API (0.3.0: `SuiText`; 0.4.0: form
controls; 0.5.0: `SuiProgressBar`; 0.6.0: `SuiLevelMeter`;
0.7.0: `SuiTable`; 0.8.0: `SuiChart`, `SuiHistogram`; 0.9.0: `SuiWaveform`); an app
pinned below the new minor (`scshafe-qt>=0.2,<0.3`) stays where it is until it widens
the range. 0.2.0 changed only the supported Python range.

Every release is also a GitHub Release of `scshafe/scshafe-qt` with the same wheel and
sdist, their sha256 in the notes and a `SHA256SUMS` file. `publish.yml` uploads the
very files it attached to the Release (PyPI and the Release are byte-identical), with
PEP 740 attestations from trusted publishing. As a fallback, install straight from a
Release; the repository is public, so the download URLs need no token:

```sh
pip install https://github.com/scshafe/scshafe-qt/releases/download/v0.8.0/scshafe_qt-0.8.0-py3-none-any.whl
# or, in a uv project, a pinned URL source (uv.lock records its sha256):
uv add "scshafe-qt @ https://github.com/scshafe/scshafe-qt/releases/download/v0.8.0/scshafe_qt-0.8.0-py3-none-any.whl"
```

To check the files yourself: `gh release download v0.8.0 -R scshafe/scshafe-qt -p '*.whl' -p SHA256SUMS`,
then `sha256sum -c --ignore-missing SHA256SUMS`.

The library accepts the Qt minor it is tested on (`PySide6-Essentials>=6.11.2,<6.12`);
the app's own `uv.lock` pins one exact PySide6.

## Usage

```python
import sys
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
import scshafe_qt

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
scshafe_qt.register(engine)          # adds scshafe_qt.qml_import_path() once
engine.load("main.qml")
sys.exit(app.exec())
```

```qml
import QtQuick
import Scshafe.Ui

Window {
    visible: true
    color: SuiTheme.bg
    SuiButton { text: "Sort"; variant: "primary"; onClicked: console.log("sorted") }
}
```

Imports are versionless (`import Scshafe.Ui`).

## Components

| Component | What it is | Keyboard / accessibility |
| --- | --- | --- |
| `SuiAppShell` | sidebar \| content \| inspector frame; `sidebar`, `content`, `inspector` slots; `inspectorOpen` / `sidebarOpen` collapse a pane | splitters are Tab stops (role Separator): ←/→ resize by `resizeStep` (Shift ×4), Home/End min/max, Enter collapses; drag resizes; panes are named Panes |
| `SuiSidebarList` + `SuiSidebarItem` | navigation list: icon, label, count badge, health dot (`status`: `ok` / `held` / `failing` / `none`), section headers (`section` role) | one Tab stop; ↑/↓ Home/End PgUp/PgDn move (skip disabled), Enter/Return/Space activate (`activated(index)`, `selectedIndex`); status and count in the accessible description |
| `SuiList` + `SuiListRow` | single-selection `ListView` (`currentIndex`) of two-line rows (`title`, `subtitle`, `meta`, `unread`; children go to a trailing slot) | one Tab stop; ↓/`j`, ↑/`k` emit `nextRequested()` / `previousRequested()` and move (unless `autoNavigate: false`); Enter / double-click emit `activated(index)`; `selectNext()` etc. for app shortcuts |
| `SuiChip`, `SuiBadge` | pills: `tone` `neutral` / `info` / `ok` / `warn` / `danger` or a bucket `bucket1`…`bucket8` (or 1–8); badge shows `count` (99+) | StaticText named by the text |
| `SuiButton`, `SuiIconButton` | buttons; the icon button needs `label` (its accessible name; a `required` property) and `icon.name` (built-in) or `icon.source`; `checkable` toggles | Space/Enter; role Button (CheckBox when checkable) |
| `SuiTextField`, `SuiSearchField` | inputs; search has an icon, a clear button and a `/` hook | `/` anywhere (not while typing in another field) fires `focusRequested()` then focuses and selects; Escape clears (`cleared()`), then propagates |
| `SuiEmptyState` | icon, title, description, action slot | Grouping named by the title |
| `SuiBanner` | inline status (`tone` info / ok / warn / danger), `dismissible` | warn/danger are AlertMessages; the dismiss button is a Tab stop |
| `SuiToast`, `SuiToastHost` | `host.show(text, { title, tone, timeout, actionText, onAction })`, `dismiss(id)`, `clear()`; stacks bottom-right, at most `maxToasts` | AlertMessage; announced with `Accessible.announce` (assertive for danger); the timeout pauses on hover / focus; Escape dismisses |
| `SuiDialog`, `SuiSheet` | modal dialog (`title`, `description`, content, `actions`) and a sheet sliding from an `edge` | focus moves in on open, Tab is trapped inside, Escape rejects, focus returns to the opener (with its ring if it had keyboard focus); role Dialog named by the title |
| `SuiTrail` | vertical steps: `title`, `outcome` (+ `outcomeTone`), `detail`, `via` tag, `warning` marker | List of ListItems ("2. Classifier: Receipts", description = detail, via, warning) |
| `SuiShortcutOverlay` | the `?` overlay of the app's `shortcuts` (`keys`, `description`, `group`, `separator`) | `?` toggles (not while typing); a SuiDialog |
| `SuiChart` | x/y chart of `series` of kind `line`, `area`, `band`, `scatter` or `bars` (columns as JS arrays or Python lists; gaps at null/NaN; dense lines drawn min/max per pixel), nice axes (`xLabel`, `yLabel`, limits, `xFormat` / `yFormat`), `markers`, a legend | Chart named by `label`, described by a summary of the series (or `description`); a Tab stop when it has data: ←/→ (PgUp/PgDn, Home/End) step the readout through x, announced; Escape hides it; hover shows it too |
| `SuiHistogram` | a `SuiChart` of `values` binned into `binCount` (Sturges by default) or `binWidth` bins over `from`..`to`; `density` for shares; `bins` | as `SuiChart`; described by the distribution ("N values in K bins …"); the readout names the bin |
| `SuiCheckBox`, `SuiSwitch` | labelled toggles with optional `description` (help text under the label); the checkbox does `tristate`; `label` names one without visible text | Space or a click toggles (`toggled()`); CheckBox role (Qt reports switches as checkboxes), described by `description` |
| `SuiRadioButton` | one choice of an exclusive group (same parent, or a `ButtonGroup`), with `description` | the group is one Tab stop (its checked button); ↑/↓/←/→ move and check, wrapping; RadioButton role |
| `SuiSelect` | drop-down of one option (`ComboBox`): strings or objects with `textRole` / `valueRole`; `placeholderText` for no choice; as wide as its widest option | Space/Enter opens, ↑/↓ and typing move, Enter chooses, Escape closes; closed, ↑/↓ change it; ComboBox named by `label`, described by the choice |
| `SuiSlider` | number in a range (`from`, `to`, `stepSize`), horizontal or vertical; `unit`, `decimals`, `showValue` draws `valueText` | arrows one step (1 % without `stepSize`), PgUp/PgDn ten, Home/End the ends; `moved()` for every user change; Slider named by `label`, value interface, described by `valueText` |
| `SuiLevelMeter` | live level (`level`, `from`..`to`, default -60..0 dB) in ok / warn / danger zones (`warnLevel`, `dangerLevel`), peak hold (`peak`), a latched clip lamp (`clipped`, `reset()`), a scale and `valueText`; a pinned-level marker (`pinnedLevel`, `pinnedLabel`), user-movable with `pinEditable` (`pinMoved(level)`); horizontal or vertical | ProgressBar named by `label` with the level as its value, described by level, peak, pin and clipping; an editable pin is a Slider Tab stop: arrows by `pinStep`, PgUp/PgDn ten, Home/End, drag or click |
| `SuiProgressBar` | determinate progress (`from`, `to`, `value`): `label` above, `valueText` beside (a percentage by default), `tone` `accent` / `ok` / `warn` / `danger`; `cancellable` adds a cancel button emitting `cancelRequested()` | ProgressBar named by `label`, described by `valueText`, Qt's value interface; the cancel button is a Tab stop named `cancelLabel` ("Cancel <label>") |
| `SuiTable` | sortable, virtualised data table (`columns`, `rows`: a JS array or a Python list of dicts; 10,000 rows sort in ~20 ms and scroll at ~3 ms a frame); resizable columns (`columnWidths`, `columnResized`), row selection (`selectionMode` single / multiple / none, `selectedRows`, `currentRow`, `rowKey` keeps it across new rows), `format` / `tone` per column | Table named by `label`; the header is one Tab stop (←/→ between ColumnHeaders, Enter/Space sort, Ctrl+←/→ resize), the body another (↑/↓ PgUp/PgDn Home/End, Shift extends, Ctrl moves without selecting, Space toggles, Ctrl+A, Enter / double-click `activated(row)`); rows are ListItems named "Title: value, …" |
| `SuiWaveform` | a recording's waveform (`bins`: min/max pairs in -1..1) over `frameCount` frames at `sampleRate`, the kept frames `trimStart`..`trimEnd` (the rest shaded), a `playhead`; controlled: `seekRequested(frame)` on press, drag or a key, `trimChanged(start, end)` when a handle is released (`editable`), `playRequested(frame)` on a double-click; the time under the pointer | Slider named by `label`, described "kept X to Y of Z seconds", value interface in seconds; ←/→ step 0.1 s from the playhead, Home/End the kept edges; with `editable` each handle is a Slider Tab stop (←/→ 0.1 s, PgUp/PgDn 1 s, Home/End) |
| `SuiText` | text in a type style: `variant` `display` / `title` / `heading` / `subheading` / `section` / `label` / `body` / `caption` / `small` / `code`; `tone` overrides the colour; `tabular` digits | heading variants are Headings, the rest StaticText, named by the text; plain text |
| `SuiIcon`, `SuiKbd` | built-in vector icons (`SuiIcon.names`) or a tinted image; a keyboard-key badge | icons are decorative unless given a `label` |

```qml
import QtQuick
import Scshafe.Ui

Window {
    width: 1100; height: 700; visible: true; color: SuiTheme.bg
    Shortcut { sequence: "j"; onActivated: inbox.selectNext() }     // from anywhere
    SuiAppShell {
        anchors.fill: parent
        sidebar: SuiSidebarList {
            label: "Mailboxes"; selectedIndex: 0
            model: [ { section: "Buckets", text: "Receipts", iconName: "tag", count: 3, status: "ok" } ]
        }
        content: SuiList {
            id: inbox; label: "Messages"; model: messages
            delegate: SuiListRow {
                width: ListView.view.width
                title: model.sender; subtitle: model.subject; meta: model.time; unread: model.unread
                SuiChip { text: model.bucketName; tone: model.bucket; dot: true }   // trailing slot
            }
            onActivated: (index) => sheet.open()
        }
        inspector: SuiTrail { steps: [ { title: "Classifier", outcome: "Receipts", outcomeTone: 1, via: "model" } ] }
    }
    SuiToastHost { id: toasts; anchors.fill: parent; z: 100 }
}
```

Every interactive component is keyboard-focusable and draws its focus ring for
keyboard focus only (text fields for any focus, as browsers do). Lists are one
Tab stop with roving focus on the current row, which holds active focus (so a
screen reader announces it); the ring returns after a pointer click as soon as
an arrow key is used (the `:focus-visible` heuristic).

### Gallery

`examples/gallery.py` shows every component in one window with made-up data:

```sh
uv run python examples/gallery.py                       # follows the OS theme
uv run python examples/gallery.py --theme dark --reduced-motion
uv run python examples/gallery.py --screenshot DIR      # PNGs of every view x two themes
```

The sidebar's first section switches pages: the mail sample, typography, controls, a
table of 10,000 rows, charts and a waveform.
In the window: Tab / Shift+Tab, `j` / `k`, `1`–`8` (a toast), `/`, `?`.

### Typography

`SuiText` is a `Text` in one of the type styles of `SuiTheme.textStyles` (generated from
`TEXT_STYLES` in the NATIVE-ONLY section of `tools/gen_tokens.py`):

| `variant` | size / weight | colour | web (`components.css`) |
| --- | --- | --- | --- |
| `display` | 24 px / 600, -0.01em | strong | (native only) |
| `title` | 20 px / 600, -0.01em | strong | Title `h1` |
| `heading` | 16 px / 600 | strong | Title `h2` |
| `subheading` | 14 px / 600 | strong | Title `h3` |
| `section` | 13 px / 600, caps, 0.06em | muted | Title `h4`–`h6` |
| `label` | 12 px / 600, caps, 0.05em | muted | Label |
| `body` (default) | 13 px / 400, line height 1.5 | text | body text |
| `caption` | 12 px / 400, line height 1.5 | muted | Description |
| `small` | 11 px / 400 | muted | (native only) |
| `code` | 12 px / 400, `monoFamily` | text | Identifier |

```qml
SuiText { text: "Recordings"; variant: "title" }
SuiText { text: take.note; variant: "caption"; wrapMode: Text.Wrap; width: parent.width }
SuiText { text: "-12.4 dB"; tone: "warn"; tabular: true }
```

- `tone` overrides the variant's colour: `default` (`--sui-text`), `strong`, `muted`,
  `accent`, a status tone (`info`, `ok`, `warn`, `danger`: the tone's text colour) or a
  bucket. `SuiTheme.textColor(tone)` is the same mapping for other items.
- Titles take `--sui-text-strong`, which the registry describes as the colour of titles
  (the web's `.sui-title` uses `--sui-text`); the native dialogs and toasts do the same.
- The line height (`leading`) applies once the text wraps (`wrapMode`), as a fixed
  `size x leading` pixels per line like CSS `line-height`; a single line keeps the font's
  own height so it centres in rows. Caps are drawn; the accessible name keeps the text.
- `tabular: true` sets the `tnum` feature (equal-width digits) for values that change.
- Everything else is `Text`'s: `elide`, `wrapMode`, `maximumLineCount`, alignment.
  Caller text is plain text (`textFormat` is `Text.PlainText`).

### Form controls

```qml
SuiCheckBox { text: "Normalise loudness"; description: "Every take to -23 LUFS"; checked: true }
SuiSwitch { text: "Monitor input"; onToggled: recorder.monitor = checked }
Column {                                     // one exclusive group: the same parent
    SuiRadioButton { text: "44.1 kHz" }
    SuiRadioButton { text: "48 kHz"; checked: true }
}
SuiSelect { label: "Input"; model: devices; textRole: "name"; valueRole: "id"
            onActivated: recorder.device = currentValue }
SuiSlider { label: "Input gain"; from: -24; to: 24; stepSize: 0.5; unit: "dB"; showValue: true
            onMoved: recorder.gain = value }
```

- They are Qt Quick Templates controls (`T.CheckBox`, `T.Switch`, `T.RadioButton`,
  `T.ComboBox`, `T.Slider`), so their whole Qt API applies; listen to the user-change
  signals (`toggled()`, `activated(index)`, `moved()`) to write values back.
- Checked toggles fill with the accent and draw their mark in `SuiTheme.accentForeground`
  (white on the light theme's accent, the page colour on the dark theme's; 4.5:1 or more,
  tested); unchecked boxes use `--sui-field-border`, the 3:1 control boundary.
- `SuiSelect` and `SuiSlider` need a `label` (their accessible name; the visible label
  is a `SuiText { variant: "label" }` beside them) and warn without one.
- Name a radio group with a container: `Accessible.role: Accessible.Grouping` and
  `Accessible.name`, and a `SuiText` section heading.
- Sizes are NATIVE-ONLY tokens: `indicatorSize`, `checkboxRadius`, `switchWidth`,
  `switchHeight`, `switchThumbSize`, `sliderTrackHeight`, `sliderHandleSize`,
  `menuMaxHeight`.

### Progress

```qml
SuiProgressBar { label: "Transcribing take 3"; value: job.fraction }
SuiProgressBar {
    label: "Exporting"; from: 0; to: job.total; value: job.done
    valueText: job.done + " of " + job.total + " files"
    cancellable: job.running
    onCancelRequested: job.cancel()
}
```

Determinate only: Qt's `indeterminate` is not drawn (say what is happening in the
label instead). The fill moves on `SuiTheme.duration`, so it jumps under reduced motion.
`showLabel: false` and `showValue: false` leave the bare bar (`SuiTheme.progressHeight`).
The app stops its task on `cancelRequested()` and clears `cancellable`.

### Level meter

```qml
SuiLevelMeter { label: "Input level"; level: recorder.levelDb }          // dBFS, -60..0
SuiLevelMeter {
    label: "Microphone"; level: input.rmsDb
    pinnedLevel: settings.gateDb; pinnedLabel: "Gate threshold"; pinEditable: true
    onPinMoved: (level) => settings.gateDb = level
}
SuiLevelMeter { label: "Left"; orientation: Qt.Vertical; height: 180; level: left.db }
```

- `level` is in the meter's unit (`from`/`to`, default -60..0 dB; a linear 0..1 works
  with `from: 0; to: 1; unit: ""`); `-Infinity` reads as silence (`-∞ dB`). The meter
  draws each level as it arrives: no smoothing, so ballistics (VU, PPM) are the app's.
  Nothing in it animates; reduced motion leaves it unchanged.
- Zones: ok (`--sui-ok`) below `warnLevel` (-12), warn (`--sui-tone-yellow`) up to
  `dangerLevel` (-3), danger (`--sui-tone-red`) above; the level reveals them.
- Peak hold: `peak` holds the highest level for `SuiTheme.meterPeakHold` (1.5 s), then
  drops to the level. Clip: `clipped` latches when the level reaches `clipLevel` (`to`)
  and lights the lamp after the bar. `reset()` clears both.
- The pinned-level marker is the app's (a target, a gate threshold; NaN hides it), drawn
  in the accent with a halo. With `pinEditable` the user moves it: it is a Slider (Tab
  stop, ring for keyboard focus) moved by the arrows (`pinStep`, default 1), PageUp /
  PageDown (ten steps), Home/End, a drag or a click on the meter. `pinMoved(level)` fires
  and `pinnedLevel` follows; write it back from the handler.
- `showScale` (tick labels every `scaleStep`, or the smallest step whose labels do not
  collide), `showValue` (`valueText`, `decimals`, `unit`), `showClip`, `peakHold`.

### Table

```qml
SuiTable {
    label: "Takes"
    columns: [
        { key: "name", title: "Take", width: 220 },
        { key: "speaker", title: "Speaker" },
        { key: "seconds", title: "Duration", width: 90, align: "right", format: (v) => v.toFixed(1) + " s" },
        { key: "score", title: "Score", width: 80, align: "right", tone: (v) => v < 0.5 ? "danger" : "" }
    ]
    rows: takes                      // a JS array of objects, or a Python list of dicts
    rowKey: "id"                     // keeps selection and current row when rows are replaced
    selectionMode: "multiple"
    onActivated: (row) => openTake(rows[row])
}
```

- Rows are plain objects; a column shows `row[key]`, through `format(value, row)` when
  given and in the colour of `tone(value, row)` (a `SuiText` tone) when given. Column
  fields: `key`, `title`, `width` (`SuiTheme.tableColumnWidth`), `minWidth` / `maxWidth`
  (`tableMinColumnWidth` / `tableMaxColumnWidth`), `align` (`right` cells use tabular
  digits), `sortable`, `resizable`. The last column fills the view (`fillLastColumn`).
- Every row number in the API (`currentRow`, `selectedRows`, `activated(row)`,
  `select([...])`, `setCurrentRow`, `positionViewAtRow`, `cellText(row, key)`) is an
  index into `rows`, whatever the sort.
- Sorting (`sortKey`, `sortOrder`, `sortBy(key[, order])`) runs in JS over an index
  permutation: numbers as numbers, other values as case-insensitive text, empty values
  last, ties in `rows` order. Qt 6.10's `SortFilterProxyModel` takes 1–1.6 s per sort
  over a Python model of 10,000 rows (every comparison calls Python), and does not
  accept JS arrays; the JS sort takes about 20 ms.
- Only the rows near the view exist (a `ListView` with `reuseItems`): 44 delegates for
  10,000 rows in a 1000 x 700 window; replace `rows` to update (10,000 dicts convert in
  about 80 ms).
- `columnWidths` (`{ key: width }`) is the user's sizing: bind it to settings to restore
  it, and save on `columnResized(key, width)`; `resetColumnWidth(key)` (double-click a
  header edge) returns to the column's `width`.
- Scroll bars (internal `SuiScrollBar`) show while the content overflows; Left/Right
  on the body scroll sideways and the header follows.

### Charts

```qml
SuiChart {
    label: "Pitch, take 12"; xLabel: "Time (s)"; yLabel: "F0 (Hz)"
    series: [
        { kind: "band", name: "Range", x: t, lower: f0lo, upper: f0hi },
        { kind: "line", name: "F0", x: t, y: f0 },               // null / NaN breaks the line
        { kind: "scatter", name: "Onsets", x: onsetT, y: onsetF0, tone: "warn" }
    ]
    markers: [{ axis: "y", value: 180, label: "Target" }]
}
SuiChart { label: "Energy"; series: [{ kind: "area", y: rmsDb, baseline: -60 }] }
SuiHistogram { label: "Take durations"; values: durations; binWidth: 2.5; xLabel: "Duration (s)" }
```

- Built on Qt Quick Shapes (lines, areas, bands: `PathMultiline`, the curve renderer) and
  Canvas (scatter); no Qt Graphs, so `PySide6-Essentials` stays the only dependency.
  Lines and areas with far more points than pixels are reduced to min/max per pixel
  column, keeping spikes: a 100,000-point line draws as ~1,500 vertices.
- Series fields: `kind`, `x` (default 0, 1, …), `y`, `lower` / `upper` (band), `x0` /
  `x1` (bars), `baseline` (area, default 0), `name`, `tone` (default bucket 1, 2, … by
  position: the categorical palette, 3:1 on every surface), `size` (scatter).
- Axes: automatic from the data and markers, or `xMin` / `xMax` / `yMin` / `yMax`;
  `yNice` (default) / `xNice` extend to whole ticks of 1, 2, 2.5 or 5 x 10^n; `yIntegers`
  for counts; `xGrid` / `yGrid`. The legend shows with two or more named series.
- The readout is the accessible part: Tab to the chart, ←/→ step through the first
  series' x values (each step is announced with `Accessible.announce`), Escape hides it;
  `inspectedX` and `readoutText` expose it. Nothing animates.
- `SuiHistogram` bins `values` (non-numbers are left out) into `binCount` bins (Sturges
  by default) or `binWidth` bins (aligned to multiples of the width; the largest value
  gets its own bin), over `from`..`to`; `density` plots shares; `bins` is
  `[{ x0, x1, count, share }]`.

### Waveform

```qml
SuiWaveform {
    label: "Take 12"
    bins: take.bins                          // [min0, max0, min1, max1, ...] in -1..1
    frameCount: take.frameCount              // sampleRate: 48000 (the default)
    trimStart: take.trimStart; trimEnd: take.trimEnd
    playhead: player.playing ? player.frame : -1
    onTrimChanged: (start, end) => take.setTrim(start, end)   // write it back
    onSeekRequested: (frame) => player.seek(frame)
    onPlayRequested: (frame) => player.playFrom(frame)
}
```

- Frames are the original's; the waveform never edits audio and never assigns the trim
  or the playhead. The owner computes `bins` (about 2,048 pairs whatever the length is
  plenty) and maps them to any display scale it wants; they draw min/max per pixel
  column on a Canvas that repaints only when the bins, the size or the theme change.
- The kept frames are `[trimStart, trimEnd)` (`trimEnd` 0: to the end). Dragging a
  handle shows the new edge in `shownStart` / `shownEnd`; `trimChanged` fires on release,
  and with the keyboard on each step. A press within `SuiTheme.waveformHandleReach` of
  an edge grabs its handle (the nearer; when both share a pixel, the side of the press),
  without jumping to the pointer; the handles never cross.
- Seeking (press, drag, ←/→, Home/End) stays within the kept frames; a double-click in
  them asks to play from that frame. `hoverFrame` / `hoverText` (m:ss.mmm) are the time
  under the pointer; `placeholderText` shows while there are no bins. Nothing animates.

### Theme and motion

`SuiTheme` is a singleton with every registry token as a property (`--sui-text-strong`
is `SuiTheme.textStrong`; `SuiTheme.registry` maps CSS names to property names).

- `SuiTheme.mode`: `"system"` (default) follows `Qt.styleHints.colorScheme`; `"light"`
  and `"dark"` pin a theme. `SuiTheme.dark` / `SuiTheme.themeName` report the result.
- `SuiTheme.reducedMotion`: when `true`, `SuiTheme.duration` (every transition) is 0.
  Qt (through 6.11) exposes **no** OS reduced-motion preference (QStyleHints has none;
  `QAccessibilityHints`, 6.10+, only carries `contrastPreference`), so the application sets it,
  e.g. from GNOME's `org.gnome.desktop.interface enable-animations` or macOS's
  "Reduce motion" setting. Every component animates only on `SuiTheme.duration`
  (`tests/test_rules.py` checks it statically and, over the gallery, at runtime), so this
  one switch stops them all; it can change at any time:

  ```python
  theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")   # after scshafe_qt.register(engine)
  theme.setProperty("reducedMotion", True)
  ```
- Units: lengths are logical pixels (CSS px), durations milliseconds; shadows are
  `{ offsetX, offsetY, blur, spread, color }` for `MultiEffect`.
- Native-only tokens (not in the registry) live in the clearly marked NATIVE-ONLY
  section of `tools/gen_tokens.py` and are generated into `SuiTheme.qml`: focus ring,
  control metrics (with `accentForeground`) and layout defaults, type scale and text styles (`textStyles`,
  `textStyle(variant)`, `textColor(tone)`), the bucket palette, tone helpers
  (`toneBase`, `toneText`, `toneFill`, `toneBorder`, `statusColor`), `monoFamily` and
  `alpha(color, amount)`.

### Tones and the bucket palette

Status tones reuse the registry's tone tokens: `info` blue, `ok` green, `warn`
yellow, `danger` red; `neutral` is `--sui-text` on `--sui-tint`. A chip's fill is
its tone at `toneTint` (12 %, the web library's `TONE_TINT`), its border at 45 %.

`bucket1`…`bucket8` are native-only categorical tones for user-defined groups,
chosen in OKLCH about 45° apart (blue, teal, green, olive, amber, rust, rose,
violet). `tests/test_tokens.py` checks, in both themes, that each bucket's text
reaches 4.5:1 on its chip fill over every surface and every overlay (selection,
hover, tint), that each base (dots, swatches) reaches 3:1 on every surface, and that
the bases stay pairwise distinct (OKLab distance ≥ 0.07). Lowest ratios today:

| | blue | teal | green | olive | amber | rust | rose | violet |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| light text on chip | 5.08 | 4.99 | 4.98 | 5.01 | 5.04 | 4.98 | 4.96 | 4.96 |
| dark text on chip | 6.01 | 6.03 | 6.08 | 6.01 | 6.01 | 6.02 | 6.12 | 6.02 |
| light base on surfaces | 3.69 | 3.73 | 3.73 | 3.68 | 3.75 | 3.76 | 3.82 | 3.77 |
| dark base on surfaces | 7.20 | 7.62 | 7.66 | 7.37 | 7.10 | 6.87 | 6.75 | 6.90 |

### Monospace

`--sui-mono` is a CSS stack; a Qt font takes one family, so `SuiTheme.monoFamily`
is the first installed candidate for the platform (assign it to override):

- Linux: `monospace`, fontconfig's alias for the user's configured monospace face
  (DejaVu Sans Mono, Noto Sans Mono, Liberation Mono or Ubuntu Mono on common
  distributions);
- macOS: SF Mono (when installed), else Menlo (always present), Monaco;
- Windows: Cascadia Mono, Consolas, Courier New;
- fallback: `monospace`.

### Accessibility contract

Every interactive component is keyboard-focusable, shows a focus ring
(`SuiTheme.focusRing`, outside the control, or inset on list rows) for keyboard
focus only (Qt's `visualFocus`, the native `:focus-visible`), sets
`Accessible.role` and `Accessible.name`, and animates only on `SuiTheme.duration`.
Components carry no colour literals (`tests/test_rules.py` enforces it, as
`@scshafe/ui` does for its stylesheets) and every animation runs on
`SuiTheme.duration`, so `reducedMotion` stops them all (checked statically and at
runtime over the gallery).

### Qt version notes

The QML targets Qt 6.11 and uses no 6.9–6.11-only QML API: the suite also passes
on PySide6 6.8.3 except for the dialog's accessible name (below). Worth knowing:

- `SuiIcon` tints image icons with `IconImage` from `QtQuick.Controls.impl`, the
  module Qt's own styles use; it is not a public API with compatibility promises,
  so a Qt upgrade re-checks it (the tests load it).
- `SuiToastHost` announces toasts with `Accessible.announce()` (Qt 6.8+), guarded.
- A dialog's accessible name comes from Qt: on 6.11 `T.Dialog` names its popup by
  `title` once accessibility is active (an assistive technology is running); Qt
  6.8.3 leaves it unnamed.
- Qt (through 6.11) reports no OS reduced-motion preference; the app sets
  `SuiTheme.reducedMotion`.

## Token pipeline

```
@scshafe/ui  ./tokens export (lib/tokens.js), cross-checked with src/tokens.ts
   │  tools/gen_tokens.py --refresh   (node reads the registry)
   ▼
tokens/sui-tokens.json                committed snapshot: version, file sha256,
   │                                   source commit, registry hash, tokens
   │  tools/gen_tokens.py
   ▼
src/scshafe_qt/qml/Scshafe/Ui/SuiTheme.qml   committed, header records the source
```

- `uv run python tools/gen_tokens.py --refresh [--from DIR]` re-reads the registry
  (DIR: a scshafe-ui checkout or an installed `node_modules/@scshafe/ui`; default
  `$SCSHAFE_UI_DIR`, then a sibling `../scshafe-ui`) and rewrites both files. Needs Node.
- `uv run python tools/gen_tokens.py` regenerates `SuiTheme.qml` from the snapshot.
- `uv run python tools/gen_tokens.py --check` fails if `SuiTheme.qml` or the qmldir
  `singleton` entry is stale, and, when the registry is reachable, if the snapshot is.
  CI has no scshafe-ui checkout, so there it checks QML against the snapshot and
  says it skipped the registry comparison (`--require-source` makes that a failure).
- `tests/test_tokens.py` checks every token in both themes against the snapshot
  (and the live registry when reachable).

Change a token in scshafe-ui, release it, then `--refresh` here in one commit.

## Development

Toolchain: [uv](https://docs.astral.sh/uv/) 0.12.21 (`[tool.uv] required-version`),
Python 3.14 (`.python-version`; uv uses a matching interpreter or downloads a managed
CPython 3.14), `uv.lock` committed (one lock for every supported Python). To run the
suite on another supported Python, `UV_PYTHON=3.12 uv run --frozen pytest` (uv rebuilds
`.venv` for that interpreter; plain `uv sync --frozen` returns it to 3.14), as CI does.

```sh
uv sync --frozen                                   # .venv with PySide6 + pytest-qt
uv run python tools/gen_tokens.py --check
uv run pytest                                      # offscreen; includes the QML TestCases
uv run python tests/qml_runner.py                  # QML TestCases alone (tests/qml/tst_*.qml)
SCSHAFE_QT_SCREENSHOTS=DIR uv run pytest tests/test_gallery.py   # gallery PNGs into DIR
uv build && uv run python tools/check_dist.py --smoke
```

Tests run under `QT_QPA_PLATFORM=offscreen` and `QT_QUICK_BACKEND=software` (set by
`tests/conftest.py` and `tests/qml_runner.py`). PySide6 wheels ship no
`qmltestrunner`; `tests/qml_runner.py` uses `PySide6.QtQuickTest`'s
`QUICK_TEST_MAIN_WITH_SETUP` with `scshafe_qt.register`. Any Qt or QML warning
fails a test (`qt_log_level_fail = "WARNING"`). The gallery screenshot test writes
its PNGs to `$SCSHAFE_QT_SCREENSHOTS` (else pytest's temporary directory); they are
for review and never committed.

On Ubuntu the wheels need these system libraries (CI installs them): `libegl1 libgl1
libxkbcommon0 libfontconfig1 libfreetype6 libx11-6 libglib2.0-0t64 libdbus-1-3` and a
font (`fonts-dejavu-core`). ICU is bundled.

To try a change in an app before a release, install this checkout into the app's
environment (`uv pip install -e <path>` in the app's venv) and never commit that.

## CI

`.github/workflows/ci.yml`, GitHub-hosted runners only, `contents: read`, actions pinned
by SHA: Linux (`ubuntu-latest`) on Python 3.12, 3.13 and 3.14 on every push and pull
request; macOS (`macos-latest`, Apple Silicon) on Python 3.12 and 3.14 on
`workflow_dispatch` and weekly, to keep macOS minutes low (release tags run
`publish.yml`, which verifies on both, on `.python-version`'s 3.14). The matrix sets
`UV_PYTHON`. Every job runs `uv sync --frozen`, the token check, the tests, `uv build` and the
distribution check (wheel carries the QML module, payload scan, install-and-load smoke).

## Releasing

The library standard's Python variant. `pyproject.toml` `version` is the authority: a
release commit bumps it and adds `## <x.y.z> — <date>` to `CHANGELOG.md`; after CI is
green on `main` the owning agent runs the dry run
(`gh workflow run publish.yml -f dry_run=true`, every check on Linux and macOS) and then
pushes the annotated tag `v<x.y.z>` on that commit. `.github/workflows/publish.yml` is
the only publisher. It refuses tags not on `main`, not annotated or not matching the
version, and lock files with non-registry sources; tests, builds and smoke-installs on
Linux and macOS; rebuilds the tag and requires the same bytes (hatchling builds are
reproducible); creates a **draft** Release with the wheel, sdist and `SHA256SUMS`;
downloads those assets back, checks their hashes and runs the payload check and the
install-and-load smoke on the downloaded wheel; and only then publishes the Release.
Every Release asset is the build job's own file (passed as a run artifact); the rebuild
only proves reproducibility. Last, the `pypi` job (environment `pypi`, deployable from
`v*` tags only; `id-token: write`, no stored token) checks the same files against the
build digests and the Release's `SHA256SUMS`, uploads them to PyPI by trusted publishing
(`pypa/gh-action-pypi-publish`, with attestations) and confirms PyPI serves those
digests. If that job fails, the Release stays; re-run the failed job. The dry run stops
before the Release and PyPI. Versions are never reused, moved or deleted, here or on
PyPI (PyPI never accepts a file name twice).

## License

MIT, see [LICENSE](https://github.com/scshafe/scshafe-qt/blob/main/LICENSE).
