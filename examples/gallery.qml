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

    // The gallery's pages (the sidebar's first section); the mail sample is the first.
    readonly property var pages: [
        { section: "Gallery", text: "Mail", iconName: "mail", page: "mail" },
        { section: "Gallery", text: "Typography", iconName: "text", page: "type" },
        { section: "Gallery", text: "Controls", iconName: "sliders", page: "controls" }
    ]
    property string page: "mail"
    function showPage(id) {
        page = id
        sidebar.selectedIndex = pages.findIndex(p => p.page === id)
    }

    // Hooks for examples/gallery.py --screenshot and the screenshot test.
    function showSample() {
        showPage("mail")
        toasts.show("Mail from this sender now goes to Family.", { title: "Sorted", tone: "ok", actionText: "Undo", timeout: 0 })
        inbox.forceActiveFocus(Qt.TabFocusReason)  // as if tabbed to: the ring shows
    }
    function showType() { showPage("type") }
    function showControls() { showPage("controls") }
    function openDialog() { ruleDialog.open() }
    function openSheet() { senderSheet.open() }
    function openShortcuts() { shortcutOverlay.open() }
    function closeAll() {
        ruleDialog.close()
        senderSheet.close()
        shortcutOverlay.close()
        toasts.clear()
        showPage("mail")
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
            model: root.pages.concat([
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
            ])
            onActivated: (index) => {
                const entry = model[index]
                root.page = entry.page !== undefined ? entry.page : "mail"
                if (entry.page === undefined)
                    toasts.show("Opened " + entry.text)
            }
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

            StackLayout {
                objectName: "pages"
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: Math.max(0, root.pages.findIndex(p => p.page === root.page))

                ColumnLayout {
                    objectName: "mailPage"
                    spacing: 0
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

                Flickable {
                    objectName: "typePage"
                    contentHeight: typeColumn.implicitHeight + 2 * SuiTheme.spaceXl
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: typeColumn
                        x: SuiTheme.spaceXl
                        y: SuiTheme.spaceXl
                        width: Math.min(parent.width - 2 * SuiTheme.spaceXl, 720)
                        spacing: SuiTheme.spaceLg

                        SuiText { text: "Typography"; variant: "title" }
                        SuiText {
                            Layout.fillWidth: true
                            variant: "caption"
                            wrapMode: Text.Wrap
                            text: "SuiText draws the type scale: one variant per role, each from SuiTheme.textStyles. "
                                  + "The heading variants are announced as headings."
                        }
                        GridLayout {
                            objectName: "typeSpecimens"
                            columns: 2
                            columnSpacing: SuiTheme.spaceLg
                            rowSpacing: SuiTheme.spaceSm
                            Repeater {
                                model: SuiTheme.textVariants
                                SuiText {
                                    required property string modelData
                                    Layout.row: SuiTheme.textVariants.indexOf(modelData)
                                    Layout.column: 0
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData
                                    variant: "code"
                                    tone: "muted"
                                }
                            }
                            Repeater {
                                model: SuiTheme.textVariants
                                SuiText {
                                    required property string modelData
                                    Layout.row: SuiTheme.textVariants.indexOf(modelData)
                                    Layout.column: 1
                                    Layout.fillWidth: true
                                    text: modelData === "code" ? "take-0042.wav  48000 Hz" : "Session 12: morning reads"
                                    variant: modelData
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        SuiText { text: "Tones"; variant: "section" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: SuiTheme.spaceMd
                            Repeater {
                                model: ["default", "strong", "muted", "accent", "info", "ok", "warn", "danger", "bucket5"]
                                SuiText { required property string modelData; text: modelData; tone: modelData }
                            }
                        }
                        RowLayout {
                            spacing: SuiTheme.spaceLg
                            SuiText { text: "Input"; variant: "label" }
                            SuiText { text: "-12.4 dB"; variant: "subheading"; tabular: true }
                            SuiText { text: "peak -3.1 dB"; tone: "warn"; tabular: true }
                        }
                    }
                }

                Flickable {
                    objectName: "controlsPage"
                    contentHeight: controlsColumn.implicitHeight + 2 * SuiTheme.spaceXl
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: controlsColumn
                        x: SuiTheme.spaceXl
                        y: SuiTheme.spaceXl
                        width: Math.min(parent.width - 2 * SuiTheme.spaceXl, 720)
                        spacing: SuiTheme.spaceLg

                        SuiText { text: "Form controls"; variant: "title" }
                        GridLayout {
                            objectName: "formControls"
                            columns: 2
                            columnSpacing: SuiTheme.space2xl
                            rowSpacing: SuiTheme.spaceMd
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                spacing: SuiTheme.spaceMd
                                SuiText { text: "Processing"; variant: "section" }
                                SuiCheckBox {
                                    objectName: "normaliseCheck"
                                    Layout.fillWidth: true
                                    text: "Normalise loudness"
                                    description: "Every take to -23 LUFS."
                                    checked: true
                                }
                                SuiCheckBox { text: "Trim silence"; description: "Some takes"; tristate: true; checkState: Qt.PartiallyChecked }
                                SuiCheckBox { text: "Keep raw files"; enabled: false }
                                SuiSwitch {
                                    objectName: "monitorSwitch"
                                    Layout.fillWidth: true
                                    text: "Monitor input"
                                    description: "Hear the microphone while recording."
                                    checked: true
                                }
                                SuiSwitch { text: "Noise gate" }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                Layout.fillWidth: true
                                spacing: SuiTheme.spaceMd
                                SuiText { text: "Sample rate"; variant: "section" }
                                Column {
                                    objectName: "rateGroup"
                                    spacing: SuiTheme.spaceXs
                                    Accessible.role: Accessible.Grouping
                                    Accessible.name: "Sample rate"
                                    SuiRadioButton { text: "16 kHz"; description: "For speech models" }
                                    SuiRadioButton { text: "44.1 kHz" }
                                    SuiRadioButton { text: "48 kHz"; checked: true }
                                }
                                SuiText { text: "Input"; variant: "label" }
                                SuiSelect {
                                    objectName: "inputSelect"
                                    label: "Input"
                                    model: ["Desk microphone", "Headset", "Line in", "System audio"]
                                }
                                SuiText { text: "Gain"; variant: "label" }
                                SuiSlider {
                                    objectName: "gainSlider"
                                    Layout.fillWidth: true
                                    label: "Input gain"
                                    from: -24
                                    to: 24
                                    stepSize: 0.5
                                    value: 6
                                    unit: "dB"
                                    showValue: true
                                }
                            }
                        }

                        SuiText { text: "Progress"; variant: "title"; Layout.topMargin: SuiTheme.spaceSm }
                        ColumnLayout {
                            objectName: "progressDemo"
                            Layout.fillWidth: true
                            spacing: SuiTheme.spaceMd
                            SuiProgressBar {
                                objectName: "transcribeProgress"
                                Layout.fillWidth: true
                                label: "Transcribing session 12"
                                value: 0.42
                            }
                            SuiProgressBar {
                                id: exportProgress
                                objectName: "exportProgress"
                                Layout.fillWidth: true
                                label: "Exporting takes"
                                from: 0
                                to: 12
                                value: 5
                                valueText: Math.round(value) + " of 12 files"
                                tone: value >= to ? "ok" : "accent"
                                cancellable: exportTimer.running
                                onCancelRequested: {
                                    exportTimer.stop()
                                    toasts.show("Export cancelled at " + valueText, { tone: "warn" })
                                }
                            }
                            RowLayout {
                                spacing: SuiTheme.spaceSm
                                SuiButton {
                                    objectName: "exportButton"
                                    text: exportTimer.running ? "Exporting…" : "Export again"
                                    enabled: !exportTimer.running
                                    onClicked: {
                                        exportProgress.value = 0
                                        exportTimer.start()
                                    }
                                }
                                SuiText { text: "The cancel button shows while the export runs."; variant: "caption" }
                            }
                            Timer {
                                id: exportTimer
                                interval: 250
                                repeat: true
                                onTriggered: {
                                    exportProgress.value += 0.5
                                    if (exportProgress.value >= exportProgress.to)
                                        stop()
                                }
                            }
                        }
                    }
                }
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

                SuiText { text: "Why it was sorted"; variant: "heading" }
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

                SuiText { text: "Tones"; variant: "heading" }
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

                SuiText { text: "Fields"; variant: "heading" }
                SuiTextField { objectName: "noteField"; Layout.fillWidth: true; label: "Note"; placeholderText: "Add a note" }
                RowLayout {
                    spacing: SuiTheme.spaceSm
                    SuiButton { text: "Primary"; variant: "primary" }
                    SuiButton { text: "Secondary"; variant: "secondary" }
                    SuiButton { text: "Ghost"; variant: "ghost" }
                    SuiIconButton { label: "Add"; icon.name: "plus"; variant: "default" }
                }

                SuiText { text: "Banners"; variant: "heading" }
                SuiBanner { Layout.fillWidth: true; tone: "info"; text: "Live updates are on." }
                SuiBanner { Layout.fillWidth: true; tone: "danger"; title: "Sign-in expired"; text: "Sign in again to keep sorting."; dismissible: true }

                SuiText { text: "Empty state"; variant: "heading" }
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
