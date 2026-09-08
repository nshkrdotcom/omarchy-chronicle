"""Read-only investigation queries. Aggregation never replaces source evidence."""
import json
import re

from .history import MAX_INTEGER, integer, query as history_query

CAUTION = ("Counts describe retained observations, not complete system activity. "
           "Zero observations do not prove recovery. Recorder notices, pauses, retention and "
           "clock changes can affect comparison. Exact stored text may match after redaction.")


def context(store, ident, scope="unit", radius_seconds=120, limit=30, ceiling=None):
    if not isinstance(ident, str) or not re.fullmatch("[0-9a-f]{32}", ident):
        raise ValueError("invalid event identity")
    if scope not in ("unit", "all"):
        raise ValueError("invalid context scope")
    integer(radius_seconds, "context radius", 1, 3600)
    integer(limit, "context limit", 1, 100)
    _, ceiling, _, _ = store._selection(dict(from_us=0, to_us=MAX_INTEGER, ceiling=ceiling))
    row = store.db.execute("SELECT body FROM events WHERE id=? AND seq<=?", (ident, ceiling)).fetchone()
    if row is None:
        raise ValueError("Selected event is no longer retained in this view. Inspect a saved pin if available.")
    anchor = json.loads(row[0])
    at = integer(anchor["time_us"], "event time")
    start, end = max(0, at-radius_seconds*1_000_000), min(MAX_INTEGER, at+radius_seconds*1_000_000)
    where = " WHERE seq<=? AND time_us>=? AND time_us<=?"
    args = [ceiling, start, end]
    if scope == "unit":
        where += " AND source=? AND json_extract(body,'$.unit')=? AND json_extract(body,'$.boot')=?"
        args += [anchor["source"], anchor["unit"], anchor["boot"]]
    counts, sides = [], []
    for operator, direction in (("<", "DESC"), (">", "ASC")):
        clause = where + " AND (time_us,id)" + operator + "(?,?)"
        values = args + [at, ident]
        counts.append(store.db.execute("SELECT count(*) FROM events" + clause, values).fetchone()[0])
        sides.append([json.loads(r[0]) for r in store.db.execute(
            "SELECT body FROM events" + clause + " ORDER BY time_us " + direction + ",id " + direction + " LIMIT ?",
            values + [limit])])
    return {"anchor": anchor, "scope": scope, "radius_seconds": radius_seconds, "ceiling": ceiling,
            "from_us": start, "to_us": end, "events": list(reversed(sides[0])) + [anchor] + sides[1],
            "before_count": counts[0], "after_count": counts[1],
            "shown_before": len(sides[0]), "shown_after": len(sides[1]),
            "truncated": any(n > limit for n in counts), "retained": store.retained(),
            "retention_generation": store.setting("retention_generation", 0),
            "caution": "Search, exclusions, category and level filters are lifted. "
                       "Same unit uses recorded source, unit and boot, not process identity. "
                       "Missing neighbors do not establish complete history."}


def analyze(store, options):
    query = history_query({**options, "limit": options.get("limit", 50)})
    limit = integer(query["limit"], "analysis limit", 1, 100)
    if options.get("before") is not None:
        raise ValueError("analysis uses the full interval, not a page cursor")
    sort = options.get("sort", "repeat")
    if sort not in ("repeat", "change"):
        raise ValueError("invalid analysis sort")
    duration = query["to_us"] - query["from_us"] + 1
    previous_start = query["from_us"] - duration
    if previous_start < 0:
        raise ValueError("Choose a later interval so both comparison windows fit after 1970-01-01.")
    _, ceiling, where, args = store._selection({**query, "from_us": previous_start})
    # SQLite aggregates the full retained interval and returns only the requested
    # rows. No collection of thousands of message bodies crosses into QML/Python.
    fields = "source,json_extract(body,'$.unit') AS unit,json_extract(body,'$.boot') AS boot,category,severity,json_extract(body,'$.message') AS message"
    sql = """WITH groups AS (
        SELECT """ + fields + """,
          sum(time_us>=?) AS current, sum(time_us<?) AS previous,
          min(CASE WHEN time_us>=? THEN time_us END) AS first_us,
          max(CASE WHEN time_us>=? THEN time_us END) AS last_us,
          min(CASE WHEN time_us<? THEN time_us END) AS previous_first_us,
          max(CASE WHEN time_us<? THEN time_us END) AS previous_last_us,
          substr(max(printf('%020d',time_us)||id),21) AS event_id
        FROM events""" + where + """
        GROUP BY source,unit,boot,category,severity,message)
        SELECT *,count(*) OVER() AS group_count,sum(current) OVER() AS current_count,
          sum(previous) OVER() AS previous_count FROM groups ORDER BY """
    sql += ("abs(current-previous) DESC," if sort == "change" else "")
    sql += "current DESC,previous DESC,source,unit,boot,category,severity,message LIMIT ?"
    rows = [dict(row) for row in store.db.execute(sql, [query["from_us"]]*6 + args + [limit])]
    totals = {key: rows[0][key] if rows else 0 for key in ("group_count", "current_count", "previous_count")}
    for row in rows:
        for key in totals:
            row.pop(key)
        row["delta"] = row["current"] - row["previous"]
        row["state"] = ("newly observed" if not row["previous"] else "not seen again" if not row["current"]
                        else "unchanged" if not row["delta"] else "increased" if row["delta"] > 0 else "decreased")
    notices = store.db.execute("SELECT count(*) FROM events WHERE source='recorder' AND seq<=? AND time_us BETWEEN ? AND ?",
                              (ceiling, previous_start, query["to_us"])).fetchone()[0]
    return {**totals, "groups": rows, "truncated": totals["group_count"] > len(rows),
            "from_us": query["from_us"], "to_us": query["to_us"], "previous_from_us": previous_start,
            "previous_to_us": query["from_us"] - 1, "ceiling": ceiling, "sort": sort,
            "filters": {key: query[key] for key in ("search", "unit", "exclude", "source", "category", "severity")},
            "recorder_notices": notices, "retained": store.retained(), "caution": CAUTION,
            "retention_generation": store.setting("retention_generation", 0)}
