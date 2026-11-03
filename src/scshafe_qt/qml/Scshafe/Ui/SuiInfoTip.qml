// SuiInfoTip: a small info button that shows a popover with details, so
// secondary text can leave the layout.
//
//     SuiInfoTip {
//         title: "Trim"
//         text: "Drag a handle to keep part of the take. <b>Save</b> writes the trim."
//     }
//
// - Hover opens it after `delay` (SuiTheme.infoTipDelay); it closes
//   SuiTheme.infoTipCloseDelay after the pointer leaves both the button and the
//   popover (moving into the popover keeps it, for its links).
// - A click opens and pins it: it stays until a click outside or on the button
//   again. A click on a tip hover opened pins it.
// - Keyboard: a Tab stop (ring for keyboard focus only); Space / Return toggle,
//   Escape closes (and propagates when it is closed); focus leaving closes a tip
//   the keyboard opened.
// - It never takes focus: a click does not focus the button and the popover is
//   never focused, so an app's keys keep working while a tip is open.
// - Placement: centred on the button, `placement` "below" (default) or "above";
//   it flips when that side has no room and the other has more, and stays
//   SuiTheme.spaceSm inside the window.
// - `text` is a small markup subset (textFormat Text.StyledText, the default):
//   <b> <strong> <i> <em> <code> <br> <p> <ul> <ol> <li> <a href="...">, every
//   other attribute dropped; any other tag, or a stray < or &, shows as text, so
//   nothing (no <img>) is ever fetched. Links emit linkActivated(link) and open
//   nothing themselves. Text.PlainText shows `text` as it is.
// - Accessible: a Button named by `label` ("About <title>" by default),
//   described by the title and the plain body; the popover is a HelpBalloon.
import QtQuick
import QtQuick.Templates as T

