import QtQuick

// Each cockpit owns this limited model. The shared service routes replies only;
// it never stores another cockpit's query or historical result.
Item {
    id: root
    property var service: null
    property bool active: true
    property var options: null
    property var result: null
    property var pageStarts: [null]
    property int pageIndex: 0
    property var ceiling: null
    property var retentionBaseline: null
    property bool retentionChanged: false
    property string error: ""
    property string requestId: ""
    property int generation: 0
    property int sentGeneration: -1
    property bool queued: false
    readonly property bool busy: requestId !== ""

    function reset() {
        generation++;
        result = null;
        options = null;
        pageStarts = [null];
        pageIndex = 0;
        ceiling = null;
        retentionBaseline = null;
        retentionChanged = false;
        requestId = "";
        queued = false;
        error = "";
        dispatch.stop();
    }
    function hold() {
        generation++;
        queued = false;
        dispatch.stop();
    }
    function load(query, receiptCeiling) {
        generation++;
        options = query;
        result = null;
        pageStarts = [null];
        pageIndex = 0;
        ceiling = receiptCeiling === undefined ? null : receiptCeiling;
        retentionBaseline = null;
        retentionChanged = false;
        queued = true;
        dispatch.restart();
    }
    function older() {
        if (busy || !result || !result.next)
            return;
        pageStarts = pageStarts.slice(0, pageIndex + 1).concat([result.next]);
        pageIndex++;
        queued = true;
        dispatch.restart();
    }
    function newer() {
        if (busy || pageIndex < 1)
            return;
        pageIndex--;
        queued = true;
        dispatch.restart();
    }
    function pump() {
        if (!active || busy || !queued || !options || !service)
            return;
        queued = false;
        sentGeneration = generation;
        requestId = service.request("history", Object.assign({}, options, {
            ceiling: ceiling,
            before: pageStarts[pageIndex]
        }));
        if (!requestId)
            error = "History request not sent; recorder unavailable.";
    }
    onActiveChanged: if (active)
        dispatch.restart()
    Timer {
        id: dispatch
        interval: 1
        onTriggered: root.pump()
    }
    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCompleted(id, command, data, failure) {
            if (command !== "history" || id !== root.requestId)
                return;
            root.requestId = "";
            if (root.sentGeneration === root.generation) {
                root.error = failure;
                if (!failure) {
                    root.result = data;
                    root.ceiling = data.ceiling;
                    if (root.retentionBaseline === null)
                        root.retentionBaseline = data.retention_generation;
                    root.retentionChanged = data.retention_generation !== root.retentionBaseline;
                }
            }
            if (root.queued)
                dispatch.restart();
        }
        function onRestarted() {
            var query = root.options;
            root.reset();
            root.error = "Recorder restarted; historical membership refreshed. Review the interval.";
            if (query)
                root.load(query);
        }
    }
}
