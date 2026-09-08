import QtQuick
import qs.Commons
import "Timeline.js" as Model

Item {
    id: root
    property var samples: []
    property real fromUs: 0
    property real toUs: 1
    property string metric: "cpu_some_avg10"
    property int inspectedIndex: -1
    readonly property color chartAccent: Color.accent
    readonly property color chartLine: Color.popups.border
    readonly property color chartForeground: Color.popups.text
    onChartAccentChanged: chart.requestPaint()
    onChartLineChanged: chart.requestPaint()
    onChartForegroundChanged: chart.requestPaint()
    readonly property var inspected: visibleSamples[inspectedIndex] || null
    readonly property string readout: inspected ? Model.timestamp(inspected.time_us) + " · " + (typeof inspected.values[metric] === "number" ? inspected.values[metric].toFixed(2) + "% stalled" : "measurement unavailable") : "Hover to inspect · Tab + ←/→ steps actual samples · missing/delayed samples break the line"
    activeFocusOnTab: true
    Accessible.role: Accessible.Graphic
    Accessible.name: metricLabel + " pressure history"
    Accessible.description: readout
    implicitHeight: Math.max(Style.space(96), Style.font.caption * 7)
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            inspectedIndex = Math.max(0, Math.min(visibleSamples.length - 1, inspectedIndex + (event.key === Qt.Key_Right ? 1 : -1)));
            event.accepted = true;
        }
    }
    onSamplesChanged: chart.requestPaint()
    onMetricChanged: chart.requestPaint()
    onFromUsChanged: chart.requestPaint()
    onToUsChanged: chart.requestPaint()
    onInspectedIndexChanged: chart.requestPaint()
    readonly property var visibleSamples: samples.filter(function (s) {
        return s.time_us >= root.fromUs && s.time_us <= root.toUs;
    })
    readonly property real maxValue: Math.max(1, Math.ceil(visibleSamples.reduce(function (m, s) {
        var v = s.values[root.metric];
        return typeof v === "number" ? Math.max(m, v) : m;
    }, 0)))
    readonly property int availableCount: visibleSamples.filter(function (s) {
        return typeof s.values[root.metric] === "number";
    }).length
    readonly property string metricLabel: metric === "cpu_some_avg10" ? "CPU" : metric === "memory_some_avg10" ? "Memory" : "I/O"
    ChronicleLabel {
        text: root.metricLabel + " pressure · some avg10 · % stalled (not utilization)"
        font.pixelSize: Style.font.caption
    }
    ChronicleLabel {
        anchors.right: parent.right
        text: "0–" + root.maxValue.toFixed(0) + "%"
        font.pixelSize: Style.font.caption
    }
    Canvas {
        id: chart
        anchors.fill: parent
        anchors.topMargin: Style.space(22)
        anchors.bottomMargin: Style.space(20)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = Color.popups.border;
            ctx.strokeRect(0, 0, width, height);
            ctx.strokeStyle = Color.accent;
            ctx.fillStyle = Color.accent;
            ctx.lineWidth = 1.5;
            Model.segments(root.visibleSamples, root.metric).forEach(function (segment) {
                ctx.beginPath();
                segment.forEach(function (p, i) {
                    var x = Model.position(p.time_us, root.fromUs, root.toUs, width);
                    var y = height - 2 - p.value / root.maxValue * (height - 4);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                });
                ctx.stroke();
                if (segment.length === 1) {
                    var p = segment[0];
                    ctx.fillRect(Model.position(p.time_us, root.fromUs, root.toUs, width) - 1, height - 2 - p.value / root.maxValue * (height - 4), 3, 3);
                }
            });
            if (root.inspected) {
                var x = Model.position(root.inspected.time_us, root.fromUs, root.toUs, width);
                ctx.strokeStyle = Color.popups.text;
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
        }
    }
    Rectangle {
        anchors.fill: chart
        color: "transparent"
        border.color: Color.accent
        border.width: root.activeFocus ? Style.space(2) : 0
    }
    MouseArea {
        anchors.fill: chart
        hoverEnabled: true
        onPositionChanged: function (mouse) {
            root.inspectedIndex = Model.sampleIndex(root.visibleSamples, root.fromUs + mouse.x / width * (root.toUs - root.fromUs));
        }
        onExited: if (!root.activeFocus)
            root.inspectedIndex = -1
        onClicked: root.forceActiveFocus()
    }
    ChronicleLabel {
        anchors.centerIn: chart
        visible: !root.availableCount
        text: "No available measurements in this interval"
        font.pixelSize: Style.font.caption
    }
    ChronicleLabel {
        anchors.bottom: parent.bottom
        width: parent.width
        text: root.readout
        font.pixelSize: Style.font.caption
    }
}
