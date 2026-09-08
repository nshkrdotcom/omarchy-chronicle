import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Native

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
        color: root.chosen ? Native.Color.popups.background : Native.Color.popups.text
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
        color: root.chosen ? Native.Color.accent : root.hovered ? Qt.rgba(0.5, 0.5, 0.5, 0.15) : "transparent"
        border.width: root.activeFocus ? Style.space(2) : Style.spacing.hairline
        border.color: root.activeFocus ? (root.chosen ? Native.Color.popups.text : Native.Color.accent) : Native.Color.popups.border
    }
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    ToolTip.delay: 600
}
