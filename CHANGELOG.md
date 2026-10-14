# Changelog

All notable changes to `scshafe-qt` are recorded here. Versions follow
[SemVer](https://semver.org/). A release is the annotated tag `v<x.y.z>` on a
commit on `main` whose `pyproject.toml` version is `<x.y.z>`; released versions
are never deleted, replaced or reused.

## Unreleased

## 0.8.0 — 2026-10-13

Charts. Additive; no existing API changes.

- **`SuiChart`**: an x/y chart of `series` of kind `line`, `area`, `band`,
  `scatter` and `bars`, from columns (JS arrays or Python lists; null / NaN
  breaks a line, area or band). Lines, areas and bands are Qt Quick Shapes
  (`PathMultiline`, curve renderer), scatter a Canvas; no Qt Graphs, so the
  only dependency stays `PySide6-Essentials`. Dense lines are reduced to
  min/max per pixel column (100,000 points draw as ~1,500 vertices, spikes
  kept). Nice axes (automatic or `xMin` / `xMax` / `yMin` / `yMax`; `xNice`,
  `yNice`, `yIntegers`; `xFormat` / `yFormat`; `xLabel`, `yLabel`; grids),
  dashed `markers` with labels, a legend for two or more named series,
  series colours from the bucket palette or a `tone`.
  The readout shows each series' value at the x under the pointer (the point
  for scatter, the bin for bars). The chart is a Tab stop when it has data:
  Left/Right, PageUp/PageDown and Home/End step through x and announce the
  readout; Escape hides it (`inspectedX`, `readoutText`). Accessible: Chart
  named by `label`, described by a summary of the series (or `description`).
- **`SuiHistogram`**: a `SuiChart` that bins `values` into `binCount` bins
  (Sturges by default) or `binWidth` bins over `from`..`to`, with `density`
  shares, `bins` and a distribution summary as its description.
- `SuiTheme` NATIVE-ONLY: `chartLineWidth`, `chartFillAlpha`,
  `chartPointSize`, `chartTickLength`.
- `SuiIcon`: built-in `chart` icon.
- Gallery: a Charts page (pitch with a speaker band, onsets and a target;
  energy area; score by SNR over 1,500 takes; a histogram of 10,000
  durations); screenshot view `charts`.
- Tests: `tests/test_charts.py` (nice axes, limits and formats, integer
  ticks, line mapping and gaps, 100,000-point decimation keeping extremes,
  area and band polygons, colours by tone in both themes, scatter pixels,
  bars, markers and legend, no data, readout by pointer (series and scatter)
  and keyboard, the accessible summary, histogram binning, density and
  description), the shared component contract, QML TestCases, the
  plain-text payload and the wheel smoke scene (32 components).

## 0.7.0 — 2026-10-13

Table. Additive; no existing API changes.

- **`SuiTable`**: a sortable, virtualised data table over `rows` (a JS array
  of objects, or a Python list of dicts) and `columns` (`key`, `title`,
  `width`, `minWidth`, `maxWidth`, `align`, `sortable`, `resizable`,
  `format(value, row)`, `tone(value, row)`). 10,000 rows: about 80 ms to
  assign from Python, about 20 ms to sort, about 3 ms a frame to scroll
  (software renderer), 44 delegates in a 1000 x 700 view.
  - Sorting by header click or keyboard, or `sortKey` / `sortOrder` /
    `sortBy()`: numbers numerically, text case-insensitively, empty values
    last, stable.
  - Columns resize by dragging a header edge or Ctrl+Left/Right on a focused
    header; double-click resets; `columnWidths` and `columnResized(key,
    width)` persist them; the last column fills the view.
  - Selection (`selectionMode` single / multiple / none): click, Ctrl+click,
    Shift+click, and the keyboard (arrows, PageUp/PageDown, Home/End, Shift
    ranges, Ctrl moves, Space toggles, Ctrl+A); `selectedRows`, `currentRow`,
    `select()`, `selectAll()`, `clearSelection()`; `rowKey` keeps the
    selection when `rows` is replaced. Enter / double-click emit
    `activated(row)`. Row numbers are indices into `rows`.
  - Focus: the header and the body are one Tab stop each, with the
    keyboard-only ring; `forceActiveFocus()` focuses the body.
  - Accessible: Table named by `label`, ColumnHeaders described by their
    sort, rows as ListItems named "Title: value, ..." with their selection.
- Internal `SuiScrollBar` (themed `T.ScrollBar`).
- `SuiTheme` NATIVE-ONLY: `tableRowHeight`, `tableColumnWidth`,
  `tableMinColumnWidth`, `tableMaxColumnWidth`, `scrollBarSize`.
