# Recorder protocol v1

Launch `python3 bin/chronicle` from any directory. `--state-dir` changes only
Chronicle's state location. `--demo` requires an explicit state directory and
never reads host sources. `--once` performs one collection, emits a closed-panel
snapshot, then exits. Stdin EOF, SIGTERM, SIGINT or `shutdown` ends the helper.

Input and output are one JSON object per line. Stdout contains protocol only.
Input lines are limited to 16 KiB. Invalid, oversized and deeply nested commands
produce a safe error and do not authorize arbitrary execution.

```json
{"cmd":"panel","open":true,"request_id":"request-1"}
{"cmd":"bookmark","label":"Before change","request_id":"request-2"}
{"cmd":"query","search":"worker","source":"user-journal","severity":"error","category":"all","limit":500,"request_id":"request-3"}
```

Successful commands emit `{"type":"result","request_id":"…","cmd":"…",
"ok":true,"result":{…}}`, followed by an updated snapshot (except shutdown).
Errors carry `type:error`, an optional request ID and a safe operator message.
Request IDs are strings of at most 100 characters. Commands without a valid ID
still execute, but cannot be correlated by the UI.

Snapshots contain protocol/session identity, realtime microseconds, source
statuses, pause/demo flags, scalar values, storage error qualification, total
event count, bookmarks and incident summaries. Event and sample arrays are
sent only while a panel is open. Closing a panel does not pause collection.
The service tracks multiple panel owners so closing one does not declare all
panels closed. The helper has one active live query, shared by its consumers.

| Command | Arguments | Result / effect |
| --- | --- | --- |
| `panel` | `open: bool` | Select full or summary snapshots |
| `query` | `search`, `severity`, `category`, `source`, `limit: 1..500` | Persist active live query in helper memory |
| `refresh` | none | Attempt collection; pause remains respected |
| `pause` | `paused: bool` | Persist pause state and lifecycle evidence |
| `system_journal` | `enabled: bool` | Persist accessible-system-journal opt-in |
| `bookmark` | `label` | Current collected scalar snapshot, not supplied metrics |
| `remove_bookmark` | `id` | Remove exact saved bookmark |
| `compare` | `a`, `b` bookmark IDs | Signed comparable deltas, missing fields, units |
| `create_incident` | `title` | New durable incident |
| `incident` | `id` | Full saved incident |
| `update_incident` | `id`, `notes`, `status: open/closed` | Save notes/status |
| `pin` / `unpin` | `id`, `event_id` | Add/remove exact saved evidence copy |
| `remove_incident` | `id`, `confirm: true` | Explicit permanent logical removal |
| `preview_export` | `id`, `detail: bool` | Exact JSON text, token, SHA-256, expiry |
| `confirm_export` | `token` | Write exact reviewed bytes; return path/hash |
| `shutdown` | none | Graceful stop |

The QML controller correlates results with limited pending jobs, drops
uncorrelated responses, invalidates pending/preview state on helper session
change and uses limited restart backoff. A lost acknowledgement is **not**
proof that an action failed; refresh state before repeating it. Do not blindly
retry create/bookmark operations, which can already have committed.

The transport is local parent-child stdio, not a network server or public
shell IPC API. Unknown commands are rejected. No command accepts a shell
program, service-management operation or arbitrary export destination.
# Historical investigation requests (additive protocol 1)

## Revision-checked incident editing

Incident reads/mutations return `revision` (legacy bodies default to 1) and
`draft` (null or notes/base_revision/token/updated_us). Notes/status mutation
`update_incident` now requires `expected_revision` and accepts `draft_token`
(empty means no acknowledged draft). Pin/unpin advance incident revision.
`stage_draft` requires `id`, `notes` (4096 max), `base_revision`, `draft_token`.
It checks the current draft token, writes a redacted replacement with a fresh
token, and does not change committed notes. One draft per existing incident;
there can be at most 128. `discard_draft` checks the exact token and returns
the current incident. A successful note commit clears only the checked draft.
Conflict responses have `code: conflict` and a fixed safe explanation; arbitrary
input, database errors and secret-bearing values are not echoed.

