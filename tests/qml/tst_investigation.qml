import QtQuick
import QtTest
import "../../qml" as Chronicle

TestCase {
    id: test
    name: "ChronicleInvestigation"
    property var sent: []
    property int serial: 0
    QtObject {
        id: fake
        signal completed(string requestId, string command, var result, string error)
        signal restarted
        function request(cmd, args) {
            var id = "job-" + (++test.serial);
            test.sent.push({
                id: id,
                cmd: cmd,
                args: args
            });
            return id;
        }
    }
    Chronicle.InvestigationController {
        id: first
        service: fake
    }
    Chronicle.InvestigationController {
        id: second
        service: fake
    }
    function init() {
        first.reset();
        second.reset();
        first.service = fake;
        sent = [];
    }
    function test_panels_accept_only_their_own_replies() {
        first.load("context", {
            id: "a"
        });
        second.load("context", {
            id: "b"
        });
        tryVerify(function () {
            return sent.length === 2;
        });
        fake.completed(sent[0].id, "context", {
            anchor: "a"
        }, "");
        compare(first.result.anchor, "a");
        compare(second.result, null);
        fake.completed(sent[1].id, "context", {
            anchor: "b"
        }, "");
        compare(second.result.anchor, "b");
    }
    function test_scope_changes_coalesce_and_drop_stale_results() {
        first.load("context", {
            scope: "unit"
        });
        tryVerify(function () {
            return sent.length === 1;
        });
        first.load("context", {
            scope: "all"
        });
        first.load("context", {
            scope: "unit",
            radius_seconds: 600
        });
        fake.completed(sent[0].id, "context", {
            stale: true
        }, "");
        compare(first.result, null);
        tryVerify(function () {
            return sent.length === 2;
        });
        compare(sent[1].args.radius_seconds, 600);
        fake.completed(sent[1].id, "context", {
            correct: true
        }, "");
        verify(first.result.correct);
    }
    function test_restart_clears_result_and_requires_retry() {
        first.load("analyze", {});
        tryVerify(function () {
            return sent.length === 1;
        });
        fake.completed(sent[0].id, "analyze", {
            groups: []
        }, "");
        fake.restarted();
        compare(first.result, null);
        verify(first.error.length > 0);
        verify(!first.busy);
        wait(20);
        compare(sent.length, 1);
    }
    function test_unavailable_service_and_errors_preserve_no_stale_result() {
        first.service = null;
        first.load("context", {});
        tryVerify(function () {
            return first.error.length > 0;
        });
        verify(!first.busy);
        first.service = fake;
        first.load("context", {});
        tryVerify(function () {
            return sent.length === 1;
        });
        fake.completed(sent[0].id, "context", null, "Expired anchor");
        compare(first.error, "Expired anchor");
        compare(first.result, null);
    }
    function test_close_discards_late_reply() {
        first.load("context", {});
        tryVerify(function () {
            return sent.length === 1;
        });
        first.reset();
        fake.completed(sent[0].id, "context", {
            late: true
        }, "");
        compare(first.result, null);
    }
}
