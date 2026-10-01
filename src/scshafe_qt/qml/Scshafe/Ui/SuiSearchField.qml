// SuiSearchField: a search input with a leading search icon and a clear button.
//
// - `/` (focusShortcut; "" disables) focuses the field from anywhere in the
//   window: `focusRequested()` fires first (the hook an app uses to, e.g.,
//   reveal a collapsed pane), then the field takes focus and selects its text.
//   Text inputs keep their own `/`: the shortcut does not fire while one has
//   focus.
// - Escape clears a non-empty field (`cleared()`); on an empty field it
//   propagates (so a dialog can close).
// - The clear button is not in the Tab order (Escape does the same).
import QtQuick

SuiTextField {
    id: control

    property string focusShortcut: "/"
    signal focusRequested()
    signal cleared()

    label: "Search"
    placeholderText: "Search"
    leftPadding: SuiTheme.spaceSm + SuiTheme.iconSize + SuiTheme.spaceXs + 2
    rightPadding: clearButton.visible ? clearButton.width + SuiTheme.spaceXs : SuiTheme.spaceSm
    inputMethodHints: Qt.ImhNoPredictiveText

    function clear() {
        if (text === "")
            return
        text = ""
        cleared()
    }

    // Focus the field as `/` does (for an app's own shortcut or menu item).
    function focusSearch() {
        focusRequested()
        forceActiveFocus(Qt.ShortcutFocusReason)
        selectAll()
    }

    Keys.onEscapePressed: (event) => {
        if (control.text !== "") {
            control.clear()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    SuiIcon {
        objectName: "searchIcon"
        name: "search"
        size: SuiTheme.iconSize
        color: SuiTheme.muted
        x: SuiTheme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
    }

    SuiIconButton {
        id: clearButton
        objectName: "clearButton"
        label: "Clear search"
        icon.name: "close"
        iconSize: SuiTheme.iconSizeSm
        focusPolicy: Qt.NoFocus
        visible: control.length > 0
        width: control.height - 2 * SuiTheme.spaceXs
        height: width
        padding: (width - iconSize) / 2
        anchors.right: parent.right
        anchors.rightMargin: SuiTheme.spaceXs
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            control.clear()
            control.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    Shortcut {
        sequence: control.focusShortcut
        enabled: control.focusShortcut !== "" && control.enabled && control.visible
        context: Qt.WindowShortcut
        onActivated: control.focusSearch()
    }
}
