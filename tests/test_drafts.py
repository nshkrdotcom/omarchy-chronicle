import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys

from chronicle.evidence import normalize
from chronicle.recorder import Recorder
from chronicle.store import Store
from test_core import entry


class DraftTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "state"
        self.store = Store(self.path)
        self.item = self.store.create_incident("Investigation")
        self.ident = self.item["id"]

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def stage(self, notes="Draft", revision=1, token=""):
        return self.store.stage_draft(self.ident, notes, revision, token)

    def test_draft_survives_restart_but_does_not_change_committed_notes(self):
        draft = self.stage("token=private")
        self.assertNotIn("private", draft["notes"])
        self.store.close()
        self.store = Store(self.path)
        self.assertEqual(self.store.draft(self.ident), draft)
        self.assertEqual(self.store.incident(self.ident)["notes"], "")

    def test_stale_note_save_cannot_overwrite_another_editor(self):
        a = self.store.incident(self.ident)
        b = self.store.incident(self.ident)
        self.store.update_incident(self.ident, "Editor A", "open", a["revision"], "")
        with self.assertRaisesRegex(ValueError, "changed"):
            self.store.update_incident(self.ident, "Editor B", "closed", b["revision"], "")
        self.assertEqual(self.store.incident(self.ident)["notes"], "Editor A")

    def test_draft_compare_and_swap_preserves_other_editors_text(self):
        a = self.stage("Editor A")
        with self.assertRaisesRegex(ValueError, "draft changed"):
            self.stage("Editor B")
        b = self.stage("Editor A newer", token=a["token"])
        self.assertNotEqual(a["token"], b["token"])
        self.assertEqual(self.store.draft(self.ident)["notes"], "Editor A newer")

    def test_pin_advances_revision_without_erasing_draft(self):
        draft = self.stage()
        event = normalize(entry(timestamp=self.store.now()))
        self.store.ingest("user-journal", [event])
        pinned = self.store.pin(self.ident, event["id"])
        self.assertEqual(pinned["revision"], 2)
        self.assertEqual(self.store.draft(self.ident), draft)
        with self.assertRaises(ValueError):
            self.store.update_incident(self.ident, "Stale", "open", 1, draft["token"])

    def test_commit_clears_only_the_reviewed_draft_and_export_excludes_drafts(self):
        draft = self.stage("Uncommitted secret-free note")
        preview = self.store.preview_export(self.ident, detail=True)
        self.assertNotIn("Uncommitted", preview["text"])
        with self.assertRaises(ValueError):
            self.store.update_incident(self.ident, "wrong", "open", 1, "")
        updated = self.store.update_incident(self.ident, draft["notes"], "open", 1, draft["token"])
        self.assertEqual(updated["revision"], 2)
        self.assertIsNone(self.store.draft(self.ident))
        self.assertIn("Uncommitted", self.store.preview_export(self.ident, detail=True)["text"])

    def test_explicit_discard_requires_exact_token_and_delete_cleans_draft(self):
        draft = self.stage()
        with self.assertRaises(ValueError):
            self.store.discard_draft(self.ident, "wrong")
        self.store.discard_draft(self.ident, draft["token"])
        self.assertIsNone(self.store.draft(self.ident))
        self.stage()
        self.store.remove_incident(self.ident)
        self.assertEqual(self.store.db.execute("SELECT count(*) FROM drafts").fetchone()[0], 0)

    def test_invalid_staging_is_rejected_and_missing_incident_cannot_make_orphan(self):
        for args in (("x"*4097, 1, ""), ("text", True, ""), ("text", 100, "")):
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.store.stage_draft(self.ident, *args)
        with self.assertRaises(ValueError):
            self.store.stage_draft("missing", "x", 1, "")

    def test_public_protocol_requires_revision_and_returns_draft_with_incident(self):
        recorder = Recorder(self.store, demo=True)
        with self.assertRaises(ValueError):
            recorder.command({"cmd":"update_incident", "id":self.ident, "notes":"unsafe"})
        draft = recorder.command({"cmd":"stage_draft", "id":self.ident, "notes":"Safe draft", "base_revision":1, "draft_token":""})
        result = recorder.command({"cmd":"incident", "id":self.ident})
        self.assertEqual(result["draft"], draft)

    def test_legacy_incident_revision_defaults_without_rewriting_evidence(self):
        legacy = dict(self.item)
        legacy.pop("revision", None)
        self.store.db.execute("UPDATE incidents SET body=? WHERE id=?", (json.dumps(legacy), self.ident))
        self.store.db.commit()
        self.assertEqual(self.store.incident(self.ident)["revision"], 1)

    def test_stdio_conflict_is_actionable_without_echoing_private_input(self):
        self.store.update_incident(self.ident, "Saved by another editor", "open", 1, "")
        request = {"cmd":"update_incident", "id":self.ident, "notes":"DO_NOT_ECHO_PRIVATE", "expected_revision":1,"request_id":"conflict"}
        result = subprocess.run([sys.executable,"-m","chronicle","--demo","--state-dir",str(self.path)],
            input=json.dumps(request)+'\n{"cmd":"shutdown"}\n', text=True, capture_output=True, timeout=10)
        response = next(json.loads(line) for line in result.stdout.splitlines() if json.loads(line).get("request_id") == "conflict")
        self.assertEqual(response.get("code"), "conflict")
        self.assertIn("changed", response["error"])
        self.assertNotIn("DO_NOT_ECHO_PRIVATE", result.stdout)
