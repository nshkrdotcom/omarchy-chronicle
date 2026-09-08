import json
import re
import struct
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RepositoryTests(unittest.TestCase):
    def test_manifest_has_only_native_service_and_bar(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        self.assertEqual(manifest["id"], "nshkr.chronicle")
        self.assertEqual(manifest["kinds"], ["service", "bar-widget"])
        for entry in manifest["entryPoints"].values():
            self.assertTrue((ROOT / entry).is_file())
        self.assertTrue(manifest["keepLoaded"])

    def test_license(self):
        self.assertIn("Copyright (c) 2026 nshkrdotcom", (ROOT / "LICENSE").read_text())

    def test_native_host_contract(self):
        panel = re.sub(r"\s+", "", (ROOT / "qml/Panel.qml").read_text())
        for token in ("Ui.Panel", "Ui.KeyboardPanel", "padding:Style.space(8)",
                      "fittedContentWidth(Style.space(1280))", "cappedContentHeight(Style.space(840))"):
            self.assertIn(token, panel)
        self.assertNotIn("Overlay", panel)

    def test_no_install_or_desktop_mutation_in_make_targets(self):
        make = (ROOT / "Makefile").read_text()
        for forbidden in ("rescanPlugins", "restart shell", "plugin enable", "plugin add", "~/.config"):
            self.assertNotIn(forbidden, make)

    def test_persisted_files_not_tracked(self):
        for filename in ROOT.rglob("*.sqlite*"):
            self.fail("Private state in repository: " + str(filename))

    def test_readme_opens_with_full_panel_preview(self):
        readme = (ROOT / "README.md").read_text()
        self.assertLess(readme.index("![Chronicle preview](preview.png)"), readme.index("## Operator capabilities"))
        png = (ROOT / "preview.png").read_bytes()
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        width, height = struct.unpack(">II", png[16:24])
        self.assertGreaterEqual(width, 1200)
        self.assertGreaterEqual(height, 800)
        self.assertLess(len(png), 2 * 1024 * 1024)
