"""Every Scshafe.Ui component: renders in both themes, accessible role and name,
keyboard focus shows the ring (pixel-checked), pointer focus does not.

Component-specific behaviour (lists, shell, dialogs, toasts, search) has its
own test module; this one runs the shared contract over a table of specs.
"""

from __future__ import annotations

from dataclasses import dataclass

import pytest
from conftest import RING, close_enough, find, owner, ring_pixel, set_theme, visible_rings, window_scene
from PySide6.QtCore import Qt
from PySide6.QtGui import QAccessible, QColor
from PySide6.QtTest import QTest

R = QAccessible.Role


@dataclass(frozen=True)
class Spec:
    qml: str  # the component, objectName "subject"
    role: QAccessible.Role
    name: str
    focusable: bool = False  # Tab reaches it (or its current entry)
    pointer: str | None = None  # objectName to click for the pointer-focus check
    size: tuple[int, int] = (480, 320)


SIDEBAR_MODEL = """[
    { section: "Mailboxes", text: "Unsorted", iconName: "inbox", count: 12, status: "ok" },
    { section: "Buckets", text: "Receipts", iconName: "tag", count: 3, status: "held" },
    { section: "Buckets", text: "Bills", iconName: "tag", count: 1, status: "failing" }
]"""

LIST = """
ListModel { id: msgs
    ListElement { sender: "Ada"; subject: "Engines"; time: "09:41"; unread: true; bucket: 3 }
    ListElement { sender: "Grace"; subject: "Relays"; time: "09:12"; unread: false; bucket: 7 }
}
SuiList { objectName: "subject"; x: 20; y: 20; width: 360; height: 200; label: "Messages"; model: msgs
    delegate: SuiListRow { objectName: "row" + index; width: ListView.view.width
        title: model.sender; subtitle: model.subject; meta: model.time; unread: model.unread
        SuiChip { text: "Bucket " + model.bucket; tone: model.bucket } } }
"""

SPECS: dict[str, Spec] = {
    "SuiButton": Spec('SuiButton { objectName: "subject"; x: 40; y: 40; text: "Sort" }', R.Button, "Sort", True, "subject"),
    "SuiIconButton": Spec(
        'SuiIconButton { objectName: "subject"; x: 40; y: 40; label: "Dismiss"; icon.name: "close" }',
        R.Button, "Dismiss", True, "subject",
    ),
    "SuiTextField": Spec(
        'SuiTextField { objectName: "subject"; x: 40; y: 40; width: 220; label: "Note"; placeholderText: "Add a note" }',
        R.EditableText, "Note", True,
    ),
    "SuiSearchField": Spec(
        'SuiSearchField { objectName: "subject"; x: 40; y: 40; width: 220; text: "ada" }',
        R.EditableText, "Search", True,
    ),
    "SuiChip": Spec('SuiChip { objectName: "subject"; x: 40; y: 40; text: "Receipts"; tone: "bucket1"; dot: true }',
                    R.StaticText, "Receipts"),
    "SuiBadge": Spec('SuiBadge { objectName: "subject"; x: 40; y: 40; count: 120 }', R.StaticText, "99+"),
    "SuiKbd": Spec('SuiKbd { objectName: "subject"; x: 40; y: 40; text: "Ctrl" }', R.StaticText, "Ctrl"),
    "SuiIcon": Spec('SuiIcon { objectName: "subject"; x: 40; y: 40; name: "inbox"; label: "Inbox"; size: 32 }',
                    R.Graphic, "Inbox"),
    "SuiSidebarItem": Spec(
        'SuiSidebarItem { objectName: "subject"; x: 40; y: 40; width: 220; text: "Unsorted"; iconName: "inbox";'
        ' count: 12; status: "failing" }',
        R.ListItem, "Unsorted", True, "subject",
    ),
    "SuiSidebarList": Spec(
        f'SuiSidebarList {{ objectName: "subject"; x: 20; y: 20; width: 240; height: 240; label: "Mailboxes";'
        f" selectedIndex: 0; model: {SIDEBAR_MODEL} }}",
        R.List, "Mailboxes", True,
    ),
    "SuiList": Spec(LIST, R.List, "Messages", True),
    "SuiEmptyState": Spec(
        'SuiEmptyState { objectName: "subject"; x: 20; y: 20; width: 400; iconName: "inbox";'
        ' title: "Inbox zero"; description: "Nothing to sort." }',
        R.Grouping, "Inbox zero",
    ),
    "SuiBanner": Spec(
        'SuiBanner { objectName: "subject"; x: 20; y: 20; width: 400; tone: "warn"; title: "Held";'
        ' text: "Deliveries paused."; dismissible: true }',
        R.AlertMessage, "Held", True, "dismissButton",
    ),
    "SuiToast": Spec(
        'SuiToast { objectName: "subject"; x: 20; y: 20; tone: "ok"; title: "Sorted"; text: "Into Receipts";'
        ' timeout: 0 }',
        R.AlertMessage, "Sorted", True, "closeButton",
    ),
    "SuiTrail": Spec(
        'SuiTrail { objectName: "subject"; x: 20; y: 20; width: 400; label: "Sort trail"; steps: ['
        '{ title: "Rules", outcome: "no match", via: "whitelist" },'
        '{ title: "Model", outcome: "Receipts", outcomeTone: "bucket1", detail: "0.91", via: "model" },'
        '{ title: "Auditor", outcome: "disputed", outcomeTone: "warn", warning: "Disagreed" } ] }',
        R.List, "Sort trail",
    ),
    "SuiAppShell": Spec(
        'SuiAppShell { objectName: "subject"; anchors.fill: parent;'
        ' sidebar: Rectangle { color: SuiTheme.tint } content: Item {} inspector: Item {} }',
        R.Pane, "Sidebar", True, "sidebarHandle", (900, 400),
    ),
}

