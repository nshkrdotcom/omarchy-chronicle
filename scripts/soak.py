#!/usr/bin/env python3
"""Isolated synthetic helper soak; not an installed/native shell acceptance test."""
import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import tempfile
import time


def process_metrics(pid):
    proc = Path("/proc") / str(pid)
    rss = next(int(line.split()[1]) for line in (proc / "status").read_text().splitlines() if line.startswith("VmRSS:"))
    fields = (proc / "stat").read_text().rsplit(")", 1)[1].split()
    cpu = (int(fields[11]) + int(fields[12])) / os.sysconf("SC_CLK_TCK")
    return {"rss_kib": rss, "fds": len(list((proc / "fd").iterdir())), "cpu_seconds": cpu}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=int, default=60)
    args = parser.parse_args()
    if not 5 <= args.seconds <= 3600:
        parser.error("duration must be 5..3600 seconds")
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="chronicle-soak-") as folder:
        child = subprocess.Popen([sys.executable, str(repo / "bin/chronicle"), "--demo", "--state-dir", str(Path(folder)/"state")],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        started = time.monotonic()
        frames, toggles, buffer, measures = 0, 0, b"", []
        print(f"Synthetic helper soak started for {args.seconds}s; no desktop or live sources.", flush=True)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(child.stdout, selectors.EVENT_READ)
                while time.monotonic()-started < args.seconds:
                    if child.poll() is not None:
                        raise RuntimeError("helper exited during soak")
                    if frames and toggles < 100:
                        child.stdin.write((json.dumps({"cmd":"panel", "open":toggles%2==0})+"\n").encode())
                        child.stdin.flush()
                        toggles += 1
                    for key, _ in selector.select(.1):
                        chunk = os.read(key.fileobj.fileno(), 65536)
                        if not chunk:
                            raise RuntimeError("helper output ended during soak")
                        buffer += chunk
                        while b"\n" in buffer:
                            line, buffer = buffer.split(b"\n",1)
                            message = json.loads(line)
                            if message.get("type") == "error":
                                raise RuntimeError("helper protocol error during soak")
                            if message.get("type") == "snapshot":
                                frames += 1
                                if message.get("storage_error"):
                                    raise RuntimeError("storage error during soak")
                    measures.append(process_metrics(child.pid))
                child.stdin.write(b'{"cmd":"shutdown"}\n')
                child.stdin.flush()
                child.communicate(timeout=5)
            elapsed = time.monotonic()-started
            peak = max(row["rss_kib"] for row in measures)
            fd_growth = measures[-1]["fds"]-measures[0]["fds"]
            assert child.returncode == 0 and toggles == 100
            assert peak < 96*1024 and fd_growth <= 0
            print(json.dumps({"result":"pass", "scope":"synthetic Python helper only", "seconds":round(elapsed,2),
                              "panel_state_cycles":toggles//2, "snapshots":frames,
                              "peak_rss_kib":peak, "fd_growth":fd_growth,
                              "cpu_seconds":measures[-1]["cpu_seconds"],
                              "native_compositor_acceptance":False}))
        finally:
            if child.poll() is None:
                os.killpg(child.pid,signal.SIGTERM)
                try:
                    child.communicate(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid,signal.SIGKILL)
                    child.communicate()


if __name__ == "__main__":
    main()
