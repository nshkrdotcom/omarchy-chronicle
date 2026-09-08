#!/usr/bin/env python3
"""Resolve packaged native imports without starting or reloading Omarchy."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
shell = Path("/usr/share/omarchy/shell")
lint = shutil.which("qmllint") or "/usr/lib/qt6/bin/qmllint"
if not shell.is_dir() or not Path(lint).is_file():
    raise SystemExit("Native import lint unavailable: install development tools separately; this script changes nothing.")
with tempfile.TemporaryDirectory(prefix="chronicle-native-imports-") as directory:
    (Path(directory) / "qs").symlink_to(shell, target_is_directory=True)
    result = subprocess.run([lint, "--import", "error", "-I", directory,
                             *map(str, sorted((root / "qml").glob("*.qml")))], timeout=60)
    raise SystemExit(result.returncode)