- `SuiIcon`: built-in `table` icon.
- Gallery: a Table page with 10,000 made-up takes; screenshot view `table`.
- Tests: `tests/test_table.py` (virtualisation over 10,000 rows, sort speed
  and semantics, header sorting, pointer and keyboard selection, activation,
  selection across sorts and new rows, column resizing by drag, keyboard and
  reset, clamping and fill, horizontal scrolling, cell format, tone and
  plain text, accessibility, the placeholder), the shared component
  contract, a QML TestCase, the plain-text payload and the wheel smoke scene
  (30 components).

## 0.6.0 — 2026-10-13

Level meter. Additive; no existing API changes.

- **`SuiLevelMeter`**: a live level in the meter's unit (`from`..`to`,
  default -60..0 dB; -Infinity is silence), revealing ok / warn / danger
  zones (`warnLevel`, `dangerLevel`), drawn as it arrives (no smoothing, no
  animation). Peak hold (`peak`, `SuiTheme.meterPeakHold`), a clip lamp that
  latches at `clipLevel` (`clipped`, `reset()`), a tick scale (`scaleStep` or
  automatic without collisions) and `valueText`. The pinned-level marker
  (`pinnedLevel`, `pinnedLabel`) is the app's; with `pinEditable` it is a
  Slider the user moves by keyboard, drag or click, emitting
  `pinMoved(level)`. Horizontal or vertical. Accessible: a ProgressBar named
  by `label` with the level as its value and the peak, pin and clipping in
  its description; the editable pin is a Slider.
- `SuiTheme` NATIVE-ONLY: `meterThickness`, `meterPinSize`, `meterPeakHold`.
- Gallery: a Level meter section on the Controls page (a target marker, an
  editable gate threshold, a stereo pair; "Simulate input" drives them).
- Tests: `tests/test_meter.py` (fill and range, zones in both themes, value
  text and silence, peak hold timing, clip latch and reset, accessibility,
  fixed and editable pins by keyboard and pointer, the scale, vertical
  meters, nothing animating), the shared component contract, a QML
  TestCase, the plain-text payload and the wheel smoke scene (29 components).

## 0.5.0 — 2026-10-13

Progress. Additive; no existing API changes.

- **`SuiProgressBar`**: determinate progress (Qt's ProgressBar: `from`, `to`,
  `value`, `position`) with `label` above the bar and `valueText` beside it
  (the percentage by default; tabular digits), `showLabel` / `showValue`,
  and `tone` (`accent`, `ok`, `warn`, `danger`). `cancellable` adds a cancel
  button beside the bar, a Tab stop named `cancelLabel` ("Cancel <label>"),
  that emits `cancelRequested()`. The fill moves on `SuiTheme.duration`
  (instant under reduced motion). Accessible: ProgressBar named by `label`,
  described by `valueText`, with Qt's value interface. `indeterminate` is
  not drawn.
- `SuiTheme` NATIVE-ONLY: `progressHeight`.
- Gallery: a Progress section on the Controls page, with an export you can
  start and cancel.
- Tests: `tests/test_progress.py` (range and fill, motion and reduced
  motion, value text, tones in both themes, cancel by keyboard, Tab order,
  accessibility), the shared component contract, a QML TestCase, the
  plain-text payload and the wheel smoke scene (28 components).

## 0.4.0 — 2026-10-13

Form controls. Additive; no existing API changes.

