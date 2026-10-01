// QtQuickTest example: the pattern Q1 component tests follow. Run by
// tests/qml_runner.py (PySide6.QtQuickTest.QUICK_TEST_MAIN_WITH_SETUP), which
// tests/test_qml.py drives under pytest.
import QtQuick
import QtTest
import Scshafe.Ui

Item {
    id: root
    width: 240
    height: 120

    SuiButton {
        id: button
        x: 20
        y: 20
        text: "Sort"
    }

    SignalSpy {
        id: clicked
        target: button
        signalName: "clicked"
    }

    TestCase {
        name: "SuiTheme"

        function cleanup() {
            SuiTheme.mode = "system"
            SuiTheme.reducedMotion = false
        }

        function test_mode_override() {
            SuiTheme.mode = "dark"
            verify(SuiTheme.dark)
            compare(SuiTheme.bg, Qt.color("#08111f"))
            SuiTheme.mode = "light"
            verify(!SuiTheme.dark)
            compare(SuiTheme.bg, Qt.color("#f6f8fb"))
        }

        function test_reduced_motion() {
            compare(SuiTheme.duration, 120)
            SuiTheme.reducedMotion = true
            compare(SuiTheme.duration, 0)
        }

        function test_provenance() {
            compare(SuiTheme.registry["--sui-text-strong"], "textStrong")
            verify(SuiTheme.registryHash.startsWith("sha256:"))
        }
    }

    TestCase {
        name: "SuiButton"
        when: windowShown

        function init() {
            clicked.clear()
            root.forceActiveFocus(Qt.OtherFocusReason)  // start each test unfocused
            verify(!button.activeFocus)
        }

        function test_accessible_name() {
            compare(button.Accessible.name, "Sort")
            compare(button.Accessible.role, Accessible.Button)
        }

        function test_keyboard_focus_ring_and_activation() {
            button.forceActiveFocus(Qt.TabFocusReason)
            verify(button.activeFocus)
            verify(button.visualFocus)
            const ring = findChild(button, "focusRing")
            verify(ring !== null)
            verify(ring.visible)
            keyClick(Qt.Key_Space)
            compare(clicked.count, 1)
        }

        function test_mouse_click() {
            mouseClick(button)
            compare(clicked.count, 1)
            verify(button.activeFocus)
            verify(!findChild(button, "focusRing").visible)  // :focus-visible, not :focus
        }
    }
}
