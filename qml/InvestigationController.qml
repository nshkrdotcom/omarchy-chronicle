import QtQuick

// One in-flight request per dialog. Changed options invalidate its reply and
// coalesce into one follow-up; the shared service does not own dialog results.
Item {
    id: root
    property var service: null
    property var result: null
    property var options: null
    property string command: ""
    property string requestId: ""
    property string sentCommand: ""
    property string error: ""
    property int generation: 0
    property int sentGeneration: -1
    property bool queued: false
    readonly property bool busy: !!requestId || queued
    signal ready
    function reset() {
        generation++;
        requestId = "";
        queued = false;
        result = null;
        error = "";
        dispatch.stop();
    }
    function load(cmd, args) {
        generation++;
        command = cmd;
        options = JSON.parse(JSON.stringify(args));
        result = null;
        error = "";
        queued = true;
        dispatch.restart();
    }
    function pump() {
        if (requestId || !queued)
            return;
        queued = false;
        sentCommand = command;
        sentGeneration = generation;
        requestId = service ? service.request(command, options) : "";
        if (!requestId)
            error = "Request not sent. Check Sources, then try again.";
    }
    Timer {
        id: dispatch
        interval: 1
        onTriggered: root.pump()
    }
    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCompleted(id, cmd, data, failure) {
            if (!root.requestId || id !== root.requestId || cmd !== root.sentCommand)
                return;
            root.requestId = "";
            if (root.sentGeneration === root.generation) {
                root.error = failure;
                if (!failure) {
                    root.result = data;
                    root.ready();
                }
            }
            if (root.queued)
                dispatch.restart();
        }
        function onRestarted() {
            var wasUsed = !!root.options;
            root.reset();
            if (wasUsed)
                root.error = "Recorder restarted. Close and reopen this tool to query the new session.";
        }
    }
}