- **`SuiCheckBox`**: a labelled checkbox (the web's CheckboxField) with
  optional `description` help text, `tristate`, and `label` for a box without
  visible text.
- **`SuiSwitch`**: an on/off switch with `description`; the thumb slides on
  `SuiTheme.duration` (instant under reduced motion) and can be dragged.
- **`SuiRadioButton`**: one choice of an exclusive group (same parent or a
  `ButtonGroup`). The group is one Tab stop (its checked button, else the
  first) and the arrow keys move and check, wrapping, as browsers do.
- **`SuiSelect`**: a drop-down (`ComboBox`) over strings or objects
  (`textRole` / `valueRole`), `placeholderText` for no choice, as wide as its
  widest option; keyboard, type-ahead and pointer choice; options are
  ListItems.
- **`SuiSlider`**: horizontal or vertical; arrows step (1 % of the range
  without `stepSize`), PageUp/PageDown ten steps, Home/End the ends, each
  emitting `moved()`; `unit`, `decimals` and `showValue` draw `valueText`
  beside the track (in a fixed `valueWidth`).
- Every control is keyboard-focusable with the keyboard-only ring, has its
  accessible role and name (`SuiSelect` and `SuiSlider` warn without a
  `label`) and animates only on `SuiTheme.duration`.
- `SuiTheme` NATIVE-ONLY: `indicatorSize`, `checkboxRadius`, `switchWidth`,
  `switchHeight`, `switchThumbSize`, `sliderTrackHeight`, `sliderHandleSize`,
  `menuMaxHeight`, and `accentForeground` (marks on an accent fill; 4.5:1 or
  more on the accent and its hover colour in both themes, tested).
- `SuiIcon`: built-in `text` and `sliders` icons.
- Internal `SuiToggleLabel` lays out a toggle's label and help text.
- Gallery: the pages are now Mail, Typography and Controls (every form
  control); screenshot views `type` and `controls`.
- Tests: `tests/test_forms.py` (keyboard, pointer, tristate, the radio
  group's Tab stop and arrows, the select popup with string and object
  models, slider steps, vertical sliders, accessibility, colours in both
  themes, reduced motion), the shared component contract, QML TestCases, the
  plain-text payload and the wheel smoke scene (27 components).

## 0.3.0 — 2026-10-13

Typography: the type scale as a component. Additive; no existing API changes.

- **`SuiText`**: a `Text` in one of ten type styles, `variant` `display`,
  `title`, `heading`, `subheading`, `section`, `label`, `body` (default),
  `caption`, `small`, `code`. `title` / `heading` / `subheading` / `section`
  are the web library's Title h1 / h2 / h3 / h4-h6, `label` its Label and
  `caption` its Description. `tone` overrides the colour (`default`, `strong`,
  `muted`, `accent`, a status tone or a bucket); `tabular` sets equal-width
  digits; the line height applies to wrapped text. Heading variants are
  accessible Headings, the others StaticText; caller text is plain text.
- `SuiTheme`: NATIVE-ONLY text styles generated from `TEXT_STYLES` in
  `tools/gen_tokens.py`: `textStyles` (size and weight from the type scale,
  tracking, caps, leading, default tone, heading, mono), `textVariants`,
  `textStyle(variant)` and `textColor(tone)`.
- Reduced motion: `SuiTheme.reducedMotion` (since 0.1.0) is the app's switch;
  the README now shows setting it from Python. Every animation, including the
  new components', runs on `SuiTheme.duration`.
- Gallery: pages in the sidebar's first section (the mail sample; text and
  controls, with every type style and tone); the inspector's headings are
  `SuiText`. `examples/gallery.py --screenshot` adds the `controls` view.
- Tests: `tests/test_typography.py` (styles against the generator, the web
  mapping, tones in both themes, leading, tabular digits, literal markup),
  the shared component contract, a QML TestCase, the plain-text payload scene
  and the wheel smoke scene.

## 0.2.0 — 2026-10-06

Python 3.12 and 3.13 supported. No change to the components, the QML module
or the Python API: the wheel's code is that of 0.1.2.

- **`requires-python = ">=3.12"`** (was `>=3.14,<3.15`), with classifiers for
  3.12, 3.13 and 3.14. The code used nothing newer than 3.12: every module
  already had `from __future__ import annotations`, and the stdlib and syntax
  in use parse and pass the suite on 3.12. `PySide6-Essentials` 6.11.x wheels
  are abi3 for CPython 3.10+ (they declare `<3.15`, which bounds the usable
  range in practice); the dependency range is unchanged (`>=6.11.2,<6.12`).
- `uv.lock` regenerated for `>=3.12`: the same package versions.
- CI: Linux on 3.12, 3.13 and 3.14 on every push and pull request; macOS on
  3.12 and 3.14 on dispatch and weekly (`UV_PYTHON` per matrix entry).
  Development and `publish.yml` keep `.python-version` (3.14).
- A minor bump because the supported range widened: apps pinned
  `scshafe-qt>=0.1.2,<0.2` stay on 0.1.2 until they widen the pin.

## 0.1.2 — 2026-10-05

Published to PyPI; docs. No library change (the wheel's code and QML module
are those of 0.1.1).

- **On PyPI:** `pip install scshafe-qt` / `uv add scshafe-qt`. `publish.yml`
  gains a `pypi` job: after the GitHub Release is published it uploads the
  build job's wheel and sdist (a run artifact; the Release carries the same
  files) by trusted publishing (OIDC, environment `pypi`, `v*` tags only,
  PEP 740 attestations), then checks that PyPI serves the verified digests.
- Package metadata for PyPI: dropped the `Private :: Do Not Upload`
  classifier (PyPI refuses it), the misleading `Framework :: Pytest` and the
  `License ::` classifier (the license is the PEP 639 expression `MIT`); added
  keywords, status, audience, OS and topic classifiers and project URLs
  (homepage, docs, issues, releases).
- README: install from PyPI, or from a Release URL as a fallback (the
  repository is public: Release downloads need no token); the CI token-check
  note no longer calls `@scshafe/ui` private.
