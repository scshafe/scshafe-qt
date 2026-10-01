# Changelog

All notable changes to `scshafe-qt` are recorded here. Versions follow
[SemVer](https://semver.org/). A release is the annotated tag `v<x.y.z>` on a
commit on `main` whose `pyproject.toml` version is `<x.y.z>`; released versions
are never deleted, replaced or reused.

## Unreleased

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
