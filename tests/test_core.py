import json
import os
from pathlib import Path
import tempfile
import unittest

from chronicle.evidence import normalize, redact
from chronicle.store import Store


def entry(cursor="c1", timestamp=1_000_000, **fields):
    return {"__CURSOR": cursor, "__REALTIME_TIMESTAMP": str(timestamp),
            "__MONOTONIC_TIMESTAMP": "100", "_BOOT_ID": "boot-a",
            "PRIORITY": "3", "_SYSTEMD_USER_UNIT": "example.service",
            "MESSAGE": "Service failed", **fields}


class EvidenceTests(unittest.TestCase):
    def test_exact_provenance(self):
        event = normalize(entry(), "user-journal")
        self.assertEqual(event["cursor"], "c1")
        self.assertEqual(event["time_us"], 1_000_000)
        self.assertEqual(event["monotonic_us"], 100)
        self.assertEqual(event["boot"], "boot-a")
        self.assertEqual(event["category"], "service")
        self.assertEqual(event["severity"], "error")

    def test_duplicate_json_fields_and_binary_message(self):
        result = normalize(entry(MESSAGE=[72, 105], PRIORITY=["4", "5"]))
        self.assertEqual(result["message"], "Hi")
        self.assertEqual(result["severity"], "warning")
        self.assertEqual(normalize(entry(MESSAGE=["one", "two"]))["message"], "one")

    def test_untrusted_fields_not_kept(self):
        result = normalize(entry(_CMDLINE="password=secret", _HOSTNAME="private"))
        self.assertNotIn("_CMDLINE", json.dumps(result))
        self.assertNotIn("private", json.dumps(result))

    def test_missing_identity_or_invalid_time_rejected(self):
        for change in ({"__CURSOR": ""}, {"__REALTIME_TIMESTAMP": "bad"},
                       {"__REALTIME_TIMESTAMP": "-1"}, {"_BOOT_ID": ""}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                normalize(entry(**change))

    def test_redaction(self):
        result = redact("token=abc123 Bearer xyz /home/alice/project a@b.com 192.168.1.2\x1b[31m")
        for secret in ("abc123", "xyz", "alice", "a@b.com", "192.168.1.2", "\x1b"):
            self.assertNotIn(secret, result)
        self.assertIn("[redacted]", result)

    def test_messages_bounded_and_category_qualified(self):
        self.assertLessEqual(len(normalize(entry(MESSAGE="x" * 20_000))["message"]), 2048)
        self.assertEqual(normalize(entry(_SYSTEMD_USER_UNIT="pipewire.service"))["category"], "audio")
        self.assertEqual(normalize(entry(_SYSTEMD_USER_UNIT="NetworkManager.service"))["category"], "network")


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "state"
        self.now = 2_000_000
        self.store = Store(self.path, now=lambda: self.now, event_limit=3)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def ingest(self, n=1):
        events = [normalize(entry("c" + str(i), self.now + i)) for i in range(n)]
        return self.store.ingest("user-journal", events, "c" + str(n - 1))

    def test_private_permissions_and_symlink_rejection(self):
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.path / "chronicle.sqlite3").stat().st_mode & 0o777, 0o600)
        alias = Path(self.temp.name) / "alias"
        alias.symlink_to(self.path, target_is_directory=True)
        with self.assertRaises(ValueError):
            Store(alias)

    def test_dedup_and_cursor_persist(self):
        self.ingest(2)
        self.ingest(2)
        self.assertEqual(len(self.store.events()), 2)
        self.assertEqual(self.store.cursor("user-journal"), "c1")
        self.store.close()
        self.store = Store(self.path)
        self.assertEqual(len(self.store.events()), 2)

    def test_retention_and_incident_evidence_survival(self):
        self.ingest()
        first = self.store.events()[0]
        incident = self.store.create_incident("Failure")
        self.store.pin(incident["id"], first["id"])
        self.ingest(8)
        self.assertEqual(len(self.store.events()), 3)
        self.assertEqual(self.store.incident(incident["id"])["evidence"][0]["id"], first["id"])

    def test_transaction_rejects_partial_batch(self):
        with self.assertRaises((ValueError, KeyError)):
            self.store.ingest("user-journal", [normalize(entry()), {}], "bad")
        self.assertEqual(self.store.events(), [])
        self.assertIsNone(self.store.cursor("user-journal"))

    def test_bookmark_snapshot_and_comparison(self):
        a = self.store.bookmark("Before", {"memory_available_kib": 200, "cpu_some_avg10": 1.0})
        self.now += 1_000_000
        b = self.store.bookmark("After", {"memory_available_kib": 100, "cpu_some_avg10": None})
        diff = self.store.compare(a["id"], b["id"])
        self.assertEqual(diff["delta"]["memory_available_kib"], -100)
        self.assertNotIn("cpu_some_avg10", diff["delta"])
        self.assertIn("cpu_some_avg10", diff["missing"])
        self.assertEqual(diff["duration_us"], 1_000_000)

    def test_literal_search_filters_and_order(self):
        self.ingest(3)
        self.assertEqual(self.store.events(search="%"), [])
        self.assertEqual(len(self.store.events(search="failed", severity="error")), 3)
        self.assertEqual(self.store.events(severity="warning"), [])
        self.assertEqual(self.store.events(limit=1)[0]["cursor"], "c2")

    def test_incident_notes_and_status(self):
        incident = self.store.create_incident("An incident")
        self.store.update_incident(incident["id"], "token=hidden", "closed")
        saved = self.store.incident(incident["id"])
        self.assertEqual(saved["status"], "closed")
        self.assertNotIn("hidden", saved["notes"])
        with self.assertRaises(ValueError):
            self.store.update_incident(incident["id"], "", "invented")

    def test_export_is_exact_preview_and_private(self):
        self.ingest()
        incident = self.store.create_incident("Failure")
        self.store.pin(incident["id"], self.store.events()[0]["id"])
        preview = self.store.preview_export(incident["id"], detail=False)
        self.assertNotIn("Service failed", preview["text"])
        result = self.store.confirm_export(preview["token"])
        path = Path(result["path"])
        self.assertEqual(path.read_text(), preview["text"])
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(ValueError):
            self.store.confirm_export(preview["token"])

    def test_export_expiry(self):
        preview = self.store.preview_export(self.store.create_incident("Test")["id"])
        self.now += 301_000_000
        with self.assertRaises(ValueError):
            self.store.confirm_export(preview["token"])

    def test_snapshot_retention_and_nulls(self):
        self.store.sample({"cpu_some_avg10": None, "memory_available_kib": 0})
        values = self.store.samples()[0]["values"]
        self.assertIsNone(values["cpu_some_avg10"])
        self.assertEqual(values["memory_available_kib"], 0)

    def test_caps_refuse_silent_incident_loss(self):
        for i in range(128):
            self.store.create_incident(str(i))
        with self.assertRaises(ValueError):
            self.store.create_incident("over limit")
