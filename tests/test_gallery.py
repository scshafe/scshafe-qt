"""The gallery (examples/gallery.qml) loads cleanly and renders offscreen in both
themes. The PNGs are for review, not committed: they go to
$SCSHAFE_QT_SCREENSHOTS when set, else to pytest's tmp_path.

    SCSHAFE_QT_SCREENSHOTS=/some/scratch/dir uv run pytest tests/test_gallery.py
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest
from conftest import ROOT, track
from PySide6.QtCore import QMetaObject, QtMsgType
from PySide6.QtGui import QImage

sys.path.insert(0, str(ROOT / "examples"))
import gallery  # noqa: E402


@pytest.fixture
def out_dir(tmp_path) -> Path:
    target = os.environ.get("SCSHAFE_QT_SCREENSHOTS")
    return Path(target) if target else tmp_path


def test_gallery_loads_without_warnings(engine, qtbot, qtlog):
    window = track(engine, gallery.load(engine, "light", reduced_motion=True))
    qtbot.waitExposed(window)
    for name in ("openDialog", "openSheet", "openShortcuts"):
        QMetaObject.invokeMethod(window, name)
        qtbot.wait(20)
        QMetaObject.invokeMethod(window, "closeAll")
    warnings = [r.message for r in qtlog.records if r.type in (QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg)]
    assert warnings == []
    window.close()


def test_gallery_screenshots_in_both_themes(engine, qtbot, out_dir):
    window = track(engine, gallery.load(engine, "light", reduced_motion=True))
    qtbot.waitExposed(window)
    written = []
    for theme in ("light", "dark"):
        written += gallery.screenshots(engine, window, out_dir, theme, lambda: qtbot.wait(120))
    window.close()
    assert [p.name for p in written] == [
        f"gallery-{view}-{theme}.png" for theme in ("light", "dark") for view in gallery.VIEWS
    ]
    for path in written:
        image = QImage(str(path))
        assert image.width() >= 1280 and image.height() >= 800, path
    for view in gallery.VIEWS:
        light = QImage(str(out_dir / f"gallery-{view}-light.png"))
        dark = QImage(str(out_dir / f"gallery-{view}-dark.png"))
        assert light != dark, f"{view}: the themes render the same"
    # Bottom-right is the inspector pane (--sui-bg-elevated over --sui-bg).
    main = {t: QImage(str(out_dir / f"gallery-main-{t}.png")) for t in ("light", "dark")}
    assert main["light"].pixelColor(1278, 798).name() == "#eef2f7"
    assert main["dark"].pixelColor(1278, 798).lightness() < 40
    print(f"gallery screenshots: {out_dir}")