## 0.1.1 — 2026-10-02

Security release.

- **Caller text is plain text.** Every `Text` in `Scshafe.Ui` sets
  `textFormat: Text.PlainText` (25 elements, 14 components). With Qt's default
  `AutoText`, a caller string that looked like HTML rendered as rich text and
  fetched remote images: a mail subject with `<img src=…>` made Qt request it,
  a tracking beacon (found by mailroom-desktop's review). No component needs
  rich text, so there is no opt-in. `tests/test_plain_text.py` proves it with
  a counting HTTP server (0.1.0: fetched; 0.1.1: zero requests) and fails any
  new `Text` without the line.
- Token snapshot from `@scshafe/ui` 0.4.1: the registry is unchanged (same
  sha256); only the recorded source version moves.
## 0.1.0 — 2026-10-01

First release.

- Releases: `.github/workflows/publish.yml` (the library standard's Python
  variant): an annotated `v<x.y.z>` tag on `main` matching the version; tests,
  build and install-and-load smoke on Linux and macOS; a reproducible rebuild
  must match; a draft GitHub Release with the wheel, sdist and `SHA256SUMS`,
  published only after the assets downloaded back pass the payload check and
  smoke. `tools/check_dist.py --dist DIR`. CI runs macOS by hand and weekly
  (tags go through `publish.yml`).
- Tests ignore one headless-only Qt warning: on macOS the offscreen platform's
  theme font "Sans Serif" doesn't exist; any other warning still fails.
- Qt 6.11: depend on `PySide6-Essentials>=6.11.2,<6.12` (was `>=6.8.3,<6.9`);
  open-source Qt patches track the current minor, so the library follows it
  (6.12 when PySide6 6.12 ships). Python 3.14 (`.python-version`,
  `requires-python >=3.14,<3.15`); the 6.11 wheels are abi3 (CPython 3.10+).
- Q1 components (QtQuick.Templates, themed from `SuiTheme`, light and dark,
  keyboard-focusable with a keyboard-only focus ring, accessible roles and
  names, animations on `SuiTheme.duration`): `SuiAppShell` (resizable,
  keyboard-operable splitters; collapsible inspector and sidebar),
  `SuiSidebarList` / `SuiSidebarItem` (counts, ok/held/failing dots, sections),
  `SuiList` / `SuiListRow` (single selection; `j`/`k`/arrow hooks as signals),
  `SuiChip`, `SuiBadge`, `SuiIconButton` (required `label`), `SuiTextField`,
  `SuiSearchField` (`/` focus hook, Escape clears), `SuiEmptyState`, `SuiBanner`,
  `SuiToast` / `SuiToastHost`, `SuiDialog` / `SuiSheet` (focus trap, Escape,
  focus return), `SuiTrail`, `SuiShortcutOverlay` (`?`), `SuiIcon` (built-in
  vector icons), `SuiKbd`; internal `SuiFocusRing`, `SuiSplitHandle`.
- `SuiTheme` NATIVE-ONLY tokens (generator section, not in the registry):
  eight bucket tones `bucket1`…`bucket8` (contrast-checked: text >= 4.5:1 on
  the chip over every surface and overlay, base >= 3:1, in both themes), tone
  helpers, control metrics and layout defaults, `monoFamily` per platform.
- `examples/gallery.py`: every component in one window; `--screenshot DIR`.
- Tests: per-component render (both themes), accessible role and name,
  keyboard focus ring (pixel), pointer focus without ring, focus order, list
  and sidebar keyboard navigation, shell resizing, dialog focus trap and
  return, toasts, no colour literals, every animation on `SuiTheme.duration`
  (static and at runtime), token parity and contrast, gallery screenshots in
  both themes; Qt warnings fail tests. `tools/check_dist.py` checks every
  module file is in the wheel and listed in `qmldir`, and the smoke builds
  every public component from the installed wheel.
- Q0 scaffold: package `scshafe_qt` (hatchling, uv, Python 3.13) depending on
  `PySide6-Essentials>=6.8.3,<6.9` (Qt 6.8 LTS), with the QML module
  `Scshafe.Ui` and `scshafe_qt.register(engine)` / `qml_import_path()`.
- `SuiTheme` singleton generated from the `@scshafe/ui` 0.3.1 token registry
  (62 tokens, light and dark): `mode` system/light/dark, `reducedMotion`, plus
  native focus-ring and type-scale values; `tools/gen_tokens.py --check`.
- `SuiButton`: themed, keyboard-focusable, keyboard-only focus ring,
  accessible role and name.
- Tests (pytest-qt and QtQuickTest, offscreen), CI on Linux (every push) and
  macOS (tags, dispatch, weekly), distribution check.
