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
- Status: **0.2.0**: `SuiTheme` (tokens) and the v0.1 component set below.
- **Untrusted text is safe to pass:** every component renders caller strings as plain text
  (`textFormat: Text.PlainText`); markup is shown literally and never fetches anything.
  0.1.0 rendered HTML-looking strings as rich text (fixed in 0.1.1; upgrade).

## Install (consumers)

From [PyPI](https://pypi.org/project/scshafe-qt/) (from 0.1.2), on Python 3.12 or later
(3.14 only before 0.2.0):

```sh
uv add scshafe-qt            # or: pip install scshafe-qt
```

An app that pins `scshafe-qt>=0.1.2,<0.2` stays on 0.1.2; widen the range to `<0.3` for
0.2.0 (same components and API; only the supported Python range changed).

Every release is also a GitHub Release of `scshafe/scshafe-qt` with the same wheel and
sdist, their sha256 in the notes and a `SHA256SUMS` file. `publish.yml` uploads the
very files it attached to the Release (PyPI and the Release are byte-identical), with
PEP 740 attestations from trusted publishing. As a fallback, install straight from a
Release; the repository is public, so the download URLs need no token:

```sh
pip install https://github.com/scshafe/scshafe-qt/releases/download/v0.2.0/scshafe_qt-0.2.0-py3-none-any.whl
# or, in a uv project, a pinned URL source (uv.lock records its sha256):
uv add "scshafe-qt @ https://github.com/scshafe/scshafe-qt/releases/download/v0.2.0/scshafe_qt-0.2.0-py3-none-any.whl"
```

To check the files yourself: `gh release download v0.2.0 -R scshafe/scshafe-qt -p '*.whl' -p SHA256SUMS`,
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
uv run python examples/gallery.py --screenshot DIR      # PNGs of four views x two themes
```

In the window: Tab / Shift+Tab, `j` / `k`, `1`–`8` (a toast), `/`, `?`.

### Theme and motion

`SuiTheme` is a singleton with every registry token as a property (`--sui-text-strong`
is `SuiTheme.textStrong`; `SuiTheme.registry` maps CSS names to property names).

- `SuiTheme.mode`: `"system"` (default) follows `Qt.styleHints.colorScheme`; `"light"`
  and `"dark"` pin a theme. `SuiTheme.dark` / `SuiTheme.themeName` report the result.
- `SuiTheme.reducedMotion`: when `true`, `SuiTheme.duration` (every transition) is 0.
  Qt (through 6.11) exposes **no** OS reduced-motion preference (QStyleHints has none;
  `QAccessibilityHints`, 6.10+, only carries `contrastPreference`), so the application sets it,
  e.g. from GNOME's `org.gnome.desktop.interface enable-animations` or macOS's
  "Reduce motion" setting.
- Units: lengths are logical pixels (CSS px), durations milliseconds; shadows are
  `{ offsetX, offsetY, blur, spread, color }` for `MultiEffect`.
- Native-only tokens (not in the registry) live in the clearly marked NATIVE-ONLY
  section of `tools/gen_tokens.py` and are generated into `SuiTheme.qml`: focus ring,
  control metrics and layout defaults, type scale, the bucket palette, tone helpers
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