INTERACTIVE = [n for n, s in SPECS.items() if s.focusable]


def subject_scene(engine, qtbot, name: str, theme: str = "light"):
    spec = SPECS[name]
    set_theme(engine, theme)
    window = window_scene(engine, qtbot, spec.qml, *spec.size)
    return window, find(window, "subject")


def test_every_public_component_has_a_spec():
    """A new component must join this table (or be covered by a popup test below)."""
    import scshafe_qt
    from pathlib import Path

    qmldir = (Path(scshafe_qt.qml_import_path()) / "Scshafe" / "Ui" / "qmldir").read_text().splitlines()
    public = {line.split()[0] for line in qmldir[1:] if line and not line.startswith(("singleton", "internal"))}
    popups = {"SuiDialog", "SuiSheet", "SuiShortcutOverlay", "SuiToastHost", "SuiListRow"}  # own modules
    assert public - popups == set(SPECS), "add the component to SPECS"


@pytest.mark.parametrize("name", list(SPECS))
def test_renders_in_both_themes(engine, qtbot, name):
    images = {}
    for theme in ("light", "dark"):
        window, subject = subject_scene(engine, qtbot, name, theme)
        assert subject.width() > 0 and subject.height() > 0
        rect = subject.mapRectToScene(subject.boundingRect()).toAlignedRect().intersected(window.contentItem().boundingRect().toAlignedRect())
        image = window.grabWindow().copy(rect)
        assert not image.isNull()
        background = QColor(window.property("color"))
        colours = {image.pixelColor(x, y).rgb() for x in range(0, image.width(), 2) for y in range(0, image.height(), 2)}
        assert len(colours) > 1, f"{name} drew nothing in {theme}"
        assert any(c != background.rgb() for c in colours)
        images[theme] = image
        window.close()
    assert images["light"] != images["dark"], f"{name} looks the same in both themes"


@pytest.mark.parametrize("name", list(SPECS))
def test_accessible_role_and_name(engine, qtbot, name):
    window, subject = subject_scene(engine, qtbot, name)
    target = subject
    if name == "SuiAppShell":
        target = find(window, "sidebarPane")
    iface = QAccessible.queryAccessibleInterface(target)
    assert iface is not None
    assert iface.role() == SPECS[name].role
    assert iface.text(QAccessible.Text.Name) == SPECS[name].name
    window.close()


@pytest.mark.parametrize("theme", ["light", "dark"])
@pytest.mark.parametrize("name", INTERACTIVE)
def test_keyboard_focus_shows_the_ring(engine, qtbot, name, theme):
    window, subject = subject_scene(engine, qtbot, name, theme)
    assert visible_rings(window.contentItem()) == []
    QTest.keyClick(window, Qt.Key.Key_Tab)
    focused = window.activeFocusItem()
    assert focused is not None and owner(focused, {"subject"}) == "subject", (name, focused)
    qtbot.waitUntil(lambda: len(visible_rings(window.contentItem())) == 1)
    ring = visible_rings(window.contentItem())[0]
    assert owner(ring, {"subject"}) == "subject"
    QTest.qWait(SPECS_SETTLE)
    colour = ring_pixel(window, ring)
    assert close_enough(colour, RING[theme]), f"{name} ring pixel {colour.name()} != {RING[theme]} ({theme})"
    window.close()


SPECS_SETTLE = 150  # ms: let colour transitions (SuiTheme.duration) finish before grabbing


