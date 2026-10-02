// SuiDialog: a modal dialog (title, content, actions).
//
//     SuiDialog {
//         id: confirm
//         title: "Always sort this sender?"
//         SuiText... / any single content item
//         actions: [
//             SuiButton { text: "Cancel"; onClicked: confirm.reject() },
//             SuiButton { text: "Always"; variant: "primary"; onClicked: confirm.accept() }
//         ]
//     }
//     SuiButton { text: "Rule…"; onClicked: confirm.open() }
//
// Focus: on open, focus moves into the dialog (`initialFocusItem`, else the
// first focusable control); Tab and Shift+Tab stay inside (focus trap);
// Escape rejects and closes; on close, focus returns to the item that had it
// when the dialog opened (`opener`, captured automatically unless set), with
// its ring if it had keyboard focus. Accessible role Dialog, named by `title`.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Dialog {
    id: control

    property string description: ""
    property Item initialFocusItem: null
    property Item opener: null
    property alias actions: actionsRow.data
    property bool dismissOnOutsideClick: true

    property Item _returnTo: null
    property int _returnReason: Qt.OtherFocusReason

    parent: T.Overlay.overlay
    modal: true
    focus: true
    closePolicy: T.Popup.CloseOnEscape | (dismissOnOutsideClick ? T.Popup.CloseOnPressOutside : T.Popup.NoAutoClose)
    anchors.centerIn: parent
    width: Math.min(SuiTheme.dialogWidth, parent ? parent.width - 2 * SuiTheme.spaceXl : SuiTheme.dialogWidth)
    implicitHeight: implicitHeaderHeight + implicitContentHeight + implicitFooterHeight + topPadding + bottomPadding
                    + (implicitHeaderHeight > 0 ? spacing : 0) + (implicitFooterHeight > 0 ? spacing : 0)
    padding: SuiTheme.spaceLg
    topPadding: SuiTheme.spaceLg
    spacing: SuiTheme.spaceMd
    font.pixelSize: SuiTheme.fontSizeMd

    function _isKeyboardFocused(item) {
        return !!item && (item.visualFocus === true || item.keyboardInteraction === true)
    }
    function _firstFocusable() {
        let item = control.contentItem.nextItemInFocusChain(true)
        for (let n = 0; item && n < 200; ++n) {
            if (control.contentItem === item || _inside(item))
                return item
            item = item.nextItemInFocusChain(true)
        }
        return null
    }
    function _inside(item) {
        const root = control.contentItem.parent  // the popup item
        for (let i = item; i; i = i.parent) {
            if (i === root)
                return true
        }
        return false
    }

    onAboutToShow: {
        const window = parent ? parent.Window.window : null
        _returnTo = opener !== null ? opener : (window ? window.activeFocusItem : null)
        _returnReason = _isKeyboardFocused(_returnTo) ? Qt.TabFocusReason : Qt.OtherFocusReason
    }
    onOpened: {
        const target = initialFocusItem !== null ? initialFocusItem : _firstFocusable()
        if (target)
            target.forceActiveFocus(_returnReason === Qt.TabFocusReason ? Qt.TabFocusReason : Qt.PopupFocusReason)
    }
    onClosed: {
        const target = _returnTo
        _returnTo = null
        if (!target || !target.visible || !target.enabled)
            return
        target.forceActiveFocus(_returnReason)
        // The popup's exit may already have handed focus back to the window's
        // content (OtherFocusReason); a control then needs its reason restored
        // for its ring (visualFocus).
        if (target.activeFocus && target.focusReason !== undefined)
            target.focusReason = _returnReason
    }

    T.Overlay.modal: Rectangle {
        color: SuiTheme.backdrop
        Behavior on opacity { NumberAnimation { duration: SuiTheme.duration } }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: SuiTheme.duration }
        NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: SuiTheme.duration; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: SuiTheme.duration }
    }

    header: ColumnLayout {
        spacing: SuiTheme.spaceXs
        visible: control.title !== "" || control.description !== ""
        Text {
            textFormat: Text.PlainText
            objectName: "title"
            text: control.title
            visible: text !== ""
            font.pixelSize: SuiTheme.fontSizeLg
            font.weight: SuiTheme.fontWeightStrong
            color: SuiTheme.textStrong
            wrapMode: Text.Wrap
            leftPadding: SuiTheme.spaceLg
            rightPadding: SuiTheme.spaceLg
            topPadding: SuiTheme.spaceLg
            Layout.fillWidth: true
            Accessible.role: Accessible.Heading
            Accessible.name: text
        }
        Text {
            textFormat: Text.PlainText
            objectName: "description"
            text: control.description
            visible: text !== ""
            font.pixelSize: SuiTheme.fontSizeMd
            color: SuiTheme.muted
            wrapMode: Text.Wrap
            leftPadding: SuiTheme.spaceLg
            rightPadding: SuiTheme.spaceLg
            Layout.fillWidth: true
        }
    }

    footer: Item {
        visible: actionsRow.children.length > 0
        implicitHeight: visible ? actionsRow.implicitHeight + SuiTheme.spaceLg : 0
        implicitWidth: actionsRow.implicitWidth + 2 * SuiTheme.spaceLg
        Row {
            id: actionsRow
            objectName: "actions"
            spacing: SuiTheme.spaceSm
            anchors.right: parent.right
            anchors.rightMargin: SuiTheme.spaceLg
            anchors.top: parent.top
            layoutDirection: Qt.LeftToRight
        }
    }

    background: Rectangle {
        objectName: "background"
        radius: SuiTheme.radiusLg
        color: SuiTheme.popover
        border.width: 1
        border.color: SuiTheme.borderStrong
    }
}
