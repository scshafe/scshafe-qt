"""The packaged QML module loads through scshafe_qt.register()."""

from __future__ import annotations

from pathlib import Path

import scshafe_qt
from PySide6.QtQml import QQmlComponent, QQmlEngine


def test_import_path_contains_the_module():
    path = Path(scshafe_qt.qml_import_path())
    qmldir = (path / "Scshafe" / "Ui" / "qmldir").read_text().splitlines()
    assert qmldir[0] == "module Scshafe.Ui"
    assert "singleton SuiTheme 1.0 SuiTheme.qml" in qmldir
    for line in qmldir[1:]:
        assert (path / "Scshafe" / "Ui" / line.split()[-1]).is_file(), line


def test_register_is_idempotent(qapp):
    engine = QQmlEngine()
    first = scshafe_qt.register(engine)
    scshafe_qt.register(engine)
    assert engine.importPathList().count(first) == 1


def _load(engine):
    comp = QQmlComponent(engine)
    comp.setData(b"import QtQuick\nimport Scshafe.Ui\nItem { property color c: SuiTheme.accent }", "t.qml")
    return comp, comp.create()


def test_module_loads_after_register(qapp):
    engine = QQmlEngine()
    scshafe_qt.register(engine)
    comp, obj = _load(engine)
    assert obj is not None, [e.toString() for e in comp.errors()]


def test_module_is_not_found_without_register(qapp):
    engine = QQmlEngine()
    comp, obj = _load(engine)
    assert obj is None
    assert any("Scshafe.Ui" in e.toString() for e in comp.errors())
