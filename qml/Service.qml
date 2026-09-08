import QtQuick
import Quickshell.Io

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    // Explicit seams for standalone, offscreen integration; never set by normal installation.
    property bool demoMode: false
    property string stateDirectory: ""
    property var snapshot: ({})
    property var incident: null
    property var comparison: null
    property var preview: null
    property string lastAction: ""
    property string lastError: ""
    property var pending: ({})
    property int sequence: 0
    property int restartDelay: 1000
    property bool shuttingDown: false
    property var panelOwners: ({})
    readonly property bool daemonRunning: daemon.running
    readonly property string pluginRoot: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""

    function setPanelOpen(owner, opened) {
        var next = Object.assign({}, panelOwners);
        if (opened)
            next[owner] = true;
        else
            delete next[owner];
        panelOwners = next;
        request("panel", {
            open: Object.keys(next).length > 0
        });
    }
    function request(cmd, args) {
        if (!daemon.running || Object.keys(pending).length >= 32) {
            lastError = "Recorder unavailable or request queue full. No action was sent.";
            return "";
        }
        var id = "ui-" + (++sequence);
        var data = Object.assign({}, args || {}, {
            cmd: cmd,
            request_id: id
        });
        var next = Object.assign({}, pending);
        next[id] = {
            cmd: cmd,
            args: args || {},
            sent: Date.now()
        };
        pending = next;
        daemon.write(JSON.stringify(data) + "\n");
        return id;
    }
    function handleLine(line) {
        if (line.length > 8 * 1024 * 1024) {
            lastError = "Oversized helper output rejected.";
            return;
        }
        try {
            var data = JSON.parse(line);
            if (data.type === "snapshot" && data.protocol === 1) {
                if (snapshot.session && snapshot.session !== data.session) {
                    incident = null;
                    comparison = null;
                    preview = null;
                    pending = ({});
                    lastAction = "Recorder restarted; selections need review.";
                }
                snapshot = data;
                restartDelay = 1000;
                return;
            }
            if (data.type === "error") {
                lastError = String(data.error || "Request failed");
                var errors = Object.assign({}, pending);
                delete errors[data.request_id];
                pending = errors;
                return;
            }
            var job = pending[data.request_id];
            if (data.type !== "result" || !job)
                return;
            var next = Object.assign({}, pending);
            delete next[data.request_id];
            pending = next;
            if (!data.ok) {
                lastError = "Request rejected";
                return;
            }
            lastError = "";
            if (["create_incident", "incident", "update_incident", "pin", "unpin"].indexOf(job.cmd) >= 0) {
                incident = data.result;
                if (job.cmd === "create_incident" && job.args.pin_event_id)
                    request("pin", {
                        id: incident.id,
                        event_id: job.args.pin_event_id
                    });
            }
            if (job.cmd === "remove_incident") {
                incident = null;
                preview = null;
            }
            if (job.cmd === "compare")
                comparison = data.result;
            if (job.cmd === "preview_export")
                preview = data.result;
            if (job.cmd === "confirm_export") {
                preview = null;
                lastAction = "Saved reviewed evidence: " + data.result.path;
            } else if (["panel", "query", "incident"].indexOf(job.cmd) < 0)
                lastAction = job.cmd.replace(/_/g, " ") + " completed.";
        } catch (error) {
            lastError = "Invalid helper response; no result accepted.";
        }
    }
    Process {
        id: daemon
        command: root.pluginRoot ? ["python3", root.pluginRoot + "/bin/chronicle"].concat(root.stateDirectory ? ["--state-dir", root.stateDirectory] : []).concat(root.demoMode ? ["--demo"] : []) : []
        stdinEnabled: true
        running: root.pluginRoot !== "" && !root.shuttingDown
        stdout: SplitParser {
            onRead: function (line) {
                root.handleLine(line);
            }
        }
        stderr: SplitParser {
            onRead: function (line) {
                if (line.trim())
                    root.lastError = "Recorder reported an internal error; inspect source and state availability.";
            }
        }
        onStarted: Qt.callLater(function () {
            root.request("panel", {
                open: Object.keys(root.panelOwners).length > 0
            });
        })
        onExited: function (code) {
            root.pending = ({});
            root.preview = null;
            if (root.shuttingDown)
                return;
            root.lastError = "Recorder stopped (" + code + "). Retrying with bounded backoff; previous evidence remains on disk.";
            restart.interval = root.restartDelay;
            root.restartDelay = Math.min(30000, root.restartDelay * 2);
            restart.restart();
        }
    }
    Timer {
        id: restart
        onTriggered: if (!root.shuttingDown && root.pluginRoot)
            daemon.running = true
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var next = Object.assign({}, root.pending);
            Object.keys(next).forEach(function (id) {
                if (Date.now() - next[id].sent > 30000) {
                    delete next[id];
                    root.lastError = "Request timed out. Refresh before repeating an action.";
                }
            });
            root.pending = next;
        }
    }
    Component.onDestruction: {
        shuttingDown = true;
        restart.stop();
        daemon.running = false;
    }
}
