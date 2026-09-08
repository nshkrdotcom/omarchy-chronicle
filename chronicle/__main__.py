"""Private stdio daemon. EOF, signals and shutdown terminate owned work."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import selectors
import signal
import sqlite3
import sys
import time

from .recorder import Recorder
from .store import Store, private_dir
from .errors import ConflictError


def state_dir():
    base = os.environ.get("XDG_STATE_HOME", "")
    return (Path(base) if base and Path(base).is_absolute() else Path.home() / ".local/state") / "nshkr.chronicle"


def emit(data):
    print(json.dumps(data, ensure_ascii=True, allow_nan=False), flush=True)


def main():
    parser = argparse.ArgumentParser(description="Chronicle local recorder (never installs or modifies Omarchy)")
    parser.add_argument("--state-dir", type=Path, default=state_dir())
    parser.add_argument("--demo", action="store_true", help="synthetic events, no host sources; requires explicit state directory")
    parser.add_argument("--once", action="store_true", help="one read-only source collection then exit")
    args = parser.parse_args()
    if args.demo and "--state-dir" not in sys.argv:
        parser.error("--demo requires --state-dir to keep fixtures out of normal history")
    os.umask(0o077)
    lock = None
    store = None
    try:
        path = private_dir(args.state_dir)
        lock = os.open(path / "recorder.lock", os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        store = Store(path)
        recorder = Recorder(store, demo=args.demo)
        def stop(*_):
            recorder.shutdown = True
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        recorder.poll()
        emit(recorder.snapshot())
        if args.once:
            return 0
        buffer, discarding = b"", False
        next_poll = time.monotonic() + 5
        with selectors.DefaultSelector() as selector:
            selector.register(sys.stdin, selectors.EVENT_READ)
            while not recorder.shutdown:
                if time.monotonic() >= next_poll:
                    recorder.poll()
                    emit(recorder.snapshot())
                    next_poll = time.monotonic() + 5
                if not selector.select(.2):
                    continue
                chunk = os.read(sys.stdin.fileno(), 8192)
                if not chunk:
                    break
                if discarding:
                    if b"\n" not in chunk:
                        continue
                    chunk = chunk.split(b"\n", 1)[1]
                    discarding = False
                buffer += chunk
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    request_id = None
                    try:
                        if len(line) > 16384:
                            raise ValueError("command too large")
                        data = json.loads(line)
                        if isinstance(data, dict):
                            request_id = data.get("request_id")
                            if not isinstance(request_id, str) or len(request_id) > 100:
                                request_id = None
                        result = recorder.command(data)
                        emit({"type": "result", "request_id": request_id, "cmd": data["cmd"], "ok": True, "result": result})
                        if not recorder.shutdown:
                            emit(recorder.snapshot())
                    except ConflictError as error:
                        emit({"type": "error", "request_id": request_id, "code": "conflict", "error": str(error)})
                    except (ValueError, TypeError, KeyError, OverflowError, RecursionError):
                        emit({"type": "error", "request_id": request_id, "error": "Command rejected: invalid input, expired selection, or configured limit. Refresh and review your selection."})
                    except (OSError, sqlite3.Error):
                        emit({"type": "error", "request_id": request_id, "error": "Storage operation failed. Check private state permissions and free space. Existing evidence was not reset."})
                    if recorder.shutdown:
                        break
                if len(buffer) > 16384:
                    buffer, discarding = b"", True
                    emit({"type": "error", "error": "Command exceeded 16 KiB; discarded."})
        return 0
    except BlockingIOError:
        emit({"type": "error", "error": "Another Chronicle recorder owns this state directory."})
        return 2
    except (OSError, sqlite3.Error, ValueError):
        emit({"type": "error", "error": "Recorder unavailable: check state permissions, disk space, schema compatibility and source availability. Existing state was not reset."})
        return 1
    finally:
        if store:
            store.close()
        if lock is not None:
            os.close(lock)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BrokenPipeError:
        os._exit(0)
