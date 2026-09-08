import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Native

TextField {
    id: root
    readonly property color foreground: Native.Color.popups.text
    color: Native.Color.popups.text
    placeholderTextColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)
    selectionColor: Native.Color.accent
    selectedTextColor: Native.Color.popups.background
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    padding: Style.space(8)
    selectByMouse: true
    maximumLength: 200
    Accessible.name: placeholderText
    background: Rectangle {
        color: Native.Color.popups.background
        radius: Style.cornerRadius
        border.color: root.activeFocus ? Native.Color.accent : Native.Color.popups.border
        border.width: root.activeFocus ? Style.space(2) : Style.spacing.hairline
    }
}
