"""Shared fixtures. Every test runs headless: offscreen platform, software Qt Quick renderer."""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Before any Qt import creates the application.
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")

import pytest  # noqa: E402
from PySide6.QtQml import QQmlComponent, QQmlEngine  # noqa: E402

import scshafe_qt  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))


@pytest.fixture
def engine(qapp):
    eng = QQmlEngine()
    scshafe_qt.register(eng)
    yield eng
    eng.collectGarbage()
    eng.deleteLater()


@pytest.fixture
def theme(engine):
    obj = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    assert obj is not None, "SuiTheme singleton did not load"
    return obj


def create(engine: QQmlEngine, source: str):
    """Instantiate QML `source`; fail with the component's errors."""
    comp = QQmlComponent(engine)
    comp.setData(source.encode(), "inline.qml")
    obj = comp.create()
    if obj is None:
        pytest.fail("QML failed to load:\n" + "\n".join(e.toString() for e in comp.errors()))
    obj._component = comp  # keep the component alive with the object
    return obj
