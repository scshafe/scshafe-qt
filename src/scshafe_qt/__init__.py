"""scshafe-qt: the SCSHAFE native component library.

The components are the QML module ``Scshafe.Ui`` shipped inside this package
(``scshafe_qt/qml/Scshafe/Ui``). An application adds the module's import path
to its engine once, then imports the module from QML::

    from PySide6.QtQml import QQmlApplicationEngine
    import scshafe_qt

    engine = QQmlApplicationEngine()
    scshafe_qt.register(engine)          # engine.addImportPath(qml_import_path())
    engine.loadData(b"import QtQuick; import Scshafe.Ui; SuiButton { text: 'Go' }")

The module needs PySide6's Qt Quick and Qt Quick Controls (Templates), both in
``PySide6-Essentials``.
"""

from __future__ import annotations

import sys
from importlib.resources import files
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # PySide6 is only imported by callers that have an engine
    from PySide6.QtQml import QQmlEngine

__all__ = ["QML_MODULE", "qml_import_path", "register"]

#: The QML module URI this package provides.
QML_MODULE = "Scshafe.Ui"


def qml_import_path() -> str:
    """The directory to add to a QML engine's import path (it contains ``Scshafe/Ui``)."""
    path = Path(str(files(__name__) / "qml"))
    if not (path / "Scshafe" / "Ui" / "qmldir").is_file():
        raise FileNotFoundError(f"{QML_MODULE} module missing under {path}: broken installation")
    return str(path)


def register(engine: QQmlEngine) -> str:
    """Make ``import Scshafe.Ui`` resolvable in ``engine``; returns the import path added.

    Idempotent: the path is added once per engine. Under the ``offscreen`` platform on
    macOS it also gives the application an installed font family (see
    :func:`_settle_offscreen_font`).
    """
    path = qml_import_path()
    if path not in engine.importPathList():
        engine.addImportPath(path)
    _settle_offscreen_font()
    return path


#: Installed on every supported macOS; the first one present is used.
_MACOS_FAMILIES = ("Helvetica Neue", "Helvetica", "Arial")


def _settle_offscreen_font() -> None:
    """Headless runs on macOS: replace the offscreen platform's default font family.

    The ``offscreen`` platform's default family is "Sans Serif", which macOS doesn't have, so
    the first text drawn makes Qt search its alias table and warn ("Populating font family
    aliases took … ms") -- a warning that fails tests run with warnings as errors. The native
    platform (cocoa) uses the system font and is untouched, as is Linux, where fontconfig
    resolves "Sans Serif".
    """
    if sys.platform != "darwin":
        return
    from PySide6.QtGui import QFontDatabase, QGuiApplication

    app = QGuiApplication.instance()
    if app is None or QGuiApplication.platformName() != "offscreen":
        return
    installed = set(QFontDatabase.families())
    font = QGuiApplication.font()
    if font.family() in installed:
        return
    for family in _MACOS_FAMILIES:
        if family in installed:
            font.setFamily(family)
            QGuiApplication.setFont(font)
            return
