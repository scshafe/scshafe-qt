// SuiText: text in one of the type styles (SuiTheme.textStyles), the type
// scale as a component.
//
//     SuiText { text: "Recordings"; variant: "title" }
//     SuiText { text: take.note; variant: "caption"; wrapMode: Text.Wrap; width: parent.width }
//     SuiText { text: "-12.4 dB"; tone: "warn"; tabular: true }
//
// `variant`: "display" | "title" | "heading" | "subheading" | "section" |
// "label" | "body" (default) | "caption" | "small" | "code" (SuiTheme.textVariants;
// an unknown name is body). The web library's Title h1 is "title", h2
// "heading", h3 "subheading", h4-h6 "section"; its Label is "label" and its
// Description "caption". The heading variants (display to section) are
// announced as headings, the others as static text.
//
// `tone` overrides the variant's colour: "" (the variant's own) | "default" |
// "strong" | "muted" | "accent" | "info" | "ok" | "warn" | "danger" | a bucket
// ("bucket1".."bucket8" or 1-8). `tabular` gives digits equal widths (meters,
// times, counts). Line height (the style's `leading`) applies once the text
// wraps (`wrapMode`); a single line keeps the font's own height, so it centres
// in rows. Everything else is Text's: elide, wrapMode, maximumLineCount,
// horizontalAlignment. Caller text is plain text, never markup.
import QtQuick

Text {
    textFormat: Text.PlainText
    id: control

    property string variant: "body"
    property var tone: ""
    property bool tabular: false
    readonly property var style: SuiTheme.textStyle(variant)

    color: SuiTheme.textColor(tone === "" ? style.tone : tone)
    font.family: style.mono ? SuiTheme.monoFamily : Qt.application.font.family
    font.pixelSize: style.size
    font.weight: style.weight
    font.letterSpacing: style.tracking * style.size
    font.capitalization: style.caps ? Font.AllUppercase : Font.MixedCase
    font.features: tabular ? ({ "tnum": 1 }) : ({})
    lineHeightMode: wrapMode === Text.NoWrap ? Text.ProportionalHeight : Text.FixedHeight
    lineHeight: wrapMode === Text.NoWrap ? 1 : Math.round(style.size * style.leading)

    Accessible.role: style.heading ? Accessible.Heading : Accessible.StaticText
    Accessible.name: text
}
