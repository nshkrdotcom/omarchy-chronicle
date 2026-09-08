"""Transactional, private and bounded Chronicle state. No observed-system writes."""

import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import time
import uuid

from .evidence import METRICS, metrics, redact


def encode(value):
    return json.dumps(value, ensure_ascii=True, sort_keys=True, allow_nan=False)


def private_dir(path):
    path = Path(path).absolute()
    if path.is_symlink():
        raise ValueError("state directory must not be a symlink")
    existed = path.exists()
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = path.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError("state directory must be owned by the current user")
    if existed and info.st_mode & 0o077:
        raise ValueError("existing state directory must already be private (0700)")
    return path


class Store:
    def __init__(self, path, now=None, event_limit=10000):
        self.path = private_dir(path)
        self.now = now or (lambda: time.time_ns() // 1000)
        self.event_limit = max(1, min(event_limit, 10000))
        self.previews = {}
        db = self.path / "chronicle.sqlite3"
        for suffix in ("", "-wal", "-shm", "-journal"):
            candidate = Path(str(db) + suffix)
            if candidate.is_symlink() or (candidate.exists() and
                    (not candidate.is_file() or candidate.stat().st_nlink != 1)):
                raise ValueError("unsafe database path")
        fd = os.open(db, os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
        os.close(fd)
        db.chmod(0o600)
        self.db = sqlite3.connect(db, timeout=2)
        self.db.row_factory = sqlite3.Row
        version = self.db.execute("PRAGMA user_version").fetchone()[0]
        if version not in (0, 1):
            self.db.close()
            raise ValueError("unsupported database schema; state preserved")
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.execute("PRAGMA journal_size_limit=1048576")
        self.db.execute("PRAGMA max_page_count=8192")
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS events (
              id TEXT PRIMARY KEY, time_us INTEGER NOT NULL, source TEXT NOT NULL,
              category TEXT NOT NULL, severity TEXT NOT NULL, body TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS events_time ON events(time_us DESC, id);
            CREATE TABLE IF NOT EXISTS cursors (source TEXT PRIMARY KEY, cursor TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS samples (id INTEGER PRIMARY KEY, time_us INTEGER, body TEXT);
            CREATE TABLE IF NOT EXISTS bookmarks (id TEXT PRIMARY KEY, time_us INTEGER, body TEXT);
            CREATE TABLE IF NOT EXISTS incidents (id TEXT PRIMARY KEY, time_us INTEGER, body TEXT);
            CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, body TEXT);
            PRAGMA user_version=1;
        """)

    def close(self):
        self.db.close()

    def cursor(self, source):
        row = self.db.execute("SELECT cursor FROM cursors WHERE source=?", (source,)).fetchone()
        return row[0] if row else None

    def ingest(self, source, events, cursor=None):
        if len(events) > 1000:
            raise ValueError("batch exceeds limit")
        with self.db:
            for event in events:
                if event["source"] != source or len(encode(event)) > 12000:
                    raise ValueError("invalid event source or size")
                self.db.execute("INSERT OR IGNORE INTO events VALUES(?,?,?,?,?,?)",
                                (event["id"], event["time_us"], source, event["category"],
                                 event["severity"], encode(event)))
            if cursor is not None:
                self.db.execute("INSERT OR REPLACE INTO cursors VALUES(?,?)", (source, cursor))
            self.db.execute("DELETE FROM events WHERE time_us < ?", (self.now() - 7 * 86400_000_000,))
            self.db.execute("DELETE FROM events WHERE id NOT IN (SELECT id FROM events ORDER BY time_us DESC, id DESC LIMIT ?)", (self.event_limit,))

    def record(self, message, category="recorder", severity="info"):
        event = {"id": uuid.uuid4().hex, "time_us": self.now(), "source": "recorder",
                 "category": category, "severity": severity, "message": redact(message),
                 "unit": "Chronicle", "cursor": None, "boot": None, "monotonic_us": None}
        self.ingest("recorder", [event])
        return event

    def events(self, search="", severity="all", category="all", source="all", limit=500):
        clauses, args = [], []
        for column, value in (("severity", severity), ("category", category), ("source", source)):
            if value != "all":
                clauses.append(column + "=?")
                args.append(value)
        sql = "SELECT body FROM events" + (" WHERE " + " AND ".join(clauses) if clauses else "")
        # Literal search, never SQL LIKE wildcards or an executable expression.
        rows = self.db.execute(sql + " ORDER BY time_us DESC, id DESC", args)
        result = []
        for row in rows:
            event = json.loads(row[0])
            if str(search).casefold() in (event["message"] + " " + event["unit"]).casefold():
                result.append(event)
            if len(result) >= max(1, min(int(limit), 10000)):
                break
        return result

    def sample(self, values):
        with self.db:
            self.db.execute("INSERT INTO samples(time_us,body) VALUES(?,?)", (self.now(), encode(metrics(values))))
            self.db.execute("DELETE FROM samples WHERE id NOT IN (SELECT id FROM samples ORDER BY id DESC LIMIT 720)")

    def samples(self):
        return [{"time_us": row[0], "values": json.loads(row[1])} for row in
                self.db.execute("SELECT time_us,body FROM samples ORDER BY id")]

    def _list(self, table):
        return [json.loads(row[0]) for row in self.db.execute(f"SELECT body FROM {table} ORDER BY time_us DESC, id DESC")]

    def bookmarks(self):
        return self._list("bookmarks")

    def bookmark(self, label, values, observed_us=None):
        if len(self.bookmarks()) >= 256:
            raise ValueError("bookmark limit reached (256); remove one first")
        result = {"id": uuid.uuid4().hex, "time_us": self.now(), "label": redact(label, 100) or "Moment",
                  "values": metrics(values), "observed_us": observed_us}
        with self.db:
            self.db.execute("INSERT INTO bookmarks VALUES(?,?,?)", (result["id"], result["time_us"], encode(result)))
        return result

    def remove_bookmark(self, ident):
        with self.db:
            self.db.execute("DELETE FROM bookmarks WHERE id=?", (ident,))

    def compare(self, a, b):
        rows = {row["id"]: row for row in self.bookmarks()}
        if a not in rows or b not in rows:
            raise ValueError("bookmark no longer exists")
        left, right = rows[a], rows[b]
        delta, missing = {}, []
        for key in METRICS:
            x, y = left["values"].get(key), right["values"].get(key)
            if x is None or y is None:
                missing.append(key)
            else:
                delta[key] = y - x
        return {"a": left, "b": right, "duration_us": right["time_us"] - left["time_us"],
                "delta": delta, "missing": missing,
                "units": {key: "percentage points" if key.endswith("avg10") else unit for key, unit in METRICS.items()},
                "caution": "Two observations, not a causal explanation. Missing fields are not zero."}

    def incidents(self):
        return self._list("incidents")

    def incident_summaries(self):
        return [dict(row) for row in self.db.execute("""
            SELECT id, time_us, json_extract(body,'$.title') AS title,
              json_extract(body,'$.status') AS status,
              json_array_length(body,'$.evidence') AS evidence_count
            FROM incidents ORDER BY time_us DESC, id DESC
        """)]

    def incident(self, ident):
        row = self.db.execute("SELECT body FROM incidents WHERE id=?", (ident,)).fetchone()
        if not row:
            raise ValueError("incident no longer exists")
        return json.loads(row[0])

    def _save_incident(self, item):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO incidents VALUES(?,?,?)", (item["id"], item["time_us"], encode(item)))
        return item

    def create_incident(self, title):
        if self.db.execute("SELECT count(*) FROM incidents").fetchone()[0] >= 128:
            raise ValueError("incident limit reached (128); export and remove one first")
        return self._save_incident({"id": uuid.uuid4().hex, "time_us": self.now(),
                                   "title": redact(title, 100) or "Investigation", "notes": "",
                                   "status": "open", "evidence": []})

    def update_incident(self, ident, notes, status):
        if status not in ("open", "closed"):
            raise ValueError("invalid incident status")
        item = self.incident(ident)
        item.update(notes=redact(notes, 4096), status=status)
        return self._save_incident(item)

    def pin(self, ident, event_id):
        item = self.incident(ident)
        if any(event["id"] == event_id for event in item["evidence"]):
            return item
        if len(item["evidence"]) >= 64:
            raise ValueError("incident evidence limit reached (64)")
        row = self.db.execute("SELECT body FROM events WHERE id=?", (event_id,)).fetchone()
        if not row:
            raise ValueError("event expired; it cannot be reconstructed")
        item["evidence"].append(json.loads(row[0]))
        return self._save_incident(item)

    def unpin(self, ident, event_id):
        item = self.incident(ident)
        item["evidence"] = [event for event in item["evidence"] if event["id"] != event_id]
        return self._save_incident(item)

    def remove_incident(self, ident):
        with self.db:
            self.db.execute("DELETE FROM incidents WHERE id=?", (ident,))

    def setting(self, key, fallback=None):
        row = self.db.execute("SELECT body FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else fallback

    def set_setting(self, key, value):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO settings VALUES(?,?)", (key, encode(value)))

    def preview_export(self, ident, detail=False):
        item = self.incident(ident)
        evidence = []
        for event in item["evidence"]:
            # Opaque cursors are retained locally, never needed in a shared report.
            clean = {key: value for key, value in event.items() if key not in ("cursor", "boot", "message")}
            if detail:
                clean["message"] = redact(event["message"])
            evidence.append(clean)
        bundle = {"format": "chronicle-evidence-v1", "created_us": self.now(),
                  "title": item["title"], "status": item["status"], "evidence": evidence,
                  "notes": redact(item["notes"], 4096) if detail else "[excluded]",
                  "detail_included": bool(detail),
                  "caution": "Correlation is not causation. Redaction is best-effort: review before sharing. This is selected evidence, not complete system history."}
        body = json.dumps(bundle, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
        if len(body.encode()) > 2 * 1024 * 1024:
            raise ValueError("export exceeds 2 MiB")
        token = uuid.uuid4().hex
        # Only the most recent preview is valid; bounds memory and avoids stale confirmations.
        self.previews = {token: (self.now() + 300_000_000, body)}
        return {"token": token, "text": body, "sha256": hashlib.sha256(body.encode()).hexdigest(),
                "expires_us": self.now() + 300_000_000}

    def confirm_export(self, token):
        preview = self.previews.pop(token, None)
        if not preview or preview[0] < self.now():
            raise ValueError("preview expired or replaced; review again")
        folder = private_dir(self.path / "exports")
        if len(list(folder.iterdir())) >= 32:
            raise ValueError("export limit reached (32); move old exports out first")
        path = folder / ("chronicle-" + uuid.uuid4().hex + ".json")
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(preview[1])
            stream.flush()
            os.fsync(stream.fileno())
        return {"path": str(path), "sha256": hashlib.sha256(preview[1].encode()).hexdigest()}
