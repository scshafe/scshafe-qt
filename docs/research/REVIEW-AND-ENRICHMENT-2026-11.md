# scshafe-qt: project review and enrichment ideas (November 2026)

Status: **proposed; nothing here is decided.** Written 2026-11-09 by the
project's agent (Claude Fable 5.2) at the owner's request. The owner picks
from it; each picked item becomes its own design note or PR.

Reviewed: `main` at `b7090a1` (release 0.10.0). No code changed in this PR.

## 1. Summary

scshafe-qt is in good health as a piece of engineering and behind as a
product. The release chain, the test suite and the accessibility contract are
the strongest parts. The weakest parts are all about staying in step with the
things around it:

1. **The token snapshot is five scshafe-ui releases old.** It records
   `@scshafe/ui` 0.4.1 (62 tokens); scshafe-ui is at 0.9.0 (77 tokens) and has
   changed the corner radii. Native apps no longer look like the web and iOS
   apps, and nothing in CI can notice.
2. **The main consumer still carries stand-ins for the two biggest
   components.** voice-lab's desktop app uses its own `SuiTable` (389 lines)
   and `SuiChart` (348 lines) in place of the library's, because 0.7.0 and
   0.8.0 shipped without the API its screens need. It also has a local
   waveform for the studio, and raw Qt templates for menus, popovers, tooltips
   and compact selects.
3. **A family of state bugs.** Several components assign to their own public
   properties from key handlers, which silently removes the app's binding
   (slider, radio button, shell panes, level-meter pin). Clearing a search
   field does not emit `textEdited`, so the documented wiring leaves a stale
   query.
4. **PySide6 6.12.0 has been on PyPI since 2026-10-08**; the library still
   caps at `<6.12`, and the README says 6.12 comes "when PySide6 6.12 ships".
5. **scshafe-qt does not accept agent requests.** voice-lab's agent tried to
   file its 0.10.0 needs and the broker refused, so the owner had to relay
   them by hand.

The top five ideas, in order (section 4 has all of them):

1. Refresh the tokens to scshafe-ui 0.9.0 and add a drift guard.
2. A 0.10.1 fix release for the state bugs and chart and table edge cases.
3. Give `SuiTable` and `SuiChart` what voice-lab needs, and retire its
   stand-ins.
4. Open the request channel, and add a parity matrix across the three
   libraries.
5. The missing primitives: tooltip, menu, popover, tabs, text area, a public
   scroll view, and button and select variants.

### How this was done

- I read `AGENTS.md`, `README.md`, `CHANGELOG.md`, `docs/design/0.10.0.md`,
  `pyproject.toml`, `dev.toml`, both workflows, the test infrastructure and
  the tools.
- Four background readers each read one area in full: two halves of the QML
  module, voice-lab (public, at `b8d36c5`, 2026-11-04) and the two sibling
  libraries (scshafe-ui at `ef069ce`, scshafe-ios at `18ddf26`). I checked
  their main claims against the code before using them.
- Items marked **probed** were reproduced by a reader with a throwaway
  offscreen script outside the repository. Items marked **unverified** were
  not confirmed. Everything else is from reading the code at the cited line.
- I ran the suite, the token check and `pyside6-qmllint` in a separate
  worktree.

Limits:

- I could not see `mailroom-desktop` or `scshafe-dev` (private to this agent),
  the capture clients, or the native UI plan (Q0 to Q2) that `AGENTS.md` and
  `dev.toml` refer to. voice-lab's `apps/desktop` is the only consumer I could
  read. Its `apps/mirror` is stdlib-only and `apps/macos` is Swift.
- Nothing was tested on a real display, on macOS, or with a screen reader.

## 2. Where the project stands

### 2.1 Grades

| Area | Grade | One line |
| --- | --- | --- |
| Release and supply chain | A | Reproducible builds, install-back, trusted publishing; 10 releases, all on PyPI |
| Test and verify health | A- | 530 pass in 75 s, warnings fail tests; some gates are loose |
| Accessibility contract | B+ | Enforced for role, name and ring; gaps in bindings, RTL, scaling, contrast |
| Core controls (buttons, forms, lists, dialogs) | B | Careful work; a cluster of binding and edge-case bugs |
| Data components (table, chart, waveform, meter) | B- | Work at 10k rows; do not fit the consumer; edge-case bugs |
| Token pipeline | C | Well built, but the snapshot is stale and CI cannot see drift |
| Parity with web and iOS | C- | No matrix; vocabularies differ; tokens differ |
| Consumer fit (voice-lab) | C+ | 13 of 35 components unused; 737 lines of stand-ins; raw templates in 10 files |
| Docs | B- | Accurate and thorough, but one 662-line README; no roadmap or decision log here |
| Developer experience | B- | Simple and fast; no lint, no type info, no test kit, no request channel |
| Localisation and internationalisation | D | No `qsTr`, about 25 fixed English strings, no RTL, no locale numbers |

### 2.2 What is done

