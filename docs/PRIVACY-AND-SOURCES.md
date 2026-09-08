# Source coverage, data lifetime and threat model

## Source matrix

| Source | Default | What is recorded | Important limits |
| --- | --- | --- | --- |
| User journal | On | Allowlisted structured records readable by this user | Journal access/retention determine coverage |
| System journal | Off | Same allowlist, accessible system records after opt-in | Never asks for elevated access |
| CPU/memory/I/O PSI | On | `some avg10`, percentage of time stalled | Unsupported/missing fields are null |
| Memory availability | On | `MemAvailable`, KiB | Observation, not a capacity forecast |
| Recorder lifecycle | On | Startup, pause/resume and continuity qualifications | Does not recover history that no longer exists |
| Network/audio/power/desktop | Journal-derived | Records classified by source unit/identifier | Not independent D-Bus device/config watchers |
| Bookmarks/incidents | Explicit operator action | Limited labels, scalar observations, notes and pinned copies | Can contain sensitive context |

No source reads clipboard data, packet payloads, process command lines,
application windows, screenshots, arbitrary files, or shell history. No
mutating system command or automatic repair path exists.

Journal reads are argv-only subprocesses with a two-second deadline and a
2-MiB combined output budget per attempt. At most 200 records are accepted
from a limited 201-record tail. An expired/unreadable cursor can trigger one
limited five-minute fallback; the discontinuity is reported. A high-volume
journal can exceed the batch size: this is a qualified flight recorder, not
an exhaustive audit facility. Cursors are opaque and committed with events.

## Stored fields

Journal events retain: generated event ID, opaque cursor, realtime and
monotonic microseconds, boot ID, source, limited/redacted unit or identifier,
category, severity, and limited/redacted message. Other journal fields are
discarded. SQLite, not the source journal, holds Chronicle's copies.

The redactor covers common credential assignments, bearer/basic credentials,
URLs, home-directory paths, email and IP patterns, private-key blocks, ANSI
escapes and dangerous directional/control characters. Unknown secret formats,
project names, arbitrary quoted content and identifiers may remain. All QML
text is plain text, never treated as rich text or a command.

## Bounds

| Resource | Bound |
| --- | --- |
| Normal journal/lifecycle history | 10,000 events by receipt sequence; seven-day receipt-wall-age cutoff |
| Resource observations | 720 samples, nominal five-second collection cadence |
| Bookmarks | 256, explicit deletion at capacity |
| Incidents | 128, explicit deletion at capacity |
| Separate incident drafts | One per incident, 4096 characters, redacted and version-checked |
| Named views | 20, labels 100 and literal search 200 characters |
| Saved evidence per incident | 64 copies |
| Message / unit / title / notes | 2048 / 160 / 100 / 4096 characters |
| Database | 8192 SQLite pages (32 MiB at the created 4-KiB page size) |
| History query result | 200 default / 500 maximum per page; time bounds before limit; stable keyset continuation |
| Density summary | 48 bins over all matching retained events in the requested interval |
| Pending UI requests | 32; 30-second acknowledgement timeout |
| Export preview | One, five-minute lifetime, 2-MiB byte limit |
| Export files | 32, unique names, no automatic overwrite |
| Control line | 16 KiB; oversized lines discarded through newline |

These are ceilings, not independent guaranteed capacities: large incidents
can reach the shared database page budget before their count limits. The WAL
and shared-memory sidecars add space beyond the database page budget.
`journal_size_limit` is a checkpoint limit, not a hard cap on active WAL size.
Only one recorder owns a state directory, guarded with a nonblocking file lock.

Schema 2 uses receipt sequence for count retention, so source clock errors cannot
crowd out newly collected rows. Legacy receipt times are migration-time estimates.
Receipt wall-clock rollback can extend the age cutoff; the hard count limit
continues to apply. Source wall/boot/monotonic provenance is not rewritten.
Historical page ceilings exclude later arrivals but cannot prevent retention
deletion. A retention generation change warns the operator rather than claiming
an immutable snapshot or continuous source coverage.

Default persistent state follows the XDG state specification; relative XDG
roots are ignored. The selected state directory must be owned by the current
user and private (0700). Existing shared permissions are rejected rather than
silently altered. Database/export files are 0600; final-path symlinks and
unsafe database links are rejected. State belongs on a local filesystem with
working SQLite locking and fsync, not an untested network-mounted home.

## Trust boundaries and exclusions

Omarchy plugins run as ordinary user code, not in a security sandbox. These
controls minimize collection and mistakes; they do not defend against root,
another malicious process running as the same user, a compromised Python/Qt
runtime, a malicious filesystem owner, or tampered source logs. Evidence is
not cryptographically authenticated and is not a forensic chain of custody.

Export hashes describe bytes, not source authenticity. Export has no network
path. Metadata can still reveal service names and activity times. Test and
preview assets use synthetic data only; CI never receives real journal data.

Deletion is logical cleanup, not secure erasure. Saved copies are intentionally
independent of ordinary retention. Pause/disable does not purge prior data.
Disk corruption and future unsupported schemas fail explicitly; there is no
automatic destructive repair or downgrade.
