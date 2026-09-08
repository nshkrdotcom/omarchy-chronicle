import QtQuick
import QtQuick.Controls
import qs.Commons
TextField {
    id: root
    readonly property color foreground: Color.popups.text
    color: Color.popups.text
    placeholderTextColor: Qt.rgba(foreground.r,foreground.g,foreground.b,0.55)
    selectionColor: Color.accent
    selectedTextColor: Color.popups.background
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    padding: Style.space(8)
    selectByMouse: true
    maximumLength: 200
    Accessible.name: placeholderText
    background: Rectangle {
        color: Color.popups.background
        radius: Style.cornerRadius
        border.color: root.activeFocus ? Color.accent : Color.popups.border
        border.width: root.activeFocus ? Style.space(2) : Style.spacing.hairline
    }
}
