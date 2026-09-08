from pathlib import Path
import tempfile
import unittest

from chronicle.recorder import Recorder
from chronicle.store import Store


class SavedViewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "state"
        self.store = Store(self.path)
        self.recorder = Recorder(self.store, demo=True)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def save(self, **change):
        return self.recorder.command({"cmd": "save_view", "label": "Errors", "severity": "error", "window_minutes": 15, **change})

    def test_durable_redacted_view_has_no_transient_cursor(self):
        view = self.save(label="token=private", search="password=hidden", before={"untrusted": True})
        self.assertNotIn("private", view["label"])
        self.assertNotIn("hidden", view["search"])
        self.assertNotIn("before", view)
        self.store.close()
        self.store = Store(self.path)
        self.assertEqual(self.store.saved_views()[0], view)
        self.assertEqual(self.recorder.store.path, self.path)

    def test_views_bounded_and_explicit_removal(self):
        views = [self.save(label=str(i)) for i in range(20)]
        with self.assertRaises(ValueError):
            self.save()
        self.recorder.command({"cmd": "remove_view", "id": views[0]["id"]})
        self.save()
        self.assertEqual(len(self.recorder.snapshot()["saved_views"]), 20)

    def test_invalid_filters_and_windows_rejected(self):
        for args in ({"window_minutes": 0}, {"window_minutes": True}, {"window_minutes": 10081},
                     {"severity": "fatal"}, {"search": "x" * 201}, {"label": []}):
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.save(**args)
