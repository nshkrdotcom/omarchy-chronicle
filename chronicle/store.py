"""Transactional, private and limited Chronicle state. No observed-system writes."""

import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import time
import uuid

from .evidence import MAX_EVENT_BYTES, METRICS, metrics, redact
from .history import query as history_query, filters, integer
from .errors import ConflictError


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
        self.monotonic = time.monotonic
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
        if version not in (0, 1, 2):
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
            CREATE TABLE IF NOT EXISTS drafts (id TEXT PRIMARY KEY, body TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, body TEXT);
        """)
        if version < 2:
            # No executescript here: every DDL/data/schema change shares one
            # explicit transaction, including rollback on migration failure.
            try:
                self.db.execute("BEGIN IMMEDIATE")
                legacy_count = self.db.execute("SELECT count(*) FROM events").fetchone()[0]
                self.db.execute("DROP INDEX IF EXISTS events_time")
                self.db.execute("ALTER TABLE events RENAME TO events_v1")
                self.db.execute("""CREATE TABLE events (
                    seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL UNIQUE,
                    time_us INTEGER NOT NULL, source TEXT NOT NULL, category TEXT NOT NULL,
                    severity TEXT NOT NULL, body TEXT NOT NULL, received_us INTEGER NOT NULL)""")
                self.db.execute("""INSERT INTO events(id,time_us,source,category,severity,body,received_us)
                    SELECT id,time_us,source,category,severity,body,? FROM events_v1 ORDER BY time_us,id""", (self.now(),))
                self.db.execute("DROP TABLE events_v1")
                self.db.execute("CREATE INDEX events_time ON events(time_us DESC,id DESC)")
                self.db.execute("CREATE INDEX events_received ON events(received_us)")
                if legacy_count:
                    self.db.execute("INSERT OR REPLACE INTO settings VALUES(?,?)", ("receipt_age_estimated", "true"))
                self.db.execute("PRAGMA user_version=2")
                self.db.commit()
            except Exception:
                self.db.rollback()
                self.db.close()
                raise
        self.db.create_function("casefold", 1, lambda value: str(value).casefold(), deterministic=True)

    def close(self):
        self.db.close()

    def cursor(self, source):
        row = self.db.execute("SELECT cursor FROM cursors WHERE source=?", (source,)).fetchone()
        return row[0] if row else None

    def ingest(self, source, events, cursor=None, gap_message=None):
        if len(events) > 1000:
            raise ValueError("batch exceeds limit")
        with self.db:
            for event in events:
                if event["source"] != source or len(encode(event)) > MAX_EVENT_BYTES:
                    raise ValueError("invalid event source or size")
                self.db.execute("INSERT OR IGNORE INTO events(id,time_us,source,category,severity,body,received_us) VALUES(?,?,?,?,?,?,?)",
                                (event["id"], event["time_us"], source, event["category"],
                                 event["severity"], encode(event), self.now()))
            if gap_message:
                gap = self._internal_event(gap_message, severity="warning")
                self.db.execute("INSERT INTO events(id,time_us,source,category,severity,body,received_us) VALUES(?,?,?,?,?,?,?)",
                                (gap["id"], gap["time_us"], gap["source"], gap["category"],
                                 gap["severity"], encode(gap), self.now()))
            if cursor is not None:
                self.db.execute("INSERT OR REPLACE INTO cursors VALUES(?,?)", (source, cursor))
            removed = self.db.execute("DELETE FROM events WHERE received_us < ?", (self.now() - 7 * 86400_000_000,)).rowcount
            removed += self.db.execute("DELETE FROM events WHERE seq NOT IN (SELECT seq FROM events ORDER BY seq DESC LIMIT ?)", (self.event_limit,)).rowcount
            if removed:
                generation = self.setting("retention_generation", 0) + removed
                self.db.execute("INSERT OR REPLACE INTO settings VALUES(?,?)", ("retention_generation", encode(generation)))

    def _internal_event(self, message, category="recorder", severity="info"):
        return {"id": uuid.uuid4().hex, "time_us": self.now(), "source": "recorder",
                 "category": category, "severity": severity, "message": redact(message),
                 "unit": "Chronicle", "cursor": None, "boot": None, "monotonic_us": None}

    def record(self, message, category="recorder", severity="info"):
        event = self._internal_event(message, category, severity)
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

    def _selection(self, options):
        query = history_query(options)
        ceiling = query["ceiling"]
        if ceiling is None:
            row = self.db.execute("SELECT seq FROM sqlite_sequence WHERE name='events'").fetchone()
            ceiling = row[0] if row else 0
        clauses, args = ["seq<=?", "time_us>=?", "time_us<=?"], [ceiling, query["from_us"], query["to_us"]]
        for column in ("severity", "category", "source"):
            if query[column] != "all":
                clauses.append(column + "=?")
                args.append(query[column])
        if query["search"]:
            clauses.append("instr(casefold(json_extract(body,'$.message') || ' ' || json_extract(body,'$.unit')),?)>0")
            args.append(query["search"].casefold())
        if query["unit"]:
            clauses.append("json_extract(body,'$.unit')=?")
            args.append(query["unit"])
        for term in query["exclude"]:
            clauses.append("instr(casefold(json_extract(body,'$.message') || ' ' || json_extract(body,'$.unit')),?)=0")
            args.append(term.casefold())
        where = " WHERE " + " AND ".join(clauses)
        return query, ceiling, where, args

    def retained(self):
        return dict(self.db.execute("SELECT count(*) AS count,min(time_us) AS from_us,max(time_us) AS to_us FROM events").fetchone())

    def context(self, ident, **options):
        from .investigation import context
        return context(self, ident, **options)

    def analyze(self, **options):
        from .investigation import analyze
        return analyze(self, options)

    def history(self, **options):
        query, ceiling, where, args = self._selection(options)
        density = [{"count": 0, "errors": 0, "warnings": 0} for _ in range(48)]
        count = 0
        span = max(1, query["to_us"] - query["from_us"])
        for row in self.db.execute("SELECT time_us,severity FROM events" + where, args):
            bucket = density[min(47, (row[0] - query["from_us"]) * 48 // span)]
            bucket["count"] += 1
            bucket["errors"] += row[1] == "error"
            bucket["warnings"] += row[1] == "warning"
            count += 1
        if query["before"]:
            where += " AND (time_us,id)<(?,?)"
            args += [query["before"]["time_us"], query["before"]["id"]]
        rows = self.db.execute("SELECT body FROM events" + where + " ORDER BY time_us DESC,id DESC LIMIT ?", args + [query["limit"] + 1]).fetchall()
        events = [json.loads(row[0]) for row in rows[:query["limit"]]]
        next_cursor = {key: events[-1][key] for key in ("time_us", "id")} if len(rows) > query["limit"] else None
        retained = self.retained()
        return {"events": events, "next": next_cursor, "ceiling": ceiling,
                "matching_count": count, "density": density, "retained": retained,
                "from_us": query["from_us"], "to_us": query["to_us"],
                "retention_generation": self.setting("retention_generation", 0),
                "receipt_age_estimated": self.setting("receipt_age_estimated", False)}

    def samples(self):
        return [{"time_us": row[0], "values": json.loads(row[1])} for row in
                self.db.execute("SELECT time_us,body FROM samples ORDER BY id")]

    def _list(self, table):
        return [json.loads(row[0]) for row in self.db.execute(f"SELECT body FROM {table} ORDER BY time_us DESC, id DESC")]

    def bookmarks(self):
        return self._list("bookmarks")

    def saved_views(self):
        return self.setting("saved_views", [])

    def save_view(self, label, options):
        if not isinstance(label, str) or len(label) > 100:
            raise ValueError("invalid view label")
        view = filters(options)
        view.update(id=uuid.uuid4().hex, label=redact(label, 100) or "Saved view",
                    window_minutes=integer(options.get("window_minutes", 5), "window_minutes", 1, 10080))
        view["search"] = redact(view["search"], 200)
        view["unit"] = redact(view["unit"], 160)
        view["exclude"] = [redact(term, 200) for term in view["exclude"]]
        views = self.saved_views()
        if len(views) >= 20:
            raise ValueError("saved view limit reached (20); remove one first")
        self.set_setting("saved_views", views + [view])
        return view

    def remove_view(self, ident):
        self.set_setting("saved_views", [view for view in self.saved_views() if view["id"] != ident])

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
        item = json.loads(row[0])
        item.setdefault("revision", 1)
        return item

    def _write_incident(self, item):
        self.db.execute("INSERT OR REPLACE INTO incidents VALUES(?,?,?)", (item["id"], item["time_us"], encode(item)))
        return item

    def _save_incident(self, item):
        with self.db:
            self._write_incident(item)
        return item

    def create_incident(self, title):
        if self.db.execute("SELECT count(*) FROM incidents").fetchone()[0] >= 128:
            raise ValueError("incident limit reached (128); export and remove one first")
        return self._save_incident({"id": uuid.uuid4().hex, "time_us": self.now(),
                                   "title": redact(title, 100) or "Investigation", "notes": "",
                                   "status": "open", "evidence": [], "revision": 1})

    def update_incident(self, ident, notes, status, expected_revision=None, draft_token=None):
        if status not in ("open", "closed"):
            raise ValueError("invalid incident status")
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            item = self.incident(ident)
            if expected_revision is not None and item["revision"] != expected_revision:
                raise ConflictError("Incident changed; reload and review before saving. Your draft was not committed.")
            if draft_token is not None:
                self._check_draft(ident, draft_token)
            item.update(notes=redact(notes, 4096), status=status, revision=item["revision"] + 1)
            self._write_incident(item)
            if draft_token is not None:
                self.db.execute("DELETE FROM drafts WHERE id=?", (ident,))
        return item

    def draft(self, ident):
        row = self.db.execute("SELECT body FROM drafts WHERE id=?", (ident,)).fetchone()
        return json.loads(row[0]) if row else None

    def _check_draft(self, ident, token):
        draft = self.draft(ident)
        if (draft["token"] if draft else "") != token:
            raise ConflictError("The saved draft changed in another editor; reload and review. Local text was not saved.")

    def stage_draft(self, ident, notes, base_revision, token):
        integer(base_revision, "base_revision", 1)
        if not isinstance(notes, str) or len(notes) > 4096:
            raise ValueError("invalid draft notes")
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            item = self.incident(ident)
            if base_revision > item["revision"]:
                raise ValueError("invalid draft base revision")
            self._check_draft(ident, token)
            draft = {"notes": redact(notes, 4096), "base_revision": base_revision,
                     "token": uuid.uuid4().hex, "updated_us": self.now()}
            self.db.execute("INSERT OR REPLACE INTO drafts VALUES(?,?)", (ident, encode(draft)))
        return draft

    def discard_draft(self, ident, token):
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            self.incident(ident)
            self._check_draft(ident, token)
            self.db.execute("DELETE FROM drafts WHERE id=?", (ident,))

    def pin(self, ident, event_id):
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            item = self.incident(ident)
            if any(event["id"] == event_id for event in item["evidence"]):
                return item
            if len(item["evidence"]) >= 64:
                raise ValueError("incident evidence limit reached (64)")
            row = self.db.execute("SELECT body FROM events WHERE id=?", (event_id,)).fetchone()
            if not row:
                raise ValueError("event expired; it cannot be reconstructed")
            item["evidence"].append(json.loads(row[0]))
            item["revision"] += 1
            return self._write_incident(item)

    def unpin(self, ident, event_id):
        with self.db:
            self.db.execute("BEGIN IMMEDIATE")
            item = self.incident(ident)
            item["evidence"] = [event for event in item["evidence"] if event["id"] != event_id]
            item["revision"] += 1
            return self._write_incident(item)

    def remove_incident(self, ident):
        with self.db:
            self.db.execute("DELETE FROM incidents WHERE id=?", (ident,))
            self.db.execute("DELETE FROM drafts WHERE id=?", (ident,))

    def setting(self, key, fallback=None):
        row = self.db.execute("SELECT body FROM settings WHERE key=?", (key,)).fetchone()
        return json.loads(row[0]) if row else fallback

    def set_setting(self, key, value):
        with self.db:
            self.db.execute("INSERT OR REPLACE INTO settings VALUES(?,?)", (key, encode(value)))

    def preview_export(self, ident, detail=False, format="json"):
        if format not in ("json", "markdown"):
            raise ValueError("export format must be json or markdown")
        item = self.incident(ident)
        evidence = []
        for event in item["evidence"]:
            # Opaque cursors are retained locally, never needed in a shared report.
            clean = {key: value for key, value in event.items() if key not in ("cursor", "boot", "message")}
            if detail:
                clean["message"] = redact(event["message"])
            evidence.append(clean)
        bundle = {"format": "chronicle-evidence-v1", "created_us": self.now(),
                  "title": item["title"], "status": item["status"], "revision": item["revision"], "evidence": evidence,
                  "notes": redact(item["notes"], 4096) if detail else "[excluded]",
                  "detail_included": bool(detail),
                  "caution": "Correlation is not causation. Redaction is best-effort: review before sharing. This is selected evidence, not complete system history."}
        body = json.dumps(bundle, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
        if format == "markdown":
            from .report import markdown
            body = markdown(bundle)
        if len(body.encode()) > 2 * 1024 * 1024:
            raise ValueError("export exceeds 2 MiB")
        token = uuid.uuid4().hex
        # Only the most recent preview is valid; bounds memory and avoids stale confirmations.
        expiry = self.now() + 300_000_000
        self.previews = {token: (expiry, body, self.monotonic() + 300, ".md" if format == "markdown" else ".json")}
        return {"token": token, "text": body, "sha256": hashlib.sha256(body.encode()).hexdigest(),
                "expires_us": expiry, "format": format}

    def confirm_export(self, token):
        preview = self.previews.pop(token, None)
        if not preview or preview[0] <= self.now() or preview[2] <= self.monotonic():
            raise ValueError("preview expired or replaced; review again")
        folder = private_dir(self.path / "exports")
        if len(list(folder.iterdir())) >= 32:
            raise ValueError("export limit reached (32); move old exports out first")
        path = folder / ("chronicle-" + uuid.uuid4().hex + preview[3])
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(preview[1])
            stream.flush()
            os.fsync(stream.fileno())
        directory_fd = os.open(folder, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        return {"path": str(path), "sha256": hashlib.sha256(preview[1].encode()).hexdigest()}
