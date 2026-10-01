"""SuiButton renders, takes keyboard focus with a visible ring, and has an accessible name."""

from __future__ import annotations

import pytest
from conftest import create
from PySide6.QtCore import QPoint, Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

SCENE = """
import QtQuick
import Scshafe.Ui

Window {
    width: 240; height: 120; visible: true
    color: SuiTheme.bg
    property int clicks: 0
    Row {
        x: 20; y: 20; spacing: 16
        SuiButton { objectName: "first"; text: "Sort"; onClicked: clicks += 1 }
        SuiButton { objectName: "second"; text: "Skip"; variant: "primary" }
    }
}
"""


@pytest.fixture
def scene(engine, qtbot):
    window = create(engine, SCENE)
    assert isinstance(window, QQuickWindow)
    qtbot.waitExposed(window)
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    yield window
    window.close()


def item(window: QQuickWindow, name: str) -> QQuickItem:
    found = window.findChild(QQuickItem, name)
    assert found is not None, name
    return found


def ring(button: QQuickItem) -> QQuickItem:
    return button.findChild(QQuickItem, "focusRing")


def test_renders(scene):
    first = item(scene, "first")
    assert first.width() > 0 and first.height() > 0
    assert first.property("text") == "Sort"
    image = scene.grabWindow()
    assert not image.isNull() and image.width() >= 240
    # The button's 1px border is drawn: the pixel on its left edge is not the window background.
    top_left = first.mapToScene(first.boundingRect().topLeft())
    edge = QPoint(int(top_left.x()), int(top_left.y() + first.height() / 2))
    assert image.pixelColor(edge) != QColor(scene.property("color"))
    # Inside the button is the --sui-field surface (#ffffff in the light theme).
    centre = QPoint(int(top_left.x()) + 3, int(top_left.y()) + 3)
    assert image.pixelColor(centre) == QColor("#ffffff")


def test_tab_focus_shows_the_ring(scene):
    first, second = item(scene, "first"), item(scene, "second")
    assert not ring(first).isVisible()
    QTest.keyClick(scene, Qt.Key.Key_Tab)
    assert first.hasActiveFocus()
    assert first.property("visualFocus") is True
    assert ring(first).isVisible() and not ring(second).isVisible()
    # The ring is drawn outside the control (outline-offset), in --sui-focus-ring.
    assert ring(first).width() > first.width()
    top_left = first.mapToScene(first.boundingRect().topLeft())
    on_ring = QPoint(int(top_left.x()) - 3, int(top_left.y() + first.height() / 2))
    assert scene.grabWindow().pixelColor(on_ring) == QColor("#0a4f99")  # light --sui-accent
    QTest.keyClick(scene, Qt.Key.Key_Tab)
    assert second.hasActiveFocus()
    assert ring(second).isVisible() and not ring(first).isVisible()


def test_mouse_focus_shows_no_ring(scene):
    first = item(scene, "first")
    centre = first.mapToScene(first.boundingRect().center()).toPoint()
    QTest.mouseClick(scene, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert scene.property("clicks") == 1
    assert first.hasActiveFocus()
    assert not ring(first).isVisible()  # :focus-visible, not :focus


def test_keyboard_activation(scene):
    QTest.keyClick(scene, Qt.Key.Key_Tab)
    QTest.keyClick(scene, Qt.Key.Key_Space)
    assert scene.property("clicks") == 1


def test_accessible_name_and_role(scene):
    first = item(scene, "first")
    iface = QAccessible.queryAccessibleInterface(first)
    assert iface is not None
    assert iface.role() == QAccessible.Role.Button
    assert iface.text(QAccessible.Text.Name) == "Sort"


def test_disabled_button_is_not_focusable(engine, qtbot):
    window = create(
        engine,
        "import QtQuick\nimport Scshafe.Ui\n"
        "Window { visible: true; width: 200; height: 80\n"
        "  Row { SuiButton { objectName: 'off'; text: 'Off'; enabled: false }\n"
        "        SuiButton { objectName: 'on'; text: 'On' } } }",
    )
    qtbot.waitExposed(window)
    window.requestActivate()
    qtbot.waitUntil(lambda: window.isActive())
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert item(window, "on").hasActiveFocus()
    assert item(window, "off").property("opacity") == pytest.approx(0.48)
    window.close()
