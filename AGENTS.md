# scshafe-qt Agent Contract

A managed library (Python variant of the SCSHAFE library standard,
`scshafe-library` v1, to be amended with that variant): the QML module
`Scshafe.Ui` for PySide6 apps, released as wheels on GitHub Releases and PyPI
(the same files). It deploys nothing. Read `README.md` before meaningful changes.

## Invariants

- Names: distribution `scshafe-qt`, import `scshafe_qt`, QML module `Scshafe.Ui`
  (versionless imports), components `Sui<Name>.qml`, the theme singleton
  `SuiTheme`. Every QML file in the module is listed in its `qmldir`.
- `SuiTheme.qml` is generated: never edit it by hand. Registry tokens come from
  `@scshafe/ui` through `tools/gen_tokens.py --refresh` (snapshot
  `tokens/sui-tokens.json`); native-only values (focus ring, type scale,
  helpers) live in the generator's template. `gen_tokens.py --check` and
  `tests/test_tokens.py` must pass; change the snapshot and the QML in one commit.
- Components carry no colour or duration literals (`tests/test_rules.py`
  enforces both) and take sizes from `SuiTheme`: native-only values go in the
  NATIVE-ONLY section of `tools/gen_tokens.py`, never into a component.
  Every interactive component is keyboard-focusable, shows its focus ring
  (internal `SuiFocusRing`) for keyboard focus only (`visualFocus`, or the
  lists' `keyboardInteraction`), sets `Accessible.role` and `Accessible.name`,
  and animates only on `SuiTheme.duration`. `SuiButton.qml` is the pattern
  (QtQuick.Templates, no platform style).
- A new component gets: a `qmldir` line (`internal` for helpers), an entry in
  `tests/test_components.py`'s `SPECS` (render in both themes, accessible
  role and name, keyboard ring pixel, pointer focus), behaviour tests, a QML
  `TestCase` in `tests/qml/tst_*.qml`, a place in `examples/gallery.qml`, a
  line in the README table and the `check_dist.py` smoke scene.
- Qt and QML warnings fail tests (`qt_log_level_fail`); tests delete their
  scenes before the engine and avoid `metaObject()` on QML objects (stale
  PySide wrappers).
- Runtime dependency: `PySide6-Essentials` only, in the tested minor range
  (`>=<tested patch>,<next minor>`, today `>=6.11.2,<6.12`); apps pin exactly. Adding another runtime
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
uv run --frozen python tools/gen_tokens.py --check
uv run --frozen pytest -v         # offscreen, includes the QML TestCases
uv build && uv run --frozen python tools/check_dist.py --smoke
```

## Releasing (from Q2)

- SemVer; `pyproject.toml` `version` is the authority. A release commit bumps it
  and adds `## <x.y.z> — <date>` to `CHANGELOG.md`.
- After `ci.yml` is green on `main`, the owning agent pushes the annotated tag
  `v<x.y.z>` on that commit; `publish.yml` (Q2) is the only publisher (GitHub
  Release with wheel, sdist and sha256s, then install-back from the Release URL,
  then the same files to PyPI by trusted publishing from the `pypi` environment,
  `v*` tags only). No PyPI token exists anywhere.
- Never upload wheels by hand (to a Release or to PyPI), never reuse, move or
  delete a tag, a Release or a PyPI file; yank on PyPI only with the owner.
  A bad release is superseded by a higher patch with a changelog note.

<!-- scshafe-dev:begin landing -->
## Verify and landing

Managed by scshafe-dev: `dev adopt` and `dev update` refresh this section from `dev.toml`; change `dev.toml`, not these lines.

Before finishing, both of these must pass:

```sh
uv run --frozen pytest -v
dev check .
```

How a change lands:

1. Work on a branch and open a PR.
2. Run the two commands above. If the repository is private, GitHub Actions does not run for it: verify locally and say in the PR what you ran. If it is public, wait for CI to be green.
3. Merge your own PR with a merge commit, one change at a time: `gh pr merge <N> --merge --subject "Merge #<N>: <title>"`. Never squash or rebase (both are off on the repository), and pass `--subject`: `gh pr merge` does not make the `Merge #N: <title>` subject by itself.

The project's agent may merge its own PR and push `main`; there is no approval gate.
<!-- scshafe-dev:end landing -->
