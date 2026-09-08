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
    property string eventId: ""
    property string scope: "unit"
    property int radiusSeconds: 120
    property var receiptCeiling: null
    property string selectedId: ""
    property bool pinEnabled: true
    property string pinLabel: "Pin selected to incident"
    signal pin(string eventId)
    property alias queryModel: query
    readonly property var selected: query.result ? Model.selected(query.result.events, selectedId) : null
    function showEvent(id, ceiling) {
        eventId = id;
        receiptCeiling = ceiling === undefined ? null : ceiling;
        scope = "unit";
        radiusSeconds = 120;
        selectedId = id;
        open();
        reload();
    }
    function reload() {
        query.load("context", {
            id: eventId,
            scope: scope,
            radius_seconds: radiusSeconds,
            ceiling: receiptCeiling
        });
    }
    title: "Surrounding events"
    modal: true
    width: Math.min(parent.width - 24, Style.space(1000))
    height: Math.min(parent.height - 24, Style.space(710))
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
        onReady: {
            root.receiptCeiling = result.ceiling;
            root.selectedId = root.eventId;
            Qt.callLater(function () {
                rows.positionViewAtIndex(query.result ? query.result.shown_before : 0, ListView.Center);
            });
        }
    }
    ColumnLayout {
        anchors.fill: parent
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            text: "Search, exclusions, category and level filters are lifted here. Your Timeline filters stay unchanged. Same unit matches recorded source, unit and boot—not a process ID."
        }
        RowLayout {
            ChronicleButton {
                text: "Same unit + boot"
                chosen: root.scope === "unit"
                onClicked: {
                    root.scope = "unit";
                    root.reload();
                }
            }
            ChronicleButton {
                text: "All sources"
                chosen: root.scope === "all"
                onClicked: {
                    root.scope = "all";
                    root.reload();
                }
            }
            ChronicleButton {
                text: "±" + (root.radiusSeconds / 60) + " min"
                hint: "Cycle through 2, 10 and 60 minutes around the selected event"
                onClicked: {
                    root.radiusSeconds = root.radiusSeconds === 120 ? 600 : root.radiusSeconds === 600 ? 3600 : 120;
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
            objectName: "contextSummary"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            color: query.error ? Native.Color.urgent : Native.Color.popups.text
            text: query.error || (query.busy ? "Loading surroundings…" : query.result ? query.result.shown_before + "/" + query.result.before_count + " earlier · selected event · " + query.result.shown_after + "/" + query.result.after_count + " later · closest 30 each side" + (query.result.truncated ? " · more events exist in this radius" : "") : "No result")
        }
        ListView {
            id: rows
            objectName: "contextEvents"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(4)
            model: query.result ? query.result.events : []
            ScrollBar.vertical: ScrollBar {}
            delegate: ChronicleButton {
                required property var modelData
                width: rows.width - Style.space(14)
                textAlignment: Text.AlignLeft
                chosen: root.selectedId === modelData.id
                text: (modelData.id === root.eventId ? "ANCHOR · " : "") + Model.timestamp(modelData.time_us) + " · " + modelData.severity + " · " + modelData.unit + " · " + modelData.message
                hint: modelData.message
                onClicked: root.selectedId = modelData.id
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(175)
            Notes {
                readOnly: true
                maximumCharacters: 0
                Accessible.name: "Selected surrounding evidence"
                text: root.selected ? Model.evidenceText(root.selected) : "Select a row to inspect its exact identity. Empty surroundings do not prove complete history."
            }
        }
        ChronicleButton {
            text: root.pinLabel
            enabled: !!root.selected && root.pinEnabled && !query.busy
            onClicked: root.pin(root.selected.id)
        }
        ChronicleLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font.pixelSize: Style.font.caption
            text: "Read-only inspection. Source clock changes and missing journal history can affect order; proximity does not establish causation."
        }
    }
}
