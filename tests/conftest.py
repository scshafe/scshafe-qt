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
    eng.created = []  # root objects to delete before the engine (see track())
    yield eng
    # QML objects must not outlive their engine: delete the scenes first.
    from PySide6.QtCore import QCoreApplication, QEvent

    import gc

    for obj in reversed(eng.created):
        obj.deleteLater()
    eng.created.clear()
    gc.collect()  # drop Python wrappers of the scene before its objects go
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    eng.collectGarbage()
    eng.deleteLater()
    QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    gc.collect()


def track(engine, obj):
    """Delete `obj` (a root object created in `engine`) before the engine at teardown."""
    engine.created.append(obj)
    return obj


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
    return track(engine, obj)


# ---------------------------------------------------------------------------
# Scene helpers for the component tests
# ---------------------------------------------------------------------------

# --sui-focus-ring (= --sui-accent) per theme, from the snapshot.
RING = {"light": "#0a4f99", "dark": "#6cb6ff"}


def window_scene(engine, qtbot, body: str, width: int = 480, height: int = 320, imports: str = ""):
    """A shown, active Window (themed background) containing `body`."""
    from PySide6.QtQuick import QQuickWindow

    source = (
        "import QtQuick\nimport QtQuick.Layouts\nimport Scshafe.Ui\n" + imports + "\n"
        f"Window {{ width: {width}; height: {height}; visible: true; color: SuiTheme.bg\n{body}\n}}\n"
    )
    window = create(engine, source)
    assert isinstance(window, QQuickWindow)
    qtbot.waitExposed(window)
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    return window


def find(window, name: str):
    from PySide6.QtCore import QObject
    from PySide6.QtQuick import QQuickItem

    found = window.findChild(QQuickItem, name) or window.findChild(QObject, name)
    if found is None:  # delegates and popup content are outside the QObject tree
        found = find_item(window.contentItem(), name)
    assert found is not None, name
    return found


def find_item(root, name: str):
    """Depth-first search of the visual item tree (reaches delegates and popups)."""
    if root.objectName() == name:
        return root
    for child in root.childItems():
        if (hit := find_item(child, name)) is not None:
            return hit
    return None


def visible_rings(root) -> list:
    """Every focus ring currently shown under `root` (visual tree)."""
    out = []
    if root.objectName() == "focusRing" and root.isVisible():
        out.append(root)
    for child in root.childItems():
        out.extend(visible_rings(child))
    return out


def owner(item, names) -> str | None:
    """The objectName of the closest ancestor of `item` (itself included) named in `names`."""
    while item is not None:
        if item.objectName() in names:
            return item.objectName()
        item = item.parentItem()
    return None


def ring_pixel(window, ring):
    """The colour at the middle of the ring's top border."""
    from PySide6.QtCore import QPoint

    top_left = ring.mapToScene(ring.boundingRect().topLeft())
    # SuiTheme.focusRingWidth is 2: the border covers rows y and y + 1.
    point = QPoint(int(top_left.x() + ring.width() / 2), int(round(top_left.y())) + 1)
    return window.grabWindow().pixelColor(point)


def close_enough(a, b, tolerance: int = 6) -> bool:
    from PySide6.QtGui import QColor

    a, b = QColor(a), QColor(b)
    return all(abs(x - y) <= tolerance for x, y in zip(a.getRgb()[:3], b.getRgb()[:3], strict=True))


def set_theme(engine, mode: str) -> None:
    engine.singletonInstance("Scshafe.Ui", "SuiTheme").setProperty("mode", mode)



def spy(obj, signature: str):
    """A QSignalSpy on a QML-declared signal ("activated(int)").

    Uses SIGNAL() rather than obj.metaObject(): PySide keeps wrappers of QML
    objects' dynamic meta-objects, and a later object at a reused address can
    then come back as a stale QMetaObject wrapper.
    """
    from PySide6.QtCore import SIGNAL
    from PySide6.QtTest import QSignalSpy

    watcher = QSignalSpy(obj, SIGNAL(signature))
    assert watcher.isValid(), f"{signature} is not a signal of {obj.objectName()!r}"
    return watcher
