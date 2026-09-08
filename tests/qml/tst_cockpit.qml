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
        cockpit.nowUs = 1000000000;
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
    function test_dialog_chrome_uses_popup_palette() {
        var dialog = findChild(cockpit, "filterDialog");
        dialog.showFilters("", []);
        compare(dialog.header.color, Color.popups.text);
        compare(dialog.header.background.color, Color.popups.background);
        compare(dialog.footer.background.color, Color.popups.background);
        dialog.close();
    }
    function test_filter_editor_validation_and_space_do_not_freeze() {
        var dialog = findChild(cockpit, "filterDialog");
        dialog.showFilters("", []);
        var field = findChild(dialog, "exclusionInput");
        field.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(!cockpit.frozen);
        field.text = "x\nx\nx\nx\nx\nx\nx\nx\nx";
        verify(!findChild(dialog, "applyFilters").enabled);
        field.text = "health\nrefresh";
        verify(findChild(dialog, "applyFilters").enabled);
        mouseClick(findChild(dialog, "applyFilters"));
        compare(cockpit.exclusions.length, 2);
        cockpit.applyView({});
    }
    function test_new_filters_are_restored_and_passed_to_history() {
        cockpit.applyView({
            unit: "pipewire.service",
            exclude: ["health"],
            window_minutes: 15
        });
        compare(cockpit.historyModel.options.unit, "pipewire.service");
        compare(cockpit.historyModel.options.exclude[0], "health");
        cockpit.applyView({});
        compare(cockpit.historyModel.options.unit, "");
        compare(cockpit.historyModel.options.exclude.length, 0);
    }
    function test_notes_outline_is_explicit_and_never_overwrites_work() {
        cockpit.incidentEditor.adopt({
            id: "outline",
            title: "Test",
            notes: "",
            revision: 1,
            status: "open",
            evidence: []
        });
        verify(cockpit.insertNotesOutline());
        verify(cockpit.incidentEditor.notes.indexOf("Observed facts") >= 0);
        verify(cockpit.incidentEditor.dirty);
        cockpit.incidentEditor.edit("My investigation");
        verify(!cockpit.insertNotesOutline());
        compare(cockpit.incidentEditor.notes, "My investigation");
    }
    function test_pin_from_context_preserves_exact_selected_identity() {
        cockpit.incidentEditor.adopt({
            id: "saved",
            title: "Saved",
            notes: "",
            revision: 1,
            status: "open",
            evidence: []
        });
        cockpit.pinEvidence("exact-surrounding-id");
        compare(sent[0].cmd, "pin");
        compare(sent[0].args.id, "saved");
        compare(sent[0].args.event_id, "exact-surrounding-id");
        compare(cockpit.page, 2);
    }
    function test_context_preserves_timeline_filters_and_exact_anchor() {
        cockpit.applyView({
            severity: "error",
            unit: "worker.service",
            exclude: ["health"]
        });
        cockpit.showContext("exact-id", 42);
        var dialog = findChild(cockpit, "contextDialog");
        compare(dialog.queryModel.options.id, "exact-id");
        compare(dialog.queryModel.options.ceiling, 42);
        verify(dialog.queryModel.options.severity === undefined);
        dialog.close();
        compare(cockpit.severity, "error");
        compare(cockpit.unitFilter, "worker.service");
        compare(cockpit.exclusions[0], "health");
        cockpit.applyView({});
    }
    function test_analysis_uses_accepted_range_filters_and_ceiling() {
        cockpit.applyView({
            unit: "worker.service",
            exclude: ["health"]
        });
        cockpit.historyModel.result = {
            events: [],
            from_us: 600000000,
            to_us: 900000000,
            ceiling: 42
        };
        cockpit.showAnalysis();
        var dialog = findChild(cockpit, "analysisDialog");
        compare(dialog.options.from_us, 600000000);
        compare(dialog.options.to_us, 900000000);
        compare(dialog.options.ceiling, 42);
        compare(dialog.options.exclude[0], "health");
        verify(cockpit.frozen);
        dialog.close();
        cockpit.applyView({});
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
    function test_density_and_axis_stay_on_the_returned_interval_until_refresh() {
        cockpit.historyModel.result = {
            events: [],
            from_us: 700000000,
            to_us: 1000000000
        };
        cockpit.nowUs = 1005000000;
        compare(cockpit.endUs, 1000000000);
        cockpit.updateQuery();
        compare(cockpit.historyModel.options.to_us, 1005000000);
        cockpit.nowUs = 1000000000;
    }
    function test_typing_space_in_notes_preserves_typography_and_does_not_freeze() {
        cockpit.incidentEditor.adopt({
            id: "one",
            title: "One",
            notes: "Text",
            revision: 1,
            status: "open",
            evidence: []
        });
        cockpit.page = 2;
        var field = findChild(cockpit, "incidentNotes");
        field.forceActiveFocus();
        field.cursorPosition = field.length;
        keyClick(Qt.Key_Space);
        compare(cockpit.incidentEditor.notes, "Text ");
        verify(!cockpit.frozen);
        cockpit.forceActiveFocus();
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
        const patterns = findChild(cockpit, "patternsButton");
        verify(patterns.mapToItem(cockpit, patterns.width, 0).x <= cockpit.width + 1);
        cockpit.page = 2;
        wait(20);
        const remove = findChild(cockpit, "removeIncidentButton");
        verify(remove.mapToItem(cockpit, remove.width, 0).x <= cockpit.width + 1);
        compare(findChild(cockpit, "chronicleTitle").font.pixelSize, Style.font.subtitle);
        test.width = 1280;
    }
}
