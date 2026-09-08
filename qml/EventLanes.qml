pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import "Timeline.js" as Model

Item {
    id: root
    property var events: []
    property real fromUs: 0
    property real toUs: 1
    property string selectedId: ""
    signal selected(string eventId)
    implicitHeight: Math.max(Style.space(170), (Style.font.caption + Style.space(8)) * Model.categories.length + Style.space(20))
    readonly property real labelWidth: Style.space(100)
    readonly property real laneHeight: (height - Style.space(20)) / Model.categories.length
    onEventsChanged: canvas.requestPaint()
    onFromUsChanged: canvas.requestPaint()
    onToUsChanged: canvas.requestPaint()
    onSelectedIdChanged: canvas.requestPaint()
    readonly property color chartAccent: Color.accent
    readonly property color chartUrgent: Color.urgent
    readonly property color chartLine: Color.popups.border
    readonly property color chartForeground: Color.popups.text
    onChartAccentChanged: canvas.requestPaint()
    onChartUrgentChanged: canvas.requestPaint()
    onChartLineChanged: canvas.requestPaint()
    onChartForegroundChanged: canvas.requestPaint()
    Repeater {
        model: Model.categories
        ChronicleLabel {
            required property string modelData
            required property int index
            text: modelData
            y: index * root.laneHeight + Style.space(3)
            width: root.labelWidth - Style.space(8)
            font.pixelSize: Style.font.caption
        }
    }
    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var span = width - root.labelWidth;
            for (var i = 0; i < Model.categories.length; i++) {
                ctx.strokeStyle = Color.popups.border;
                ctx.beginPath();
                ctx.moveTo(root.labelWidth, (i + 1) * root.laneHeight);
                ctx.lineTo(width, (i + 1) * root.laneHeight);
                ctx.stroke();
            }
            Model.filter(root.events, {
                from: root.fromUs,
                to: root.toUs
            }).forEach(function (e) {
                var lane = Model.categories.indexOf(e.category);
                if (lane < 0)
                    return;
                var x = root.labelWidth + Model.position(e.time_us, root.fromUs, root.toUs, span - 6);
                var y = (lane + 0.5) * root.laneHeight;
                ctx.fillStyle = e.severity === "error" ? Color.urgent : e.severity === "warning" ? "#e7bc72" : Color.accent;
                ctx.beginPath();
                if (e.severity === "error") {
                    ctx.moveTo(x, y - 5);
                    ctx.lineTo(x + 5, y);
                    ctx.lineTo(x, y + 5);
                    ctx.lineTo(x - 5, y);
                    ctx.closePath();
                } else if (e.severity === "warning") {
                    ctx.moveTo(x, y - 5);
                    ctx.lineTo(x + 5, y + 4);
                    ctx.lineTo(x - 5, y + 4);
                    ctx.closePath();
                } else
                    ctx.arc(x, y, 3, 0, Math.PI * 2);
                ctx.fill();
                if (e.id === root.selectedId) {
                    ctx.strokeStyle = Color.popups.text;
                    ctx.strokeRect(x - 7, y - 7, 14, 14);
                }
            });
        }
    }
    ChronicleLabel {
        anchors.left: parent.left
        anchors.leftMargin: root.labelWidth
        anchors.bottom: parent.bottom
        font.pixelSize: Style.font.caption
        text: new Date(root.fromUs / 1000).toLocaleTimeString()
    }
    ChronicleLabel {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        font.pixelSize: Style.font.caption
        text: new Date(root.toUs / 1000).toLocaleTimeString()
    }
    MouseArea {
        anchors.fill: parent
        onClicked: function (mouse) {
            if (mouse.x < root.labelWidth)
                return;
            var lane = Math.floor(mouse.y / root.laneHeight);
            var time = root.fromUs + (mouse.x - root.labelWidth) / (width - root.labelWidth) * (root.toUs - root.fromUs);
            var row = Model.nearest(root.events.filter(function (e) {
                return e.category === Model.categories[lane];
            }), time, root.fromUs, root.toUs);
            if (row)
                root.selected(row.id);
        }
    }
}
