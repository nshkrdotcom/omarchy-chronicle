import QtQuick
import qs.Commons
import qs.Commons as Native

Text {
    textFormat: Text.PlainText
    color: Native.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
    Accessible.role: Accessible.StaticText
    Accessible.name: text
}
