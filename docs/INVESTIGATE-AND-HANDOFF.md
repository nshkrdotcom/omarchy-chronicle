# Find an error and hand off the evidence

Use this workflow when something stopped working and you need to understand
what happened nearby, preserve useful observations and help another person
continue. Chronicle observes; it does not restart services or diagnose a cause.
Installation and native human acceptance remain deferred.

## Start with one useful event

1. Open **Timeline** and choose a time window. Search for a service or phrase.
2. Select an error or warning. Selection freezes your view, not recording.
3. Read the evidence pane: time, source, unit, boot and exact ID.
4. Choose **Surrounding events** to see what came before and after it.

The list and lanes show the loaded page. The density strip counts all matching
retained events in the interval. **Older/Newer** visits additional pages.
**Jump…** accepts an explicit timezone, such as `2026-09-07T08:00:00-10:00`.
**Live** returns to the present. Pin evidence you need to keep: a frozen view
does not stop history retention.

## Read the surroundings without losing your search

Context deliberately lifts search, exclusions, category and level filters.
An ERROR can therefore appear beside useful INFO messages. Your Timeline
filters are unchanged when you close the dialog.

- **Same unit + boot** matches the anchor's recorded source, unit and boot.
  It is not a process-ID filter; missing boot metadata weakens that distinction.
- **All sources** includes nearby retained evidence from other sources and units.
  Use it to investigate a possible desktop-wide interruption.
- **±2 min** cycles through two, ten and sixty minutes on each side.
- The chronological list includes the anchor exactly once and the nearest
  30 earlier and 30 later events. Counts disclose additional eligible rows.
- Select a row to inspect its full text and provenance. **Pin selected to
  incident** preserves that exact observation; if no incident is selected,
  **Create incident + pin selected** creates one. This opens the incident page.

For example, search for an audio error, select it, then open context. An INFO
message describing graph synchronization may help establish a sequence.
Switch to All sources to see nearby link or desktop events. Their proximity
is a lead to investigate, not proof that one caused the other.

Context inspection does not change source records. If the anchor expires,
Chronicle reports it instead of substituting a different event. An existing
incident pin remains available through **Inspect** on the Incidents page.

## Hide known noise temporarily

1. Choose **Filters** on Timeline.
2. Enter an **Exact unit**, or choose **Use selected**. Leave it empty for all.
3. Enter one phrase per line in the exclusion field, such as `health check`.
4. Choose **Apply filters**. The Filters button indicates active extra filters.

Up to eight phrases are supported, each at most 200 characters. An event is
hidden if its stored message or unit contains any phrase, ignoring case.
These are literal phrases: `%`, `*` and regex punctuation have no special meaning.
Exact-unit matching is case-sensitive and uses the stored unit text.

To undo these filters, open Filters and choose **Clear unit + exclusions**.
Search, level, category and source controls remain as they were. For a full
reset, open **Views → All evidence**. Nothing is erased from history or pins.

To reuse the combination, open **Views**, name it and choose **Save view**.
Views save all filters and window length, not your current historical position.
Saved text is redacted, so review restored phrases before relying on results.

## Find repeated messages and changes

Choose **Patterns** once the Timeline query finishes. Chronicle freezes the
accepted interval and compares it with the immediately preceding interval of
equal duration, using the same filters and receipt ceiling.

**Most repeated** ranks by current count. **Biggest changes** ranks by the
absolute change in count. Each row shows current count, previous count, signed
change, source, boot and first/last observation times. The paired bars use one
shared count scale: previous above, current below. Text carries the same values.
The dialog displays the highest-ranked 50 groups and tells you when more exist.
All matching retained events contribute to the totals, not only the loaded page.

| Result | What it means | What it does not establish |
|---|---|---|
| Newly observed | Matching stored text appears only in the current interval | The underlying fault began then |
| Not seen again | Matching stored text appears only in the previous interval | The fault has recovered |
| Increased/decreased | The observed count changed | A cause or a complete activity rate |
| Unchanged | The observed counts match | The system is healthy |

For example, 80 previous retries and 650 current retries produce a change of
**+570**. Choose **Context** on that group to inspect its exact latest retained
event. If the group occurs only in the previous interval, that representative
comes from the previous interval. You can pin a selected context row.

