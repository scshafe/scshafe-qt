// SuiToastHost: shows SuiToasts stacked in a corner of its area. Put one at
// the top of the window (z above the content) and call `show()`:
//
//     SuiToastHost { id: toasts; anchors.fill: parent; z: 100 }
//     ...
//     toasts.show("Sorted into Receipts", { tone: "ok", actionText: "Undo",
//                                          onAction: () => app.undo() })
//
// show(text, options) returns an id; options: title, tone ("info" | "ok" |
// "warn" | "danger"), timeout (ms, 0 = until dismissed), actionText, onAction.
// dismiss(id) and clear() remove toasts. At most `maxToasts` show (the oldest
// goes). Each toast is announced to assistive technology (Accessible.announce,
// polite; assertive for danger). The host only takes input where a toast is.
import QtQuick

Item {
    id: host

    property int maxToasts: 4
    // Qt.AlignBottom | Qt.AlignRight (default), or Qt.AlignTop | Qt.AlignRight.
    property int alignment: Qt.AlignBottom | Qt.AlignRight
    property int margin: SuiTheme.spaceLg
    readonly property int count: toastModel.count
    signal actionTriggered(int toastId)

    property int _nextId: 1
    property var _actions: ({})

    function show(text, options) {
        const o = options || {}
        const id = _nextId++
        if (o.onAction)
            _actions[id] = o.onAction
        while (toastModel.count >= Math.max(1, maxToasts))
            _removeAt(0)
        toastModel.append({
            toastId: id,
            text: String(text || ""),
            title: o.title !== undefined ? String(o.title) : "",
            tone: o.tone !== undefined ? String(o.tone) : "info",
            timeout: o.timeout !== undefined ? Number(o.timeout) : SuiTheme.toastTimeout,
            actionText: o.actionText !== undefined ? String(o.actionText) : ""
        })
        _announce((o.title ? o.title + ": " : "") + text, o.tone === "danger")
        return id
    }
    function dismiss(id) {
        for (let i = 0; i < toastModel.count; ++i) {
            if (toastModel.get(i).toastId === id) {
                _removeAt(i)
                return true
            }
        }
        return false
    }
    function clear() {
        while (toastModel.count > 0)
            _removeAt(0)
    }
    function _removeAt(i) {
        delete _actions[toastModel.get(i).toastId]
        toastModel.remove(i)
    }
    function _announce(message, assertive) {
        try {
            host.Accessible.announce(message, assertive ? Accessible.Assertive : Accessible.Polite)
        } catch (e) {
            // Accessible.announce is Qt 6.8+; older engines stay silent.
        }
    }

    ListModel { id: toastModel }

    ListView {
        id: stack
        objectName: "toastStack"
        width: SuiTheme.toastWidth
        height: Math.min(contentHeight, host.height - 2 * host.margin)
        x: (host.alignment & Qt.AlignLeft) ? host.margin : host.width - width - host.margin
        y: (host.alignment & Qt.AlignTop) ? host.margin : host.height - height - host.margin
        interactive: false
        spacing: SuiTheme.spaceSm
        verticalLayoutDirection: (host.alignment & Qt.AlignTop) ? ListView.TopToBottom : ListView.BottomToTop
        model: toastModel
        Accessible.ignored: true

        delegate: SuiToast {
            objectName: "toast"
            required property int toastId
            required tone
            required title
            required text
            required timeout
            required actionText
            width: stack.width
            onDismissRequested: host.dismiss(toastId)
            onActionTriggered: {
                const action = host._actions[toastId]
                if (action)
                    action()
                host.actionTriggered(toastId)
            }
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: SuiTheme.duration }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: SuiTheme.duration; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: SuiTheme.duration }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: SuiTheme.duration; easing.type: Easing.OutCubic }
        }
    }
}
