// The Scshafe.Ui gallery: every component in one window, with made-up data.
// Run it with `uv run python examples/gallery.py` (see --help there).
import QtQuick
import QtQuick.Layouts
import Scshafe.Ui

Window {
    id: root
    objectName: "gallery"
    width: 1280
    height: 800
    visible: true
    title: "Scshafe.Ui gallery"
    color: SuiTheme.bg

    readonly property var bucketLabels: ["Receipts", "Travel", "Family", "Newsletters",
                                         "Bills", "Alerts", "Social", "Later"]

    // Hooks for examples/gallery.py --screenshot and the screenshot test.
    function showSample() {
        toasts.show("Mail from this sender now goes to Family.", { title: "Sorted", tone: "ok", actionText: "Undo", timeout: 0 })
        inbox.forceActiveFocus(Qt.TabFocusReason)  // as if tabbed to: the ring shows
    }
    function openDialog() { ruleDialog.open() }
    function openSheet() { senderSheet.open() }
    function openShortcuts() { shortcutOverlay.open() }
    function closeAll() {
        ruleDialog.close()
        senderSheet.close()
        shortcutOverlay.close()
        toasts.clear()
    }

    ListModel {
        id: messages
        ListElement { sender: "Ada Lovelace"; subject: "Notes on the analytical engine"; time: "09:41"; unread: true; bucket: 3 }
        ListElement { sender: "Northwind Air"; subject: "Your boarding pass for Friday"; time: "09:12"; unread: true; bucket: 2 }
        ListElement { sender: "Corner Grocer"; subject: "Receipt #20391"; time: "08:55"; unread: false; bucket: 1 }
        ListElement { sender: "The Weekly Byte"; subject: "Issue 212: compilers all the way down"; time: "Yesterday"; unread: false; bucket: 4 }
        ListElement { sender: "City Water"; subject: "Statement available"; time: "Yesterday"; unread: false; bucket: 5 }
        ListElement { sender: "Status Page"; subject: "Resolved: elevated error rates"; time: "Mon"; unread: false; bucket: 6 }
        ListElement { sender: "Grace Hopper"; subject: "Re: the bug in relay 70"; time: "Mon"; unread: true; bucket: 7 }
        ListElement { sender: "Reading List"; subject: "Saved for later: three long reads"; time: "Sun"; unread: false; bucket: 8 }
    }

    Shortcut { sequence: "j"; onActivated: inbox.selectNext() }
    Shortcut { sequence: "k"; onActivated: inbox.selectPrevious() }
    Repeater {
        model: 8
        Item {
            required property int index
            Shortcut {
                sequence: String(index + 1)
                onActivated: toasts.show("Sorted into " + root.bucketLabels[index],
                                         { tone: "ok", actionText: "Undo" })
            }
        }
    }

    SuiAppShell {
        id: shell
        objectName: "shell"
        anchors.fill: parent
        inspectorOpen: inspectorToggle.checked

        sidebar: SuiSidebarList {
            id: sidebar
            objectName: "sidebar"
            label: "Mailboxes"
            selectedIndex: 0
            topMargin: SuiTheme.spaceSm
            leftMargin: SuiTheme.spaceSm
            rightMargin: SuiTheme.spaceSm
            model: [
                { section: "Mailboxes", text: "Unsorted", iconName: "inbox", count: 12, status: "ok" },
                { section: "Mailboxes", text: "All mail", iconName: "mail", count: -1, status: "none" },
                { section: "Mailboxes", text: "Archive", iconName: "archive", count: -1, status: "none", enabled: false },
                { section: "Buckets", text: "Receipts", iconName: "tag", count: 3, status: "ok" },
                { section: "Buckets", text: "Travel", iconName: "tag", count: 1, status: "ok" },
                { section: "Buckets", text: "Family", iconName: "tag", count: 4, status: "held" },
                { section: "Buckets", text: "Newsletters", iconName: "tag", count: 27, status: "ok" },
                { section: "Buckets", text: "Bills", iconName: "tag", count: 2, status: "failing" },
                { section: "Buckets", text: "Alerts", iconName: "tag", count: 0, status: "none" },
                { section: "Buckets", text: "Social", iconName: "tag", count: 9, status: "ok" },
                { section: "Buckets", text: "Later", iconName: "clock", count: 130, status: "none" }
            ]
            onActivated: (index) => toasts.show("Opened " + model[index].text)
        }

        content: ColumnLayout {
            spacing: 0

            // Toolbar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: toolbar.implicitHeight + 2 * SuiTheme.spaceSm
                color: SuiTheme.panel
                RowLayout {
                    id: toolbar
                    anchors.fill: parent
                    anchors.margins: SuiTheme.spaceSm
                    spacing: SuiTheme.spaceSm
                    SuiSearchField {
                        id: search
                        objectName: "search"
                        Layout.preferredWidth: 280
                        placeholderText: "Search mail  ( / )"
                        onAccepted: toasts.show("Searching for “" + text + "”")
                    }
                    Item { Layout.fillWidth: true }
                    SuiButton { objectName: "toastButton"; text: "Toast"; onClicked: toasts.show("Sorted into Receipts", { tone: "ok", actionText: "Undo" }) }
                    SuiButton { objectName: "dialogButton"; text: "Dialog"; onClicked: ruleDialog.open() }
                    SuiButton { objectName: "sheetButton"; text: "Sheet"; onClicked: senderSheet.open() }
                    SuiIconButton { objectName: "shortcutsButton"; label: "Keyboard shortcuts"; icon.name: "keyboard"; onClicked: shortcutOverlay.open() }
                    SuiIconButton {
                        objectName: "themeButton"
                        label: SuiTheme.dark ? "Use light theme" : "Use dark theme"
                        icon.name: SuiTheme.dark ? "sun" : "moon"
                        onClicked: SuiTheme.mode = SuiTheme.dark ? "light" : "dark"
                    }
                    SuiIconButton {
                        id: inspectorToggle
                        objectName: "inspectorToggle"
                        label: "Show inspector"
                        icon.name: "panel-right"
                        checkable: true
                        checked: true
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: SuiTheme.line }
            }

            SuiBanner {
                objectName: "banner"
                Layout.fillWidth: true
                Layout.margins: SuiTheme.spaceSm
                tone: "warn"
                title: "Bills endpoint is failing"
                text: "Three deliveries are waiting; they will retry in 5 minutes."
                dismissible: true
                SuiButton { text: "Retry now"; variant: "secondary" }
            }

            SuiList {
                id: inbox
                objectName: "inbox"
                label: "Messages"
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: messages
                delegate: SuiListRow {
                    width: ListView.view.width
                    title: model.sender
                    subtitle: model.subject
                    meta: model.time
                    unread: model.unread
                    SuiChip { text: root.bucketLabels[model.bucket - 1]; tone: model.bucket; dot: true }
                }
                onActivated: (index) => senderSheet.open()
            }
        }

        inspector: Flickable {
            objectName: "inspector"
            contentHeight: inspectorColumn.implicitHeight + 2 * SuiTheme.spaceLg
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: inspectorColumn
                x: SuiTheme.spaceLg
                y: SuiTheme.spaceLg
                width: parent.width - 2 * SuiTheme.spaceLg
                spacing: SuiTheme.spaceMd

                Text { text: "Why it was sorted"; font.pixelSize: SuiTheme.fontSizeLg; font.weight: SuiTheme.fontWeightStrong; color: SuiTheme.textStrong }
                SuiTrail {
                    objectName: "trail"
                    label: "Sort trail"
                    Layout.fillWidth: true
                    steps: [
                        { title: "Sender rules", outcome: "no match", via: "whitelist v12" },
                        { title: "DMARC", outcome: "pass", outcomeTone: "ok", detail: "DKIM aligned (d=example.org)", via: "headers" },
                        { title: "Classifier", outcome: "Family", outcomeTone: "bucket3", detail: "Confidence 0.91 over 8 buckets.", via: "model" },
                        { title: "Auditor", outcome: "disputed", outcomeTone: "warn", detail: "Second opinion requested.", via: "auditor", warning: "Auditor suggested Newsletters." }
                    ]
                }

                Text { text: "Tones"; font.pixelSize: SuiTheme.fontSizeLg; font.weight: SuiTheme.fontWeightStrong; color: SuiTheme.textStrong }
                Flow {
                    Layout.fillWidth: true
                    spacing: SuiTheme.spaceXs
                    Repeater {
                        model: SuiTheme.statusTones
                        SuiChip { required property string modelData; text: modelData; tone: modelData }
                    }
                }
                Flow {
                    objectName: "bucketChips"
                    Layout.fillWidth: true
                    spacing: SuiTheme.spaceXs
                    Repeater {
                        model: SuiTheme.bucketCount
                        SuiChip {
                            required property int index
                            text: (index + 1) + " " + root.bucketLabels[index]
                            tone: "bucket" + (index + 1)
                            dot: true
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: SuiTheme.spaceXs
                    SuiBadge { count: 3 }
                    SuiBadge { count: 27; tone: "info" }
                    SuiBadge { count: 130; tone: "danger" }
                    SuiBadge { text: "new"; tone: "ok" }
                    SuiKbd { text: "Ctrl" }
                    SuiKbd { text: "K" }
                    SuiChip { text: "with icon"; iconName: "clock"; tone: "info" }
                }

                Text { text: "Fields"; font.pixelSize: SuiTheme.fontSizeLg; font.weight: SuiTheme.fontWeightStrong; color: SuiTheme.textStrong }
                SuiTextField { objectName: "noteField"; Layout.fillWidth: true; label: "Note"; placeholderText: "Add a note" }
                RowLayout {
                    spacing: SuiTheme.spaceSm
                    SuiButton { text: "Primary"; variant: "primary" }
                    SuiButton { text: "Secondary"; variant: "secondary" }
                    SuiButton { text: "Ghost"; variant: "ghost" }
                    SuiIconButton { label: "Add"; icon.name: "plus"; variant: "default" }
                }

                Text { text: "Banners"; font.pixelSize: SuiTheme.fontSizeLg; font.weight: SuiTheme.fontWeightStrong; color: SuiTheme.textStrong }
                SuiBanner { Layout.fillWidth: true; tone: "info"; text: "Live updates are on." }
                SuiBanner { Layout.fillWidth: true; tone: "danger"; title: "Sign-in expired"; text: "Sign in again to keep sorting."; dismissible: true }

                Text { text: "Empty state"; font.pixelSize: SuiTheme.fontSizeLg; font.weight: SuiTheme.fontWeightStrong; color: SuiTheme.textStrong }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: empty.implicitHeight
                    radius: SuiTheme.radiusLg
                    color: SuiTheme.panel
                    border.color: SuiTheme.line
                    SuiEmptyState {
                        id: empty
                        anchors.fill: parent
                        iconName: "inbox"
                        title: "Inbox zero"
                        description: "Nothing is waiting to be sorted."
                        SuiButton { text: "Refresh" }
                    }
                }
            }
        }
    }

    SuiToastHost { id: toasts; objectName: "toasts"; anchors.fill: parent; z: 100 }

    SuiDialog {
        id: ruleDialog
        objectName: "ruleDialog"
        title: "Always sort this sender?"
        description: "Mail from ada@example.org will go straight to Family."
        SuiTextField { objectName: "ruleNote"; width: parent ? parent.width : 0; label: "Rule note"; placeholderText: "Why (optional)" }
        actions: [
            SuiButton { text: "Cancel"; onClicked: ruleDialog.reject() },
            SuiButton { text: "Always sort"; variant: "primary"; onClicked: ruleDialog.accept() }
        ]
        onAccepted: toasts.show("Rule added", { tone: "ok" })
    }

    SuiSheet {
        id: senderSheet
        objectName: "senderSheet"
        title: "Ada Lovelace"
        description: "ada@example.org · 14 messages"
        ColumnLayout {
            width: parent ? parent.width : 0
            spacing: SuiTheme.spaceMd
            SuiTrail {
                Layout.fillWidth: true
                label: "Recent decisions"
                steps: [
                    { title: "Notes on the engine", outcome: "Family", outcomeTone: "bucket3", via: "rule" },
                    { title: "Re: tables", outcome: "Family", outcomeTone: "bucket3", via: "model" }
                ]
            }
            SuiTextField { Layout.fillWidth: true; label: "Display name"; text: "Ada Lovelace" }
        }
        actions: [ SuiButton { text: "Done"; variant: "primary"; onClicked: senderSheet.close() } ]
    }

    SuiShortcutOverlay {
        id: shortcutOverlay
        objectName: "shortcutOverlay"
        shortcuts: [
            { group: "Navigation", keys: ["j"], description: "Next message" },
            { group: "Navigation", keys: ["k"], description: "Previous message" },
            { group: "Navigation", keys: ["Enter"], description: "Open message" },
            { group: "Sorting", keys: ["1", "8"], separator: "–", description: "Sort into bucket 1–8" },
            { group: "Sorting", keys: ["w"], description: "Always for this sender" },
            { group: "Search", keys: ["/"], description: "Search mail" },
            { group: "Help", keys: ["?"], description: "Show this list" }
        ]
    }
}
