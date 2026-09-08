import json
import os
from pathlib import Path
import selectors
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from chronicle.evidence import redact, normalize
from chronicle.recorder import Recorder
from chronicle.sources import Journal
from chronicle.store import Store


class HardeningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "state"
        self.store = Store(self.path)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def test_new_preview_invalidates_old_and_is_immutable(self):
        incident = self.store.create_incident("Original")
        first = self.store.preview_export(incident["id"], detail=True)
        second = self.store.preview_export(incident["id"], detail=True)
        with self.assertRaises(ValueError):
            self.store.confirm_export(first["token"])
        self.store.update_incident(incident["id"], "Changed after review", "closed")
        output = self.store.confirm_export(second["token"])
        self.assertEqual(Path(output["path"]).read_text(), second["text"])

    def test_database_symlink_not_followed(self):
        other = Path(self.temp.name) / "other"
        other.mkdir(mode=0o700)
        (other / "chronicle.sqlite3").symlink_to(self.path / "chronicle.sqlite3")
        with self.assertRaises(ValueError):
            Store(other)

    def test_existing_nonprivate_directory_is_not_silently_changed(self):
        other = Path(self.temp.name) / "shared"
        other.mkdir(mode=0o755)
        other.chmod(0o755)
        with self.assertRaises(ValueError):
            Store(other)
        self.assertEqual(other.stat().st_mode & 0o777, 0o755)

    def test_private_key_url_ipv6_and_bidi_redaction(self):
        for text, secret in (("https://user:pass@host.test/?key=private", "private"),
                             ("2001:db8::1", "2001"),
                             ("-----BEGIN RSA PRIVATE KEY-----\nprivate\n-----END RSA PRIVATE KEY-----", "\nprivate"),
                             ("normal\u202esecret", "\u202e")):
            self.assertNotIn(secret, redact(text))

    def test_resource_bounds_with_many_records(self):
        for _ in range(800):
            self.store.sample({"cpu_some_avg10": 0})
        self.assertEqual(len(self.store.samples()), 720)
        self.assertLess((self.path / "chronicle.sqlite3").stat().st_size, 32*1024*1024)

    def test_bookmark_reports_measurement_age(self):
        recorder = Recorder(self.store, demo=True)
        recorder.poll()
        mark = recorder.command({"cmd":"bookmark", "label":"Now"})
        self.assertIn("observed_us", mark)
        self.assertLessEqual(mark["observed_us"], mark["time_us"])

    def test_storage_failure_does_not_disable_reading_saved_incidents(self):
        incident = self.store.create_incident("Saved")
        recorder = Recorder(self.store, demo=True)
        with patch.object(self.store, "sample", side_effect=sqlite3.OperationalError("database or disk is full")):
            recorder.poll()
        self.assertTrue(recorder.snapshot()["storage_error"])
        self.assertEqual(recorder.command({"cmd":"incident", "id":incident["id"]})["title"], "Saved")
        recorder.poll()
        self.assertFalse(recorder.snapshot()["storage_error"])
        self.assertFalse(any(s["status"] == "error" for s in recorder.snapshot()["sources"]))

    def test_deep_json_does_not_crash_control_channel(self):
        result = subprocess.run([sys.executable,"-m","chronicle","--demo","--state-dir",str(Path(self.temp.name)/"deep")],
                                input="["*2000+"0"+"]"*2000+'\n{"cmd":"shutdown","request_id":"done"}\n',
                                text=True,capture_output=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertTrue(any(json.loads(line).get("request_id")=="done" for line in result.stdout.splitlines()))

    def test_second_recorder_cannot_own_same_database(self):
        folder = str(Path(self.temp.name)/"locked")
        process = subprocess.Popen([sys.executable,"-m","chronicle","--demo","--state-dir",folder],
                                   stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout,selectors.EVENT_READ)
                self.assertTrue(selector.select(5),"helper startup timed out")
            self.assertEqual(json.loads(process.stdout.readline())["type"],"snapshot")
            second = subprocess.run([sys.executable,"-m","chronicle","--demo","--once","--state-dir",folder],capture_output=True,text=True,timeout=5)
            self.assertEqual(second.returncode,2)
            self.assertIn("Another Chronicle",second.stdout)
        finally:
            process.terminate()
            process.communicate(timeout=5)

    def test_bounded_tail_reports_loss(self):
        lines = []
        for i in range(201):
            lines.append(json.dumps({"__CURSOR":str(i),"__REALTIME_TIMESTAMP":str(i),"_BOOT_ID":"boot","MESSAGE":"event"}))
        response = Journal(runner=lambda *a,**k:{"status":"ok","code":0,"stdout":"\n".join(lines).encode()}).read()
        self.assertTrue(response["gap"])
        self.assertEqual(len(response["events"]),200)
        self.assertEqual(response["cursor"],"200")

    def test_gap_evidence_commits_in_same_transaction_as_cursor(self):
        self.store.ingest("user-journal", [], "next", gap_message="Bounded tail gap")
        self.assertEqual(self.store.cursor("user-journal"), "next")
        self.assertEqual(self.store.events()[0]["message"], "Bounded tail gap")
        self.assertEqual(self.store.events()[0]["source"], "recorder")
        with self.assertRaises(KeyError):
            self.store.ingest("user-journal", [{}], "bad", gap_message="Must roll back")
        self.assertEqual(self.store.cursor("user-journal"), "next")
        self.assertEqual(len(self.store.events()), 1)

    def test_wall_clock_rewind_cannot_extend_preview_lifetime(self):
        self.store.monotonic = lambda: 100
        incident = self.store.create_incident("Clock change")
        preview = self.store.preview_export(incident["id"])
        self.store.monotonic = lambda: 401
        self.store.now = lambda: 1
        with self.assertRaises(ValueError):
            self.store.confirm_export(preview["token"])

    def test_unicode_message_fits_persistence_budget_and_is_visibly_truncated(self):
        event=normalize({"__CURSOR":"unicode", "_BOOT_ID":"boot", "__REALTIME_TIMESTAMP":str(self.store.now()), "MESSAGE":"界"*2048})
        self.store.ingest("user-journal",[event])
        self.assertLessEqual(len(json.dumps(event,ensure_ascii=True,sort_keys=True)),12000)
        self.assertIn("[truncated]",event["message"])

    def test_unpersistable_identity_becomes_qualified_gap_not_recorder_crash(self):
        lines=[{"__CURSOR":"界"*4096,"_BOOT_ID":"boot","__REALTIME_TIMESTAMP":str(self.store.now()),"MESSAGE":"oversized identity"},
               {"__CURSOR":"valid","_BOOT_ID":"boot","__REALTIME_TIMESTAMP":str(self.store.now()),"MESSAGE":"valid record"}]
        journal=Journal(runner=lambda *a,**k:{"status":"ok","code":0,"stdout":"\n".join(json.dumps(row) for row in lines).encode()})
        recorder=Recorder(self.store)
        recorder.journals=[journal]
        recorder.poll()
        self.assertEqual(self.store.cursor("user-journal"),"valid")
        self.assertEqual(recorder.sources["user-journal"]["status"],"degraded")
        self.assertTrue(any("history gap" in row["message"] for row in self.store.events()))
