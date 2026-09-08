import json
from contextlib import closing
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from chronicle.evidence import normalize
from chronicle.recorder import Recorder
from chronicle.store import Store
from test_core import entry


class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "state"
        self.now = 900_000_000_000
        self.store = Store(self.path, now=lambda: self.now)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def add(self, ident, at, message="failure"):
        event = normalize(entry(ident, at, MESSAGE=message))
        self.store.ingest("user-journal", [event])
        return event

    def history(self, **kwargs):
        return self.store.history(from_us=0, to_us=self.now, **kwargs)

    def test_time_filter_precedes_page_limit_and_density_covers_all_matches(self):
        events = [normalize(entry(str(i), self.now - i * 1_000_000)) for i in range(700)]
        self.store.ingest("user-journal", events)
        page = self.store.history(from_us=self.now-699_000_000, to_us=self.now-550_000_000, limit=10)
        self.assertEqual(len(page["events"]), 10)
        self.assertEqual(page["matching_count"], 150)
        self.assertEqual(sum(b["count"] for b in page["density"]), 150)
        self.assertEqual(sum(b["errors"] for b in page["density"]), 150)
        self.assertEqual(len(page["density"]), 48)
        self.assertIsNotNone(page["next"])

    def test_tied_timestamps_page_exactly_once(self):
        expected = {self.add(str(i), self.now)["id"] for i in range(9)}
        page = self.history(limit=2)
        seen = [e["id"] for e in page["events"]]
        while page["next"]:
            page = self.history(limit=2, ceiling=page["ceiling"], before=page["next"])
            seen.extend(e["id"] for e in page["events"])
        self.assertEqual(len(seen), 9)
        self.assertEqual(set(seen), expected)

    def test_receipt_ceiling_excludes_new_backdated_arrivals(self):
        self.add("first", self.now)
        self.add("older", self.now-2)
        first = self.history(limit=1)
        self.add("late", self.now-1)
        next_page = self.history(limit=1, ceiling=first["ceiling"], before=first["next"])
        self.assertEqual(next_page["events"][0]["cursor"], "older")
        self.assertEqual(next_page["matching_count"], 2)

    def test_retention_loss_is_reported_and_sequence_never_reused(self):
        self.store.event_limit = 1
        self.add("first", self.now)
        first = self.history()
        self.now += 8 * 86400_000_000
        self.store.ingest("user-journal", [])
        self.add("new", self.now)
        page = self.history(ceiling=first["ceiling"])
        self.assertEqual(page["events"], [])
        self.assertGreater(page["retention_generation"], first["retention_generation"])
        self.assertGreater(self.history()["ceiling"], first["ceiling"])

    def test_future_source_clock_does_not_evict_fresh_receipts(self):
        self.store.event_limit = 2
        self.add("future", self.now + 999_000_000_000)
        self.add("normal", self.now)
        self.add("new", self.now-1)
        self.assertEqual({e["cursor"] for e in self.store.events()}, {"normal", "new"})

    def test_old_source_event_is_retained_by_receipt_age(self):
        self.add("delayed", 1)
        self.assertEqual(self.history()["matching_count"], 1)
        self.now += 8 * 86400_000_000
        self.store.ingest("user-journal", [])
        self.assertEqual(self.history()["matching_count"], 0)

    def test_literal_unicode_search_and_exact_filters(self):
        self.add("unicode", self.now, "Straße 100%")
        self.add("plain", self.now, "plain")
        self.assertEqual(self.history(search="STRASSE")["matching_count"], 1)
        self.assertEqual(self.history(search="%")["matching_count"], 1)
        self.assertEqual(self.history(severity="warning")["matching_count"], 0)

    def test_invalid_queries_rejected_at_protocol_boundary(self):
        recorder = Recorder(self.store, demo=True)
        cases = [{"from_us": True}, {"to_us": -1}, {"from_us": 2, "to_us": 1},
                 {"limit": 501}, {"limit": 1.5}, {"ceiling": -1},
                 {"before": {"time_us": 1, "id": "x"}}, {"search": []},
                 {"category": "invented"}, {"severity": "fatal"}, {"source": "sh"},
                 {"from_us": 2**63}, {"before": [1, "id"]}]
        for change in cases:
            with self.subTest(change=change), self.assertRaises(ValueError):
                recorder.command({"cmd": "history", "from_us": 0, "to_us": self.now, **change})

    def test_history_is_stateless_and_does_not_open_panel(self):
        recorder = Recorder(self.store, demo=True)
        old = dict(recorder.query)
        result = recorder.command({"cmd": "history", "from_us": 0, "to_us": self.now})
        self.assertIn("density", result)
        self.assertEqual(recorder.query, old)
        self.assertFalse(recorder.panel_open)

    def test_v1_migration_preserves_evidence_and_other_tables(self):
        event = self.add("legacy", self.now)
        incident = self.store.create_incident("Preserve")
        self.store.pin(incident["id"], event["id"])
        self.store.close()
        with closing(sqlite3.connect(self.path / "chronicle.sqlite3")) as db, db:
            db.executescript("""
                ALTER TABLE events RENAME TO migrated_events;
                CREATE TABLE events (id TEXT PRIMARY KEY, time_us INTEGER NOT NULL,
                  source TEXT NOT NULL, category TEXT NOT NULL, severity TEXT NOT NULL, body TEXT NOT NULL);
                INSERT INTO events SELECT id,time_us,source,category,severity,body FROM migrated_events;
                DROP TABLE migrated_events;
                PRAGMA user_version=1;
            """)
        self.store = Store(self.path, now=lambda: self.now)
        self.assertEqual(self.store.db.execute("PRAGMA user_version").fetchone()[0], 2)
        self.assertEqual(self.history()["events"][0]["id"], event["id"])
        self.assertEqual(self.store.incident(incident["id"])["evidence"][0]["id"], event["id"])
        self.assertTrue(self.history()["receipt_age_estimated"])

    def test_invalid_batch_does_not_advance_receipt_ceiling(self):
        before = self.history()["ceiling"]
        with self.assertRaises(KeyError):
            self.store.ingest("user-journal", [normalize(entry("rollback", self.now)), {}])
        self.assertEqual(self.history()["ceiling"], before)

    def test_failed_v1_migration_rolls_back_schema_and_event_payload(self):
        path = Path(self.temp.name) / "legacy"
        path.mkdir(mode=0o700)
        event = normalize(entry("legacy-fail", self.now))
        database = path / "chronicle.sqlite3"
        with closing(sqlite3.connect(database)) as db, db:
            db.executescript("CREATE TABLE events(id TEXT PRIMARY KEY,time_us INTEGER,source TEXT,category TEXT,severity TEXT,body TEXT); PRAGMA user_version=1;")
            db.execute("INSERT INTO events VALUES(?,?,?,?,?,?)", (event["id"],event["time_us"],event["source"],event["category"],event["severity"],json.dumps(event)))
        connect = sqlite3.connect
        class FailingConnection(sqlite3.Connection):
            def execute(self, sql, *args):
                if sql == "DROP TABLE events_v1":
                    raise sqlite3.OperationalError("simulated migration write failure")
                return super().execute(sql, *args)
        with patch("chronicle.store.sqlite3.connect", side_effect=lambda *a, **k: connect(*a, **k, factory=FailingConnection)):
            with self.assertRaises(sqlite3.OperationalError):
                Store(path)
        with closing(connect(database)) as db:
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0],1)
            self.assertEqual(json.loads(db.execute("SELECT body FROM events").fetchone()[0]),event)
            self.assertNotIn("seq",[row[1] for row in db.execute("PRAGMA table_info(events)")])
