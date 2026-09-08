#!/usr/bin/env python3
"""Real Quickshell stdio transport, no windows, host IPC, installation or live sources."""
import json
import os
from pathlib import Path
import shutil
import signal
import sqlite3
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
if not shutil.which("quickshell"):
    raise SystemExit("Quickshell unavailable; integration was NOT run.")
with tempfile.TemporaryDirectory(prefix="chronicle-transport-") as directory:
    work = Path(directory)
    runtime = work / "runtime"
    runtime.mkdir(mode=0o700)
    service_copy = work / "service"
    service_copy.mkdir()
    for filename in ("Service.qml", "HistoryController.qml", "IncidentController.qml"):
        shutil.copyfile(root / "qml" / filename, service_copy / filename)
    template = (root / "tests/fixtures/service-harness.qml.in").read_text()
    for key, value in {"@QML_ROOT@": service_copy.as_uri(), "@REPO_ROOT@": str(root), "@STATE_ROOT@": str(work / "state")}.items():
        template = template.replace(key, json.dumps(value))
    (work / "shell.qml").write_text(template)
    env = {key: value for key, value in os.environ.items() if not key.startswith("QS_")}
    for key in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
        env.pop(key, None)
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               QT_QPA_PLATFORMTHEME="", QT_QUICK_CONTROLS_STYLE="Basic", QT_STYLE_OVERRIDE="Fusion",
               XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(work / "cache"),
               XDG_CONFIG_HOME=str(work / "config"), XDG_STATE_HOME=str(work / "state-home"))
    child = subprocess.Popen(["quickshell", "--no-color", "--path", str(work / "shell.qml")],
                             env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             start_new_session=True)
    try:
        stdout, stderr = child.communicate(timeout=25)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGTERM)
        try:
            child.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.communicate()
        raise SystemExit("Isolated transport timed out; its owned process group was stopped.")
    output = stdout + stderr
    if child.returncode or "CHRONICLE_INTEGRATION_OK" not in output or "CHRONICLE_INTEGRATION_ERROR" in output:
        print(output)
        raise SystemExit("Isolated Quickshell transport failed.")
    exports = list((work / "state/exports").glob("*.json"))
    assert len(exports) == 1
    evidence = json.loads(exports[0].read_text())
    assert len(evidence["evidence"]) == 1
    assert evidence["detail_included"] is False
    assert not any("message" in event for event in evidence["evidence"])
    with sqlite3.connect(work / "state/chronicle.sqlite3") as db:
        incident = json.loads(db.execute("SELECT body FROM incidents").fetchone()[0])
        assert incident["notes"] == "Verified committed investigation notes"
        assert incident["revision"] == 3
        assert db.execute("SELECT count(*) FROM drafts").fetchone()[0] == 0
        assert len(json.loads(db.execute("SELECT body FROM settings WHERE key='saved_views'").fetchone()[0])) == 1
    print("PASS: real offscreen Quickshell → paged history → bookmark → incident → pin → draft → revision-checked commit → saved view → metadata preview/export → clean shutdown. Synthetic data only.")
