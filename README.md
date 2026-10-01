# scshafe-qt

The SCSHAFE native component library: the QML module **`Scshafe.Ui`** (Qt Quick) for
Python + PySide6 desktop apps, themed from the same token registry as the web library
`@scshafe/ui`, so web and native share one source of truth for colour, spacing, radii,
type and motion.

- Distribution `scshafe-qt`, import `scshafe_qt`, QML module `Scshafe.Ui`.
- Qt **6.8 LTS** through `PySide6-Essentials` 6.8.x (6.8.3, the last 6.8 wheel on
  PyPI); the move to 6.12 LTS comes when PySide6 6.12 ships.
- Python 3.13 (PySide6 6.8 wheels declare `requires-python <3.14`).
- Status: **Q0 scaffold**, unreleased. Components so far: `SuiTheme` (tokens) and
  `SuiButton`. The v0.1 component set is Q1; the first release (0.1.0) is Q2.

## Install (consumers)

Releases will be wheels attached to GitHub Releases of `scshafe/scshafe-qt` (Q2), never
a package index. A consumer pins the exact Release URL, and `uv lock` records the
wheel's sha256:

```toml
# the app's pyproject.toml (shape to be finalised at Q2)
[project]
dependencies = [
    "scshafe-qt @ https://github.com/scshafe/scshafe-qt/releases/download/v0.1.0/scshafe_qt-0.1.0-py3-none-any.whl",
]
```

The Release body will list each file's sha256 so the pin can be checked by hand. How
private-repository downloads authenticate for people, agents and CI (App installation
token or a fine-grained read token) is decided at Q2. The library accepts the Qt LTS
line it is tested on (`PySide6-Essentials>=6.8.3,<6.9`); the app's own `uv.lock` pins
one exact PySide6.

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

Imports are versionless (`import Scshafe.Ui`). `SuiButton` variants: `default`,
`primary`, `secondary`, `ghost`.

### Theme and motion

`SuiTheme` is a singleton with every registry token as a property (`--sui-text-strong`
is `SuiTheme.textStrong`; `SuiTheme.registry` maps CSS names to property names).

- `SuiTheme.mode`: `"system"` (default) follows `Qt.styleHints.colorScheme`; `"light"`
  and `"dark"` pin a theme. `SuiTheme.dark` / `SuiTheme.themeName` report the result.
- `SuiTheme.reducedMotion`: when `true`, `SuiTheme.duration` (every transition) is 0.
  Qt 6.8 exposes **no** OS reduced-motion preference (QStyleHints has none; Qt 6.10's
  `QAccessibilityHints` only adds `contrastPreference`), so the application sets it,
  e.g. from GNOME's `org.gnome.desktop.interface enable-animations` or macOS's
  "Reduce motion" setting.
- Units: lengths are logical pixels (CSS px), durations milliseconds; shadows are
  `{ offsetX, offsetY, blur, spread, color }` for `MultiEffect`.
- Native extensions not in the registry (focus-ring width/offset, type scale
  `fontSizeXs`…`fontSize3xl`, weights, `disabledOpacity`, `alpha(color, amount)`) live
  in the generator's template, documented in `SuiTheme.qml`.

### Accessibility contract

Every interactive component is keyboard-focusable, shows a focus ring
(`SuiTheme.focusRing`, outside the control) for keyboard focus only (Qt's
`visualFocus`, the native `:focus-visible`), sets `Accessible.role` and
`Accessible.name`, and animates only on `SuiTheme.duration`.

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
  CI cannot read the private registry, so there it checks QML against the snapshot and
  says it skipped the registry comparison (`--require-source` makes that a failure).
- `tests/test_tokens.py` checks every token in both themes against the snapshot
  (and the live registry when reachable).

Change a token in scshafe-ui, release it, then `--refresh` here in one commit.

## Development

Toolchain: [uv](https://docs.astral.sh/uv/) 0.12.21 (`[tool.uv] required-version`),
Python 3.13 (`.python-version`, installed by uv), `uv.lock` committed.

```sh
uv sync --frozen                                   # .venv with PySide6 + pytest-qt
uv run python tools/gen_tokens.py --check
uv run pytest                                      # offscreen; includes the QML TestCases
uv run python tests/qml_runner.py                  # QML TestCases alone (tests/qml/tst_*.qml)
uv build && uv run python tools/check_dist.py --smoke
```

Tests run under `QT_QPA_PLATFORM=offscreen` and `QT_QUICK_BACKEND=software` (set by
`tests/conftest.py` and `tests/qml_runner.py`). PySide6 wheels ship no
`qmltestrunner`; `tests/qml_runner.py` uses `PySide6.QtQuickTest`'s
`QUICK_TEST_MAIN_WITH_SETUP` with `scshafe_qt.register`.

On Ubuntu the wheels need these system libraries (CI installs them): `libegl1 libgl1
libxkbcommon0 libfontconfig1 libfreetype6 libx11-6 libglib2.0-0t64 libdbus-1-3` and a
font (`fonts-dejavu-core`). ICU is bundled.

To try a change in an app before a release, install this checkout into the app's
environment (`uv pip install -e <path>` in the app's venv) and never commit that.

## CI

`.github/workflows/ci.yml`, GitHub-hosted runners only, `contents: read`, actions pinned
by SHA: Linux (`ubuntu-latest`) on every push and pull request; macOS (`macos-latest`,
Apple Silicon) on `v*` tags, `workflow_dispatch` and weekly, to keep macOS minutes low.
Both run `uv sync --frozen`, the token check, the tests, `uv build` and the
distribution check (wheel carries the QML module, payload scan, install-and-load smoke).

## Releasing

Not yet: the first release, 0.1.0, is Q2. The planned shape, after the library
standard: `pyproject.toml` `version` is the authority; a release commit bumps it and
adds `## <x.y.z> — <date>` to `CHANGELOG.md`; after CI is green on `main` the owning
agent pushes the annotated tag `v<x.y.z>` on that commit; `publish.yml` (Q2) is the only
publisher: it refuses tags not on `main` or not matching the version, builds the wheel
and sdist, attaches them to a GitHub Release with their sha256s, then installs the
wheel back from the Release URL into a clean environment and loads the module
offscreen. Versions are never reused, moved or deleted.

## License

MIT, see [LICENSE](LICENSE).
