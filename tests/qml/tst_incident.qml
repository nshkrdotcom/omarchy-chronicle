import QtQuick
import QtTest
import "../../qml" as Chronicle

TestCase {
    id: test
    name: "ChronicleIncident"
    property var sent: []
    property int serial: 0
    QtObject {
        id: fake
        signal completed(string requestId, string command, var result, string error)
        signal restarted
        function request(cmd, args) {
            var id = "edit-" + (++test.serial);
            test.sent.push({
                id: id,
                cmd: cmd,
                args: args
            });
            return id;
        }
    }
    Chronicle.IncidentController {
        id: editor
        service: fake
    }
    function item(id, notes, revision) {
        return {
            id: id,
            title: id,
            notes: notes,
            status: "open",
            revision: revision || 1,
            evidence: [],
            draft: null
        };
    }
    function init() {
        editor.reset();
        editor.adopt(item("one", "Committed", 1));
        sent = [];
    }
    function reply(index, data, error) {
        var job = sent[index];
        fake.completed(job.id, job.cmd, data, error || "");
    }
    function test_navigation_stages_before_switching_and_waits_for_ack() {
        editor.edit("Human text");
        editor.open("two");
        compare(sent[0].cmd, "stage_draft");
        compare(editor.item.id, "one");
        reply(0, {
            notes: "Human text",
            base_revision: 1,
            token: "draft-one"
        });
        compare(sent[1].cmd, "incident");
        reply(1, item("two", "Second", 1));
        compare(editor.notes, "Second");
    }
    function test_staging_failure_preserves_text_and_stays_on_incident() {
        editor.edit("Do not lose this");
        editor.open("two");
        reply(0, null, "Disk full");
        compare(editor.item.id, "one");
        compare(editor.notes, "Do not lose this");
        compare(sent.length, 1);
        compare(editor.error, "Disk full");
    }
    function test_late_stage_ack_does_not_replace_new_keystrokes() {
        editor.edit("First");
        editor.flush();
        editor.edit("Second");
        reply(0, {
            notes: "First",
            base_revision: 1,
            token: "token"
        });
        compare(editor.notes, "Second");
        verify(!editor.draftSaved);
    }
    function test_save_contains_expected_revision_and_draft_token() {
        editor.edit("Draft");
        editor.flush();
        reply(0, {
            notes: "Draft",
            base_revision: 1,
            token: "token"
        });
        editor.save("closed");
        compare(sent[1].args.expected_revision, 1);
        compare(sent[1].args.draft_token, "token");
        reply(1, null, "Incident changed");
        compare(editor.notes, "Draft");
        verify(editor.dirty);
    }
    function test_restore_draft_and_explicit_review_rebase() {
        var current = item("one", "Other editor", 3);
        current.draft = {
            notes: "Recovered draft",
            base_revision: 1,
            token: "old"
        };
        editor.adopt(current);
        compare(editor.notes, "Recovered draft");
        verify(editor.conflict);
        editor.review();
        reply(0, current);
        compare(editor.baseRevision, 1);
        editor.rebase();
        compare(editor.baseRevision, 3);
        compare(editor.notes, "Recovered draft");
    }
    function test_unrelated_results_cannot_replace_notes() {
        editor.edit("Local");
        fake.completed("someone-else", "incident", item("two", "Wrong", 1), "");
        compare(editor.notes, "Local");
    }
    function test_close_stages_and_emits_only_after_acknowledgement() {
        var spy = Qt.createQmlObject('import QtTest; SignalSpy {}', test);
        spy.target = editor;
        spy.signalName = "readyToClose";
        editor.edit("Close draft");
        editor.closeSafely();
        compare(spy.count, 0);
        reply(0, {
            notes: "Close draft",
            base_revision: 1,
            token: "saved"
        });
        compare(spy.count, 1);
        spy.destroy();
    }
    function test_returning_to_committed_text_replaces_old_durable_draft() {
        editor.edit("Temporary");
        editor.flush();
        reply(0, {
            notes: "Temporary",
            base_revision: 1,
            token: "old"
        });
        editor.edit("Committed");
        editor.flush();
        compare(sent.length, 2);
        compare(sent[1].args.notes, "Committed");
    }
}
