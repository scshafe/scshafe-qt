"""The Scshafe.Ui gallery: every component in one window.

    uv run python examples/gallery.py                    # follow the OS theme
    uv run python examples/gallery.py --theme dark --reduced-motion
    uv run python examples/gallery.py --screenshot DIR   # render PNGs offscreen and exit

Keys in the window: Tab / Shift+Tab move focus; j / k move the message
selection; 1-8 "sort" (a toast); / searches; ? lists the shortcuts.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GALLERY_QML = HERE / "gallery.qml"
# The views --screenshot renders: name -> gallery.qml function to call first.
VIEWS = {"main": "showSample", "dialog": "openDialog", "sheet": "openSheet", "shortcuts": "openShortcuts"}


def load(engine, theme: str = "system", reduced_motion: bool = False):
    """Load the gallery window into `engine` (any QQmlEngine; Scshafe.Ui is
    registered here) and return the window."""
    import scshafe_qt
    from PySide6.QtCore import QUrl
    from PySide6.QtQml import QQmlComponent
    from PySide6.QtQuick import QQuickWindow  # noqa: F401  (so create() returns a QQuickWindow)

    scshafe_qt.register(engine)
    sui = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    sui.setProperty("mode", theme)
    sui.setProperty("reducedMotion", reduced_motion)
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(GALLERY_QML)))
    window = component.create()
    if window is None:
        raise RuntimeError("\n".join(e.toString() for e in component.errors()))
    window._component = component  # keep the component alive with the window
    return window


def screenshots(engine, window, out_dir: Path, theme: str, settle) -> list[Path]:
    """Render each view of `window` to out_dir/gallery-<view>-<theme>.png.

    `settle()` lets the event loop run (animations, layout) between steps.
    """
    from PySide6.QtCore import QMetaObject

    out_dir.mkdir(parents=True, exist_ok=True)
    engine.singletonInstance("Scshafe.Ui", "SuiTheme").setProperty("mode", theme)
    written = []
    for view, opener in VIEWS.items():
        QMetaObject.invokeMethod(window, "closeAll")
        settle()
        if opener:
            QMetaObject.invokeMethod(window, opener)
        settle()
        path = out_dir / f"gallery-{view}-{theme}.png"
        if not window.grabWindow().save(str(path)):
            raise RuntimeError(f"could not write {path}")
        written.append(path)
    QMetaObject.invokeMethod(window, "closeAll")
    return written


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--theme", choices=["system", "light", "dark"], default="system")
    ap.add_argument("--reduced-motion", action="store_true", help="every transition instant")
    ap.add_argument("--screenshot", metavar="DIR", type=Path, help="render light and dark PNGs into DIR and exit")
    args = ap.parse_args(argv)

    if args.screenshot:
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        os.environ.setdefault("QT_QUICK_BACKEND", "software")

    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlEngine
    from PySide6.QtTest import QTest

    app = QGuiApplication(sys.argv[:1])
    engine = QQmlEngine()
    engine.quit.connect(app.quit)
    window = load(engine, args.theme, args.reduced_motion or bool(args.screenshot))
    if args.screenshot:
        for theme in ("light", "dark"):
            for path in screenshots(engine, window, args.screenshot, theme, lambda: QTest.qWait(150)):
                print(path)
        return 0
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
