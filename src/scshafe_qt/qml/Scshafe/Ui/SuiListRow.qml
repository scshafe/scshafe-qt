// SuiListRow: a two-line row for SuiList (sender / subject / time style).
//
//     delegate: SuiListRow {
//         title: model.sender; subtitle: model.subject; meta: model.time
//         unread: model.unread
//         SuiChip { text: model.bucket; tone: "bucket" + model.bucketNumber }   // trailing slot
//     }
//
// Children go to the trailing slot (chips, badges). States: `selected`
// (defaults to being the list's current item), `unread` (accent dot, strong
// title), hover. The accessible name reads unread, title, subtitle and meta.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.ItemDelegate {
    id: control

    property string title: ""
    property string subtitle: ""
    property string meta: ""
    property bool unread: false
    property bool selected: ListView.isCurrentItem
    // Draw the keyboard focus ring: in a SuiList, on its current row after
    // keyboard use; standalone, on keyboard focus.
    property bool keyboardFocus: _inSuiList ? ListView.isCurrentItem && _view.activeFocus && _view.keyboardInteraction
                                            : visualFocus
    default property alias trailing: trailingRow.data
    signal pointerPressed()

    readonly property var _view: ListView.view
    readonly property bool _inSuiList: !!_view && _view.keyboardInteraction !== undefined
    function _index() { return _view ? _view.indexAt(x + 1, y + 1) : -1 }

    text: title
    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(SuiTheme.listRowHeight, implicitContentHeight + topPadding + bottomPadding)
    leftPadding: SuiTheme.spaceMd
    rightPadding: SuiTheme.spaceMd
    topPadding: SuiTheme.spaceSm
    bottomPadding: SuiTheme.spaceSm
    hoverEnabled: true
    highlighted: selected
    focusPolicy: Qt.NoFocus
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd

    Accessible.role: Accessible.ListItem
    Accessible.name: [unread ? "Unread" : "", title, subtitle, meta].filter(s => s !== "").join(", ")
    Accessible.selectable: true
    Accessible.selected: selected
    Accessible.onPressAction: control.click()

    onPointerPressed: if (_inSuiList) _view._rowPressed(_index())
    onDoubleClicked: if (_inSuiList) _view.activated(_index())
    // Space on the focused row (AbstractButton) selects it.
    onClicked: if (_inSuiList) _view.currentIndex = _index()

    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed) control.pointerPressed()
    }

    contentItem: RowLayout {
        spacing: SuiTheme.spaceSm
        Rectangle {
            objectName: "unreadDot"
            implicitWidth: SuiTheme.statusDotSize
            implicitHeight: SuiTheme.statusDotSize
            radius: width / 2
            color: control.unread ? SuiTheme.accent : "transparent"
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: (titleText.implicitHeight - height) / 2
        }
        ColumnLayout {
            spacing: SuiTheme.spaceXs - 2
            Layout.fillWidth: true
            RowLayout {
                spacing: SuiTheme.spaceSm
                Layout.fillWidth: true
                Text {
                    id: titleText
                    objectName: "title"
                    text: control.title
                    font.pixelSize: SuiTheme.fontSizeMd
                    font.weight: control.unread ? SuiTheme.fontWeightBold : SuiTheme.fontWeightStrong
                    color: control.unread || control.selected ? SuiTheme.textStrong : SuiTheme.text
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    objectName: "meta"
                    visible: text !== ""
                    text: control.meta
                    font.pixelSize: SuiTheme.fontSizeSm
                    font.features: ({ "tnum": 1 })
                    color: SuiTheme.muted
                }
            }
            RowLayout {
                spacing: SuiTheme.spaceSm
                Layout.fillWidth: true
                Text {
                    objectName: "subtitle"
                    text: control.subtitle
                    font.pixelSize: SuiTheme.fontSizeMd
                    font.weight: control.unread ? SuiTheme.fontWeightStrong : SuiTheme.fontWeightNormal
                    color: control.unread ? SuiTheme.text : SuiTheme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Row {
                    id: trailingRow
                    objectName: "trailing"
                    spacing: SuiTheme.spaceXs
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: 240
        color: control.selected ? SuiTheme.accentSubtle
               : control.hovered || control.down ? SuiTheme.bgHover : "transparent"
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }

        Rectangle {  // divider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: SuiTheme.line
        }
        Rectangle {  // selection bar
            objectName: "selectionBar"
            visible: control.selected
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: SuiTheme.focusRingWidth + 1
            color: SuiTheme.accent
        }
        SuiFocusRing { inset: true; targetRadius: 0; visible: control.keyboardFocus }
    }
}
