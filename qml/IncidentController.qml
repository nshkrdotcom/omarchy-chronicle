import QtQuick

Item {
    id: root
    property var service: null
    property var item: null
    property string notes: ""
    property int baseRevision: 1
    property string draftToken: ""
    property string stagedText: ""
    property string error: ""
    property string requestId: ""
    property var job: null
    property var nextAction: null
    property var reviewItem: null
    readonly property bool busy: requestId !== ""
    readonly property bool dirty: !!item && notes !== item.notes
    readonly property bool draftSaved: dirty && !!draftToken && notes === stagedText
    readonly property bool needsStage: !!item && notes !== stagedText
    readonly property bool conflict: !!item && baseRevision !== item.revision
    readonly property string stateText: error || (conflict ? "Incident changed. Review latest before saving; local text is preserved." : needsStage ? "Draft not yet acknowledged" : draftSaved ? "Draft saved privately · not committed or exported" : "Committed notes")
    signal readyToClose
    signal reviewReady

    function reset() {
        idle.stop();
        item = null;
        notes = "";
        stagedText = "";
        baseRevision = 1;
        draftToken = "";
        requestId = "";
        job = null;
        nextAction = null;
        reviewItem = null;
        error = "";
    }
    function adopt(data) {
        item = data;
        var draft = data.draft || null;
        notes = draft ? draft.notes : data.notes;
        stagedText = notes;
        baseRevision = draft ? draft.base_revision : data.revision;
        draftToken = draft ? draft.token : "";
        error = "";
    }
    function edit(text) {
        notes = text;
        idle.restart();
    }
    function send(cmd, args, mode) {
        if (busy || !service)
            return "";
        job = {
            cmd: cmd,
            args: args,
            mode: mode || ""
        };
        requestId = service.request(cmd, args);
        if (!requestId) {
            error = "Recorder unavailable; local notes have not been saved.";
            job = null;
        }
        return requestId;
    }
    function flush() {
        idle.stop();
        if (busy || !item || !needsStage)
            return;
        send("stage_draft", {
            id: item.id,
            notes: notes,
            base_revision: baseRevision,
            draft_token: draftToken
        });
    }
    function flushThen(action) {
        nextAction = action;
        if (busy)
            return;
        if (needsStage) {
            flush();
            return;
        }
        nextAction = null;
        if (action.cmd === "close") {
            readyToClose();
            return;
        }
        send(action.cmd, action.args, action.mode);
    }
    function open(id) {
        flushThen({
            cmd: "incident",
            args: {
                id: id
            }
        });
    }
    function closeSafely() {
        flushThen({
            cmd: "close",
            args: {}
        });
    }
    function perform(cmd, args) {
        if (cmd === "create_incident") {
            // The controller owns the follow-up pin; do not duplicate the
            // service's legacy create+pin convenience request.
            flushThen({
                cmd: cmd,
                args: {
                    title: args.title
                },
                mode: args.pin_event_id || ""
            });
            return requestId;
        }
        if (busy) {
            error = "Wait for the current incident action to finish.";
            return "";
        }
        return send(cmd, args);
    }
    function save(status) {
        idle.stop();
        if (!item || busy)
            return;
        send("update_incident", {
            id: item.id,
            notes: notes,
            status: status,
            expected_revision: baseRevision,
            draft_token: draftToken
        });
    }
    function discard() {
        idle.stop();
        if (item && !busy)
            send("discard_draft", {
                id: item.id,
                draft_token: draftToken
            });
    }
    function review() {
        if (item && !busy)
            send("incident", {
                id: item.id
            }, "review");
    }
    function rebase() {
        if (!reviewItem || busy)
            return;
        item = reviewItem;
        baseRevision = reviewItem.revision;
        draftToken = reviewItem.draft ? reviewItem.draft.token : "";
        stagedText = reviewItem.draft ? reviewItem.draft.notes : reviewItem.notes;
        reviewItem = null;
        error = "";
        idle.restart();
    }
    Timer {
        id: idle
        interval: 500
        onTriggered: root.flush()
    }
    Connections {
        target: root.service
        ignoreUnknownSignals: true
        function onCompleted(id, command, data, failure) {
            if (id !== root.requestId || !root.job)
                return;
            var finished = root.job;
            root.requestId = "";
            root.job = null;
            if (failure) {
                root.error = failure;
                root.nextAction = null;
                return;
            }
            root.error = "";
            if (command === "stage_draft") {
                root.draftToken = data.token;
                root.stagedText = data.notes;
                if (root.notes === finished.args.notes)
                    root.notes = data.notes;
                if (root.needsStage)
                    idle.restart();
            } else if (command === "incident" && finished.mode === "review") {
                root.reviewItem = data;
                root.reviewReady();
            } else if (command === "incident" || command === "create_incident" || command === "discard_draft") {
                root.adopt(data);
                if (command === "create_incident" && finished.mode)
                    root.send("pin", {
                        id: data.id,
                        event_id: finished.mode
                    });
            } else if (command === "update_incident") {
                var changedSinceSend = root.notes !== finished.args.notes;
                var latestText = root.notes;
                root.adopt(data);
                if (changedSinceSend) {
                    root.notes = latestText;
                    idle.restart();
                }
            } else if (command === "pin" || command === "unpin") {
                if (root.item && data.id === root.item.id) {
                    var clean = !root.dirty;
                    root.item = data;
                    if (clean)
                        root.adopt(data);
                }
            } else if (command === "remove_incident")
                root.reset();
            if (root.nextAction)
                root.flushThen(root.nextAction);
        }
        function onRestarted() {
            root.error = "Recorder restarted. Local notes retained; review latest before saving.";
            root.nextAction = null;
            idle.stop();
        }
    }
    Component.onDestruction: flush()
}
