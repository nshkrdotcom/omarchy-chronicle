"""Bounded read-only source adapters; no shell interpolation or privileged calls."""

import json
import os
from pathlib import Path
import re
import selectors
import subprocess
import time

from .evidence import metrics, normalize


def run_bounded(argv, timeout=2.0, limit=2 * 1024 * 1024):
    try:
        child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 stdin=subprocess.DEVNULL, env={**os.environ, "LC_ALL": "C"})
    except OSError:
        return {"status": "unavailable", "stdout": b"", "code": -1}
    data = bytearray()
    total = 0
    status = "ok"
    deadline = time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(child.stdout, selectors.EVENT_READ)
            selector.register(child.stderr, selectors.EVENT_READ)
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    status = "timeout"
                    break
                for key, _ in selector.select(min(remaining, .1)):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue
                    total += len(chunk)
                    if key.fileobj is child.stdout:
                        data.extend(chunk[:max(0, limit - len(data))])
                    if total > limit:
                        status = "truncated"
                        break
                if status != "ok":
                    break
        if status != "ok":
            child.kill()
        try:
            code = child.wait(timeout=max(.05, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            child.kill()
            code = child.wait()
            status = "timeout"
        if code and status == "ok":
            status = "error"
        return {"status": status, "stdout": bytes(data), "code": code}
    finally:
        if child.poll() is None:
            child.kill()
            child.wait()
        child.stdout.close()
        child.stderr.close()


class Journal:
    def __init__(self, name="user-journal", runner=run_bounded):
        if name not in ("user-journal", "system-journal"):
            raise ValueError("unsupported journal scope")
        self.name, self.runner = name, runner

    def read(self, cursor=None):
        argv = ["journalctl", "--user" if self.name == "user-journal" else "--system",
                "--output=json", "--no-pager", "--quiet", "--lines=201",
                "--output-fields=__CURSOR,__REALTIME_TIMESTAMP,__MONOTONIC_TIMESTAMP,_BOOT_ID,PRIORITY,_SYSTEMD_USER_UNIT,_SYSTEMD_UNIT,SYSLOG_IDENTIFIER,MESSAGE"]
        response = self.runner(argv + (["--after-cursor=" + cursor] if cursor else ["--since=-5min"]))
        gap = False
        if cursor and response["status"] == "error":
            # Do not silently treat a vacuumed/unreadable cursor as continuity.
            response = self.runner(argv + ["--since=-5min"])
            gap = response["status"] == "ok"
        events, rejected = [], 0
        for line in response["stdout"].splitlines():
            try:
                if len(line) > 65536:
                    raise ValueError("oversized record")
                events.append(normalize(json.loads(line), self.name))
            except (ValueError, TypeError, OverflowError):
                rejected += 1
        if len(events) > 200:
            events, gap = events[-200:], True
        status = response["status"]
        if status in ("error", "timeout", "unavailable"):
            events = []  # Retry same cursor; partial error output is not a successful batch.
        elif status == "truncated":
            gap = True
        elif rejected:
            status = "degraded"
        elif gap:
            status = "gap"
        elif not events:
            status = "empty"  # No accessible records, not proof that nothing happened.
        return {"events": events, "cursor": events[-1]["cursor"] if events else None,
                "status": status, "gap": gap or rejected > 0, "rejected": rejected}


def read_pressure(proc=Path("/proc")):
    values = {}
    for name in ("cpu", "memory", "io"):
        value = None
        try:
            with (Path(proc) / "pressure" / name).open() as stream:
                text = stream.read(4096)
            found = re.search(r"^some\s+avg10=([^\s]+)", text, re.M)
            if found:
                value = float(found[1])
        except (OSError, ValueError):
            pass
        values[name + "_some_avg10"] = value
    values["memory_available_kib"] = None
    try:
        with (Path(proc) / "meminfo").open() as stream:
            found = re.search(r"^MemAvailable:\s+(\d+)\s+kB", stream.read(16384), re.M)
        if found:
            values["memory_available_kib"] = int(found[1])
    except OSError:
        pass
    return metrics(values)
