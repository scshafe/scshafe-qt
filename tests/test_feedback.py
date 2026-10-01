"""SuiBanner, SuiToast and SuiToastHost."""

from __future__ import annotations

from conftest import find, find_item, spy, window_scene
from PySide6.QtCore import QMetaObject, Q_ARG, Q_RETURN_ARG, Qt
from PySide6.QtGui import QAccessible
from PySide6.QtTest import QTest


def test_banner_dismiss_from_the_keyboard(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'SuiBanner { objectName: "banner"; width: 400; tone: "danger"; title: "Sign-in expired";'
        ' text: "Sign in again."; dismissible: true }',
    )
    banner = find(window, "banner")
    dismissed = spy(banner, "dismissed()")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert window.activeFocusItem().objectName() == "dismissButton"
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert dismissed.count() == 1
    assert banner.property("open") is False and not banner.isVisible()
    window.close()


def test_banner_roles_by_tone(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Column { SuiBanner { objectName: "info"; width: 300; tone: "info"; text: "Live updates on." }'
        ' SuiBanner { objectName: "warn"; width: 300; tone: "warn"; title: "Held"; text: "Paused." } }',
    )
    info = QAccessible.queryAccessibleInterface(find(window, "info"))
    warn = QAccessible.queryAccessibleInterface(find(window, "warn"))
    assert info.role() == QAccessible.Role.Grouping and info.text(QAccessible.Text.Name) == "Live updates on."
    assert warn.role() == QAccessible.Role.AlertMessage
    assert warn.text(QAccessible.Text.Name) == "Held" and warn.text(QAccessible.Text.Description) == "Paused."
    assert not find(window, "dismissButton").isVisible()  # not dismissible
    window.close()


HOST = 'SuiToastHost { id: host; objectName: "host"; anchors.fill: parent; maxToasts: 3 }'


def show(host, text: str, options: dict | None = None) -> int:
    ret = QMetaObject.invokeMethod(
        host, "show", Qt.ConnectionType.DirectConnection, Q_RETURN_ARG("QVariant"),
        Q_ARG("QVariant", text), Q_ARG("QVariant", options or {}),
    )
    return int(ret)


def toasts(window) -> list:
    stack = find_item(window.contentItem(), "toastStack")
    out = []

    def walk(item):
        if item.objectName() == "toast":
            out.append(item)
        for c in item.childItems():
            walk(c)

    walk(stack)
    return [t for t in out if t.isVisible()]


def host_scene(engine, qtbot):
    window = window_scene(engine, qtbot, HOST, 600, 400)
    engine.singletonInstance("Scshafe.Ui", "SuiTheme").setProperty("reducedMotion", True)
    return window, find(window, "host")


def test_host_shows_and_dismisses(engine, qtbot):
    window, host = host_scene(engine, qtbot)
    first = show(host, "Sorted into Receipts", {"tone": "ok", "timeout": 0})
    second = show(host, "Rule added", {"timeout": 0})
    assert host.property("count") == 2 and first != second
    qtbot.waitUntil(lambda: len(toasts(window)) == 2)
    toast = toasts(window)[0]
    assert toast.x() + toast.width() <= 600 and toast.y() + toast.height() <= 400
    QMetaObject.invokeMethod(host, "dismiss", Qt.ConnectionType.DirectConnection,
                             Q_RETURN_ARG("QVariant"), Q_ARG("QVariant", first))
    assert host.property("count") == 1
    QMetaObject.invokeMethod(host, "clear")
    assert host.property("count") == 0
    window.close()


def test_host_keeps_at_most_max_toasts(engine, qtbot):
    window, host = host_scene(engine, qtbot)
    for i in range(5):
        show(host, f"toast {i}", {"timeout": 0})
    assert host.property("count") == 3
    window.close()


def test_toast_times_out(engine, qtbot):
    window, host = host_scene(engine, qtbot)
    show(host, "Soon gone", {"timeout": 60})
    assert host.property("count") == 1
    qtbot.waitUntil(lambda: host.property("count") == 0, timeout=2000)
    window.close()


def test_toast_pauses_while_focused(engine, qtbot):
    window, host = host_scene(engine, qtbot)
    show(host, "Stay", {"timeout": 80})
    qtbot.waitUntil(lambda: len(toasts(window)) == 1)
    close = find_item(toasts(window)[0], "closeButton")
    close.forceActiveFocus(Qt.FocusReason.TabFocusReason)
    QTest.qWait(250)
    assert host.property("count") == 1
    QTest.keyClick(window, Qt.Key.Key_Space)  # the close button
    assert host.property("count") == 0
    window.close()


def test_toast_action_runs_the_callback(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        HOST + '\nproperty int undone: 0\n'
        'SuiButton { objectName: "go"; text: "Go"\n'
        '  onClicked: host.show("Sorted", { actionText: "Undo", timeout: 0, onAction: () => undone += 1 }) }',
    )
    host = find(window, "host")
    triggered = spy(host, "actionTriggered(int)")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Space)
    qtbot.waitUntil(lambda: len(toasts(window)) == 1)
    action = find_item(toasts(window)[0], "actionButton")
    assert action is not None and action.isVisible()
    centre = action.mapToScene(action.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert window.property("undone") == 1
    assert triggered.count() == 1
    qtbot.waitUntil(lambda: host.property("count") == 0)
    window.close()


def test_toast_is_an_alert(engine, qtbot):
    window = window_scene(
        engine, qtbot, 'SuiToast { objectName: "t"; title: "Sorted"; text: "Into Receipts"; timeout: 0 }'
    )
    iface = QAccessible.queryAccessibleInterface(find(window, "t"))
    assert iface.role() == QAccessible.Role.AlertMessage
    assert iface.text(QAccessible.Text.Name) == "Sorted"
    assert iface.text(QAccessible.Text.Description) == "Into Receipts"
    window.close()


def test_escape_on_a_focused_toast_dismisses_it(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiToast { objectName: "t"; text: "Hi"; timeout: 0 }')
    toast = find(window, "t")
    requested = spy(toast, "dismissRequested()")
    QTest.keyClick(window, Qt.Key.Key_Tab)
    assert window.activeFocusItem().objectName() == "closeButton"
    QTest.keyClick(window, Qt.Key.Key_Escape)
    assert requested.count() == 1
    window.close()
