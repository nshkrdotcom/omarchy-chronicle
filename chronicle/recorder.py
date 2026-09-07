"""Recorder control protocol. Observation continues independently of panel visibility."""

import math
import uuid

from .evidence import normalize
from .sources import Journal, read_pressure


class Recorder:
    def __init__(self, store, demo=False):
        self.store, self.demo = store, demo
        self.session = uuid.uuid4().hex
        self.paused = store.setting("paused", False) is True
        self.system_journal = store.setting("system_journal", False) is True
        self.panel_open = False
        self.journals = [Journal()]
        if self.system_journal:
            self.journals.append(Journal("system-journal"))
        self.sources = {}
        self.values = {}
        self.sequence = 0
        self.shutdown = False
        self.query = {}
        self.store.record("Recorder started. History while Chronicle was stopped may be incomplete.", severity="warning")

    def source_status(self, name, status, count=0):
        previous = self.sources.get(name, {})
        good = status in ("ok", "empty", "demo")
        self.sources[name] = {"id": name, "status": status, "checked_us": self.store.now(),
                              "last_success_us": self.store.now() if good else previous.get("last_success_us"),
                              "batch_count": count}

    def poll(self):
        if self.paused:
            return
        self.sequence += 1
        if self.demo:
            if self.sequence == 1:
                names = [("omarchy-shell.service", "Desktop configuration reloaded", 6),
                         ("NetworkManager.service", "Link changed: connection unavailable", 4),
                         ("pipewire.service", "Audio graph resynchronized", 6),
                         ("example.service", "Worker exited unexpectedly", 3),
                         ("systemd-suspend.service", "System resumed", 6)]
                events = []
                for i in range(45):
                    unit, message, priority = names[i % len(names)]
                    events.append(normalize({"__CURSOR": self.session + ":" + str(i),
                        "__REALTIME_TIMESTAMP": str(self.store.now() - (45 - i) * 5_000_000),
                        "__MONOTONIC_TIMESTAMP": str(i * 5_000_000), "_BOOT_ID": "fixture-boot",
                        "_SYSTEMD_USER_UNIT": unit, "MESSAGE": message, "PRIORITY": str(priority)}, "demo"))
                self.store.ingest("demo", events)
                for i in range(60):
                    # Backdated fixture samples only; no host access.
                    self.store.db.execute("INSERT INTO samples(time_us,body) VALUES(?,?)",
                        (self.store.now() - (60 - i) * 5_000_000,
                         '{"cpu_some_avg10":' + str(round(3 + 2 * math.sin(i / 4), 2)) + ',"memory_some_avg10":0.2,"io_some_avg10":0.4,"memory_available_kib":8000000}'))
                self.store.db.commit()
            self.values = {"cpu_some_avg10": round(3 + 2 * math.sin(self.sequence), 2),
                           "memory_some_avg10": .2, "io_some_avg10": .4, "memory_available_kib": 8_000_000}
            self.store.sample(self.values)
            for name in ("user-journal", "system-journal", "pressure"):
                self.source_status(name, "demo")
            return
        for journal in self.journals:
            result = journal.read(self.store.cursor(journal.name))
            self.store.ingest(journal.name, result["events"], result["cursor"])
            if result["gap"]:
                self.store.record(journal.name + ": history gap, rejected record or bounded tail; continuity is not established.", severity="warning")
            self.source_status(journal.name, result["status"], len(result["events"]))
        if not self.system_journal:
            self.source_status("system-journal", "disabled")
        self.values = read_pressure()
        self.store.sample(self.values)
        self.source_status("pressure", "ok" if all(v is not None for v in self.values.values()) else "degraded")

    def snapshot(self):
        return {"type": "snapshot", "protocol": 1, "session": self.session,
                "time_us": self.store.now(), "demo": self.demo, "paused": self.paused,
                "system_journal": self.system_journal,
                "sources": list(self.sources.values()), "values": self.values,
                "event_count": self.store.db.execute("SELECT count(*) FROM events").fetchone()[0],
                "events": self.store.events(**self.query) if self.panel_open else [],
                "samples": self.store.samples() if self.panel_open else [],
                "bookmarks": self.store.bookmarks(),
                "incidents": [{k: v for k, v in item.items() if k not in ("evidence", "notes")}
                              | {"evidence_count": len(item["evidence"])} for item in self.store.incidents()]}

    def command(self, data):
        if not isinstance(data, dict) or not isinstance(data.get("cmd"), str):
            raise ValueError("command object required")
        cmd = data["cmd"]
        def text(key, default="", limit=4096):
            value = data.get(key, default)
            if not isinstance(value, str) or len(value) > limit:
                raise ValueError("invalid " + key)
            return value
        def boolean(key):
            if type(data.get(key)) is not bool:
                raise ValueError(key + " must be boolean")
            return data[key]
        if cmd == "panel":
            self.panel_open = boolean("open")
            return {"open": self.panel_open}
        if cmd == "pause":
            self.paused = boolean("paused")
            self.store.set_setting("paused", self.paused)
            self.store.record("Recording paused by operator." if self.paused else "Recording resumed; paused interval is a sampling gap.")
            if not self.paused:
                self.poll()
            return {"paused": self.paused}
        if cmd == "system_journal":
            self.system_journal = boolean("enabled")
            self.store.set_setting("system_journal", self.system_journal)
            self.journals = [Journal()] + ([Journal("system-journal")] if self.system_journal else [])
            self.store.record("Accessible system journal " + ("enabled" if self.system_journal else "disabled") + " by operator.")
            self.source_status("system-journal", "pending" if self.system_journal else "disabled")
            return {"enabled": self.system_journal}
        if cmd == "refresh":
            self.poll()
            return {"refreshed": True}
        if cmd == "query":
            limit = data.get("limit", 500)
            if type(limit) is not int or not 1 <= limit <= 500:
                raise ValueError("query limit must be 1..500")
            self.query = {key: text(key, "" if key == "search" else "all", 200)
                          for key in ("search", "severity", "category", "source")}
            self.query["limit"] = limit
            return {"query": self.query}
        if cmd == "bookmark":
            if self.paused or not self.values:
                raise ValueError("resume recording and obtain a sample before marking this moment")
            return self.store.bookmark(text("label", "Moment", 100), self.values)
        if cmd == "remove_bookmark":
            self.store.remove_bookmark(text("id"))
            return {}
        if cmd == "compare":
            return self.store.compare(text("a"), text("b"))
        if cmd == "create_incident":
            return self.store.create_incident(text("title", "Investigation", 100))
        if cmd == "incident":
            return self.store.incident(text("id"))
        if cmd == "update_incident":
            return self.store.update_incident(text("id"), text("notes"), text("status", "open"))
        if cmd == "pin":
            return self.store.pin(text("id"), text("event_id"))
        if cmd == "unpin":
            return self.store.unpin(text("id"), text("event_id"))
        if cmd == "remove_incident":
            if data.get("confirm") is not True:
                raise ValueError("explicit deletion confirmation required")
            self.store.remove_incident(text("id"))
            return {}
        if cmd == "preview_export":
            detail = boolean("detail") if "detail" in data else False
            return self.store.preview_export(text("id"), detail)
        if cmd == "confirm_export":
            return self.store.confirm_export(text("token"))
        if cmd == "shutdown":
            self.shutdown = True
            return {"stopped": True}
        raise ValueError("unknown command")
