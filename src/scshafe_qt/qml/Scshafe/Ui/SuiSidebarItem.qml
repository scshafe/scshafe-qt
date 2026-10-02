// SuiSidebarItem: one navigation entry (icon, label, count, health dot).
//
// Used by SuiSidebarList (which drives `selected` and `keyboardFocus`), or on
// its own. `status`: "ok" | "held" | "failing" | "none" draws a health dot;
// the status and count are in the accessible description, since the dot is
// colour only.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.ItemDelegate {
    id: control

    property string iconName: ""
    property int count: -1
    property string status: "none"
    property bool selected: false
    // Draw the keyboard focus ring. Standalone: keyboard focus (visualFocus);
    // SuiSidebarList sets it for its current entry.
    property bool keyboardFocus: visualFocus
    // A pointer press on this entry (not a keyboard press): lists use it to
    // tell keyboard focus from pointer focus.
    signal pointerPressed()

    readonly property string statusText: status === "ok" ? "healthy"
                                         : status === "held" ? "held"
                                         : status === "failing" ? "failing" : ""

    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(SuiTheme.rowHeight, implicitContentHeight + topPadding + bottomPadding)
    leftPadding: SuiTheme.spaceSm
    rightPadding: SuiTheme.spaceSm
    topPadding: SuiTheme.spaceXs
    bottomPadding: SuiTheme.spaceXs
    spacing: SuiTheme.spaceSm
    hoverEnabled: true
    highlighted: selected
    focusPolicy: Qt.StrongFocus  // SuiSidebarList sets NoFocus (one Tab stop for the list)
    opacity: enabled ? 1 : SuiTheme.disabledOpacity
    font.pixelSize: SuiTheme.fontSizeMd
    font.weight: selected ? SuiTheme.fontWeightStrong : SuiTheme.fontWeightNormal

    Accessible.role: Accessible.ListItem
    Accessible.name: text
    Accessible.description: [count >= 0 ? count + (count === 1 ? " item" : " items") : "",
                             statusText].filter(s => s !== "").join(", ")
    Accessible.selectable: true
    Accessible.selected: selected
    Accessible.onPressAction: control.click()

    TapHandler {
        gesturePolicy: TapHandler.DragThreshold
        onPressedChanged: if (pressed) control.pointerPressed()
    }

    contentItem: RowLayout {
        spacing: control.spacing
        SuiIcon {
            objectName: "icon"
            visible: control.iconName !== ""
            name: control.iconName
            color: control.selected ? SuiTheme.accent : SuiTheme.muted
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            textFormat: Text.PlainText
            objectName: "label"
            text: control.text
            font: control.font
            color: control.selected ? SuiTheme.textStrong : SuiTheme.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
        }
        Rectangle {
            objectName: "statusDot"
            visible: control.status === "ok" || control.status === "held" || control.status === "failing"
            implicitWidth: SuiTheme.statusDotSize
            implicitHeight: SuiTheme.statusDotSize
            radius: width / 2
            color: SuiTheme.statusColor(control.status)
            Layout.alignment: Qt.AlignVCenter
        }
        SuiBadge {
            objectName: "count"
            count: control.count
            tone: control.selected ? "info" : "neutral"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    background: Rectangle {
        objectName: "background"
        implicitWidth: 160
        radius: SuiTheme.radiusSm
        color: control.selected ? SuiTheme.accentSubtle
               : control.hovered || control.down ? SuiTheme.bgHover : "transparent"
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { inset: true; visible: control.keyboardFocus }
    }
}