Groups use exact stored message, source, unit, boot, category and severity.
Messages with different variable values stay separate. Conversely, redaction
can make different original messages share stored text. No individual event
is merged or deleted by grouping.

Check the coverage note before drawing conclusions. It reports recorder
notices across both intervals regardless of your filters, plus the retained
source-time range. Gaps, pauses, retention and clock changes can affect counts.
No notices does not mean no missing history. An empty interval is not a health
verdict. Near the epoch, a request fails if an equal previous interval cannot fit.

## Write notes that another person can use

Create or select an incident. For empty notes, **Notes outline** inserts prompts
for impact, observed facts, hypotheses, actions/results and next steps. It never
overwrites existing text, and insertion is an unsaved edit, not a committed report.

Replace prompts with specifics: when audio stopped, the evidence IDs supporting
that observation, what you tried, what changed, and who should verify the result.
Keep hypotheses separate from confirmed facts. Avoid blame and unnecessary
personal information. Choose **Save notes** before sharing detailed evidence.

Notes stage to a private draft after 500 ms of inactivity. Wait for the durable
acknowledgement before intentionally stopping the shell. Explicit incident
switches and Close/Escape wait for staging; outside-click/unload is best effort.
If another editor changes the incident, **Review latest** shows committed notes,
the saved draft and your local text. Reconcile explicitly. Do not assume unsent
keystrokes survived a crash. Resolve/Reopen also commits the current notes.

## Create a readable handoff

1. On **Incidents**, choose **Markdown** in the format control. JSON remains
   available for tools that need structured data.
2. Start with **Metadata only**. Include messages and notes only if necessary.
3. Choose **Preview export**. Detailed export requires committed local notes.
4. Read the entire preview, including title, units and timestamps.
5. Confirm to save exactly those bytes. The status shows the private local path.

Markdown includes the incident status/revision, UTC times, coverage/privacy note,
committed notes when requested and chronologically ordered pinned evidence.
Operator/source content is literal text, so embedded HTML or image syntax is
not activated in a CommonMark renderer. Review it in your intended reader too.

Metadata mode excludes messages, notes, raw journal cursors and boot identifiers.
Remaining metadata can still be sensitive. Redaction is best effort, not a
guarantee of anonymity. Nothing is uploaded or copied to the clipboard.

Files are created in Chronicle's private state `exports` directory with unique
`.md` or `.json` names and owner-only permissions. There are at most 32 exports;
move old files deliberately when needed. A preview expires after five minutes
and is single-use. Creating another preview, even in another panel, invalidates
the previous token. Reopen Preview export if confirmation says it was replaced.

## Recover when a result is unavailable

| Situation | Next step |
|---|---|
| No matches | Clear extra filters or choose another interval; check Sources |
| Selected event expired | Inspect its saved pin, or select a new retained anchor |
| Request not sent | Check Sources/recorder availability, then Retry |
| Recorder restarted | Close and reopen the tool to query the new session |
| Comparison shows missing history | Record the limitation; do not infer recovery from zero |
| Notes conflict | Review all versions before keeping or discarding text |
| Export expired/replaced | Generate and review a fresh preview |
| Storage cannot be written | Preserve existing state; check free space and capacities |

Chronicle never repairs the host or resets the database automatically. If state
is unsupported or unreadable, preserve it and follow the coordinated handoff.
Do not copy only an active SQLite main file while its WAL is being written.

## Keyboard and terms

On Timeline, `/` focuses search, Space toggles freeze/live, arrows select events,
Ctrl+M marks a current observation and Tab visits controls. Text inputs consume
normal typing. In dialogs, Tab visits controls and Escape dismisses the dialog.

An **anchor** is the exact event whose surroundings you opened. A **receipt
ceiling** excludes events arriving after the query started; it does not prevent
retention deletion. A **pin** is an incident-owned copy that survives ordinary
history retention. **PSI** measures time tasks were stalled, not utilization.

See [source coverage and privacy](PRIVACY-AND-SOURCES.md),
[protocol details](PROTOCOL.md) and [continuation](COMMUNITY-HANDOFF.md).
