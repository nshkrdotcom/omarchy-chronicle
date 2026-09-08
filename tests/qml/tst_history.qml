import QtQuick
import QtTest
import "../../qml" as Chronicle

TestCase {
    id: test
    name: "ChronicleHistory"
    property var sent: []
    property int serial: 0
    QtObject {
        id: fake
        signal completed(string requestId, string command, var result, string error)
        signal restarted
        function request(cmd, args) {
            var id = "request-" + (++test.serial);
            test.sent.push({
                id: id,
                cmd: cmd,
                args: args
            });
            return id;
        }
    }
    Chronicle.HistoryController {
        id: browser
        service: fake
    }
    function init() {
        browser.reset();
        sent = [];
    }
    function reply(job, next) {
        fake.completed(job.id, "history", {
            events: [
                {
                    id: job.id
                }
            ],
            next: next || null,
            ceiling: 12,
            retention_generation: 0
        }, "");
    }
    function test_ignores_other_cockpit_results() {
        browser.load({
            from_us: 0,
            to_us: 100
        });
        tryCompare(test, "serial", serial + 1);
        fake.completed("other", "history", {
            events: [
                {
                    id: "wrong"
                }
            ]
        }, "");
        compare(browser.result, null);
        reply(sent[0]);
        compare(browser.result.events[0].id, sent[0].id);
    }
    function test_changed_filter_discards_inflight_and_coalesces() {
        browser.load({
            from_us: 0,
            to_us: 100,
            search: "old"
        });
        tryVerify(function () {
            return sent.length === 1;
        });
        browser.load({
            from_us: 0,
            to_us: 100,
            search: "middle"
        });
        browser.load({
            from_us: 0,
            to_us: 100,
            search: "latest"
        });
        wait(20);
        compare(sent.length, 1);
        reply(sent[0]);
        compare(browser.result, null);
        tryVerify(function () {
            return sent.length === 2;
        });
        compare(sent[1].args.search, "latest");
        reply(sent[1]);
        compare(browser.result.events[0].id, sent[1].id);
    }
    function test_pages_keep_ceiling_and_previous_cursor() {
        browser.load({
            from_us: 0,
            to_us: 100
        });
        tryVerify(function () {
            return sent.length === 1;
        });
        reply(sent[0], {
            time_us: 50,
            id: "abc"
        });
        browser.older();
        tryVerify(function () {
            return sent.length === 2;
        });
        compare(sent[1].args.ceiling, 12);
        compare(sent[1].args.before.id, "abc");
        reply(sent[1]);
        browser.newer();
        tryVerify(function () {
            return sent.length === 3;
        });
        compare(sent[2].args.before, null);
        compare(sent[2].args.ceiling, 12);
    }
    function test_inactive_cockpit_does_not_send_queries() {
        browser.active = false;
        browser.load({
            from_us: 0,
            to_us: 100
        });
        wait(30);
        compare(sent.length, 0);
        browser.active = true;
        tryVerify(function () {
            return sent.length === 1;
        });
        reply(sent[0]);
    }
    function test_error_releases_request_without_retry_loop() {
        browser.load({
            from_us: 0,
            to_us: 100
        });
        tryVerify(function () {
            return sent.length === 1;
        });
        fake.completed(sent[0].id, "history", null, "Storage unavailable");
        verify(!browser.busy);
        compare(browser.error, "Storage unavailable");
        wait(30);
        compare(sent.length, 1);
    }
}