- **The plan as the repository records it is complete.** Q0 (scaffold), Q1
  (components) and Q2 (releases) are all in `CHANGELOG.md`. The two voice-lab
  rounds (0.3.0 to 0.9.0, then 0.10.0) are released.
- **35 public components** and 4 internal ones in `qmldir`, each with a spec
  in `tests/test_components.py`, a QML `TestCase`, a gallery place, a README
  row and a place in the wheel smoke scene.
- **Verify is green.** In the review worktree: `gen_tokens.py --check` passes,
  `pytest` gives 530 passed and 1 skipped in 75 s. The last 12 CI runs are
  green, including the weekly macOS run of 2026-11-09.
- **Releases.** Tags `v0.1.0` to `v0.10.0`; PyPI has 0.1.2 to 0.10.0. The
  publish workflow refuses tags that are not on `main`, rebuilds and compares
  bytes, installs back from the Release, and uses no stored token.
- **Security posture.** Caller text is plain text everywhere, proven by a
  counting HTTP server (`tests/test_plain_text.py`). The one markup path
  (`SuiInfoTip`) is sanitised and tested with the same beacon.

### 2.3 What is half-built

- **`SuiTable` and `SuiChart` for their consumer.** Released, tested, and not
  used by the app they were built for. voice-lab's `PHASE-4-LOG.md` lists what
  is missing (section 2.6). The owner decided on 2026-10-20 to keep the
  stand-ins until the library catches up; nothing here has been scheduled.
- **`SuiWaveform` for the studio.** Used once, on the prompts screen.
  voice-lab's studio has its own `StudioWaveform.qml` (216 lines) because the
  library's has no zoomed view, no live recording bins and no dB scale.
- **Reduced motion.** `SuiTheme.reducedMotion` works and is enforced, but the
  app must set it, and voice-lab never does: there is no write to
  `reducedMotion` or `mode` anywhere in its desktop source. In practice the
  OS setting is ignored.
- **The library standard's Python variant.** `AGENTS.md:3-4` says it is "to be
  amended". `dev.toml:9-12` adopts the repository as a `tool` because
  scshafe-dev has no Python library kind. `[skills] selected = []` is a
  recorded gap (`dev.toml:20-21`).
- **Six open asks from voice-lab** (`docs/design/INFO-TIPS.md:231-237` there):
  a sidebar toggle beside the window buttons that stays while the sidebar is
  hidden, a translucent sidebar, a plain muted count, the funnel as a chevron
  on the magnifier, a toolbar group, and icons for recording and measuring.
  None is tracked in this repository.

### 2.4 What has drifted

| What | Where | Detail |
| --- | --- | --- |
| Token snapshot | `tokens/sui-tokens.json:3-9` | Records `@scshafe/ui` 0.4.1, commit `8a0c314`. scshafe-ui `package.json:3` is 0.9.0 |
| Radii | snapshot vs scshafe-ui `src/tokens.ts:163-168` | `radius-sm` 6 → 8, `radius-md` 8 → 12, `radius-lg` 10 → 16; `radius-xl` 20 and `radius-pill` 999 are new |
| New tokens | same | 15 new: two radii, `ease`, `ease-spring`, and 11 glass tokens in a new `material` category |
| Registry path | `tokens/sui-tokens.json:6` | Records `lib/tokens.js`; scshafe-ui no longer commits `lib/`, and scshafe-ios reads `src/tokens.ts` |
| Qt 6.12 | `README.md:9-12`, `pyproject.toml:36` | "6.12 comes when PySide6 6.12 ships": 6.12.0 shipped 2026-10-08. 6.11.3 shipped 2026-10-26 |
| "No 6.9+ API" | `README.md:557-558` vs `SuiAppShell.qml:56,262` | The shell now uses `SafeArea`, which I believe is Qt 6.9 or later (unverified against 6.8.3) |
| Sizes "never literals" | `AGENTS.md:19-21`, `docs/design/0.10.0.md:9-10` | Implicit-size literals in 10 components, starting with the pattern itself: `SuiButton.qml:57-58` (64 x 28, although `SuiTheme.controlHeight` is 28) |
| Alpha literals | `SuiButton.qml:63-75` and 8 other files | 22 literal alphas such as `0.56`, `0.14`, `0.08`; the colour rule (`tests/test_rules.py`) does not look at them |
| Enter on buttons | `README.md:96`, `SuiButton.qml:6` | Both say Space, Enter and Return activate. There is no key handler, and Return did not click offscreen (**probed**); the test covers Space only |
| "Skip disabled" | `README.md:93` vs `SuiSidebarList.qml:33-43` | Holds for JS arrays and `ListModel`, not for a `QAbstractItemModel` |
| Search wiring | `README.md` list-header example, `docs/design/0.10.0.md:166` | `onTextEdited` misses clears (section 2.5) |
| Linear meter | `README.md:261-262` vs `SuiLevelMeter.qml:45-46` | `from: 0; to: 1` keeps the dB zone levels (-12, -3), so the whole bar is red (**probed**) |
| Install example | `README.md:49-55` | Still shows `v0.8.0` URLs |
| CI comment | `.github/workflows/ci.yml:3-6` | The macOS policy "dates from when the repository was private" |
| Old test name | `tests/test_rules.py:50-56` | `test_module_has_the_q1_components` checks 19 of 35 components |
| Performance claims | `README.md:113` vs `tests/test_table.py:147` | "Sort in ~20 ms" is true (16 ms **probed**) but guarded at 500 ms. Assign is guarded at 2 s against a claimed 80 ms. The 100,000-point chart test allows 3 s |

