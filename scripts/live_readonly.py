#!/usr/bin/env python3
"""One local source probe with disposable private state; output contains counts only."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="chronicle-readonly-") as folder:
    result = subprocess.run([sys.executable, str(root / "bin/chronicle"), "--once", "--state-dir", str(Path(folder) / "state")],
                            text=True, capture_output=True, timeout=15)
    if result.returncode:
        raise SystemExit("Read-only collection failed; no private log content printed.")
    snapshot = json.loads(result.stdout.splitlines()[0])
    assert not snapshot["demo"]
    assert snapshot["system_journal"] is False
    assert snapshot["events"] == []  # closed-panel snapshot never emits log messages
    print(json.dumps({"check":"read-only temporary-state probe", "event_count":snapshot["event_count"],
                      "source_status":{source["id"]:source["status"] for source in snapshot["sources"]},
                      "available_metrics":sum(value is not None for value in snapshot["values"].values()),
                      "storage_error":bool(snapshot["storage_error"])}))
