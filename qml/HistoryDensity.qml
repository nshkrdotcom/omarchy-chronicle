pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import "Timeline.js" as Model

Item {
    id: root
    property var bins: []
    property real fromUs: 0
    property real toUs: 1
    property int inspectedIndex: -1
    readonly property var boundedBins: bins.slice(0, 48)
    readonly property real peak: Math.max(1, boundedBins.reduce(function (n, b) {
        return Math.max(n, b.count);
    }, 0))
    readonly property var inspected: boundedBins[inspectedIndex] || null
    readonly property string readout: inspected ? Model.timestamp(fromUs + inspectedIndex * (toUs - fromUs) / Math.max(1, boundedBins.length)) + " · " + inspected.count + " events · " + inspected.errors + " errors · " + inspected.warnings + " warnings" : "Full-interval density · linear count scale · peak " + peak + " · Tab + ←/→ inspect counts"
    implicitHeight: Style.space(58)
    activeFocusOnTab: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "Matching retained event density"
    Accessible.description: readout
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            inspectedIndex = Math.max(0, Math.min(boundedBins.length - 1, inspectedIndex + (event.key === Qt.Key_Right ? 1 : -1)));
            event.accepted = true;
        }
    }
    Row {
        id: bars
        width: parent.width
        height: parent.height - Style.space(22)
        spacing: Style.space(2)
        Repeater {
            model: root.boundedBins
            Rectangle {
                id: binItem
                required property var modelData
                required property int index
                width: Math.max(1, (bars.width - bars.spacing * (root.boundedBins.length - 1)) / Math.max(1, root.boundedBins.length))
                height: bars.height
                color: "transparent"
                border.width: root.inspectedIndex === index ? 1 : 0
                border.color: Color.popups.text
                Rectangle {
                    width: parent.width
                    anchors.bottom: parent.bottom
                    height: Math.max(1, binItem.modelData.count / root.peak * (bars.height - 2))
                    color: binItem.modelData.count ? Color.accent : Color.popups.border
                    Rectangle {
                        width: parent.width
                        anchors.bottom: parent.bottom
                        height: binItem.modelData.count ? parent.height * binItem.modelData.errors / binItem.modelData.count : 0
                        color: Color.urgent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.inspectedIndex = binItem.index
                    onClicked: root.forceActiveFocus()
                }
            }
        }
    }
    ChronicleLabel {
        anchors.bottom: parent.bottom
        width: parent.width
        text: root.readout
        font.pixelSize: Style.font.caption
    }
}
