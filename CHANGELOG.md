# Changelog

All notable changes to `scshafe-qt` are recorded here. Versions follow
[SemVer](https://semver.org/). A release is the annotated tag `v<x.y.z>` on a
commit on `main` whose `pyproject.toml` version is `<x.y.z>`; released versions
are never deleted, replaced or reused.

## Unreleased

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
