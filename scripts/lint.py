#!/usr/bin/env python3
"""Resolve packaged native imports without starting or reloading Omarchy."""
from pathlib import Path
import shutil
import re
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
                             *map(str, sorted((root / "qml").glob("*.qml")))], timeout=60, capture_output=True, text=True)
    report = result.stdout + result.stderr
    warnings = [line for line in report.splitlines() if "Warning:" in line]
    # Packaged host style objects and injected loader/bar facades expose QObject
    # rather than static QML types. The Quickshell exit enum has no lint metadata.
    expected = {"missing-property", "signal-handler-parameters"}
    unexpected = [line for line in warnings if not re.search(r"\[(" + "|".join(expected) + r")\]$", line)]
    if result.returncode or unexpected:
        print(report)
        raise SystemExit(result.returncode or 1)
    with tempfile.NamedTemporaryFile(mode="w", prefix="chronicle-native-lint-", suffix=".log", delete=False) as output:
        output.write(report)
        print(f"Native imports resolved; {len(warnings)} host/dynamic typing advisories retained in {output.name}")
