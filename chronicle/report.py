"""Portable reports with untrusted content rendered as literal text blocks."""
from datetime import datetime, timedelta, timezone


def timestamp(microseconds):
    try:
        return (datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(microseconds=microseconds)).isoformat().replace("+00:00", "Z")
    except OverflowError:
        return str(microseconds) + " source microseconds (outside calendar range)"


def literal(value):
    # Four-space code blocks keep HTML, image syntax, links and embedded fences
    # inert in CommonMark. Every line is indented, including blank lines.
    return "\n".join("    " + line for line in str(value).split("\n")) + "\n"


def markdown(bundle):
    sections = ["# Chronicle incident handoff", "## Investigation",
                literal(bundle["title"]), "Status: " + bundle["status"] + " · Revision: " + str(bundle["revision"]),
                "Created: " + timestamp(bundle["created_us"]), "## Coverage and privacy", bundle["caution"],
                "Messages and notes: " + ("included after review." if bundle["detail_included"] else "excluded (metadata only)."),
                "## Committed notes", literal(bundle["notes"]), "## Selected evidence"]
    if not bundle["evidence"]:
        sections.append("No evidence was pinned. This does not mean nothing happened.")
    for i, event in enumerate(sorted(bundle["evidence"], key=lambda e: (e["time_us"], e["id"])), 1):
        fields = "\n".join(key + ": " + str(event.get(key, "not recorded")) for key in
                           ("id", "source", "unit", "category", "severity", "monotonic_us"))
        sections += ["### Evidence " + str(i), "Observed: " + timestamp(event["time_us"]), literal(fields)]
        if bundle["detail_included"]:
            sections += ["Message:", literal(event["message"])]
    return "\n\n".join(sections) + "\n"
