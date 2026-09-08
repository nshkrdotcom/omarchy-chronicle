import QtQuick
import qs.Commons
import "Timeline.js" as Model

Item {
    id: root
    property var samples: []
    property real fromUs: 0
    property real toUs: 1
    property string metric: "cpu_some_avg10"
    implicitHeight: Style.space(78)
    onSamplesChanged: chart.requestPaint()
    onMetricChanged: chart.requestPaint()
    onFromUsChanged: chart.requestPaint()
    onToUsChanged: chart.requestPaint()
    readonly property var visibleSamples: samples.filter(function(s){return s.time_us>=root.fromUs && s.time_us<=root.toUs})
    readonly property real maxValue: Math.max(1,Math.ceil(visibleSamples.reduce(function(m,s){var v=s.values[root.metric];return typeof v==="number"?Math.max(m,v):m},0)))
    ChronicleLabel { text: "CPU pressure · some avg10 · % stalled (not utilization)"; font.pixelSize: Style.font.caption }
    ChronicleLabel { anchors.right: parent.right; text: "0–"+root.maxValue.toFixed(0)+"%"; font.pixelSize: Style.font.caption }
    Canvas {
        id: chart
        anchors.fill: parent
        anchors.topMargin: Style.space(22)
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx=getContext("2d");ctx.reset();ctx.strokeStyle=Color.popups.border
            ctx.strokeRect(0,0,width,height)
            ctx.strokeStyle=Color.accent;ctx.fillStyle=Color.accent;ctx.lineWidth=1.5
            Model.segments(root.visibleSamples,root.metric).forEach(function(segment){
                ctx.beginPath()
                segment.forEach(function(p,i){var x=Model.position(p.time_us,root.fromUs,root.toUs,width);var y=height-2-p.value/root.maxValue*(height-4);if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y)})
                ctx.stroke()
                if(segment.length===1){var p=segment[0];ctx.fillRect(Model.position(p.time_us,root.fromUs,root.toUs,width)-1,height-2-p.value/root.maxValue*(height-4),3,3)}
            })
        }
    }
    ChronicleLabel { anchors.centerIn: chart; visible: !root.visibleSamples.length; text: "No samples in this interval"; font.pixelSize: Style.font.caption }
}
