"""Bounded, shared validation for history requests and durable filter views."""
import re

FILTERS = {
    "severity": ("all", "info", "warning", "error"),
    "category": ("all", "service", "desktop", "network", "audio", "power", "resource", "recorder"),
    "source": ("all", "user-journal", "system-journal", "recorder", "demo"),
}
MAX_INTEGER = 2**53 - 1  # Exactly representable over the QML JSON transport.


def integer(value, name, minimum=0, maximum=MAX_INTEGER):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError("invalid " + name)
    return value


def filters(data):
    result = {key: data.get(key, "all") for key in FILTERS}
    for key, allowed in FILTERS.items():
        if result[key] not in allowed:
            raise ValueError("invalid " + key)
    search = data.get("search", "")
    if not isinstance(search, str) or len(search) > 200:
        raise ValueError("invalid search")
    return {**result, "search": search}


def query(data):
    result = filters(data)
    for key in ("from_us", "to_us"):
        result[key] = integer(data.get(key), key)
    if result["from_us"] > result["to_us"]:
        raise ValueError("history interval is reversed")
    result["limit"] = integer(data.get("limit", 200), "limit", 1, 500)
    result["ceiling"] = data.get("ceiling")
    if result["ceiling"] is not None:
        integer(result["ceiling"], "ceiling")
    result["before"] = data.get("before")
    if result["before"] is not None:
        cursor = result["before"]
        if not isinstance(cursor, dict) or set(cursor) != {"time_us", "id"}:
            raise ValueError("invalid history cursor")
        integer(cursor["time_us"], "cursor time")
        if not isinstance(cursor["id"], str) or not re.fullmatch("[0-9a-f]{32}", cursor["id"]):
            raise ValueError("invalid cursor identity")
        if result["ceiling"] is None:
            raise ValueError("history continuation requires a receipt ceiling")
    return result
