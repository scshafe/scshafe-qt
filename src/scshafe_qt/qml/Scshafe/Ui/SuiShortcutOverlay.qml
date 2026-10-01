// SuiShortcutOverlay: the `?` overlay listing the app's keyboard shortcuts.
//
//     SuiShortcutOverlay {
//         shortcuts: [
//             { group: "Navigation", keys: ["j"], description: "Next message" },
//             { group: "Navigation", keys: ["k"], description: "Previous message" },
//             { group: "Sorting", keys: ["1", "8"], separator: "–", description: "Sort into bucket 1–8" },
//             { group: "Search", keys: ["/"], description: "Search" },
//         ]
//     }
//
// `?` (toggleShortcut; "" disables) opens and closes it from anywhere in the
// window except while a text field has focus; `toggle()` does the same. It is
// a SuiDialog: focus trap, Escape closes, focus returns to the opener. Each
// entry: `keys` (a string or a list of key names, drawn as SuiKbd),
// `description`, `group` (entries with the same group are listed together in
// first-seen order), `separator` (between keys; default "+").
import QtQuick
import QtQuick.Layouts

SuiDialog {
    id: control

    property var shortcuts: []
    property string toggleShortcut: "?"

    readonly property var groups: {
        const order = []
        const byName = {}
        const list = Array.isArray(shortcuts) ? shortcuts : []
        for (const s of list) {
            const g = s.group !== undefined ? String(s.group) : ""
            if (!(g in byName)) {
                byName[g] = []
                order.push(g)
            }
            byName[g].push(s)
        }
        return order.map(g => ({ name: g, items: byName[g] }))
    }

    function toggle() {
        if (opened || visible)
            close()
        else
            open()
    }

    title: "Keyboard shortcuts"
    width: Math.min(SuiTheme.dialogWidth + SuiTheme.space2xl * 3, parent ? parent.width - 2 * SuiTheme.spaceXl : 560)
    height: Math.min(implicitHeight, parent ? parent.height - 2 * SuiTheme.spaceXl : implicitHeight)

    actions: [
        SuiButton {
            objectName: "closeButton"
            text: "Close"
            onClicked: control.close()
        }
    ]

    // In the popup's data, the shortcut matches while the popup is closed
    // (Qt Quick Templates resolve a popup's shortcuts to its window) and is
    // not blocked by the popup itself when it is open.
    Shortcut {
        sequence: control.toggleShortcut
        enabled: control.toggleShortcut !== ""
        context: Qt.WindowShortcut
        onActivated: control.toggle()
    }

    Flickable {
        id: flick
        objectName: "shortcutList"
        clip: true
        implicitWidth: grid.implicitWidth
        implicitHeight: grid.implicitHeight
        contentWidth: width
        contentHeight: grid.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        Accessible.role: Accessible.List
        Accessible.name: control.title

        ColumnLayout {
            id: grid
            width: flick.width
            spacing: SuiTheme.spaceLg
            Repeater {
                model: control.groups
                delegate: ColumnLayout {
                    required property var modelData
                    spacing: SuiTheme.spaceXs
                    Layout.fillWidth: true
                    Text {
                        objectName: "groupHeader"
                        visible: modelData.name !== ""
                        text: modelData.name
                        font.pixelSize: SuiTheme.fontSizeXs
                        font.weight: SuiTheme.fontWeightBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.4
                        color: SuiTheme.muted
                        Accessible.role: Accessible.Heading
                        Accessible.name: text
                    }
                    Repeater {
                        model: modelData.items
                        delegate: RowLayout {
                            id: entryRow
                            required property var modelData
                            readonly property var keys: {
                                const k = modelData.keys
                                if (k !== null && typeof k === "object" && k.length !== undefined)
                                    return Array.from(k, String)
                                return [String(k)]
                            }
                            readonly property string separator: modelData.separator !== undefined ? modelData.separator : "+"
                            spacing: SuiTheme.spaceSm
                            Layout.fillWidth: true
                            Accessible.role: Accessible.ListItem
                            Accessible.name: keys.join(" " + separator + " ") + ": " + modelData.description
                            Row {
                                spacing: SuiTheme.spaceXs
                                Layout.preferredWidth: SuiTheme.space2xl * 4
                                Repeater {
                                    model: entryRow.keys
                                    delegate: Row {
                                        required property string modelData
                                        required property int index
                                        spacing: SuiTheme.spaceXs
                                        Text {
                                            visible: index > 0
                                            text: entryRow.separator
                                            font.pixelSize: SuiTheme.fontSizeXs
                                            color: SuiTheme.muted
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        SuiKbd { text: modelData }
                                    }
                                }
                            }
                            Text {
                                objectName: "shortcutDescription"
                                text: entryRow.modelData.description
                                font.pixelSize: SuiTheme.fontSizeMd
                                color: SuiTheme.text
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
