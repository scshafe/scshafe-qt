# Changelog

All notable changes to `scshafe-qt` are recorded here. Versions follow
[SemVer](https://semver.org/). A release is the annotated tag `v<x.y.z>` on a
commit on `main` whose `pyproject.toml` version is `<x.y.z>`; released versions
are never deleted, replaced or reused.

## Unreleased

- Qt 6.11: depend on `PySide6-Essentials>=6.11.2,<6.12` (was `>=6.8.3,<6.9`);
  open-source Qt patches track the current minor, so the library follows it
  (6.12 when PySide6 6.12 ships). Python 3.14 (`.python-version`,
  `requires-python >=3.14,<3.15`); the 6.11 wheels are abi3 (CPython 3.10+).
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
