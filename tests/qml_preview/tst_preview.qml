import QtQuick
import QtTest
import qs.Commons
import "../../qml" as Chronicle
import "../../qml/Timeline.js" as Model

TestCase {
    id: test
    name: "ChronicleFixturePreview"
    when: windowShown
    visible: true
    width: 1280
    height: 840
    property real baseUs: Date.UTC(2026, 8, 7, 18, 0, 0) * 1000
    Rectangle {
        anchors.fill: parent
        color: Color.popups.background
    }
    QtObject {
        id: fake
        property var snapshot: ({})
        property var incident: null
        property var preview: null
        property var comparison: null
        property bool daemonRunning: true
        property string lastError: ""
        property string lastAction: "Synthetic fixture · no host collection · not installed"
        function request(cmd, args) {
            return "fixture";
        }
    }
    Chronicle.Cockpit {
        id: cockpit
        anchors.fill: parent
        anchors.margins: 8
        service: fake
        nowUs: test.baseUs
        viewActive: false
    }
    function initTestCase() {
        var events = [], samples = [];
        var units = ["example.service", "omarchy-shell.service", "NetworkManager.service", "pipewire.service", "systemd-suspend.service"];
        var messages = ["Worker exited unexpectedly", "Desktop configuration reloaded", "Connection became unavailable", "Audio graph resynchronized", "System resumed"];
        var categories = ["service", "desktop", "network", "audio", "power"];
        for (var i = 0; i < 45; i++)
            events.unshift({
                id: "event-" + i,
                time_us: test.baseUs - (45 - i) * 5000000,
                severity: i % 5 === 0 ? "error" : i % 5 === 2 ? "warning" : "info",
                category: categories[i % 5],
                unit: units[i % 5],
                message: messages[i % 5],
                source: "demo",
                boot: "fixture-boot",
                monotonic_us: i * 5000000
            });
        for (var j = 0; j < 60; j++)
            samples.push({
                time_us: test.baseUs - (60 - j) * 5000000,
                values: {
                    cpu_some_avg10: j === 35 ? null : 3 + 2 * Math.sin(j / 4)
                }
            });
        fake.snapshot = {
            time_us: test.baseUs,
            demo: true,
            paused: false,
            sources: [
                {
                    id: "user-journal",
                    status: "demo",
                    checked_us: test.baseUs,
                    last_success_us: test.baseUs
                }
            ],
            events: events,
            samples: samples,
            event_count: 45,
            bookmarks: [
                {
                    id: "a",
                    label: "Before update",
                    time_us: test.baseUs - 200000000,
                    observed_us: test.baseUs - 201000000
                },
                {
                    id: "b",
                    label: "After update",
                    time_us: test.baseUs - 100000000,
                    observed_us: test.baseUs - 101000000
                }
            ],
            incidents: [
                {
                    id: "one",
                    title: "Intermittent audio interruption",
                    status: "open",
                    evidence_count: 3
                }
            ]
        };
        fake.incident = {
            id: "one",
            title: "Intermittent audio interruption",
            status: "open",
            notes: "Audio and link events occurred near each other. Cause not established.",
            evidence: events.slice(0, 3)
        };
        fake.incident.revision = 1;
        cockpit.incidentEditor.adopt(fake.incident);
        fake.comparison = {
            a: fake.snapshot.bookmarks[0],
            b: fake.snapshot.bookmarks[1],
            duration_us: 100000000,
            delta: {
                cpu_some_avg10: 1.2,
                memory_available_kib: -1024
            },
            missing: ["io_some_avg10"],
            units: {
                cpu_some_avg10: "percentage points",
                memory_available_kib: "KiB"
            }
        };
        cockpit.selectedId = "event-40";
        cockpit.historyModel.result = {
            events: events,
            matching_count: events.length,
            from_us: test.baseUs - 300000000,
            to_us: test.baseUs,
            next: null,
            ceiling: 45,
            density: Model.buckets(events, test.baseUs - 300000000, test.baseUs, 48)
        };
    }
    function test_capture_data() {
        return [
            {
                tag: "timeline",
                page: 0
            },
            {
                tag: "bookmarks",
                page: 1
            },
            {
                tag: "incidents",
                page: 2
            },
            {
                tag: "sources",
                page: 3
            }
        ];
    }
    function test_capture(data) {
        cockpit.page = data.page;
        wait(150);
        if (data.page === 0) {
            compare(cockpit.visibleEvents.length, 45);
            verify(!!cockpit.selectedEvent);
        }
        var path = "/tmp/chronicle-fixture-" + data.tag + "-" + Date.now() + ".png";
        // Capture the entire client area with native-style padding. No desktop
        // screenshot, window decorations, titlebar, compositing or image editing.
        grabImage(test).save(path);
        console.log("Fixture screenshot: " + path);
    }
    function test_tools_data() {
        return [
            {
                tag: "context"
            },
            {
                tag: "patterns"
            },
            {
                tag: "filters"
            }
        ];
    }
    function test_tools(data) {
        cockpit.page = 0;
        var dialog;
        if (data.tag === "context") {
            cockpit.showContext("event-40", 45);
            dialog = findChild(cockpit, "contextDialog");
            dialog.queryModel.result = {
                anchor: fake.snapshot.events[4],
                events: fake.snapshot.events.slice(0, 15).reverse(),
                shown_before: 10,
                before_count: 10,
                shown_after: 4,
                after_count: 4
            };
        } else if (data.tag === "patterns") {
            dialog = findChild(cockpit, "analysisDialog");
            dialog.showAnalysis({
                from_us: test.baseUs - 300000000,
                to_us: test.baseUs,
                severity: "all",
                source: "demo",
                exclude: []
            });
            dialog.queryModel.result = {
                from_us: test.baseUs - 300000000,
                to_us: test.baseUs,
                previous_from_us: test.baseUs - 600000001,
                previous_to_us: test.baseUs - 300000001,
                current_count: 45,
                previous_count: 9,
                group_count: 5,
                recorder_notices: 1,
                retained: {
                    from_us: test.baseUs - 600000000,
                    to_us: test.baseUs
                },
                caution: "Counts describe retained observations, not complete system activity. Zero observations do not prove recovery. Exact stored text may match after redaction.",
                groups: fake.snapshot.events.slice(0, 5).map(function (e, i) {
                    return Object.assign({}, e, {
                        current: 9,
                        previous: i === 0 ? 9 : 0,
                        delta: i === 0 ? 0 : 9,
                        state: i === 0 ? "unchanged" : "newly observed",
                        first_us: test.baseUs - 250000000,
                        last_us: e.time_us,
                        event_id: e.id
                    });
                })
            };
        } else {
            dialog = findChild(cockpit, "filterDialog");
            dialog.showFilters("pipewire.service", ["health check", "periodic refresh"]);
        }
        wait(100);
        dialog.queryModel && (dialog.queryModel.requestId = "");
        var path = "/tmp/chronicle-fixture-" + data.tag + "-" + Date.now() + ".png";
        grabImage(test).save(path);
        console.log("Fixture screenshot: " + path);
        dialog.close();
    }
}
