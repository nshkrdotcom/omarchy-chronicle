import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Native

TextArea {
    id: root
    readonly property color foreground: Native.Color.popups.text
    property int maximumCharacters: 4096
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.Wrap
    color: foreground
    placeholderTextColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
    selectionColor: Native.Color.accent
    selectedTextColor: Native.Color.popups.background
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    selectByMouse: true
    padding: Style.space(8)
    onTextChanged: if (maximumCharacters > 0 && text.length > maximumCharacters)
        text = text.slice(0, maximumCharacters)
    background: Rectangle {
        color: Native.Color.popups.background
        radius: Style.cornerRadius
        border.color: root.activeFocus ? Native.Color.accent : Native.Color.popups.border
        border.width: root.activeFocus ? Style.space(2) : Style.spacing.hairline
    }
}
