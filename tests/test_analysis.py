"""Operator investigations count observations without discarding their identity."""
from pathlib import Path
import tempfile
import unittest

from chronicle.evidence import normalize
from chronicle.recorder import Recorder
from chronicle.store import Store


class AnalysisTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.now = 10_000_000_000
        self.store = Store(Path(self.temp.name) / "state", now=lambda: self.now)
        self.seq = 0

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def event(self, at, message="retry", unit="app.service", boot="boot-a", level=3, source="user-journal"):
        self.seq += 1
        return normalize({"__CURSOR": str(self.seq), "__REALTIME_TIMESTAMP": str(at),
            "_BOOT_ID": boot, "_SYSTEMD_USER_UNIT": unit, "MESSAGE": message,
            "PRIORITY": str(level)}, source)

    def add(self, *events):
        for source in {e["source"] for e in events}:
            self.store.ingest(source, [e for e in events if e["source"] == source])

    def test_literal_exclusions_exact_unit_and_saved_view_roundtrip(self):
        self.add(self.event(500, "Straße ready"), self.event(501, "STRASSE health"),
                 self.event(502, "Straße ready", unit="other.service"), self.event(503, "100% retry"))
        query = dict(from_us=0, to_us=1000, search="strasse", unit="app.service", exclude=["HEALTH"])
        result = self.store.history(**query)
        self.assertEqual([e["message"] for e in result["events"]], ["Straße ready"])
        self.assertEqual(result["matching_count"], 1)
        self.assertEqual(sum(b["count"] for b in result["density"]), 1)
        self.assertEqual(self.store.history(from_us=0, to_us=1000, exclude=["%", "health"])["matching_count"], 2)
        view = self.store.save_view("Known noise", {**query, "window_minutes": 15})
        self.assertEqual(view["unit"], "app.service")
        self.assertEqual(view["exclude"], ["HEALTH"])
        self.assertNotIn("from_us", view)
        private = self.store.save_view("Private", {"unit": "/home/alice/app", "exclude": ["token=secret"]})
        self.assertNotIn("alice", private["unit"])
        self.assertNotIn("secret", private["exclude"][0])

    def test_filter_validation(self):
        for options in ({"unit": []}, {"unit": "x" * 161}, {"exclude": "health"},
                        {"exclude": [""]}, {"exclude": [None]}, {"exclude": ["x"] * 9},
                        {"exclude": ["x" * 201]}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.store.history(from_us=0, to_us=1000, **options)

    def test_context_lifts_level_filters_and_matches_unit_source_boot(self):
        anchor = self.event(500_000_000, "failure")
        before = self.event(499_000_000, "starting", level=6)
        after = self.event(501_000_000, "recovering", level=7)
        others = [self.event(500_000_000, boot="boot-b"), self.event(500_000_000, unit="other.service"),
                  self.event(500_000_000, source="system-journal")]
        self.add(anchor, before, after, *others)
        result = self.store.context(anchor["id"])
        self.assertEqual([e["id"] for e in result["events"]], [before["id"], anchor["id"], after["id"]])
        self.assertEqual(result["anchor"]["id"], anchor["id"])
        self.assertEqual(len(self.store.context(anchor["id"], scope="all")["events"]), 6)

    def test_context_keeps_anchor_and_nearest_neighbors_with_tied_times(self):
        events = [self.event(500_000_000) for _ in range(200)]
        self.add(*events)
        ordered = sorted(events, key=lambda e: e["id"])
        result = self.store.context(ordered[100]["id"], limit=2)
        self.assertEqual([e["id"] for e in result["events"]], [e["id"] for e in ordered[98:103]])
        self.assertEqual(result["before_count"], 100)
        self.assertEqual(result["after_count"], 99)
        self.assertTrue(result["truncated"])

    def test_context_ceiling_expiry_and_validation(self):
        event = self.event(500_000_000)
        self.add(event)
        ceiling = self.store.history(from_us=0, to_us=self.now)["ceiling"]
        late = self.event(500_000_001)
        self.add(late)
        self.assertEqual(len(self.store.context(event["id"], ceiling=ceiling)["events"]), 1)
        for options in ({"scope": "process"}, {"radius_seconds": 0}, {"limit": 101}, {"ceiling": True}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.store.context(event["id"], **options)
        with self.assertRaises(ValueError):
            self.store.context(late["id"], ceiling=ceiling)
        self.store.db.execute("DELETE FROM events")
        with self.assertRaises(ValueError):
            self.store.context(event["id"])

    def test_context_with_missing_boot_retains_recorder_neighbors(self):
        before = self.store.record("Paused")
        self.now += 1
        anchor = self.store.record("Resumed")
        context = self.store.context(anchor["id"])
        self.assertEqual(context["before_count"], 1)
        self.assertEqual(context["events"][0]["id"], before["id"])

    def test_saved_view_cannot_become_invalid_after_redaction(self):
        with self.assertRaises(ValueError):
            self.store.save_view("Empty after cleaning", {"exclude": ["\x1b[31m"]})
        self.assertEqual(self.store.saved_views(), [])

    def test_analysis_counts_full_intervals_and_keeps_distinct_groups(self):
        current = [self.event(1000 + i % 100) for i in range(650)]
        previous = [self.event(900 + i % 100) for i in range(80)]
        self.add(*current, *previous, self.event(1005, boot="boot-b"), self.event(1005, level=6))
        result = self.store.analyze(from_us=1000, to_us=1099)
        self.assertEqual(result["current_count"], 652)
        self.assertEqual(result["previous_count"], 80)
        self.assertEqual(result["previous_from_us"], 900)
        self.assertEqual(result["previous_to_us"], 999)
        self.assertEqual(result["group_count"], 3)
        row = result["groups"][0]
        self.assertEqual((row["current"], row["previous"], row["delta"]), (650, 80, 570))
        self.assertEqual((row["first_us"], row["last_us"]), (1000, 1099))
        self.assertIn(row["event_id"], {e["id"] for e in current})
        self.assertEqual(len(self.store.events(limit=10000)), 732)

    def test_analysis_endpoint_filters_change_sort_and_coverage(self):
        events = [self.event(99, "outside"), self.event(100, "gone"), self.event(199, "gone"),
                  self.event(200, "new"), self.event(299, "new"), self.event(300, "outside"),
                  self.event(210, "health")]
        self.add(*events)
        self.store.record("Read gap", severity="warning")
        result = self.store.analyze(from_us=200, to_us=299, exclude=["health"], sort="change", limit=1)
        self.assertEqual(result["current_count"], 2)
        self.assertEqual(result["previous_count"], 2)
        self.assertEqual(result["group_count"], 2)
        self.assertTrue(result["truncated"])
        full = self.store.analyze(from_us=200, to_us=299, exclude=["health"])
        self.assertEqual({g["state"] for g in full["groups"]}, {"newly observed", "not seen again"})
        self.assertIn("not prove", full["caution"])
        self.assertEqual(full["retained"]["count"], 8)
        self.assertEqual(full["recorder_notices"], 0)

    def test_analysis_ceiling_and_invalid_requests(self):
        self.add(self.event(200))
        before = self.store.analyze(from_us=200, to_us=299)
        self.add(self.event(220), self.event(150))
        after = self.store.analyze(from_us=200, to_us=299, ceiling=before["ceiling"])
        self.assertEqual((after["current_count"], after["previous_count"]), (1, 0))
        for options in ({"from_us": 0, "to_us": 100}, {"sort": "anything"}, {"limit": 101}, {"before": {}}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.store.analyze(**{**dict(from_us=200, to_us=299), **options})

    def test_protocol_tools_do_not_change_shared_query_or_panel_state(self):
        recorder = Recorder(self.store, demo=True)
        event = self.event(500_000_000)
        self.add(event)
        self.assertEqual(recorder.command({"cmd": "context", "id": event["id"]})["anchor"]["id"], event["id"])
        self.assertEqual(recorder.command({"cmd": "analyze", "from_us": 500_000_000, "to_us": 500_000_001})["current_count"], 1)
        self.assertFalse(recorder.panel_open)
        self.assertEqual(recorder.query, {})