### 2.5 Bugs and risks found

These are for a fix release; none is fixed here. Ordered by how likely a
consumer is to hit them.

**Components overwrite the app's bindings.** A JS assignment to a property
removes the binding the app put there. Pointer paths mostly avoid this; key
paths do not.

- `SuiSlider.qml:44`: with `value: backend.gain`, one arrow key stops the
  slider following `gain` (**probed**).
- `SuiRadioButton.qml:81`: arrow keys remove a `checked:` binding (**probed**).
- `SuiAppShell.qml:291,345`: Enter on a splitter removes
  `inspectorOpen: toggle.checked`, which is the file's own header example
  (**probed**).
- `SuiLevelMeter.qml:331`: moving the pin assigns `pinnedLevel` (**probed**).
  `SuiWaveform` is the counter-example: it never assigns its trim.
- By reading: `SuiBanner.qml:31` (`open`), `SuiSearchField.qml:32` (`text`),
  `SuiListHeader.qml:90,101,112` (`activeFilters`).

The module has no stated rule for controlled versus uncontrolled state. That
is a design decision (section 5).

**Other behaviour bugs.**

- `SuiSearchField.qml:29-34`: Escape or the clear button emits only
  `cleared()`, not `textEdited()` (**probed**).
- `SuiSlider.qml:24`: `decimals` assumes a power-of-ten step. `stepSize: 0.25`
  shows "0.3"; 2.5 shows "3" (**probed**).
- `SuiShortcutOverlay.qml:30`: `Array.isArray` is false for a Python list, so
  the overlay is empty (**probed**). `SuiListHeader.qml:66` uses `Array.from`
  and works. The module has three different array checks.
- `SuiList.qml:36-49`: Enter activates a disabled row (**probed**).
- `SuiAppShell.qml:97-102`: replacing a slot leaves the old item in the pane
  (**probed**).
- `SuiAppShell.qml:291`: Enter on the sidebar splitter hides the sidebar even
  when it is not hideable and has no shortcut, so the keyboard has no way back.
- `SuiDialog.qml:39-42`: no height clamp or scrolling for tall content.
- `SuiSheet.qml:17-26`: `Qt.TopEdge` is laid out as a left panel with no slide.
- `SuiListHeader.qml:56`: an unknown key in `activeFilters` inflates the badge
  (**probed**).
- `SuiText.qml:31`: the read-only property `style` hides `Text.style`
  (qmllint `property-override`), so a caller cannot use Qt's outline or raised
  text styles.
- Two search fields or two list headers in one window have ambiguous
  shortcuts; by Qt's rule neither fires (**unverified**).

**Table.**

- `SuiTable.qml:589`: the body's model is the row count, so replacing `rows`
  with a different length resets the scroll position to the top (**probed**).
  Every filter or append jumps the view.
- `SuiTable.qml:213-222`: numeric strings sort as text ("10" before "9"),
  accented text sorts after "z", and there is no per-column comparator
  (**probed**).
- `SuiTable.qml:265-269`: rows without the `rowKey` field all share the key
  "undefined", so a selection moves to another row (**probed**).
- Scale (**probed**, software renderer): 100,000 rows take 584 ms to assign,
  196 ms to sort and 984 ms to change one cell, because every update converts,
  sorts and re-keys all rows. The practical cap is 10,000 to 20,000 rows.

**Chart and histogram.**

- `SuiChart.qml:383-384`: `Math.min.apply(null, finite)` throws a `RangeError`
  on a 1,000,000-point series, and the accessible description goes stale
  (**probed**).
- `SuiChart.qml:153-180`: a one-sided limit beyond the data (`yMin: 10` with
  data 1 to 3) gives a NaN axis and a blank plot (**probed**).
- `SuiChart.qml:557-563`: a gap in only one edge of a band draws a wrong
  polygon (**probed**).
- A scatter-only chart announces only the x value from the keyboard
  (**probed**).
- Scale (**probed**): 100,000 points take about 1 s to draw and 1.7 s per
  resize step on the software renderer. Scatter is not decimated.
- `SuiHistogram.qml:72-79`: the bin count is unbounded, and `share` divides by
  all values, including those outside `from`..`to` (**probed**: shares sum to
  0.75).

**Waveform, meter, icons.**

- `SuiWaveform.qml:211`: new `bins` reset the interaction, so live updates
  cancel a drag. This is one reason voice-lab's studio cannot use it.
- `SuiWaveform.qml:127,248`: End seeks to `frameCount`, one past the last
  frame (**probed**).
- `SuiLevelMeter.qml:92`: a NaN level shows "∞ dB" over a silent bar
  (**probed**).