Clients must not silently retry conflicting writes with a newer revision/token.
Present committed notes, saved draft and local text for explicit review first.
Exports use committed notes only. Acknowledged drafts survive helper restart;
unacknowledged keystrokes are not promised crash durability.

`save_view`: `label` (100 characters), filters as below and `window_minutes`
1..10080. Returns a durable view with generated ID; at most 20. `remove_view`:
exact `id`. Snapshots include `saved_views`. Labels/search are redacted before
persistence; transient cursor/anchor/ceiling fields are not stored.

`history`: `from_us`/`to_us` inclusive, nonnegative JSON-safe integers;
`limit` 1..500 (default 200); optional literal `search` (200 characters),
`severity`, `category`, `source`. Returns `events`, `matching_count`, 48 density
bins (`count`, `errors`, `warnings`), retained source-time bounds, `ceiling`,
`next` and `retention_generation`. Continue with the same filters/range/ceiling
and `before: next`. Equal timestamps are disambiguated by exact event ID.
This request is stateless and does not change the legacy global live query.
Later arrivals, even backdated ones, are excluded by the receipt ceiling.
Retention can remove earlier results; compare retention generations and warn.
Counts/density describe matching retained evidence, not source completeness.

Schema 2 migrates schema 1 transactionally, preserving existing records and
cursors. Events receive an AUTOINCREMENT sequence and receipt time; legacy
receipt times are migration-time estimates (`receipt_age_estimated`). Count
retention uses receipt sequence, age retention uses receipt wall time. Source
wall time/boot/monotonic fields remain unchanged. Backwards receipt-clock changes
can extend age retention; the hard event-count cap still applies. Older builds
refuse schema 2 rather than resetting it. Back up private state before upgrading
an installed recorder; do not run old and new helpers against one state directory.

## Inspect surroundings and recurring events

History and saved-view filters also accept `unit` (exact stored unit, at most
160 characters, empty for all) and `exclude` (up to eight nonempty literal
terms, each at most 200 characters). Any excluded term in message or unit
hides that event from the result; nothing is deleted. Search and exclusions
use Unicode case-folding, with no regex or wildcard syntax. Saved text is
redacted before storage, so review restored filters.

```json
{"cmd":"context","id":"EXACT_EVENT_ID","scope":"unit","radius_seconds":120,"limit":30}
{"cmd":"analyze","from_us":1800000000000000,"to_us":1800000299999999,"unit":"pipewire.service","exclude":["health check"],"sort":"change","limit":50}
```

Replace `EXACT_EVENT_ID` with a retained 32-character ID. Context accepts
`scope: unit|all`, radius 1–3600 seconds, 1–100 neighbors per side and an optional
receipt `ceiling`. Default unit scope matches source/unit/boot, not PID.
Text, category and level filters do not carry over. The anchor is always included;
neighbors are the closest by `(time_us,id)`, shown chronologically. Results give
eligible and shown counts per side, `truncated`, `retained` and the receipt ceiling.
An expired anchor returns an error, never a replacement.

Analysis accepts the history interval/filters/ceiling, `sort: repeat|change`
and limit 1–100 (default 50), but no page cursor. Previous range ends one
microsecond before `from_us` and has the same inclusive duration. A range too
close to the epoch returns a useful error instead of comparing unequal periods.
Every matching retained row contributes, including rows beyond history page one.

Groups use exact stored source/unit/boot/category/severity/message. Each returns
current/previous counts, signed `delta`, state, current and previous first/last
times, and an exact latest representative `event_id`. Results include both
intervals, filters, group/event totals, omitted-group indication, retention
generation and recorder notices counted independently of filters. Notice-free
history still does not establish completeness. No observations are deduplicated
by these queries; redaction can make distinct raw messages share stored text.

## Preview a portable report

`preview_export` accepts `format: json|markdown` (default JSON). Both formats use
the same metadata-only default, optional `detail: true`, exact-byte preview,
single-use five-minute token and 2 MiB maximum. The format and extension are
bound to that token. Confirmation writes a private `.json` or `.md` file and
returns its path and SHA-256. A new preview invalidates the previous one across
all panels. The current incident revision is included; only committed notes
are eligible. Markdown user content is indented literal text, not executable
HTML, image syntax or links. No report is uploaded or copied to the clipboard.
