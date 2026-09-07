import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from chronicle.sources import Journal, read_pressure, run_bounded
from chronicle.recorder import Recorder
from chronicle.store import Store


class SourceTests(unittest.TestCase):
    def test_pressure_is_not_utilization_and_missing_is_null(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "pressure").mkdir()
            (root / "pressure/cpu").write_text("some avg10=2.50 avg60=1.00 avg300=0.00 total=99\n")
            (root / "pressure/io").write_text("some avg10=nan avg60=0\n")
            (root / "meminfo").write_text("MemTotal: 999 kB\nMemAvailable: 100 kB\n")
            values = read_pressure(root)
            self.assertEqual(values["cpu_some_avg10"], 2.5)
            self.assertIsNone(values["memory_some_avg10"])
            self.assertIsNone(values["io_some_avg10"])
            self.assertEqual(values["memory_available_kib"], 100)

    def test_bounded_command_timeout_and_output(self):
        timeout = run_bounded([sys.executable, "-c", "import time; time.sleep(5)"], timeout=.05)
        self.assertEqual(timeout["status"], "timeout")
        large = run_bounded([sys.executable, "-c", "print('x'*1000000)"], limit=100)
        self.assertEqual(large["status"], "truncated")
        self.assertLessEqual(len(large["stdout"]), 100)

    def test_source_scope_and_cursor_not_shell_interpolated(self):
        calls = []
        def runner(argv, **kwargs):
            calls.append(argv)
            return {"status": "ok", "stdout": b"", "code": 0}
        journal = Journal("user-journal", runner=runner)
        journal.read("cursor ; touch /bad")
        self.assertIn("--user", calls[0])
        self.assertIn("--after-cursor=cursor ; touch /bad", calls[0])
        self.assertNotIn("sh", calls[0])

    def test_cursor_loss_has_visible_gap_and_bounded_fallback(self):
        responses = iter([{"status": "error", "stdout": b"", "code": 1},
                          {"status": "ok", "stdout": b"", "code": 0}])
        result = Journal(runner=lambda *a, **k: next(responses)).read("expired")
        self.assertEqual(result["status"], "gap")
        self.assertTrue(result["gap"])

    def test_malformed_lines_do_not_advance_cursor(self):
        result = Journal(runner=lambda *a, **k: {"status": "ok", "stdout": b'{"bad":true}\nno\n', "code": 0}).read()
        self.assertEqual(result["events"], [])
        self.assertIsNone(result["cursor"])
        self.assertEqual(result["status"], "degraded")


class RecorderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = Store(Path(self.temp.name) / "state")
        self.recorder = Recorder(self.store, demo=True)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def command(self, cmd, **args):
        return self.recorder.command({"cmd": cmd, **args})

    def test_demo_never_calls_host_sources(self):
        self.recorder.poll()
        state = self.recorder.snapshot()
        self.assertTrue(state["demo"])
        self.assertGreater(state["event_count"], 0)
        self.assertTrue(all(s["status"] == "demo" for s in state["sources"]))

    def test_pause_survives_restart_and_panel_close_does_not_pause(self):
        self.command("panel", open=False)
        self.assertFalse(self.recorder.paused)
        self.command("pause", paused=True)
        other = Recorder(self.store, demo=True)
        self.assertTrue(other.paused)
        count = len(self.store.samples())
        other.poll()
        self.assertEqual(len(self.store.samples()), count)

    def test_bookmark_uses_collected_not_caller_supplied_metrics(self):
        self.recorder.poll()
        result = self.command("bookmark", label="Before", values={"memory_available_kib": 123456789})
        self.assertNotEqual(result["values"]["memory_available_kib"], 123456789)

    def test_unknown_or_wrong_type_commands_rejected(self):
        for command in ({"cmd": "reboot"}, {"cmd": "pause", "paused": "false"},
                        {"cmd": "panel", "open": 1}, [], {"cmd": "query", "limit": -1}):
            with self.subTest(command=command), self.assertRaises(ValueError):
                self.recorder.command(command)

    def test_unavailable_sources_remain_qualified(self):
        class Broken:
            name = "user-journal"
            def read(self, cursor=None):
                return {"status": "timeout", "events": [], "cursor": None, "gap": False}
        self.recorder.demo = False
        self.recorder.journals = [Broken()]
        self.recorder.poll()
        status = {s["id"]: s["status"] for s in self.recorder.snapshot()["sources"]}
        self.assertEqual(status["user-journal"], "timeout")

    def test_cli_protocol_and_eof_cleanup(self):
        result = subprocess.run([sys.executable, "-m", "chronicle", "--state-dir", str(Path(self.temp.name) / "cli"), "--demo"],
                                input='not-json\n{"cmd":"bookmark","label":"Before","request_id":"one"}\n{"cmd":"shutdown","request_id":"two"}\n',
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        messages = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertTrue(any(m.get("type") == "error" for m in messages))
        self.assertTrue(any(m.get("request_id") == "one" and m.get("ok") for m in messages))
        self.assertEqual(result.stderr, "")

    def test_oversized_command_recovered_at_next_line(self):
        result = subprocess.run([sys.executable, "-m", "chronicle", "--state-dir", str(Path(self.temp.name) / "large"), "--demo"],
                                input="x" * 100000 + '\n{"cmd":"shutdown","request_id":"done"}\n',
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        messages = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertTrue(any(m.get("request_id") == "done" for m in messages))