- `SuiIcon.qml:24-59`: the 33-path table is built per instance (**probed**).
  voice-lab has 180 `SuiText`, 91 `SuiButton` and many icons per window.
- HiDPI: nothing sets a device pixel ratio on the Canvas items; whether the
  waveform draws at full resolution at 2x is **unverified**.

**Architecture and API risks.**

- **Pure QML and JS, with `property var` everywhere.** That keeps the Python
  API to three names (`src/scshafe_qt/__init__.py:27`) and the wheel pure, and
  it is why 35 components exist after six weeks. The cost: no incremental
  model updates, no type information for consumers, and scale limits above.
- **No lint.** `pyside6-qmllint` ships in the wheel already. Over the module
  it reports 113 `unqualified` warnings, 7 `missing-property`, 1
  `property-override` and 1 unused import. No `ruff`, no type check, no
  `py.typed`.
- **One private Qt API.** `SuiIcon.qml:12` imports `QtQuick.Controls.impl` for
  `IconImage`. The README owns up to it; it is the main risk in a Qt upgrade.
- **API vocabulary is not uniform.** Visible text is `text`, `title`,
  `description` or `label` depending on the component. Tones are four
  different sets. `label` is required, warned, silent or absent. `from`/`to`
  mean a value range on the meter and a bin range on the histogram. These are
  cheap to fix before 1.0 and expensive after.
- **Version cap.** The `<6.12` cap means an app cannot move to Qt 6.12 until
  this library does, and the library has one maintainer session at a time.
- **Loose gates.** `tests/test_qml.py:28` and `tools/check_dist.py:123` check
  counts (`>= 35`, `== 35`), not names. The payload scan covers only GitHub
  token shapes and PEM headers.
- **CI runs twice per PR.** `ci.yml:8-10` triggers on every branch push and on
  `pull_request`; the run list shows both for each PR.

**Accessibility gaps against the contract.**

- No right-to-left support: no `LayoutMirroring` anywhere, and
  `SuiDialog.qml:149` forces left-to-right.
- No font scaling: every size is a `font.pixelSize` token. scshafe-ios maps
  the same ten text roles to Dynamic Type.
- No high-contrast theme, although Qt 6.10 exposes `contrastPreference`.
- `SuiInfoTip.qml:221`: links in the body cannot be reached by keyboard.
- `SuiShortcutOverlay.qml:71-81`: overflow cannot be scrolled by keyboard.
- `SuiCheckBox.qml:41`: the partial state reads as unchecked.
- List rows never take focus and nothing marks the active row; what a screen
  reader announces on a move is **unverified**.
- About 25 accessible strings are fixed English with no property to override
  them, for example `SuiSidebarItem.qml:25-27`, `SuiTable.qml:476-477`,
  `SuiChart.qml:385-389`, `SuiToast.qml:98`, `SuiBanner.qml:94`. There is no
  `qsTr` in the module.

### 2.6 The consumer's view (voice-lab desktop)

Pins: `scshafe-qt>=0.10.0,<0.11` and `PySide6-Essentials>=6.11.2,<6.12`
(`apps/desktop/pyproject.toml:24-25` there). Python surface used:
`scshafe_qt.register(engine)` only.

**Used heavily:** `SuiText` (180), `SuiButton` (91), `SuiChip` (27),
`SuiTextField` (14), `SuiBanner` (13), `SuiDialog` (9), and 422 `SuiTheme`
references.

**Not used at all:** `SuiBadge`, `SuiHistogram`, `SuiIcon`, `SuiList`,
`SuiListRow`, `SuiRadioButton`, `SuiSidebarItem`, `SuiSwitch`, `SuiTrail`,
and the library's own `SuiChart` and `SuiTable`.

**What the stand-ins have that the library lacks.**

| Stand-in | Missing in the library |
| --- | --- |
| `StandIn/SuiTable.qml` | Pinned columns; cell kinds `chip`, `stack`, `link`, `actions`; `cellActivated`, `actionTriggered`; `sortRequested` for a server-side sort; `endReached` paging; a `QAbstractListModel` source |
| `StandIn/SuiChart.qml` | Stacked panels on a shared x axis; a `log2` scale; a compact sparkline; per-point `id` and `activated(id)`; zones and text layers; right-hand ticks |
| `StudioWaveform.qml` | A zoomed view, live recording bins, a dB display scale |
| `Controls/SelectField.qml` | A captioned, controlled select (`value`, `valueSelected`) |
| `Controls/InfoTip.qml` | Plain text as the default format (tips hold server strings), and `Keys.onShortcutOverride` so Space and Escape beat window shortcuts |

**Raw Qt templates the app styles by hand** (10 files): a compact 24 px combo
box, popovers, a tooltip, menus, scroll bars (the library's `SuiScrollBar` is
internal), row delegates, clickable chips, a link, a round record button.
Local helpers that look like library candidates: `Card`, `ScreenHeader`,
`ScreenPage`, a legend swatch, a button with a key hint, a chip row with a
"+N" overflow.

