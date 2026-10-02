"""Caller text is plain text: markup in a string never renders and never fetches anything.

Every public component that shows a caller-provided string gets the same hostile payload: an
<img> pointing at a local HTTP server that counts requests, plus a <b>. With Qt's default
Text.AutoText those strings render as rich text and Qt fetches the image -- a tracking beacon when
the string is a mail subject (found by mailroom-desktop's review of 0.1.0). The module now sets
textFormat: Text.PlainText on every Text it owns.
"""

from __future__ import annotations

import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest
from conftest import window_scene
from PySide6.QtQuick import QQuickItem

class _Beacon(BaseHTTPRequestHandler):
    hits = 0

    def do_GET(self):  # noqa: N802 (http.server API)
        type(self).hits += 1
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.end_headers()

    def log_message(self, *args):  # keep test output quiet
        pass


@pytest.fixture
def beacon():
    _Beacon.hits = 0
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Beacon)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    yield server
    server.shutdown()
    server.server_close()


def _is_plain(engine, text_item) -> bool:
    """textFormat === Text.PlainText, asked of QML (PySide cannot convert the enum)."""
    from PySide6.QtQml import QQmlEngine, QQmlExpression

    context = QQmlEngine.contextForObject(text_item) or engine.rootContext()
    expression = QQmlExpression(context, text_item, "textFormat === Text.PlainText")
    value, failed = expression.evaluate()
    assert not failed, expression.error().toString()
    return value is True


def _all_items(root: QQuickItem):
    stack = [root]
    while stack:
        item = stack.pop()
        yield item
        stack.extend(item.childItems())


def _scene(port: int) -> str:
    p = f'"<img src=\\"http://127.0.0.1:{port}/beacon.png\\"><b>x</b>"'
    return f"""
    id: root
    property string p: {p}
    Flickable {{
        anchors.fill: parent; contentHeight: col.height
        Column {{
            id: col; width: parent.width; spacing: 4
            SuiButton {{ text: root.p }}
            SuiChip {{ text: root.p; tone: "bucket1" }}
            SuiBadge {{ text: root.p }}
            SuiKbd {{ text: root.p }}
            SuiSidebarItem {{ text: root.p }}
            SuiSidebarList {{ width: 300; height: 80
                model: [{{ text: root.p, count: 1, status: "ok", section: root.p }}] }}
            SuiList {{ width: 300; height: 60; model: 1
                delegate: SuiListRow {{ title: root.p; subtitle: root.p; meta: root.p }} }}
            SuiEmptyState {{ title: root.p; description: root.p }}
            SuiBanner {{ title: root.p; text: root.p }}
            SuiToast {{ title: root.p; text: root.p; actionText: root.p; timeout: 0 }}
            SuiTextField {{ label: "x"; placeholderText: root.p }}
            SuiTrail {{ width: 300
                steps: [{{ title: root.p, outcome: root.p, via: root.p, detail: root.p, warningText: root.p }}] }}
        }}
    }}
    SuiToastHost {{ id: host; anchors.fill: parent }}
    SuiDialog {{ id: dialog; title: root.p; description: root.p }}
    SuiSheet {{ id: sheet; title: root.p; description: root.p }}
    SuiShortcutOverlay {{ id: overlay
        shortcuts: [{{ group: root.p, keys: [root.p], description: root.p }}] }}
    Component.onCompleted: {{ host.show(root.p); dialog.open(); sheet.open(); overlay.open() }}
    """


def test_markup_in_caller_text_never_renders_or_fetches(engine, qtbot, beacon):
    window = window_scene(engine, qtbot, _scene(beacon.server_address[1]), width=700, height=900)
    for _ in range(10):  # several frames, and time for any image request to go out
        window.grabWindow()
        qtbot.wait(100)
    texts = [i for i in _all_items(window.contentItem())
             if i.metaObject().className() == "QQuickText"]
    showing = [t for t in texts if "<img" in (t.property("text") or "")]
    assert len(showing) >= 20, f"expected the payload in most components, found {len(showing)}"
    assert _Beacon.hits == 0, f"markup fetched the beacon {_Beacon.hits} time(s)"
    rich = [t.objectName() or t.parentItem().metaObject().className()
            for t in showing if not _is_plain(engine, t)]
    assert rich == [], f"Text items not plain: {rich}"


def test_every_text_in_the_module_is_plain():
    from pathlib import Path
    import re

    import scshafe_qt

    module = Path(scshafe_qt.qml_import_path()) / "Scshafe" / "Ui"
    missing = []
    for qml in sorted(module.glob("*.qml")):
        lines = qml.read_text().splitlines()
        for i, line in enumerate(lines):
            if re.search(r"\bText\s*\{\s*$", line) and not line.strip().startswith("//"):
                if "textFormat: Text.PlainText" not in lines[i + 1]:
                    missing.append(f"{qml.name}:{i + 1}")
    assert missing == [], f"Text without textFormat: Text.PlainText: {missing}"