@pytest.mark.parametrize("name", [n for n in INTERACTIVE if SPECS[n].pointer])
def test_pointer_focus_shows_no_ring(engine, qtbot, name):
    window, subject = subject_scene(engine, qtbot, name)
    target = find(window, SPECS[name].pointer)
    centre = target.mapToScene(target.boundingRect().center()).toPoint()
    QTest.mousePress(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    QTest.mouseRelease(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert target.hasActiveFocus() or owner(window.activeFocusItem(), {"subject"}) == "subject"
    assert visible_rings(window.contentItem()) == [], f"{name}: pointer focus must not draw the ring"
    window.close()


@pytest.mark.parametrize("name", ["SuiList", "SuiSidebarList"])
def test_list_pointer_focus_then_keys_shows_the_ring(engine, qtbot, name):
    """:focus-visible: a click focuses without the ring; the next arrow key shows it."""
    window, subject = subject_scene(engine, qtbot, name)
    row = subject.property("currentItem")
    centre = row.mapToScene(row.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert subject.hasActiveFocus()
    assert visible_rings(window.contentItem()) == []
    QTest.keyClick(window, Qt.Key.Key_Down)
    assert subject.property("currentIndex") == 1
    assert len(visible_rings(window.contentItem())) == 1
    window.close()


def test_text_field_shows_the_ring_on_pointer_focus_too(engine, qtbot):
    """Browsers match :focus-visible on text inputs for pointer focus as well."""
    window, subject = subject_scene(engine, qtbot, "SuiTextField")
    centre = subject.mapToScene(subject.boundingRect().center()).toPoint()
    QTest.mouseClick(window, Qt.MouseButton.LeftButton, Qt.KeyboardModifier.NoModifier, centre)
    assert subject.hasActiveFocus()
    assert len(visible_rings(window.contentItem())) == 1
    window.close()


def test_icon_button_requires_a_label(engine):
    from PySide6.QtQml import QQmlComponent

    comp = QQmlComponent(engine)
    comp.setData(b"import QtQuick\nimport Scshafe.Ui\nSuiIconButton { icon.name: 'close' }", "nolabel.qml")
    assert comp.create() is None
    assert any("label" in e.toString() and "Required" in e.toString() for e in comp.errors()), [
        e.toString() for e in comp.errors()
    ]


def test_icon_button_toggle_is_announced_as_checkable(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'SuiIconButton { objectName: "t"; label: "Inspector"; icon.name: "panel-right"; checkable: true }',
    )
    toggle = find(window, "t")
    iface = QAccessible.queryAccessibleInterface(toggle)
    assert iface.role() == R.CheckBox
    assert not iface.state().checked
    QTest.keyClick(window, Qt.Key.Key_Tab)
    QTest.keyClick(window, Qt.Key.Key_Space)
    assert toggle.property("checked") is True
    assert iface.state().checked
    window.close()


def test_sidebar_item_describes_status_and_count(engine, qtbot):
    window, subject = subject_scene(engine, qtbot, "SuiSidebarItem")
    iface = QAccessible.queryAccessibleInterface(subject)
    assert iface.text(QAccessible.Text.Description) == "12 items, failing"
    dot = find(window, "statusDot")
    assert dot.isVisible()
    assert QColor(dot.property("color")) == QColor("#cf222e")  # light --sui-tone-red
    window.close()


@pytest.mark.parametrize(
    ("tone", "light_text"),
    [("neutral", "#1b2533"), ("info", "#0550ae"), ("ok", "#0f5a26"), ("warn", "#7d4e00"),
     ("danger", "#a40e26"), ("bucket1", "#0053a4"), (8, "#6a3ea5")],
)
def test_chip_tones(engine, qtbot, tone, light_text):
    tone_qml = f'"{tone}"' if isinstance(tone, str) else str(tone)
    window = window_scene(engine, qtbot, f'SuiChip {{ objectName: "c"; text: "x"; tone: {tone_qml} }}')
    label = find(window, "label")
    assert QColor(label.property("color")) == QColor(light_text)
    window.close()


def test_badge_count_and_max(engine, qtbot):
    window = window_scene(
        engine, qtbot,
        'Row { SuiBadge { objectName: "a"; count: 7 } SuiBadge { objectName: "b"; count: 1000; max: 999 }'
        ' SuiBadge { objectName: "c" } }',
    )
    assert find(window, "a").property("text") == "7"
    assert find(window, "b").property("text") == "999+"
    assert find(window, "c").isVisible() is False  # no count, no text: hidden
    window.close()


def test_trail_steps_are_list_items(engine, qtbot):
    window, subject = subject_scene(engine, qtbot, "SuiTrail")
    assert subject.property("stepCount") == 3
    step = find(window, "step2")
    iface = QAccessible.queryAccessibleInterface(step)
    assert iface.role() == R.ListItem
    assert iface.text(QAccessible.Text.Name) == "3. Auditor: disputed"
    assert iface.text(QAccessible.Text.Description) == "Warning: Disagreed"
    assert find_visible(step, "warningMarker")
    assert not find_visible(find(window, "step0"), "warningMarker")
    assert find(window, "step1").property("via") == "model"
    window.close()


def find_visible(root, name):
    from conftest import find_item

    hit = find_item(root, name)
    return hit is not None and hit.isVisible()


def test_monospace_face_is_used_for_keys(engine, qtbot):
    window = window_scene(engine, qtbot, 'SuiKbd { objectName: "k"; text: "Ctrl" }')
    theme = engine.singletonInstance("Scshafe.Ui", "SuiTheme")
    kbd = find(window, "k")
    assert kbd.property("font").family() == theme.property("monoFamily")
    window.close()