**Other frictions.**

- About 132 bare pixel literals in the app: the theme's size tokens do not
  cover what screens need.
- Test helpers re-implemented: a visual-tree `find` (because `findChildren`
  misses delegates), info-tip helpers that depend on the library's internal
  `objectName`s, and engine setup repeated by hand. `tests/conftest.py` here
  has the same helpers and does not ship.
- Packaging: the macOS PyInstaller bundle needs
  `collect_data_files("scshafe_qt")`. The library ships no hook.
- The `SuiInfoTip` default (styled text) is the opposite of what the consumer
  wanted for server strings. The sanitiser makes it safe, but the wrapper
  shows the default surprised its first user.

### 2.7 What blocks the owner from getting value today

1. **Native apps look one design generation behind the web and iOS apps**
   (radii, and no glass tokens) and will stay so until someone refreshes by
   hand.
2. **The owner is the message bus.** voice-lab's needs reach this repository
   only when the owner relays them. Six asks are waiting.
3. **Two of the three most expensive components earn nothing yet**, because
   voice-lab cannot swap its stand-ins for them.
4. **No roadmap or decision log lives here.** The plan that named Q0 to Q2 is
   elsewhere; `docs/` holds one design note. A session starting cold has to
   reconstruct priorities from the changelog and a memory note.

## 3. Parity with scshafe-ui and scshafe-ios

