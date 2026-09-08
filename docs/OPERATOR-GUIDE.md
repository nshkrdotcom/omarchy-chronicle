# Using Chronicle

This guide describes the implemented UI. Installation and live desktop
acceptance are pending; see [the release gate](RELEASE-GATE.md).

## Investigate what just happened

1. Open Timeline. Start at 5m and widen the window if the event is older.
2. Search for an application, service, or phrase. Search is literal, not a
   regular expression. Live search queries retained history; the view shows
   the newest 500 matching records. Time-window filtering then applies locally.
3. Cycle severity, category, and source controls to narrow the evidence.
4. Select a timeline marker or row. Its exact recorded identity is inspected.
   Selection and scrolling freeze the view; collection continues in the service.
5. Review its timestamp, unit, source, boot identity and monotonic timestamp.
   The timeline uses wall time, which can jump. Monotonic values are only
   comparable within the same boot. No cause is inferred from proximity alone.
6. Use the pressure lenses to examine CPU/memory/I/O stalls. Hover or focus the
   trace and use left/right arrows to read actual observations. A null reading
   is unavailable, not zero; delayed samples break the line.

Selecting **Live** releases the frozen view and refreshes the retained-history
query. Frozen search only filters the captured evidence set. The recorder can
outlive the panel, but it cannot collect while Omarchy/the helper is stopped.

## Compare a deliberate change

In Bookmarks, name a moment (for example, “Before restart”) and Mark now. Make
your change yourself, then mark “After restart.” Select A and B and Compare.

Results show signed differences for available metrics. PSI deltas are
**percentage points**; available memory is KiB. Each mark distinguishes its
creation time from the measurement's observation time. Marking is refused
when recording is paused or the latest observation is older than 15 seconds.
Missing pairs are called out instead of imputed. A/B comparison is not an
event replay, complete configuration diff, or proof of causation.

## Save an incident

Select an event and choose Create incident + pin, or create a named incident
on the Incidents page first. Pin further events to that selected incident.
Saved evidence is copied: pruning the recorder's normal history does not
delete pinned evidence. Notes are saved explicitly; resolving an incident
does not remove it, and it can be reopened.

Removing an incident/bookmark requires the confirmation dialog. Unpin removes
only that incident's saved copy; the original may remain in retained history.
Export evidence before deleting anything you need. There is no undo or
guaranteed secure erasure; SQLite/WAL and external backups can retain bytes.

## Export safely

Metadata only is the default. It omits message bodies, notes, raw journal
cursors and boot identifiers. The title, units, timestamps, categories,
severity and selected event identities remain visible and can be sensitive.

If messages/notes are necessary, opt in and open Preview export. Review all
the displayed JSON. The save action writes **exactly those reviewed bytes**
to a unique private file in the state's `exports` directory. Confirmation is
single-use and expires after five minutes; opening a new preview invalidates
the old one. Later incident edits do not mutate an already-previewed bundle.

Chronicle does not upload or copy the file. The status line reports its path.
Redaction is best-effort. A metadata-only bundle is not guaranteed anonymous.

## Source status and recovery

- RECORDING: active sources have no currently reported read failures; it does
  not mean the machine itself is healthy.
- DEMO: synthetic data, never a real-system diagnosis.
- PAUSED: source collection stopped by the operator; UI history remains.
- STALE/OFFLINE: investigate recorder availability before trusting freshness.
- DEGRADED: inspect Sources. Timeouts, rejected records, missing metrics and
  journal continuity gaps remain distinct from healthy data.

Enable accessible system journal only if you want system-service evidence.
Chronicle does not request root or change journal permissions. Disabling a
source stops subsequent collection but keeps already-stored evidence.

If writes fail, existing saved evidence remains inspectable where SQLite can
still read it. Check filesystem free space, export count, and incident limits.
Export/remove unneeded saved incidents deliberately. Chronicle never resets a
database automatically. An unsupported schema or unreadable/corrupt database
requires operator intervention; preserve the complete state directory first.

## Keyboard and layout

`/` search, `Space` freeze/live, `↑/↓` event selection, `Ctrl+M` mark now,
`Tab` controls, `←/→` focused pressure samples, `Esc` close. Text inputs consume
normal typing so spaces in a search/notes do not freeze the cockpit.

Closing the panel is not pausing the recorder. Header fonts and top-right
action alignment are shared across invocation routes; no overlay alternative
exists. Styling derives from Omarchy's native popup and font tokens.
# Historical exploration and saved views

## Notes that survive investigation switches

Notes stage to a separate private redacted draft after 500 ms of inactivity.
The status distinguishes an unacknowledged draft, durable draft, committed notes
and conflict. **Save notes** commits; **Resolve/Reopen** also commits the current
text. An incident switch or explicit Close/Escape waits for outstanding local
text to be acknowledged before leaving. Native outside-click/unload flushes are
best effort: verify acknowledgement before deliberate shell restart or disable.

An editor changing the same incident or draft cannot silently overwrite yours.
**Review latest** displays committed notes, the saved draft, and your local text.
Explicitly keep your text on the reviewed revision or use committed notes.
**Discard draft** is confirmed and version-checked. Do not assume unsent text is
safe after a process crash or storage failure. One bounded draft per incident;
conflicting editors must reconcile deliberately.

Detailed exports are disabled while local notes are uncommitted. Metadata-only
exports never include those notes. **Inspect** beside a pin opens the saved copy
with its exact source/boot/monotonic identity even after ordinary history expiry.
Export previews are routed to their requesting cockpit; a newer preview still
invalidates the helper's previous single-use token, including in another panel.

The Timeline now requests its own bounded history pages, independent of other
open cockpits. The interval is applied before the page limit. **Older/Newer**
traverse matches; Older freezes the interval and receipt membership. **Interval**
arrows move the time range. **Jump** accepts a real ISO timestamp with an explicit
`Z` or UTC offset (for example `2026-09-07T08:00:00-10:00`), avoiding ambiguous
local times. A bookmark's **Context** opens a centered historical
interval. The existing **Live** header control returns to the present.

The density strip counts every matching retained event in the interval; the
lanes and list show only the loaded page (200 rows normally). Tab and arrow keys
expose density counts without relying on color. Changed retention is explicitly
qualified: a frozen receipt ceiling is not an immutable evidence archive.
Pin important events to an incident to retain copies.

**Views** offers All evidence, Errors, Audio and Network presets, plus up to 20
named durable filters. It saves search, source/category/severity and window
length, not the page or historical anchor. Saved labels/search are redacted:
review restored text if a search looked like a secret.
