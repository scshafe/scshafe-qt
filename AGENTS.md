# scshafe-qt Agent Contract

A managed library (Python variant of the SCSHAFE library standard,
`scshafe-library` v1, to be amended with that variant): the QML module
`Scshafe.Ui` for PySide6 apps, released as wheels on GitHub Releases. It deploys
nothing. Read `README.md` before meaningful changes.

## Invariants

- Names: distribution `scshafe-qt`, import `scshafe_qt`, QML module `Scshafe.Ui`
  (versionless imports), components `Sui<Name>.qml`, the theme singleton
  `SuiTheme`. Every QML file in the module is listed in its `qmldir`.
- `SuiTheme.qml` is generated: never edit it by hand. Registry tokens come from
  `@scshafe/ui` through `tools/gen_tokens.py --refresh` (snapshot
  `tokens/sui-tokens.json`); native-only values (focus ring, type scale,
  helpers) live in the generator's template. `gen_tokens.py --check` and
  `tests/test_tokens.py` must pass; change the snapshot and the QML in one commit.
- Components carry no colour, size or duration literals: they read `SuiTheme`.
  Every interactive component is keyboard-focusable, shows its focus ring for
  keyboard focus only (`visualFocus`), sets `Accessible.role` and
  `Accessible.name`, and animates only on `SuiTheme.duration`. `SuiButton.qml`
  is the pattern (QtQuick.Templates, no platform style).
- A new component gets: a `qmldir` line, pytest-qt tests (render, focus,
  accessible name) and a QML `TestCase` in `tests/qml/tst_*.qml`.
- Runtime dependency: `PySide6-Essentials` only, in the tested LTS range
  (`>=<tested patch>,<next minor>`); apps pin exactly. Adding another runtime
  dependency is a reviewed change. Do not depend on the full `PySide6` meta-package.
- Toolchain: uv `==0.12.21` (`[tool.uv] required-version`), Python from
  `.python-version`, `uv.lock` committed, installs with `uv sync --frozen`. No
  `requirements*.txt`, no pip-only workflows.
- `dist/` and `.venv/` are never committed. Builds are reproducible (hatchling);
  `tools/check_dist.py` is the payload gate (QML module present, no home paths
  or token-shaped strings).
- No application-specific names, endpoints, hosts or credentials in code or docs.
- CI runs only on GitHub-hosted runners (never self-hosted); macOS only on tags,
  dispatch and weekly.

## Verification

```sh
uv sync --frozen
uv run python tools/gen_tokens.py --check
uv run pytest                     # offscreen, includes the QML TestCases
uv build && uv run python tools/check_dist.py --smoke
```

## Releasing (from Q2)

- SemVer; `pyproject.toml` `version` is the authority. A release commit bumps it
  and adds `## <x.y.z> — <date>` to `CHANGELOG.md`.
- After `ci.yml` is green on `main`, the owning agent pushes the annotated tag
  `v<x.y.z>` on that commit; `publish.yml` (Q2) is the only publisher (GitHub
  Release with wheel, sdist and sha256s, then install-back from the Release URL).
- Never upload wheels by hand, never reuse, move or delete a tag or a Release.
  A bad release is superseded by a higher patch with a changelog note.