**Tokens.** scshafe-ios (pre-0.1) generates from `@scshafe/ui` 0.9.0 with a
port of this repository's `gen_tokens.py` and the same snapshot schema. So
iOS is current and Qt is not. Its design doc already recommends the fix:
scshafe-ui publishes the snapshot JSON as a release artefact and both native
libraries read it, with a weekly drift job (`docs/design.md` "Owner
decisions" §2 there; not yet implemented anywhere).

**Native-only tokens.** Qt has about 100 native-only properties against 62
registry tokens. The eight bucket colours and the tone amounts are identical
on iOS (copied verbatim). The ten text roles share names but not values: Qt
uses fixed pixels with caps and tracking; iOS uses Dynamic Type without
either. Nothing compares the two, and nothing compares Qt's control metrics
with the web's `components.css`, from which they were copied by hand.

**Components the web has and Qt does not:** tabs (`Tab`, `FocusTabs`),
`Popover`, `HoverCard`, `Tooltip` (Qt has only the info tip), `ContextMenu`
and `MoreActionsMenu`, `Card` and `MetricCard`, `TextAreaField`, `Copyable`,
`Identifier`, `Status`, markdown content and editor, `EditableName`,
`MessageBubble`, the layout primitives, a column menu for the data table.

**Components Qt has and the web does not:** switch, radio, slider, progress,
level meter, chart, histogram, waveform, trail, search field, list header,
shortcut overlay, info tip.

**Same concept, different words.**

| Concept | Web | Qt | iOS |
| --- | --- | --- | --- |
| Button variants | default `secondary`; `primary`, `ghost`, `danger`, `tab`, `chip`; `size="mini"` | default `default`; `primary`, `secondary`, `ghost` | `SuiButtonKind` |
| Badge colour | `tone`: blue, green, yellow, orange, red, purple | `tone`: status tones or buckets | `SuiTone`, `SuiBucket.one…eight` |
| Toast kind | `kind`: success, error, info | `tone`: info, ok, warn, danger | `SuiTone` |
| Banner | info, ok, warn, danger | the same (the web cites Qt's) | the same |

**What the siblings do that Qt could borrow.**

- iOS commits reference PNGs: eight variants per scene (light and dark, two
  text sizes, two contrast levels). Qt writes screenshots and throws them away.
- The web drives its axe, keyboard and namespace tests from one catalog and
  checks contrast by token `role`. It keeps a manual pre-release
  accessibility checklist.
- iOS gives each tone a symbol and a spoken label, so status is not carried by
  colour alone.

## 4. Enrichment ideas

Effort: **S** is under a day of agent work, **M** is one to three days, **L**
is a week or more or needs a design note first. "Decision" marks items the
owner must settle before work starts (section 5 lists them).

### 4.1 Ranking

| # | Idea | Value | Effort | Decision | Kind |
| --- | --- | --- | --- | --- | --- |
| 1 | Refresh tokens to scshafe-ui 0.9.0, add a drift guard | High | M | yes | Quick win |
| 2 | 0.10.1: fix the state bugs and the chart and table edge cases | High | M | partly | Quick win |
| 3 | Table and chart for voice-lab; retire the stand-ins | High | L | yes | Bigger bet |
| 4 | Open the request channel; parity matrix; roadmap in the repository | High | S | yes | Quick win |
| 5 | Missing primitives: tooltip, menu, popover, tabs, text area, scroll view, variants | High | L | no | Bigger bet |
| 6 | Move to Qt 6.12 | Medium | S–M | yes | Quick win |
| 7 | `scshafe_qt.testing`: ship the test kit | Medium | S | no | Quick win |
| 8 | qmllint, ruff and stricter gates in CI | Medium | S–M | no | Quick win |
| 9 | Committed reference screenshots and a published gallery | Medium | M | yes | Bigger bet |
| 10 | System preferences helper: reduced motion, contrast | Medium | M | no | Quick win |
| 11 | Python-side models and painters for scale | Medium | L | yes | Bigger bet |
| 12 | Localisation: `qsTr`, overridable strings, RTL | Medium | M–L | yes | Bigger bet |
| 13 | Waveform: zoom, live bins, markers | Medium | L | no | Bigger bet |
| 14 | A consumer skill and machine-readable API reference | Medium | M | no | Bigger bet |
| 15 | Font scaling and a high-contrast theme | Medium | L | yes | Bigger bet |
| 16 | PyInstaller hook and packaging notes | Low–Med | S | no | Quick win |
| 17 | Icon registry and more icons | Low–Med | S | no | Quick win |
| 18 | Docs: split the README, per-component pages | Low–Med | M | no | Quick win |
| 19 | API vocabulary pass before 1.0 | Medium | M | yes | Bigger bet |
| 20 | Model-assisted review loops | Medium | M | yes | Bigger bet |

### 4.2 Quick wins

**1. Refresh the tokens and guard against drift.**
- *What:* `gen_tokens.py --refresh` against scshafe-ui 0.9.0; read
  `src/tokens.ts` as iOS does; map the new radii, easing and glass tokens; a
  scheduled CI job that compares the snapshot's source version with the latest
  scshafe-ui release and fails (or opens an issue) on drift.
- *Value:* native apps match web and iOS again; drift becomes visible within a
  week instead of never.
- *Risks:* the radii change is visible in every app, so it is a minor release
  with screenshots in the PR. `radius-pill` on buttons changes their shape if
  Qt follows the web's 0.9 look. The generator turns CSS forms it cannot parse
  into strings silently (`gen_tokens.py:157-218`); `cubic-bezier` and `180%`
  need handling.
- *Depends on:* the decision on glass (5.2) and on where the snapshot comes
  from (5.3). A longer-term fix is a request to scshafe-ui to publish the
  snapshot JSON with each release; this agent can file that
  (`request targets` lists scshafe-ui).

**2. A fix release (0.10.1).**
- *What:* the bugs in section 2.5 that need no API change: search clear emits
  `textEdited`; slider decimals; Python lists in the shortcut overlay (one
  shared array helper); disabled list rows; chart `RangeError`, NaN axis and
  band gaps; histogram shares and a bin cap; table scroll position and missing
  keys; waveform End; meter NaN; shared icon paths; a dialog height clamp. A
  regression test for each.
- *Value:* removes traps a second consumer would hit in its first week.
- *Risks:* the binding fixes depend on decision 5.1. Without it, fix only the
  ones with an obvious answer (key paths should behave as pointer paths do).
- *Effort:* M. About 20 small fixes, each with a test.

**4. Open the channel and write down the plan.**
- *What:* three small things. (a) Let scshafe-qt accept agent requests, at
  least from voice-lab. (b) A `docs/PARITY.md` matrix: one row per concept,
  one column per library, with the names each uses. (c) A `docs/ROADMAP.md`
  and a short decision log, so priorities live in the repository.
- *Value:* the owner stops relaying; a cold session knows what is next; the
  three library agents have one page to keep in step.
- *Risks:* requests are reports, not instructions, and the rules for treating
  them that way are already in place. The matrix goes stale unless each
  library's release checklist touches it.
- *Depends on:* (a) is a fleet change the owner makes; this agent cannot.

**6. Move to Qt 6.12.**
- *What:* run the suite on PySide6 6.12.0, re-check `IconImage`, `SafeArea`
  and the dialog's accessible name, then widen or move the range.
- *Value:* apps are not held on 6.11; Python 3.15 becomes possible (6.12
  wheels declare `<3.16`).
- *Risks:* the private `IconImage` import; behaviour changes in templates.
- *Decision:* move (`>=6.12,<6.13`) or span two minors
  (`>=6.11.2,<6.13`, tested on both in CI). Spanning is kinder to voice-lab,
  which pins 6.11.2 exactly; moving is the stated policy.

**7. Ship the test kit.**
- *What:* `scshafe_qt.testing` (or a pytest plugin): the engine fixture with
  ordered teardown, `window_scene`, a visual-tree `find`, `spy`, theme and
  reduced-motion switches, and stable documented `objectName`s for parts such
  as `infoTipBody`.
- *Value:* voice-lab deletes its copies; every app gets the hard-won PySide
  lifetime rules (`AGENTS.md:31-33`) for free.
- *Risks:* `objectName`s become public API. pytest and pytest-qt must stay
  optional (an extra), not runtime dependencies.

**8. Lint and stricter gates.**
- *What:* `pyside6-qmllint` in CI with a baseline that only shrinks;
  `pragma ComponentBehavior: Bound` in each file; `ruff`; the smoke scene and
  the QML test floor check names, not counts; performance tests print and
  bound at about three times the claim instead of twenty-five; one CI run per
  PR instead of two; macOS on PRs that touch QML (the repository is public, so
  the minutes are free).
- *Value:* catches the `SuiText.style` class of mistake at review time; makes
  the README's numbers enforceable.
- *Risks:* tighter timing bounds can flake on shared runners; keep them
  generous on CI and strict locally.

**10. A system-preferences helper.**
- *What:* `scshafe_qt.follow_system(engine)`: reads the OS reduced-motion
  setting (GNOME `enable-animations`, macOS "Reduce motion") and Qt's
  `contrastPreference`, sets `SuiTheme`, and re-reads on change where
  possible.
- *Value:* reduced motion works in every app with one line. Today the only
  consumer never sets it.
- *Risks:* reading the macOS setting without a new dependency means a
  subprocess or `ctypes`; Windows and KDE need their own paths. Ship Linux and
  macOS first and say so.

**16. PyInstaller hook.** A `_pyinstaller` hook directory registered by entry
point, so `collect_data_files` is automatic, plus a packaging page. S. Risk:
none beyond keeping it tested (a CI job that builds a bundle is M).

**17. Icon registry.** `SuiIcon.register(name, path)` or a `path` property so
apps add vector icons without the private image path; add record, measure,
play, stop and pause. S. Fixes the per-instance table at the same time.

**18. Docs.** Keep the README to install, usage and the table; move each
component's section to `docs/components/<name>.md`; update the stale
examples. M. Value is mostly for agents: a session can read one page instead
of 662 lines.

### 4.3 Bigger bets

**3. Table and chart for their consumer.**
- *What:* a design note first, built from voice-lab's asks. Table: cell kinds
  (`chip`, `link`, `stack`, `actions`) or a cell delegate, pinned columns,
  `sortRequested` for server-side sort, `endReached` paging, `cellActivated`,
  per-column sort keys, filtering that keeps row identity. Chart: panels on a
  shared x axis, `log2` and time axes, a compact sparkline, point ids with
  `activated(id)`, zones and text.
- *Value:* retires 737 lines in voice-lab and makes the two most expensive
  components earn their keep. Every data-heavy app after it starts from them.
- *Risks:* API growth in the two largest files (765 and 833 lines). Cell
  kinds versus delegates is a real fork: kinds are safe and testable, delegates
  are flexible and let apps break the accessibility contract.
- *Depends on:* decision 5.4, and ideally on idea 11 for the model.
- *Effort:* L, two or three minors.

**5. The missing primitives.**
- *What:* in the order the consumer needs them: `SuiToolTip` (icon buttons
  have no hover label), `SuiMenu` and a context menu, `SuiPopover`, a public
  `SuiScrollView`, `SuiTabs`, `SuiTextArea`, `SuiCard`, `SuiLink`; then
  variants: `compact` on select and button, a `danger` button, icon plus text,
  a loading state, a default dialog button, a clickable chip, field error
  state and help text.
- *Value:* removes the raw templates from 10 voice-lab files and closes most
  of the gap to the web's inventory.
- *Risks:* each is small; together they are 10 or more components and the
  per-component checklist (`AGENTS.md:26-30`) makes each a half-day at least.
  Batch them as two minors with one design note each, as 0.10.0 did.

**9. Reference screenshots and a published gallery.**
- *What:* commit reference PNGs per gallery view and theme (and later per
  contrast and text size), compare in CI with a tolerance, and attach the
  gallery screenshots to each Release or publish them with GitHub Pages.
- *Value:* a token refresh or Qt upgrade shows its visual effect in the PR.
  The owner can see what a release looks like without running it.
- *Risks:* font rendering differs between machines; the references must be
  made on the CI image, with a pinned font. Binary files in the repository
  (10 PNGs today, about 1–2 MB). Decision 5.6.

**11. Python-side models and painters.**
- *What:* optional helpers in the `scshafe_qt` package: a
  `QAbstractTableModel` the table can take (incremental updates, stable
  scroll, sort in Python or with a key function), binning and decimation
  helpers for chart and waveform data, perhaps a `QQuickPaintedItem` for dense
  series.
- *Value:* lifts the 10,000-row and 100,000-point ceilings; lets live data
  append instead of replace.
- *Risks:* the Python API grows from three names to a real surface with its
  own compatibility promises. numpy must not become a runtime dependency
  (`AGENTS.md:34-36`); helpers would accept sequences and use numpy only if
  present.
- *Decision:* 5.5.

**12. Localisation.** Wrap fixed strings in `qsTr`, add a property for each
accessible string that has none, use `Qt.locale()` for numbers, and add
`LayoutMirroring` support with a mirrored gallery test. M for strings, L with
RTL. Only worth doing if a non-English or RTL app is plausible (decision 5.7);
the overridable-strings half is cheap and worth doing regardless.

**13. Waveform for the studio.** A zoomed view (`viewStart`, `viewEnd`) with
scroll, bins that update without resetting interaction, a dB display scale,
markers and regions. L. Retires voice-lab's `StudioWaveform.qml`. Risk: the
studio's reference is the Swift app; the design note should start from it.

**14. A consumer skill and API reference.**
- *What:* generate a machine-readable API file from the QML (properties,
  signals, defaults, header comments) at build time; ship it in the wheel and
  publish it. Write the `.agents/skills` entry `dev.toml` records as a gap:
  how to adopt a release, which component fits which need, the binding rules.
- *Value:* consumer agents stop guessing the API from a 662-line README and
  stop writing stand-ins for things that exist (voice-lab hand-styles a scroll
  bar the library already has, internally).
- *Risks:* a generated reference is only as good as the header comments; add
  a test that every public property is documented.

**15. Font scaling and high contrast.** A `SuiTheme.fontScale` that every
size token multiplies, and a high-contrast variant driven by
`contrastPreference`. L, because every fixed height in the module must
tolerate larger text. Brings Qt level with iOS, which tests both. Decision
5.8.

**19. Vocabulary pass before 1.0.** One rule each for visible text, `label`,
tones, selection and dismissal, applied with deprecated aliases for a minor or
two. Aligned with the parity matrix so the three libraries converge. M, but
it touches every consumer; do it once, before a second app adopts the library.

**20. Where newer models help.** These are workflows, not library code.
- *Visual review in the PR.* The gallery already writes screenshots; a model
  can look at before and after for each view and theme and describe what
  changed. This is the cheap version of idea 9 and needs no committed images.
- *Parity sweeps.* On each scshafe-ui or scshafe-ios release, a session reads
  the diff and proposes the matching native change or a matrix update.
- *Adoption reports.* On each release here, a session reads the consumers'
  public code, lists stand-ins and raw templates that the release makes
  unnecessary, and sends that as a request to the consumer's agent. Section
  2.6 is that report done by hand; it took one reader a few minutes.
- *Accessibility audits.* A reviewer that reads each new component against
  the contract and tries to break it (bindings, Python models, disabled
  states) found most of section 2.5 in one pass. Make it a standing step
  before each minor.
- *Real-display checks.* A session with a granted display or board could drive
  the gallery with a screen reader's accessibility tree and report what is
  announced; today that is entirely unverified.
- *Risks:* cost, and reports that read as confident when they are wrong. Keep
  the rule used here: reproduce or cite before it goes in a PR.

## 5. Decisions for the owner

1. **Controlled or uncontrolled state.** Should components ever assign their
   own public properties? Options: (a) never: emit a request signal and let
   the app write back, as `SuiWaveform` does; (b) assign, as Qt's own controls
   do, and document that bindings need the signal handlers; (c) per property,
   written down. I recommend (b) for form values, because the templates
   already behave that way, with key paths fixed to match pointer paths, and
   (a) for app-owned state such as the meter's pin and the shell's panes.
2. **Glass on native.** scshafe-ui 0.9.0 adds 11 glass tokens; iOS drops them
   and uses the system material. Should Qt generate them (unused), drop them,
   or use them for the translucent sidebar voice-lab asked for? I recommend
   generating them and using them only where an app opts in.
3. **Where the snapshot comes from.** Each library runs its own reader, or
   scshafe-ui publishes the JSON. I recommend the published JSON, as the iOS
   design doc does; it needs a request to scshafe-ui.
4. **Table cells: kinds or delegates.** Fixed cell kinds keep the
   accessibility contract enforceable; delegates hand it to the app. I
   recommend kinds first, with a delegate escape hatch later if a real need
   appears.
5. **A larger Python surface.** Models and helpers in `scshafe_qt`, or keep
   the package to `register()` and leave models to apps. I recommend a small
   optional surface (a table model, a test kit, the preferences helper), each
   behind its own import.
6. **Committed reference images.** Binary files in the repository in exchange
   for visual diffs in PRs, or model-described diffs with nothing committed.
   I recommend starting with the model-described diffs and committing images
   only if they prove too loose.
7. **Localisation scope.** Overridable strings only, or full `qsTr` and RTL.
8. **Text scaling and high contrast.** In scope before 1.0 or after.
9. **Qt range policy.** Follow one minor, as now, or span two.
10. **Agent requests.** Which projects may file requests here, and whether
    automatic runs are on.
11. **What 1.0 means.** The classifier still says Alpha
    (`pyproject.toml:16`). A stated bar (vocabulary settled, a second consumer,
    parity matrix green) would give the ideas above an order.

## 6. Suggested order

If the owner wants one path rather than a menu:

1. **This week:** decisions 5.1, 5.3, 5.9 and 5.10; then 0.10.1 (idea 2) and
   the Qt 6.12 check (idea 6).
2. **Next:** the token refresh as 0.11.0 with the drift guard (idea 1), with
   screenshots reviewed in the PR; the roadmap and parity matrix (idea 4).
3. **Then:** the table and chart design note (idea 3) and the first batch of
   primitives (idea 5), built against voice-lab's stand-ins; the test kit and
   lint (ideas 7 and 8) alongside, because both make that work safer.
4. **After that:** the waveform, the Python models, and the vocabulary pass
   on the way to 1.0.
