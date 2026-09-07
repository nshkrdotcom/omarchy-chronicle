"""Bounded, allowlisted evidence. Classification does not establish causation."""

import hashlib
import math
import re

METRICS = {
    "cpu_some_avg10": "% stalled", "memory_some_avg10": "% stalled",
    "io_some_avg10": "% stalled", "memory_available_kib": "KiB",
}


def scalar(value):
    if isinstance(value, list):
        if value and all(type(v) is int and 0 <= v <= 255 for v in value):
            return bytes(value[:8192]).decode("utf-8", errors="replace")
        return scalar(value[0]) if value else ""
    return str(value) if isinstance(value, (str, int, float)) else ""


def redact(value, limit=2048):
    text = scalar(value)[:16384]
    text = re.sub(r"-----BEGIN [^-]*PRIVATE KEY-----[\s\S]*", "[redacted private key]", text)
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    text = re.sub(r"[\x00-\x08\x0b-\x1f\x7f\u202a-\u202e\u2066-\u2069]", "", text)
    text = re.sub(r"(?i)\b(bearer|basic)\s+[^\s,;]+", r"\1 [redacted]", text)
    text = re.sub(r'''(?i)(["']?(?:password|passwd|token|secret|api[_-]?key|authorization|cookie)["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)''', r"\1[redacted]", text)
    text = re.sub(r"https?://[^\s]+", "[redacted url]", text)
    text = re.sub(r"/(?:home|Users)/[^\s\"'<>]+", "[redacted path]", text)
    text = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[redacted email]", text)
    text = re.sub(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", "[redacted address]", text)
    text = re.sub(r"(?<!\w)(?:[0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F:]{0,4}(?!\w)", "[redacted address]", text)
    return text[:limit]


def normalize(record, source="user-journal"):
    if not isinstance(record, dict):
        raise ValueError("journal record must be an object")
    cursor = scalar(record.get("__CURSOR"))
    boot = scalar(record.get("_BOOT_ID"))
    if not cursor or len(cursor) > 4096 or not boot or len(boot) > 128:
        raise ValueError("missing or oversized journal identity")
    timestamp = int(scalar(record.get("__REALTIME_TIMESTAMP")))
    if not 0 <= timestamp <= 2**63 - 1:
        raise ValueError("invalid journal timestamp")
    try:
        monotonic = int(scalar(record.get("__MONOTONIC_TIMESTAMP")))
        if not 0 <= monotonic <= 2**63 - 1:
            monotonic = None
    except ValueError:
        monotonic = None
    try:
        priority = int(scalar(record.get("PRIORITY")))
    except ValueError:
        priority = 6
    unit = redact(record.get("_SYSTEMD_USER_UNIT") or record.get("_SYSTEMD_UNIT") or record.get("SYSLOG_IDENTIFIER"), 160)
    message = redact(record.get("MESSAGE"))
    kind = unit.lower()
    category = "service"
    for name, tokens in (("audio", ("pipewire", "wireplumber", "pulse")),
                         ("network", ("networkmanager", "networkd", "resolved", "wpa_supplicant")),
                         ("desktop", ("omarchy", "hyprland", "quickshell")),
                         ("power", ("sleep", "suspend", "logind", "upower")),
                         ("resource", ("oom", "coredump", "kernel"))):
        if any(token in kind for token in tokens):
            category = name
            break
    return {"id": hashlib.sha256((source + "\0" + cursor).encode()).hexdigest()[:32],
            "cursor": cursor, "time_us": timestamp, "monotonic_us": monotonic,
            "boot": boot, "source": source, "unit": unit, "category": category,
            "severity": "error" if priority <= 3 else "warning" if priority == 4 else "info",
            "message": message}


def metrics(values):
    if not isinstance(values, dict):
        raise ValueError("metrics must be an object")
    return {key: value if type(value) in (float, int) and math.isfinite(value)
            and 0 <= value <= (100 if key.endswith("avg10") else 2**53) else None
            for key, value in values.items() if key in METRICS}
