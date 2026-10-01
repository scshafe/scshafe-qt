// SuiIcon: a themed icon. Either a built-in vector icon by `name` (drawn with
// QtQuick.Shapes in a 16x16 grid, stroked in `color`) or an image `source`
// tinted with `color`. Decorative by default (ignored by accessibility); give
// it a `label` when the icon carries meaning on its own.
//
// Built-in names: see `names` (close, search, check, info, warning, danger,
// chevron-left/right/up/down, inbox, mail, archive, tag, clock, filter, plus,
// more, keyboard, panel-left, panel-right, sort, user, sun, moon, dot).
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls.impl as Impl

Item {
    id: icon

    property string name: ""
    property url source: ""
    property color color: SuiTheme.text
    property int size: SuiTheme.iconSize
    property string label: ""

    // 16x16 SVG path data, stroked (no fill).
    readonly property var paths: ({
        "close": "M4 4 L12 12 M12 4 L4 12",
        "search": "M11.5 7 A4.5 4.5 0 1 1 2.5 7 A4.5 4.5 0 1 1 11.5 7 Z M10.4 10.4 L14 14",
        "check": "M3 8.5 L6.5 12 L13 4.5",
        "info": "M14 8 A6 6 0 1 1 2 8 A6 6 0 1 1 14 8 Z M8 7.5 L8 11.5 M8 4.8 L8 5.2",
        "warning": "M8 2 L14.5 13.5 L1.5 13.5 Z M8 6.5 L8 9.5 M8 11.4 L8 11.8",
        "danger": "M14 8 A6 6 0 1 1 2 8 A6 6 0 1 1 14 8 Z M8 4.5 L8 8.5 M8 10.8 L8 11.2",
        "chevron-left": "M10 3.5 L5.5 8 L10 12.5",
        "chevron-right": "M6 3.5 L10.5 8 L6 12.5",
        "chevron-up": "M3.5 10 L8 5.5 L12.5 10",
        "chevron-down": "M3.5 6 L8 10.5 L12.5 6",
        "inbox": "M2 9 L4.5 3 L11.5 3 L14 9 L14 13 L2 13 Z M2 9 L5.5 9 L6.5 10.5 L9.5 10.5 L10.5 9 L14 9",
        "mail": "M2 3.5 L14 3.5 L14 12.5 L2 12.5 Z M2 4 L8 9 L14 4",
        "archive": "M2 3 L14 3 L14 6 L2 6 Z M3 6 L3 13 L13 13 L13 6 M6.5 8.5 L9.5 8.5",
        "tag": "M2 2.5 L8 2.5 L14 8.5 L8.5 14 L2.5 8 Z M5.2 5.2 L5.3 5.3",
        "clock": "M14 8 A6 6 0 1 1 2 8 A6 6 0 1 1 14 8 Z M8 4.5 L8 8 L10.5 9.5",
        "filter": "M2 3 L14 3 L9.5 8.5 L9.5 13 L6.5 11.5 L6.5 8.5 Z",
        "plus": "M8 3 L8 13 M3 8 L13 8",
        "more": "M3.5 8 L3.6 8 M8 8 L8.1 8 M12.5 8 L12.6 8",
        "keyboard": "M1.5 4.5 L14.5 4.5 L14.5 11.5 L1.5 11.5 Z M4 7 L4.1 7 M6.7 7 L6.8 7 M9.3 7 L9.4 7 M12 7 L12.1 7 M5 9.5 L11 9.5",
        "panel-left": "M2.5 3 L13.5 3 L13.5 13 L2.5 13 Z M6 3 L6 13",
        "panel-right": "M2.5 3 L13.5 3 L13.5 13 L2.5 13 Z M10 3 L10 13",
        "sort": "M5 3 L5 13 M2.5 10.5 L5 13 L7.5 10.5 M11 13 L11 3 M8.5 5.5 L11 3 L13.5 5.5",
        "user": "M10.5 5 A2.5 2.5 0 1 1 5.5 5 A2.5 2.5 0 1 1 10.5 5 Z M3 14 C3 10.5 13 10.5 13 14",
        "sun": "M10.5 8 A2.5 2.5 0 1 1 5.5 8 A2.5 2.5 0 1 1 10.5 8 Z M8 1.5 L8 3 M8 13 L8 14.5 M1.5 8 L3 8 M13 8 L14.5 8 M3.4 3.4 L4.5 4.5 M11.5 11.5 L12.6 12.6 M3.4 12.6 L4.5 11.5 M11.5 4.5 L12.6 3.4",
        "moon": "M13.5 9.5 A5.75 5.75 0 1 1 6.5 2.5 A4.5 4.5 0 0 0 13.5 9.5 Z",
        "dot": "M8 8 L8.1 8"
    })
    readonly property var names: Object.keys(paths)
    readonly property bool _builtin: name !== "" && paths[name] !== undefined

    implicitWidth: size
    implicitHeight: size
    width: implicitWidth
    height: implicitHeight

    Accessible.role: Accessible.Graphic
    Accessible.name: label
    Accessible.ignored: label === ""

    Component.onCompleted: {
        if (name !== "" && !_builtin)
            console.warn("SuiIcon: unknown icon name", JSON.stringify(name))
    }

    Shape {
        objectName: "shape"
        visible: icon._builtin
        width: 16
        height: 16
        scale: icon.size / 16
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color
            strokeWidth: icon.name === "more" || icon.name === "dot" ? 2.2 : 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon._builtin ? icon.paths[icon.name] : "" }
        }
    }

    Impl.IconImage {
        objectName: "image"
        visible: !icon._builtin && icon.source.toString() !== ""
        anchors.fill: parent
        source: icon._builtin ? "" : icon.source
        sourceSize: Qt.size(icon.size, icon.size)
        color: icon.color
        fillMode: Image.PreserveAspectFit
    }
}
