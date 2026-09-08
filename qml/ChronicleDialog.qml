import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Native

// Qt's documented Dialog header/footer customization keeps platform-default
// chrome from overriding the native Omarchy popup palette.
Dialog {
    id: root
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    padding: Style.space(12)
    background: Rectangle {
        color: Native.Color.popups.background
        border.color: Native.Color.popups.border
        border.width: Style.spacing.hairline
        radius: Style.cornerRadius
    }
    header: Label {
        text: root.title
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Native.Color.popups.text
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        font.weight: Font.DemiBold
        padding: Style.space(12)
        background: Rectangle {
            color: Native.Color.popups.background
        }
    }
    footer: DialogButtonBox {
        standardButtons: root.standardButtons
        visible: count > 0
        alignment: Qt.AlignRight
        padding: Style.space(12)
        delegate: ChronicleButton {}
        background: Rectangle {
            color: Native.Color.popups.background
        }
    }
}
