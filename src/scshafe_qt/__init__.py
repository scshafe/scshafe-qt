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

    Idempotent: the path is added once per engine.
    """
    path = qml_import_path()
    if path not in engine.importPathList():
        engine.addImportPath(path)
    return path
