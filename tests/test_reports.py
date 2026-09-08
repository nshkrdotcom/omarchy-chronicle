from pathlib import Path
import hashlib
import json
import stat
import tempfile
import unittest

from chronicle.evidence import normalize
from chronicle.recorder import Recorder
from chronicle.store import Store


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.now = 1_800_000_000_000_000
        self.store = Store(Path(self.temp.name) / "state", now=lambda: self.now)
        self.item = self.store.create_incident("Audio interruption")
        self.event = normalize({"__CURSOR": "private-cursor", "_BOOT_ID": "private-boot",
            "__REALTIME_TIMESTAMP": str(self.now), "MESSAGE": "Audio recovered", "PRIORITY": "4"})
        self.store.ingest("user-journal", [self.event])
        self.store.pin(self.item["id"], self.event["id"])
        self.store.update_incident(self.item["id"], "Committed observation", "open")

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def preview(self, **options):
        return self.store.preview_export(self.item["id"], format="markdown", **options)

    def test_markdown_metadata_is_private_exact_reviewed_bytes(self):
        preview = self.preview()
        self.assertEqual(preview["format"], "markdown")
        for private in ("Audio recovered", "Committed observation", "private-cursor", "private-boot"):
            self.assertNotIn(private, preview["text"])
        self.assertIn(self.event["id"], preview["text"])
        self.assertIn("## Coverage and privacy", preview["text"])
        self.assertIn("Z", preview["text"])
        self.store.update_incident(self.item["id"], "Changed later", "closed")
        result = self.store.confirm_export(preview["token"])
        path = Path(result["path"])
        self.assertEqual(path.suffix, ".md")
        self.assertEqual(path.read_bytes(), preview["text"].encode())
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), result["sha256"])
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        with self.assertRaises(ValueError):
            self.store.confirm_export(preview["token"])

    def test_detailed_markdown_uses_committed_notes_never_drafts(self):
        self.store.stage_draft(self.item["id"], "UNCOMMITTED", 3, "")
        text = self.preview(detail=True)["text"]
        self.assertIn("Committed observation", text)
        self.assertIn("Audio recovered", text)
        self.assertNotIn("UNCOMMITTED", text)

    def test_untrusted_markup_is_indented_literal_content(self):
        payload = "<script>unsafe</script>\n\n![image](https://example.test/x)\n```\n# Forged heading"
        self.store.update_incident(self.item["id"], payload, "open")
        text = self.preview(detail=True)["text"]
        for line in ("<script>unsafe</script>", "```", "# Forged heading"):
            self.assertIn("\n    " + line, text)
            self.assertNotIn("\n" + line, text)

    def test_format_validation_default_json_and_preview_replacement(self):
        recorder = Recorder(self.store, demo=True)
        for format in ("html", "../../bad", True, None):
            with self.subTest(format=format), self.assertRaises(ValueError):
                recorder.command({"cmd": "preview_export", "id": self.item["id"], "format": format})
        old = self.preview()
        preview = recorder.command({"cmd": "preview_export", "id": self.item["id"]})
        self.assertEqual(json.loads(preview["text"])["format"], "chronicle-evidence-v1")
        with self.assertRaises(ValueError):
            self.store.confirm_export(old["token"])
        self.assertEqual(Path(self.store.confirm_export(preview["token"])["path"]).suffix, ".json")

    def test_markdown_expiry_and_timestamp_outside_datetime_range(self):
        event = normalize({"__CURSOR": "future", "_BOOT_ID": "boot",
                           "__REALTIME_TIMESTAMP": str(2**63-1), "MESSAGE": "Future"})
        self.store.ingest("user-journal", [event])
        self.store.pin(self.item["id"], event["id"])
        preview = self.preview(detail=True)
        self.assertIn(str(2**63-1), preview["text"])
        self.now += 300_000_001
        with self.assertRaises(ValueError):
            self.store.confirm_export(preview["token"])
