pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import "Timeline.js" as Model

FocusScope {
    id: root
    property var service: null
    property bool viewActive: true
    property real anchorUs: 0
    property alias historyModel: browser
    property alias incidentEditor: editor
    property var inspectedCopy: null
    property var reviewedPreview: null
    property string previewRequest: ""
    property real nowUs: Date.now() * 1000
    property int page: 0
    property bool frozen: false
    property var frozenSnapshot: ({})
    property string selectedId: ""
    property int windowMinutes: 5
    property string severity: "all"
    property string category: "all"
    property string sourceFilter: "all"
    property string pressureMetric: "cpu_some_avg10"
    property string bookmarkA: ""
    property string bookmarkB: ""
    property string incidentId: ""
    property string confirmationId: ""
    property bool detailedExport: false
    readonly property var live: service ? service.snapshot : ({})
    readonly property var view: frozen ? frozenSnapshot : live
    readonly property real endUs: anchorUs > 0 ? anchorUs : browser.result ? Number(browser.result.to_us) : nowUs
    readonly property real startUs: Math.max(0, Model.windowStart(endUs, windowMinutes))
    readonly property var visibleEvents: browser.result ? browser.result.events : browser.options ? [] : Model.filter(view.events || [], {
        from: startUs,
        to: endUs,
        severity: severity,
        category: category,
        source: sourceFilter,
        search: search.text
    })
    readonly property var selectedEvent: Model.selected(visibleEvents, selectedId)
    readonly property var currentIncident: editor.item
    readonly property string status: service && !service.daemonRunning ? "OFFLINE" : Model.health(live, nowUs)
    signal dismissed
    function request(cmd, args) {
        if (["create_incident", "pin", "unpin", "remove_incident"].indexOf(cmd) >= 0)
            return editor.perform(cmd, args || {});
        if (cmd === "preview_export") {
            previewRequest = service ? service.request(cmd, args || {}) : "";
            return previewRequest;
        }
        if (service)
            return service.request(cmd, args || {});
        return "";
    }
    function toggleFreeze() {
        if (!frozen) {
            frozenSnapshot = JSON.parse(JSON.stringify(live));
            anchorUs = browser.result ? browser.result.to_us : nowUs;
            browser.hold();
            frozen = true;
        } else {
            frozen = false;
            anchorUs = 0;
            updateQuery();
        }
    }
    function selectEvent(id) {
        if (!frozen && Model.selected(visibleEvents, id))
            toggleFreeze();
        selectedId = id;
    }
    function openIncident(id) {
        editor.open(id);
    }
    function updateQuery() {
        var targetEnd = frozen && anchorUs > 0 ? anchorUs : nowUs;
        browser.load({
            from_us: Math.max(0, Math.round(targetEnd - windowMinutes * 60000000)),
            to_us: Math.round(targetEnd),
            search: search.text,
            severity: severity,
            category: category,
            source: sourceFilter
        }, frozen ? browser.ceiling : null);
    }
    function jumpTo(timeUs) {
        if (!frozen)
            toggleFreeze();
        anchorUs = Math.max(windowMinutes * 60000000, Number(timeUs) + windowMinutes * 30000000);
        page = 0;
        updateQuery();
    }
    function shiftInterval(direction) {
        if (!frozen)
            toggleFreeze();
        anchorUs = Math.max(windowMinutes * 60000000, endUs + direction * windowMinutes * 60000000);
        updateQuery();
    }
    function applyView(item) {
        search.text = item.search || "";
        severity = item.severity || "all";
        category = item.category || "all";
        sourceFilter = item.source || "all";
        windowMinutes = item.window_minutes || 5;
        page = 0;
        updateQuery();
    }
    onWindowMinutesChanged: updateQuery()
    onSeverityChanged: updateQuery()
    onCategoryChanged: updateQuery()
    onSourceFilterChanged: updateQuery()
    onViewActiveChanged: {
        if (viewActive && !frozen)
            updateQuery();
        if (!viewActive)
            editor.flush();
    }
    onPageChanged: if (page !== 2)
        editor.flush()
    IncidentController {
        id: editor
        service: root.service
        onItemChanged: root.incidentId = item ? item.id : ""
        onReadyToClose: root.dismissed()
        onReviewReady: reviewDialog.open()
    }
    HistoryController {
        id: browser
        service: root.service
        active: root.viewActive && root.page === 0
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.viewActive && root.page === 0 && !root.frozen
        onTriggered: root.updateQuery()
    }
    Component.onCompleted: if (viewActive)
        updateQuery()
    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCompleted(id, command, result, error) {
            if (command === "preview_export" && id === root.previewRequest) {
                root.previewRequest = "";
                if (!error) {
                    root.reviewedPreview = result;
                    exportDialog.open();
                }
            }
        }
        function onRestarted() {
            root.reviewedPreview = null;
            root.previewRequest = "";
            exportDialog.close();
        }
    }
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            editor.closeSafely();
            event.accepted = true;
        } else if (event.key === Qt.Key_Space && !event.modifiers) {
            root.toggleFreeze();
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash && !event.modifiers) {
            root.page = 0;
            search.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_M && (event.modifiers & Qt.ControlModifier)) {
            root.request("bookmark", {
                label: "Moment"
            });
            event.accepted = true;
        } else if ((event.key === Qt.Key_Up || event.key === Qt.Key_Down) && root.page === 0) {
            var index = root.visibleEvents.findIndex(function (e) {
                return e.id === root.selectedId;
            });
            index = Math.max(0, Math.min(root.visibleEvents.length - 1, index + (event.key === Qt.Key_Down ? 1 : -1)));
            if (root.visibleEvents[index]) {
                root.selectEvent(root.visibleEvents[index].id);
                eventList.positionViewAtIndex(index, ListView.Contain);
            }
            event.accepted = true;
        }
    }
    Rectangle {
        anchors.fill: parent
        color: Color.popups.background
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.huge
            ColumnLayout {
                Layout.maximumWidth: Style.space(330)
                spacing: Style.spacing.xxs
                ChronicleLabel {
                    objectName: "chronicleTitle"
                    text: "CHRONICLE"
                    font.pixelSize: Style.font.subtitle
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                }
                ChronicleLabel {
                    text: root.status + (root.frozen ? " · FROZEN VIEW" : " · LIVE VIEW")
                    color: root.status === "RECORDING" ? Color.accent : Color.urgent
                    font.pixelSize: Style.font.caption
                }
            }
            Item {
                Layout.fillWidth: true
            }
            RowLayout {
                objectName: "headerActions"
                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                spacing: Style.spacing.sm
                ChronicleButton {
                    text: "/ Search"
                    onClicked: {
                        root.page = 0;
                        search.forceActiveFocus();
                    }
                }
                ChronicleButton {
                    objectName: "freezeButton"
                    text: root.frozen ? "Live" : "Freeze"
                    chosen: root.frozen
                    hint: "Space · Freeze this view; recording continues"
                    onClicked: root.toggleFreeze()
                }
                ChronicleButton {
                    objectName: "markButton"
                    text: "Mark"
                    hint: "Ctrl+M · Save this moment with current scalar measurements"
                    enabled: root.service && root.service.daemonRunning && !root.live.paused
                    onClicked: root.request("bookmark", {
                        label: "Moment"
                    })
                }
                ChronicleButton {
                    text: "Close"
                    hint: "Esc · Close panel; recording continues"
                    onClicked: editor.closeSafely()
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ChronicleButton {
                text: "Timeline"
                chosen: root.page === 0
                onClicked: root.page = 0
            }
            ChronicleButton {
                text: "Bookmarks"
                chosen: root.page === 1
                onClicked: root.page = 1
            }
            ChronicleButton {
                text: "Incidents"
                chosen: root.page === 2
                onClicked: root.page = 2
            }
            ChronicleButton {
                objectName: "sourcesTab"
                text: "Sources"
                chosen: root.page === 3
                onClicked: root.page = 3
            }
            Item {
                Layout.fillWidth: true
            }
            ChronicleLabel {
                text: Number(root.live.event_count || 0) + " retained"
                font.pixelSize: Style.font.caption
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Style.spacing.hairline
            color: Color.popups.border
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.page === 0
            Input {
                id: search
                objectName: "searchInput"
                Layout.fillWidth: true
                placeholderText: root.frozen ? "Filter frozen evidence…" : "Search retained history…"
                onTextEdited: queryDelay.restart()
                Keys.onEscapePressed: root.forceActiveFocus()
            }
            Repeater {
                model: [5, 15, 60, 10080]
                ChronicleButton {
                    required property int modelData
                    text: modelData === 10080 ? "7d" : modelData + "m"
                    chosen: root.windowMinutes === modelData
                    onClicked: root.windowMinutes = modelData
                }
            }
        }
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.page
            ColumnLayout {
                spacing: Style.space(6)
                RowLayout {
                    ChronicleButton {
                        text: root.severity === "all" ? "All levels" : root.severity
                        onClicked: root.severity = root.severity === "all" ? "error" : root.severity === "error" ? "warning" : "all"
                    }
                    ChronicleButton {
                        text: root.category === "all" ? "All categories" : root.category
                        onClicked: {
                            var choices = ["all"].concat(Model.categories);
                            root.category = choices[(choices.indexOf(root.category) + 1) % choices.length];
                        }
                    }
                    ChronicleButton {
                        text: root.sourceFilter === "all" ? "All sources" : root.sourceFilter
                        onClicked: {
                            var choices = ["all", "user-journal", "system-journal", "recorder", "demo"];
                            root.sourceFilter = choices[(choices.indexOf(root.sourceFilter) + 1) % choices.length];
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        text: "● info   ▲ warning   ◆ error · loaded-page lanes"
                        font.pixelSize: Style.font.caption
                    }
                    ChronicleButton {
                        text: "Views"
                        onClicked: viewsDialog.open()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    ChronicleButton {
                        text: "← Interval"
                        onClicked: root.shiftInterval(-1)
                    }
                    ChronicleButton {
                        text: "Interval →"
                        onClicked: root.shiftInterval(1)
                    }
                    ChronicleButton {
                        text: "Jump…"
                        onClicked: jumpDialog.open()
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        font.pixelSize: Style.font.caption
                        text: Model.timestamp(root.startUs) + " → " + Model.timestamp(root.endUs) + " (local)"
                    }
                    ChronicleButton {
                        text: "Newer"
                        enabled: !browser.busy && browser.pageIndex > 0
                        onClicked: browser.newer()
                    }
                    ChronicleButton {
                        text: "Older"
                        enabled: !browser.busy && !!browser.result && !!browser.result.next
                        onClicked: {
                            if (!root.frozen)
                                root.toggleFreeze();
                            browser.older();
                        }
                    }
                }
                ChronicleLabel {
                    Layout.fillWidth: true
                    font.pixelSize: Style.font.caption
                    color: browser.retentionChanged || browser.error ? Color.urgent : Color.popups.text
                    text: browser.error || (browser.retentionChanged ? "Retention changed since page one; some evidence may have expired. " : "") + (browser.result ? "Page " + (browser.pageIndex + 1) + " · " + root.visibleEvents.length + " loaded / " + browser.result.matching_count + " matching retained events" : browser.busy ? "Loading retained evidence…" : "No historical query result")
                }
                HistoryDensity {
                    Layout.fillWidth: true
                    bins: browser.result ? browser.result.density || [] : Model.buckets(root.visibleEvents, root.startUs, root.endUs, 48)
                    fromUs: root.startUs
                    toUs: root.endUs
                }
                EventLanes {
                    Layout.fillWidth: true
                    events: root.visibleEvents
                    fromUs: root.startUs
                    toUs: root.endUs
                    selectedId: root.selectedId
                    onSelected: function (eventId) {
                        root.selectEvent(eventId);
                    }
                }
                RowLayout {
                    ChronicleButton {
                        text: "CPU PSI"
                        chosen: root.pressureMetric === "cpu_some_avg10"
                        onClicked: root.pressureMetric = "cpu_some_avg10"
                    }
                    ChronicleButton {
                        text: "Memory PSI"
                        chosen: root.pressureMetric === "memory_some_avg10"
                        onClicked: root.pressureMetric = "memory_some_avg10"
                    }
                    ChronicleButton {
                        text: "I/O PSI"
                        chosen: root.pressureMetric === "io_some_avg10"
                        onClicked: root.pressureMetric = "io_some_avg10"
                    }
                }
                PressureTrace {
                    Layout.fillWidth: true
                    samples: root.view.samples || []
                    fromUs: root.startUs
                    toUs: root.endUs
                    metric: root.pressureMetric
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: eventList
                        objectName: "eventList"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: root.width * 0.6
                        clip: true
                        model: root.visibleEvents
                        spacing: Style.space(3)
                        ScrollBar.vertical: ScrollBar {}
                        onMovementStarted: if (!root.frozen)
                            root.toggleFreeze()
                        delegate: ChronicleButton {
                            required property var modelData
                            width: eventList.width - Style.space(14)
                            text: (modelData.severity === "error" ? "◆ " : modelData.severity === "warning" ? "▲ " : "● ") + new Date(modelData.time_us / 1000).toLocaleTimeString() + " · " + modelData.unit + " · " + modelData.message
                            chosen: root.selectedId === modelData.id
                            hint: modelData.message
                            textAlignment: Text.AlignLeft
                            onClicked: {
                                if (!root.frozen)
                                    root.toggleFreeze();
                                root.selectEvent(modelData.id);
                            }
                        }
                        ChronicleLabel {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: eventList.count === 0
                            text: root.status === "OFFLINE" ? "Recorder offline. Open Sources for status." : "No matching evidence in this interval. Widen the time window or clear filters; missing history is not proof that nothing happened."
                        }
                    }
                    Rectangle {
                        Layout.fillHeight: true
                        implicitWidth: Style.spacing.hairline
                        color: Color.popups.border
                    }
                    ScrollView {
                        Layout.fillHeight: true
                        Layout.preferredWidth: Math.max(Style.space(230), root.width * 0.34)
                        clip: true
                        contentWidth: availableWidth
                        ColumnLayout {
                            width: parent.width
                            ChronicleLabel {
                                text: "EVIDENCE"
                                color: Color.accent
                                font.pixelSize: Style.font.caption
                            }
                            ChronicleLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WrapAnywhere
                                text: root.selectedEvent ? root.selectedEvent.message : root.selectedId ? "Selected event is no longer in this view. No substitute was selected." : "Select a marker or event. Scroll or select a row to freeze the investigation view."
                            }
                            ChronicleLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.WrapAnywhere
                                font.pixelSize: Style.font.caption
                                text: root.selectedEvent ? "Time: " + Model.timestamp(root.selectedEvent.time_us) + "\nSource: " + root.selectedEvent.source + "\nUnit: " + root.selectedEvent.unit + "\nBoot: " + (root.selectedEvent.boot || "not recorded") + "\nMonotonic µs: " + (root.selectedEvent.monotonic_us === null ? "unavailable" : root.selectedEvent.monotonic_us) + "\nID: " + root.selectedEvent.id : ""
                            }
                            ChronicleButton {
                                text: root.incidentId ? "Pin to selected incident" : "Create incident + pin"
                                enabled: !!root.selectedEvent
                                onClicked: {
                                    if (root.incidentId)
                                        root.request("pin", {
                                            id: root.incidentId,
                                            event_id: root.selectedId
                                        });
                                    else
                                        root.request("create_incident", {
                                            title: "Investigation",
                                            pin_event_id: root.selectedId
                                        });
                                    root.page = 2;
                                }
                            }
                            ChronicleLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.pixelSize: Style.font.caption
                                text: "Nearby events are not automatically causes. Categories come from source identity. Messages are redacted best-effort; do not assume they are safe to share."
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                RowLayout {
                    Layout.fillWidth: true
                    Input {
                        id: momentLabel
                        Layout.fillWidth: true
                        maximumLength: 100
                        placeholderText: "Name this moment (e.g. Before update)"
                    }
                    ChronicleButton {
                        text: "Mark now"
                        onClicked: root.request("bookmark", {
                            label: momentLabel.text || "Moment"
                        })
                    }
                    ChronicleButton {
                        text: "Compare A → B"
                        enabled: root.bookmarkA !== "" && root.bookmarkB !== ""
                        onClicked: root.request("compare", {
                            a: root.bookmarkA,
                            b: root.bookmarkB
                        })
                    }
                }
                ChronicleLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Style.font.caption
                    text: "Marks capture current collected measurements, not the frozen view. Select exact A/B marks for a signed comparison."
                }
                ListView {
                    id: marks
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(Style.space(60), Math.min(count * Style.space(36), Style.space(260)))
                    clip: true
                    model: root.live.bookmarks || []
                    spacing: Style.space(4)
                    ScrollBar.vertical: ScrollBar {}
                    delegate: RowLayout {
                        id: markRow
                        required property var modelData
                        width: marks.width - Style.space(14)
                        ChronicleLabel {
                            Layout.fillWidth: true
                            text: markRow.modelData.label + " · " + Model.timestamp(markRow.modelData.time_us)
                        }
                        ChronicleButton {
                            text: "Context"
                            onClicked: root.jumpTo(markRow.modelData.time_us)
                        }
                        ChronicleButton {
                            text: "A"
                            chosen: root.bookmarkA === markRow.modelData.id
                            onClicked: root.bookmarkA = markRow.modelData.id
                        }
                        ChronicleButton {
                            text: "B"
                            chosen: root.bookmarkB === markRow.modelData.id
                            onClicked: root.bookmarkB = markRow.modelData.id
                        }
                        ChronicleButton {
                            text: "Remove"
                            onClicked: {
                                root.confirmationId = "bookmark:" + markRow.modelData.id;
                                confirmDialog.open();
                            }
                        }
                    }
                    ChronicleLabel {
                        anchors.centerIn: parent
                        visible: marks.count === 0
                        text: "No bookmarks yet. Mark a moment before your next change."
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: availableWidth
                    clip: true
                    ChronicleLabel {
                        width: parent.width
                        wrapMode: Text.Wrap
                        font.pixelSize: Style.font.caption
                        text: Model.comparisonText(root.service ? root.service.comparison : null)
                    }
                }
            }
            RowLayout {
                ListView {
                    id: incidents
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.max(Style.space(180), root.width * 0.24)
                    clip: true
                    model: root.live.incidents || []
                    spacing: Style.space(4)
                    ScrollBar.vertical: ScrollBar {}
                    delegate: ChronicleButton {
                        required property var modelData
                        width: incidents.width - Style.space(14)
                        text: modelData.title + " · " + modelData.status + " · " + modelData.evidence_count
                        chosen: root.incidentId === modelData.id
                        onClicked: root.openIncident(modelData.id)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        Layout.fillWidth: true
                        Input {
                            id: incidentTitle
                            Layout.fillWidth: true
                            maximumLength: 100
                            placeholderText: "New incident title"
                        }
                        ChronicleButton {
                            text: "Create"
                            onClicked: root.request("create_incident", {
                                title: incidentTitle.text || "Investigation"
                            })
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        text: root.currentIncident ? root.currentIncident.title + " · " + root.currentIncident.status : "Select or create an incident"
                        color: Color.accent
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(120)
                        Notes {
                            id: notes
                            objectName: "incidentNotes"
                            placeholderText: "Investigation notes (4096 characters maximum)"
                            text: editor.notes
                            onTextChanged: if (text !== editor.notes)
                                editor.edit(text)
                            enabled: !!root.currentIncident && (!editor.busy || (editor.job && editor.job.cmd === "stage_draft"))
                            Accessible.name: "Incident notes"
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: Style.font.caption
                        color: editor.error || editor.conflict ? Color.urgent : Color.accent
                        text: editor.stateText
                    }
                    RowLayout {
                        ChronicleButton {
                            text: "Save notes"
                            enabled: !!root.currentIncident && !editor.busy && !editor.conflict
                            onClicked: editor.save(root.currentIncident.status)
                        }
                        ChronicleButton {
                            text: root.currentIncident && root.currentIncident.status === "closed" ? "Reopen" : "Resolve"
                            enabled: !!root.currentIncident && !editor.busy && !editor.conflict
                            onClicked: editor.save(root.currentIncident.status === "closed" ? "open" : "closed")
                        }
                        ChronicleButton {
                            text: "Review latest"
                            enabled: !!root.currentIncident && !editor.busy
                            onClicked: editor.review()
                        }
                        ChronicleButton {
                            text: "Discard draft"
                            enabled: !!root.currentIncident && !editor.busy && (editor.dirty || !!editor.draftToken)
                            onClicked: discardDialog.open()
                        }
                        ChronicleButton {
                            text: "Remove"
                            enabled: !!root.currentIncident && !editor.busy
                            onClicked: {
                                root.confirmationId = "incident:" + root.incidentId;
                                confirmDialog.open();
                            }
                        }
                    }
                    ListView {
                        id: pins
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Style.space(4)
                        model: root.currentIncident ? root.currentIncident.evidence : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: RowLayout {
                            id: pinRow
                            required property var modelData
                            width: pins.width - Style.space(14)
                            ChronicleLabel {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: Model.timestamp(pinRow.modelData.time_us) + " · " + pinRow.modelData.unit + "\n" + pinRow.modelData.message
                                font.pixelSize: Style.font.caption
                            }
                            ChronicleButton {
                                text: "Inspect"
                                onClicked: {
                                    root.inspectedCopy = pinRow.modelData;
                                    evidenceDialog.open();
                                }
                            }
                            ChronicleButton {
                                text: "Unpin"
                                enabled: !editor.busy
                                onClicked: root.request("unpin", {
                                    id: root.incidentId,
                                    event_id: pinRow.modelData.id
                                })
                            }
                        }
                        ChronicleLabel {
                            anchors.centerIn: parent
                            visible: pins.count === 0
                            width: parent.width
                            wrapMode: Text.Wrap
                            text: "No pinned evidence. Select an event on the Timeline and pin it here. Saved copies survive ordinary history retention."
                        }
                    }
                    RowLayout {
                        ChronicleButton {
                            text: root.detailedExport ? "Messages + notes included" : "Metadata only"
                            chosen: root.detailedExport
                            onClicked: root.detailedExport = !root.detailedExport
                        }
                        ChronicleButton {
                            text: "Preview export"
                            enabled: !!root.currentIncident && !editor.busy && (!root.detailedExport || !editor.dirty)
                            hint: editor.dirty ? "Commit or discard the draft before a detailed export. Metadata excludes notes." : "Review committed evidence only"
                            onClicked: root.request("preview_export", {
                                id: root.incidentId,
                                detail: root.detailedExport
                            })
                        }
                    }
                }
            }
            ScrollView {
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    width: parent.width
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "SOURCE COVERAGE"
                        color: Color.accent
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "User journal is read without elevated privileges. System journal is opt-in and limited to what your account can read. No records can mean no activity, missing retention, or unavailable access—not confirmed health."
                    }
                    Repeater {
                        model: root.live.sources || []
                        ChronicleLabel {
                            required property var modelData
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            font.pixelSize: Style.font.caption
                            text: modelData.id + " · " + modelData.status + " · checked " + Model.timestamp(modelData.checked_us) + " · last successful read " + Model.timestamp(modelData.last_success_us)
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: Style.font.caption
                        text: browser.result && browser.result.retained ? "Retained source-time bounds: " + Model.timestamp(browser.result.retained.from_us) + " → " + Model.timestamp(browser.result.retained.to_us) + ". Bounds do not establish continuous coverage." + (browser.result.receipt_age_estimated ? " Legacy receipt ages are migration-time estimates." : "") : "Open Timeline to query retained bounds. Receipt order controls count retention; source wall time controls display order."
                    }
                    RowLayout {
                        ChronicleButton {
                            text: root.live.paused ? "Resume recording" : "Pause recording"
                            onClicked: root.request("pause", {
                                paused: !root.live.paused
                            })
                        }
                        ChronicleButton {
                            text: root.live.system_journal ? "Disable system journal" : "Enable accessible system journal"
                            onClicked: root.request("system_journal", {
                                enabled: !root.live.system_journal
                            })
                        }
                        ChronicleButton {
                            text: "Refresh"
                            onClicked: root.request("refresh", {})
                        }
                    }
                    ChronicleLabel {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "BOUNDS & PRIVACY\n10,000 events / 7 days; 720 resource samples; 256 bookmarks; 128 incidents with 64 evidence copies each; 32 private exports. SQLite page budget is 32 MiB. Source reads are limited to 2 MiB / 2 seconds per attempt. A bounded tail can skip history: gaps are reported.\n\nRedaction runs before persistence, but cannot detect every secret. No arbitrary commands, clipboard capture, network upload, automatic repair, or service management. Export metadata first, then review any optional messages and notes.\n\nGRAPHICS\nPSI means percentage of time tasks were stalled; it is not CPU utilization. Lines break across missing or delayed samples. Event ordering uses recorded wall time; boot/monotonic provenance is retained for inspection. Wall-clock adjustments can change apparent order.\n\nKEYBOARD\n/ Search · Space freeze view · ↑/↓ select event · Ctrl+M mark current moment · Tab controls · Esc close. Scrolling the event list freezes the view to preserve your place.\n\nDEVELOPMENT GATE\nThis build has isolated tests. Installation, live popup behavior, native theme/monitor acceptance and compositor soak are still awaiting operator approval."
                    }
                    Item {
                        implicitHeight: Style.space(12)
                    }
                }
            }
        }
        ChronicleLabel {
            Layout.fillWidth: true
            font.pixelSize: Style.font.caption
            color: root.service && (root.service.lastError || root.live.storage_error) ? Color.urgent : Color.accent
            text: editor.error || (root.service ? (root.service.lastError || root.live.storage_error || root.service.lastAction || "Local evidence · correlation is not causation · no automatic repairs") : "Waiting for Chronicle service")
        }
    }
    Timer {
        id: queryDelay
        interval: 250
        onTriggered: root.updateQuery()
    }
    Dialog {
        id: jumpDialog
        title: "Jump to an exact moment"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(620))
        standardButtons: Dialog.Cancel
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ColumnLayout {
            width: parent.width
            ChronicleLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Enter an ISO timestamp with Z or a UTC offset to avoid timezone/DST ambiguity. The chosen interval is centered on that moment; labels remain local time."
            }
            Input {
                id: jumpInput
                Layout.fillWidth: true
                placeholderText: "2026-09-07T08:00:00-10:00"
                maximumLength: 40
                Accessible.name: "Exact historical timestamp"
            }
            ChronicleLabel {
                Layout.fillWidth: true
                font.pixelSize: Style.font.caption
                text: jumpInput.text && Model.parseInstant(jumpInput.text) === null ? "Use a valid date and explicit timezone, e.g. 2026-09-07T18:00Z." : "Recording continues while you inspect history."
            }
            ChronicleButton {
                text: "Open interval"
                enabled: Model.parseInstant(jumpInput.text) !== null
                onClicked: {
                    root.jumpTo(Model.parseInstant(jumpInput.text));
                    jumpDialog.close();
                }
            }
        }
    }
    Dialog {
        id: viewsDialog
        title: "Investigation views"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(680))
        height: Math.min(parent.height - 24, Style.space(480))
        standardButtons: Dialog.Close
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ColumnLayout {
            anchors.fill: parent
            RowLayout {
                ChronicleButton {
                    text: "All evidence"
                    onClicked: {
                        root.applyView({});
                        viewsDialog.close();
                    }
                }
                ChronicleButton {
                    text: "Errors"
                    onClicked: {
                        root.applyView({
                            severity: "error",
                            window_minutes: 60
                        });
                        viewsDialog.close();
                    }
                }
                ChronicleButton {
                    text: "Audio"
                    onClicked: {
                        root.applyView({
                            category: "audio",
                            window_minutes: 15
                        });
                        viewsDialog.close();
                    }
                }
                ChronicleButton {
                    text: "Network"
                    onClicked: {
                        root.applyView({
                            category: "network",
                            window_minutes: 15
                        });
                        viewsDialog.close();
                    }
                }
            }
            RowLayout {
                Input {
                    id: viewLabel
                    Layout.fillWidth: true
                    maximumLength: 100
                    placeholderText: "Name the current filters"
                }
                ChronicleButton {
                    text: "Save view"
                    enabled: !!viewLabel.text.trim()
                    onClicked: root.request("save_view", {
                        label: viewLabel.text,
                        search: search.text,
                        severity: root.severity,
                        category: root.category,
                        source: root.sourceFilter,
                        window_minutes: root.windowMinutes
                    })
                }
            }
            ChronicleLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Style.font.caption
                text: "Up to 20 views. Saves filters and window length, not a historical position. Saved text is redacted; review restored filters."
            }
            ListView {
                id: savedViews
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.live.saved_views || []
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    id: viewRow
                    required property var modelData
                    width: savedViews.width - Style.space(14)
                    ChronicleButton {
                        Layout.fillWidth: true
                        textAlignment: Text.AlignLeft
                        text: viewRow.modelData.label
                        onClicked: {
                            root.applyView(viewRow.modelData);
                            viewsDialog.close();
                        }
                    }
                    ChronicleButton {
                        text: "Remove"
                        onClicked: root.request("remove_view", {
                            id: viewRow.modelData.id
                        })
                    }
                }
            }
        }
    }
    Dialog {
        id: confirmDialog
        title: "Remove saved item?"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(500))
        standardButtons: Dialog.Cancel | Dialog.Ok
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ChronicleLabel {
            width: parent.width
            wrapMode: Text.Wrap
            text: "This removes the selected saved item from Chronicle. Export important evidence first. This cannot be undone."
        }
        onAccepted: {
            var parts = root.confirmationId.split(":");
            root.request(parts[0] === "bookmark" ? "remove_bookmark" : "remove_incident", {
                id: parts[1],
                confirm: true
            });
            if (parts[0] === "incident")
                root.incidentId = "";
        }
    }
    Dialog {
        id: discardDialog
        title: "Discard this draft?"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(540))
        standardButtons: Dialog.Cancel | Dialog.Ok
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ChronicleLabel {
            width: parent.width
            wrapMode: Text.Wrap
            text: "Discard the local text and the acknowledged draft, returning to committed notes. A changed draft in another editor will not be removed."
        }
        onAccepted: editor.discard()
    }
    Dialog {
        id: reviewDialog
        title: "Review latest incident · resolve explicitly"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(820))
        height: Math.min(parent.height - 24, Style.space(620))
        standardButtons: Dialog.Cancel
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ColumnLayout {
            anchors.fill: parent
            ChronicleLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Review all three versions. Keeping your text acknowledges the latest revision and saved draft before staging your version. Another subsequent edit still causes a conflict."
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Notes {
                    readOnly: true
                    maximumCharacters: 0
                    text: editor.reviewItem ? "COMMITTED (revision " + editor.reviewItem.revision + ")\n" + editor.reviewItem.notes + "\n\nSAVED DRAFT\n" + (editor.reviewItem.draft ? editor.reviewItem.draft.notes : "None") + "\n\nYOUR LOCAL TEXT\n" + editor.notes : ""
                }
            }
            RowLayout {
                ChronicleButton {
                    text: "Keep my text on latest revision"
                    onClicked: {
                        editor.rebase();
                        reviewDialog.close();
                    }
                }
                ChronicleButton {
                    text: "Use committed notes"
                    onClicked: {
                        editor.rebase();
                        editor.discard();
                        reviewDialog.close();
                    }
                }
            }
        }
    }
    Dialog {
        id: evidenceDialog
        title: "Saved evidence copy · retained independently"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(760))
        height: Math.min(parent.height - 24, Style.space(500))
        standardButtons: Dialog.Close
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ScrollView {
            anchors.fill: parent
            Notes {
                readOnly: true
                maximumCharacters: 0
                text: Model.evidenceText(root.inspectedCopy)
            }
        }
    }
    Dialog {
        id: exportDialog
        objectName: "exportDialog"
        title: "Review exact export · no upload"
        modal: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 24, Style.space(900))
        height: Math.min(parent.height - 24, Style.space(620))
        standardButtons: Dialog.Cancel
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        background: Rectangle {
            color: Color.popups.background
            border.color: Color.popups.border
        }
        ColumnLayout {
            anchors.fill: parent
            ChronicleLabel {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Review every field. Redaction is best-effort. Confirm writes these exact bytes to a private file; preview expires after five minutes."
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Notes {
                    readOnly: true
                    maximumCharacters: 0
                    wrapMode: TextEdit.WrapAnywhere
                    font.pixelSize: Style.font.caption
                    text: root.reviewedPreview ? root.reviewedPreview.text : ""
                }
            }
            ChronicleButton {
                text: "Save reviewed export"
                enabled: root.service && !!root.reviewedPreview
                onClicked: {
                    root.request("confirm_export", {
                        token: root.reviewedPreview.token
                    });
                    root.reviewedPreview = null;
                    exportDialog.close();
                }
            }
        }
    }
}
