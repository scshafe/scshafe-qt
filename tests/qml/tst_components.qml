// QtQuickTest suites for the Q1 components (run by tests/qml_runner.py, which
// tests/test_qml.py drives under pytest): keyboard behaviour, accessibility
// and theme bindings, from QML.
import QtQuick
import QtTest
import Scshafe.Ui

Item {
    id: root
    width: 900
    height: 600

    ListModel {
        id: messages
        ListElement { sender: "Ada"; subject: "Engines"; time: "09:41"; unread: true }
        ListElement { sender: "Grace"; subject: "Relays"; time: "09:12"; unread: false }
        ListElement { sender: "Alan"; subject: "Machines"; time: "08:00"; unread: false }
    }

    Column {
        x: 10
        y: 10
        spacing: 8

        SuiSearchField { id: search; width: 240 }
        SuiIconButton { id: iconButton; label: "Dismiss"; icon.name: "close" }
        SuiChip { id: chip; text: "Receipts"; tone: "bucket1" }
        SuiSidebarList {
            id: sidebar
            width: 220
            height: 120
            label: "Mailboxes"
            selectedIndex: 0
            model: [
                { text: "Unsorted", iconName: "inbox", count: 12, status: "ok" },
                { text: "Receipts", iconName: "tag", count: 3, status: "held" }
            ]
        }
        SuiList {
            id: list
            width: 300
            height: 160
            label: "Messages"
            model: messages
            delegate: SuiListRow {
                width: ListView.view.width
                title: model.sender
                subtitle: model.subject
                meta: model.time
                unread: model.unread
            }
        }
        SuiTrail {
            id: trail
            width: 300
            steps: [ { title: "Rules", outcome: "no match" }, { title: "Model", outcome: "Receipts", warning: true } ]
        }
    }

    SuiAppShell {
        id: shell
        x: 400
        width: 500
        height: 300
        sidebarWidth: 160
        inspectorWidth: 240
        contentMinWidth: 60
        sidebar: Item {}
        content: Item {}
        inspector: Item {}
    }

    SuiButton { id: opener; x: 400; y: 320; text: "Open"; onClicked: dialog.open() }
    SuiDialog {
        id: dialog
        title: "Confirm"
        SuiTextField { id: dialogField; width: 200; label: "Note" }
        actions: [ SuiButton { id: dialogOk; text: "OK"; onClicked: dialog.accept() } ]
    }
    SuiToastHost { id: toasts; anchors.fill: parent }

    SignalSpy { id: nextSpy; target: list; signalName: "nextRequested" }
    SignalSpy { id: activatedSpy; target: list; signalName: "activated" }
    SignalSpy { id: sidebarSpy; target: sidebar; signalName: "activated" }
    SignalSpy { id: hookSpy; target: search; signalName: "focusRequested" }
    SignalSpy { id: rejectedSpy; target: dialog; signalName: "rejected" }

    TestCase {
        name: "SuiComponents"
        when: windowShown

        function init() {
            SuiTheme.mode = "light"
            SuiTheme.reducedMotion = true
            for (const spy of [nextSpy, activatedSpy, sidebarSpy, hookSpy, rejectedSpy])
                spy.clear()
            root.forceActiveFocus(Qt.OtherFocusReason)
        }
        function cleanup() {
            dialog.close()
            toasts.clear()
            SuiTheme.mode = "system"
            SuiTheme.reducedMotion = false
        }

        function test_icon_button_is_named() {
            compare(iconButton.Accessible.name, "Dismiss")
            compare(iconButton.Accessible.role, Accessible.Button)
            iconButton.forceActiveFocus(Qt.TabFocusReason)
            verify(findChild(iconButton, "focusRing").visible)
        }

        function test_chip_follows_the_theme() {
            const label = findChild(chip, "label")
            compare(label.color, SuiTheme.bucket1Text)
            const light = String(label.color)  // a copy: value-type reads are live references
            SuiTheme.mode = "dark"
            verify(String(label.color) !== light)
            compare(label.color, SuiTheme.bucket1Text)
        }

        function test_list_keys_and_hooks() {
            list.forceActiveFocus(Qt.TabFocusReason)
            list.currentIndex = 0
            keyClick(Qt.Key_J)
            keyClick(Qt.Key_Down)
            compare(nextSpy.count, 2)
            compare(list.currentIndex, 2)
            keyClick(Qt.Key_K)
            compare(list.currentIndex, 1)
            keyClick(Qt.Key_Return)
            compare(activatedSpy.count, 1)
            compare(activatedSpy.signalArguments[0][0], 1)
            compare(list.currentItem.Accessible.name, "Grace, Relays, 09:12")
        }

        function test_sidebar_enter_activates() {
            sidebar.forceActiveFocus(Qt.TabFocusReason)
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Return)
            compare(sidebarSpy.count, 1)
            compare(sidebar.selectedIndex, 1)
            compare(sidebar.currentItem.Accessible.description, "3 items, held")
        }

        function test_slash_focuses_search() {
            opener.forceActiveFocus(Qt.TabFocusReason)
            keyClick(Qt.Key_Slash)
            compare(hookSpy.count, 1)
            verify(search.activeFocus)
            keyClick(Qt.Key_A)
            compare(search.text, "a")
            keyClick(Qt.Key_Escape)
            compare(search.text, "")
        }

        function test_shell_keyboard_resize() {
            const handle = findChild(shell, "sidebarHandle")
            handle.forceActiveFocus(Qt.TabFocusReason)
            keyClick(Qt.Key_Right)
            compare(shell.sidebarWidth, 160 + SuiTheme.splitterStep)
            keyClick(Qt.Key_Home)
            compare(shell.sidebarWidth, SuiTheme.sidebarMinWidth)
            shell.inspectorOpen = false
            compare(findChild(shell, "inspectorPane").width, 0)
            shell.inspectorOpen = true
            compare(findChild(shell, "inspectorPane").width, 240)
        }

        function test_dialog_trap_escape_and_return() {
            opener.forceActiveFocus(Qt.TabFocusReason)
            keyClick(Qt.Key_Space)
            tryCompare(dialog, "opened", true)
            verify(dialogField.activeFocus)
            keyClick(Qt.Key_Tab)
            verify(dialogOk.activeFocus)
            keyClick(Qt.Key_Tab)
            verify(dialogField.activeFocus)  // wrapped: trapped inside
            keyClick(Qt.Key_Escape)
            tryCompare(dialog, "visible", false)
            compare(rejectedSpy.count, 1)
            verify(opener.activeFocus)
            verify(opener.visualFocus)
        }

        function test_toast_host() {
            const id = toasts.show("Sorted", { tone: "ok", timeout: 0 })
            compare(toasts.count, 1)
            verify(toasts.dismiss(id))
            compare(toasts.count, 0)
        }

        function test_trail_steps() {
            compare(trail.stepCount, 2)
            verify(findChild(trail, "warningMarker") !== null)
            compare(trail.Accessible.role, Accessible.List)
        }
    }
}
