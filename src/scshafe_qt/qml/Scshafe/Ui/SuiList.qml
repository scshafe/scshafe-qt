// SuiList: a single-selection list (a ListView) for SuiListRow delegates.
//
//     SuiList {
//         id: inbox
//         label: "Messages"
//         model: messages
//         delegate: SuiListRow { title: model.sender; subtitle: model.subject; meta: model.time }
//         onCurrentIndexChanged: app.show(currentIndex)      // selection
//         onActivated: (index) => app.open(index)            // Enter / double-click
//     }
//     Shortcut { sequence: "j"; onActivated: inbox.selectNext() }   // from anywhere
//
// Selection is `currentIndex` (one row, -1 for none). With the list focused:
// Down / `j` and Up / `k` emit `nextRequested()` / `previousRequested()` and,
// while `autoNavigate` is true, move the selection; Home/End/PageUp/PageDown
// move it too; Enter/Return emit `activated(index)`. The signals are the hooks
// an app binds to (or sets `autoNavigate: false` and decides itself);
// `selectNext()` etc. are the same moves for the app's own shortcuts.
// `vimKeys: false` turns off j/k.
import QtQuick

ListView {
    id: list

    property string label: "List"
    property bool autoNavigate: true
    property bool vimKeys: true
    signal nextRequested()
    signal previousRequested()
    signal activated(int index)

    // :focus-visible for the list: true after keyboard use, false after a pointer press.
    property bool keyboardInteraction: true
    property bool _pointerFocus: false

    function selectIndex(index) {
        if (count === 0)
            return
        currentIndex = Math.max(0, Math.min(count - 1, index))
        positionViewAtIndex(currentIndex, ListView.Contain)
    }
    function selectNext() { selectIndex(currentIndex < 0 ? 0 : currentIndex + 1) }
    function selectPrevious() { selectIndex(currentIndex < 0 ? 0 : currentIndex - 1) }
    function selectFirst() { selectIndex(0) }
    function selectLast() { selectIndex(count - 1) }
    function activateCurrent() {
        if (currentIndex >= 0 && currentIndex < count)
            activated(currentIndex)
    }

    activeFocusOnTab: true
    keyNavigationEnabled: false
    highlightFollowsCurrentItem: false
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Accessible.role: Accessible.List
    Accessible.name: label

    onActiveFocusChanged: {
        if (activeFocus) {
            if (!_pointerFocus)
                keyboardInteraction = true
            _pointerFocus = false
        }
    }

    Keys.onPressed: (event) => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        const page = Math.max(1, Math.floor(height / SuiTheme.listRowHeight) - 1)
        const key = event.key
        if (key === Qt.Key_Down || (vimKeys && key === Qt.Key_J && event.text === "j")) {
            nextRequested()
            if (autoNavigate)
                selectNext()
        } else if (key === Qt.Key_Up || (vimKeys && key === Qt.Key_K && event.text === "k")) {
            previousRequested()
            if (autoNavigate)
                selectPrevious()
        } else if (key === Qt.Key_Home) {
            selectFirst()
        } else if (key === Qt.Key_End) {
            selectLast()
        } else if (key === Qt.Key_PageDown) {
            selectIndex(currentIndex + page)
        } else if (key === Qt.Key_PageUp) {
            selectIndex(currentIndex - page)
        } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            activateCurrent()
        } else {
            return
        }
        keyboardInteraction = true
        event.accepted = true
    }

    // SuiListRow reports pointer presses here (it finds the list through
    // ListView.view): select and focus without the ring.
    function _rowPressed(index) {
        keyboardInteraction = false
        _pointerFocus = true
        if (index >= 0)
            currentIndex = index
        forceActiveFocus(Qt.MouseFocusReason)
    }
}
