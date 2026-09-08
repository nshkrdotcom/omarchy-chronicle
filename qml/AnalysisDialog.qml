pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Native
import "Timeline.js" as Model

ChronicleDialog {
    id: root
    property var service: null
    property var options: ({})
    property string sortMode: "repeat"
    property alias queryModel: query
    readonly property real peak: query.result ? Math.max(1, query.result.groups.reduce(function (p, g) {
        return Math.max(p, g.current, g.previous);
    }, 0)) : 1
    signal inspect(string eventId, var ceiling)
    function showAnalysis(args) {
        options = JSON.parse(JSON.stringify(args));
        sortMode = "repeat";
        open();
        reload();
    }
    function reload() {
        query.load("analyze", Object.assign({}, options, {
            sort: sortMode,
            limit: 50
        }));
    }
    title: "Patterns · retained observations"
    modal: true
    width: Math.min(parent.width - 24, Style.space(1060))
    height: Math.min(parent.height - 24, Style.space(720))
    standardButtons: Dialog.Close
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    background: Rectangle {
        color: Native.Color.popups.background
        border.color: Native.Color.popups.border
    }
    onClosed: query.reset()
    InvestigationController {
        id: query
        service: root.service
    }
    ColumnLayout {
        anchors.fill: parent
        RowLayout {
            ChronicleButton {
                text: "Most repeated"
                chosen: root.sortMode === "repeat"
                onClicked: {
                    root.sortMode = "repeat";
                    root.reload();
                }
            }
            ChronicleButton {
                text: "Biggest changes"
                chosen: root.sortMode === "change"
                onClicked: {
                    root.sortMode = "change";
                    root.reload();
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ChronicleButton {
                text: "Retry"
                enabled: !query.busy
                onClicked: root.reload()
            }
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            text: query.result ? "Current: " + Model.timestamp(query.result.from_us) + " → " + Model.timestamp(query.result.to_us) + "\nPrevious: " + Model.timestamp(query.result.previous_from_us) + " → " + Model.timestamp(query.result.previous_to_us) + " · equal durations · local time" : "Comparing this interval with the immediately preceding interval of equal duration."
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            text: "Filters: " + (root.options.search ? "search “" + root.options.search + "” · " : "") + (root.options.unit || "all units") + " · " + (root.options.source || "all") + " sources · " + (root.options.severity || "all") + " levels · " + (root.options.category || "all") + " categories · " + (root.options.exclude || []).length + " exclusions"
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            color: query.error ? Native.Color.urgent : Native.Color.accent
            text: query.error || (query.busy ? "Counting all matching retained events…" : query.result ? query.result.current_count + " current / " + query.result.previous_count + " previous events · " + query.result.groups.length + "/" + query.result.group_count + " groups shown" + (query.result.truncated ? " · highest-ranked 50 only" : "") + " · bars share 0–" + root.peak + " count scale" : "No result")
        }
        ListView {
            id: groups
            objectName: "patternGroups"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(10)
            model: query.result ? query.result.groups : []
            ScrollBar.vertical: ScrollBar {}
            delegate: RowLayout {
                id: row
                required property var modelData
                width: groups.width - Style.space(14)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(3)
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: row.modelData.unit + " · " + row.modelData.severity + " · " + row.modelData.state + " · " + row.modelData.current + " current / " + row.modelData.previous + " previous · Δ " + (row.modelData.delta > 0 ? "+" : "") + row.modelData.delta
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: row.modelData.message
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ChronicleLabel {
                            text: "Prev / now"
                            font.pixelSize: Style.font.caption
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: Style.space(2)
                            Rectangle {
                                width: parent.width * row.modelData.previous / root.peak
                                height: Style.space(3)
                                color: Native.Color.popups.text
                                opacity: 0.5
                            }
                            Rectangle {
                                width: parent.width * row.modelData.current / root.peak
                                height: Style.space(3)
                                color: Native.Color.accent
                            }
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: Style.font.caption
                        text: row.modelData.source + " · boot " + (row.modelData.boot || "not recorded") + " · " + (row.modelData.current ? "Current " : "Previous ") + Model.timestamp(row.modelData.current ? row.modelData.first_us : row.modelData.previous_first_us) + " → " + Model.timestamp(row.modelData.current ? row.modelData.last_us : row.modelData.previous_last_us)
                    }
                }
                ChronicleButton {
                    text: "Context"
                    hint: "Inspect the exact latest retained event in this group"
                    onClicked: root.inspect(row.modelData.event_id, query.result.ceiling)
                }
            }
            ChronicleLabel {
                anchors.centerIn: parent
                width: parent.width
                wrapMode: Text.Wrap
                visible: !!query.result && !groups.count
                text: "No retained observations match either interval. Clear filters or choose another time; this is not a health verdict."
            }
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            text: query.result ? query.result.caution + " Recorder notices across both intervals: " + query.result.recorder_notices + ". Retained source-time range: " + Model.timestamp(query.result.retained.from_us) + " → " + Model.timestamp(query.result.retained.to_us) + "." : "Groups use exact stored message, source, unit, boot, category and level. Every event keeps its own identity."
        }
    }
}
