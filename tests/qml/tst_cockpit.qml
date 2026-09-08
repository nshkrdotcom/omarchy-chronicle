import QtQuick
import QtTest
import qs.Commons
import "../../qml" as Chronicle

TestCase {
    id: test
    name: "ChronicleCockpit"
    when: windowShown
    width: 1280
    height: 840
    visible: true
    property var sent: []
    QtObject {
        id: fake
        property var snapshot: ({
                time_us: 1000000000,
                demo: true,
                paused: false,
                sources: [
                    {
                        id: "user-journal",
                        status: "demo"
                    }
                ],
                events: [
                    {
                        id: "one",
                        time_us: 999000000,
                        severity: "error",
                        category: "service",
                        unit: "worker.service",
                        message: "Example failure",
                        source: "demo",
                        boot: "fixture",
                        monotonic_us: 10
                    }
                ],
                samples: [],
                bookmarks: [],
                incidents: [],
                event_count: 1
            })
        property var incident: null
        property var comparison: null
        property var preview: null
        property string lastAction: ""
        property string lastError: ""
        property bool daemonRunning: true
        function request(cmd, args) {
            test.sent.push({
                cmd: cmd,
                args: args
            });
            return "request";
        }
    }
    Chronicle.Cockpit {
        id: cockpit
        anchors.fill: parent
        service: fake
        nowUs: 1000000000
        viewActive: false
    }
    function init() {
        cockpit.page = 0;
        cockpit.frozen = false;
        cockpit.selectedId = "";
        cockpit.anchorUs = 0;
        cockpit.severity = "all";
        cockpit.category = "all";
        cockpit.sourceFilter = "all";
        cockpit.windowMinutes = 5;
        cockpit.historyModel.reset();
        cockpit.incidentEditor.reset();
        sent = [];
    }
    function test_native_header_contract() {
        const title = findChild(cockpit, "chronicleTitle");
        compare(title.font.pixelSize, Style.font.subtitle);
        compare(title.font.weight, Font.DemiBold);
        fuzzyCompare(title.font.letterSpacing, 0.4, 0.02);
        const actions = findChild(cockpit, "headerActions");
        verify(actions.x > title.x + title.width);
    }
    function test_foreign_incident_response_cannot_replace_local_notes() {
        cockpit.incidentEditor.adopt({
            id: "local",
            title: "Local",
            notes: "Committed",
            revision: 1,
            status: "open",
            evidence: []
        });
        cockpit.incidentEditor.edit("Human work");
        fake.incident = {
            id: "other",
            notes: "Unrelated",
            title: "Other",
            revision: 1
        };
        compare(cockpit.currentIncident.id, "local");
        compare(findChild(cockpit, "incidentNotes").text, "Human work");
    }
    function test_bookmark_context_is_centered_and_frozen() {
        cockpit.jumpTo(500000000);
        verify(cockpit.frozen);
        compare(cockpit.page, 0);
        compare(cockpit.startUs, 350000000);
        compare(cockpit.endUs, 650000000);
        compare(cockpit.historyModel.options.from_us, 350000000);
    }
    function test_saved_view_applies_filters_without_header_change() {
        cockpit.applyView({
            search: "failure",
            severity: "error",
            category: "audio",
            source: "user-journal",
            window_minutes: 15
        });
        compare(cockpit.severity, "error");
        compare(cockpit.category, "audio");
        compare(cockpit.windowMinutes, 15);
        compare(cockpit.historyModel.options.search, "failure");
        compare(findChild(cockpit, "chronicleTitle").font.pixelSize, Style.font.subtitle);
        findChild(cockpit, "searchInput").text = "";
    }
    function test_history_rows_are_not_refiltered_with_incompatible_unicode_rules() {
        cockpit.historyModel.result = {
            events: [
                {
                    id: "unicode",
                    message: "Straße",
                    unit: "unit",
                    time_us: 999000000
                }
            ],
            from_us: 700000000,
            to_us: 1000000000
        };
        findChild(cockpit, "searchInput").text = "STRASSE";
        compare(cockpit.visibleEvents.length, 1);
        findChild(cockpit, "searchInput").text = "";
    }
    function test_freeze_does_not_pause_recorder() {
        cockpit.toggleFreeze();
        verify(cockpit.frozen);
        compare(cockpit.visibleEvents.length, 1);
        compare(sent.length, 0);
        cockpit.toggleFreeze();
        verify(!cockpit.frozen);
    }
    function test_mark_sends_current_moment_request() {
        mouseClick(findChild(cockpit, "markButton"));
        compare(sent[0].cmd, "bookmark");
    }
    function test_filter_and_exact_selection() {
        cockpit.selectEvent("one");
        compare(cockpit.selectedEvent.id, "one");
        cockpit.selectEvent("missing");
        compare(cockpit.selectedEvent, null);
    }
    function test_keyboard_freeze_and_escape() {
        cockpit.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(cockpit.frozen);
    }
    function test_tabs_and_focus() {
        mouseClick(findChild(cockpit, "sourcesTab"));
        compare(cockpit.page, 3);
        verify(findChild(cockpit, "sourcesTab").activeFocus);
    }
    function test_search_shortcut_returns_to_timeline() {
        cockpit.page = 3;
        cockpit.forceActiveFocus();
        keyClick(Qt.Key_Slash);
        compare(cockpit.page, 0);
        verify(findChild(cockpit, "searchInput").activeFocus);
    }
    function test_typing_space_in_search_does_not_freeze() {
        const field = findChild(cockpit, "searchInput");
        field.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(!cockpit.frozen);
        field.text = "";
        cockpit.forceActiveFocus();
    }
    function test_caption_change_never_resizes_title() {
        const original = Style.font;
        Style.font = ({
                family: original.family,
                caption: 18,
                body: original.body,
                subtitle: original.subtitle,
                title: original.title
            });
        wait(20);
        compare(findChild(cockpit, "chronicleTitle").font.pixelSize, original.subtitle);
        const rail = findChild(cockpit, "headerActions");
        verify(rail.x + rail.width <= cockpit.width + 1);
        Style.font = original;
    }
    function test_widths_keep_actions_on_right_data() {
        return [
            {
                tag: "compact",
                size: 800
            },
            {
                tag: "normal",
                size: 1280
            }
        ];
    }
    function test_widths_keep_actions_on_right(data) {
        test.width = data.size;
        wait(30);
        const rail = findChild(cockpit, "headerActions");
        verify(rail.x + rail.width <= cockpit.width + 1);
        compare(findChild(cockpit, "chronicleTitle").font.pixelSize, Style.font.subtitle);
        test.width = 1280;
    }
}