T.Button {
    id: tip

    property string title: ""
    // `text` (the body) is AbstractButton's own property.
    property int textFormat: Text.StyledText
    property string label: title !== "" ? "About " + title : "More information"
    // "info" | "help"
    property string iconName: "info"
    // "below" | "above": the preferred side.
    property string placement: "below"
    property int delay: SuiTheme.infoTipDelay
    readonly property bool opened: _mode !== ""
    signal linkActivated(string link)

    // "" (closed) | "hover" | "pinned" (a click) | "keyboard"
    property string _mode: ""
    property bool _below: placement !== "above"
    readonly property int _bodyFormat: textFormat === Text.PlainText ? Text.PlainText : Text.StyledText
    readonly property string _body: textFormat === Text.PlainText ? text : _markup(text)
    readonly property string _plainBody: textFormat === Text.PlainText ? text : _plain(_body)

    function open() { _show("pinned") }
    function close() {
        _mode = ""
        openTimer.stop()
        closeTimer.stop()
        popup.close()
    }
    function toggle() {
        if (opened)
            close()
        else
            open()
    }
    function _show(mode) {
        _mode = mode
        openTimer.stop()
        closeTimer.stop()
        if (!popup.visible)
            popup.open()
    }
    function _leaveSoon() {
        if (_mode === "hover" && !hover.hovered && !popupHover.hovered)
            closeTimer.restart()
    }

    // The markup subset as Qt StyledText: allowed tags pass (attributes dropped
    // but <a href>), everything else is escaped so it shows as text.
    function _markup(source) {
        const allowed = { b: "b", strong: "b", i: "i", em: "i", code: "tt", br: "br", p: "p",
                          ul: "ul", ol: "ol", li: "li", a: "a" }
        const tag = /<(\/?)([A-Za-z][A-Za-z0-9]*)((?:\s+[A-Za-z_:][-A-Za-z0-9_:.]*(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'<>=`]+))?)*)\s*(\/?)>/g
        const escape = (s) => s.replace(/&(?!(?:amp|lt|gt|quot|apos|nbsp);)/g, "&amp;")
                               .replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const attr = (s) => s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        const input = String(source)
        let out = ""
        let last = 0
        for (let m = tag.exec(input); m !== null; m = tag.exec(input)) {
            out += escape(input.slice(last, m.index)).replace(/\n/g, "<br>")
            last = tag.lastIndex
            const name = allowed[m[2].toLowerCase()]
            if (name === undefined) {
                out += escape(m[0])
            } else if (m[1] === "/") {
                out += name === "br" ? "" : "</" + name + ">"
            } else if (name === "a") {
                const href = /\shref\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'<>=`]+))/i.exec(m[3])
                out += href ? "<a href=\"" + attr(href[1] ?? href[2] ?? href[3]) + "\">" : escape(m[0])
            } else {
                out += "<" + name + ">"
            }
        }
        return out + escape(input.slice(last)).replace(/\n/g, "<br>")
    }
    // The sanitised markup as plain text (accessible description).
    function _plain(markup) {
        const entities = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " }
        return markup.replace(/<br>|<\/p>|<\/li>/g, " ").replace(/<[^>]*>/g, "")
                     .replace(/&(amp|lt|gt|quot|apos|nbsp);/g, (m, e) => entities[e])
                     .replace(/\s+/g, " ").trim()
    }
    function _place() {
        const overlay = T.Overlay.overlay
        if (!overlay)
            return
        const top = tip.mapToItem(overlay, 0, 0).y
        const need = popup.height + SuiTheme.spaceXs + SuiTheme.spaceSm
        const below = overlay.height - top - tip.height
        const above = top
        _below = placement !== "above" ? below >= need || below >= above
                                       : !(above >= need || above >= below)
    }

    implicitWidth: SuiTheme.infoTipSize
    implicitHeight: SuiTheme.infoTipSize
    padding: (SuiTheme.infoTipSize - SuiTheme.iconSize) / 2
    // Keyboard only: a click must not take focus from the app's keys.
    focusPolicy: Qt.TabFocus
    hoverEnabled: true
    opacity: enabled ? 1 : SuiTheme.disabledOpacity

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: title !== "" && _plainBody !== "" ? title + ". " + _plainBody : title + _plainBody
    Accessible.onPressAction: tip.toggle()

    onClicked: {
        if (_mode === "pinned")
            close()
        else
            _show("pinned")
    }
    onActiveFocusChanged: if (!activeFocus && _mode === "keyboard") close()
    onEnabledChanged: if (!enabled) close()
    onVisibleChanged: if (!visible) close()

    Keys.onPressed: (event) => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return
        switch (event.key) {
        case Qt.Key_Space: case Qt.Key_Return: case Qt.Key_Enter:
            if (tip.opened)
                tip.close()
            else
                tip._show("keyboard")
            break
        case Qt.Key_Escape:
            if (!tip.opened)
                return
            tip.close()
            break
        default:
            return
        }
        event.accepted = true
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                closeTimer.stop()
                if (tip._mode === "" && tip.enabled)
                    openTimer.restart()
            } else {
                openTimer.stop()
                tip._leaveSoon()
            }
        }
    }
    Timer {
        id: openTimer
        interval: tip.delay
        onTriggered: if (hover.hovered && tip._mode === "") tip._show("hover")
    }
    Timer {
        id: closeTimer
        interval: SuiTheme.infoTipCloseDelay
        onTriggered: if (tip._mode === "hover") tip.close()
    }

    contentItem: Item {
        implicitWidth: SuiTheme.iconSize
        implicitHeight: SuiTheme.iconSize
        SuiIcon {
            objectName: "icon"
            anchors.centerIn: parent
            name: tip.iconName
            size: SuiTheme.iconSize
            color: tip.opened ? SuiTheme.accent : (tip.hovered || tip.visualFocus) && tip.enabled ? SuiTheme.text : SuiTheme.muted
            Behavior on color { ColorAnimation { duration: SuiTheme.duration } }
        }
    }

    background: Rectangle {
        objectName: "background"
        radius: height / 2
        color: tip.opened ? SuiTheme.accentSubtle : tip.hovered && tip.enabled ? SuiTheme.bgHover : "transparent"
        Behavior on color { ColorAnimation { duration: SuiTheme.duration } }

        SuiFocusRing { visible: tip.visualFocus; targetRadius: parent.radius }
    }

    T.Popup {
        id: popup
        objectName: "infoTipPopup"
        // Never focused: the app's keys stay where they were.
        focus: false
        modal: false
        closePolicy: T.Popup.CloseOnPressOutsideParent
        margins: SuiTheme.spaceSm
        x: Math.round((tip.width - width) / 2)
        y: tip._below ? tip.height + SuiTheme.spaceXs : -height - SuiTheme.spaceXs
        width: Math.min(SuiTheme.infoTipMaxWidth, Math.max(titleText.implicitWidth, bodyText.implicitWidth))
               + leftPadding + rightPadding
        implicitHeight: implicitContentHeight + topPadding + bottomPadding
        topPadding: SuiTheme.spaceSm
        bottomPadding: SuiTheme.spaceSm
        leftPadding: SuiTheme.spaceMd
        rightPadding: SuiTheme.spaceMd

        onAboutToShow: tip._place()
        onHeightChanged: if (visible) tip._place()
        // Closing by a click outside (closePolicy) as well as by close().
        onAboutToHide: {
            tip._mode = ""
            closeTimer.stop()
        }

        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: SuiTheme.duration } }
        exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: SuiTheme.duration } }

        contentItem: Column {
            objectName: "infoTipContent"
            spacing: SuiTheme.spaceXs
            Accessible.role: Accessible.HelpBalloon
            Accessible.name: tip.title !== "" ? tip.title : tip.label
            Accessible.description: tip._plainBody

            HoverHandler {
                id: popupHover
                cursorShape: bodyText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onHoveredChanged: {
                    if (hovered)
                        closeTimer.stop()
                    else
                        tip._leaveSoon()
                }
            }

            Text {
                textFormat: Text.PlainText
                id: titleText
                objectName: "infoTipTitle"
                width: parent.width
                visible: text !== ""
                text: tip.title
                font.pixelSize: SuiTheme.fontSizeMd
                font.weight: SuiTheme.fontWeightStrong
                color: SuiTheme.textStrong
                wrapMode: Text.Wrap
                Accessible.ignored: true
            }
            Text {
                textFormat: tip._bodyFormat  // the sanitised subset (_markup) or plain text
                id: bodyText
                objectName: "infoTipBody"
                width: parent.width
                visible: text !== ""
                text: tip._body
                font.pixelSize: SuiTheme.fontSizeSm
                lineHeight: SuiTheme.textStyle("caption").leading  // fontSizeSm's leading
                color: SuiTheme.text
                linkColor: SuiTheme.accent
                wrapMode: Text.Wrap
                onLinkActivated: (link) => tip.linkActivated(link)
                Accessible.ignored: true
            }
        }

        background: Rectangle {
            objectName: "infoTipBackground"
            radius: SuiTheme.radiusLg
            color: SuiTheme.popover
            border.width: 1
            border.color: SuiTheme.borderStrong
        }
    }
}
