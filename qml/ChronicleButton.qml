import QtQuick
import QtQuick.Controls
import qs.Commons

Button {
    id: root
    property bool chosen: false
    property string hint: ""
    property int textAlignment: Text.AlignHCenter
    leftPadding: Style.spacing.controlPaddingX
    rightPadding: Style.spacing.controlPaddingX
    topPadding: Style.spacing.controlPaddingY
    bottomPadding: Style.spacing.controlPaddingY
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    Accessible.description: hint
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        color: root.chosen ? Color.popups.background : Color.popups.text
        opacity: root.enabled ? 1 : 0.45
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.weight: root.chosen ? Font.DemiBold : Font.Normal
        horizontalAlignment: root.textAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Style.cornerRadius
        color: root.chosen ? Color.accent : root.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.15) : "transparent"
        border.width: root.activeFocus ? Style.space(2) : Style.spacing.hairline
        border.color: root.activeFocus ? (root.chosen ? Color.popups.text : Color.accent) : Color.popups.border
    }
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    ToolTip.delay: 600
}
