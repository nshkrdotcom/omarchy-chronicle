# Chronicle — complete investigation workflow improvement plan

Date: 2026-09-07 (Hawaii). Repository: `/home/home/src/omarchy-chronicle`.
Remote: https://github.com/nshkrdotcom/omarchy-chronicle .
Branch: `feat/chronicle-operator-cockpit`; starting revision: `4fdbf08`.

## Outcome and non-negotiable boundaries

Make Chronicle substantially better at answering “what happened around this
moment?” and preserving a human's investigation. Complete the implementation,
test it in isolation, commit/push coherent milestones, and hand off the installed
acceptance work. Do not install, enable, reload or modify the running desktop.
Another agent owns installed Omarchy work. Installation requires later explicit
operator coordination. Isolated tests cannot establish native visual polish.

Preserve the clicked Tactical Display panel's native conventions: `Ui.Panel`,
`Ui.KeyboardPanel`, subtitle font token, DemiBold title, existing top-right
Search / Freeze-Live / Mark / Close rail, native padding and size bounds. No
overlay, replacement typography, new title scaling or movement of that rail.
All new investigation controls belong below the existing header.

## Findings from the current implementation

1. `Recorder.query` is global. Every open cockpit consumes the same filtered
   snapshot, so one panel can change another panel's available events.
2. Only the newest 500 matches reach the UI; the time window is then applied
   locally. Older matching evidence can be retained but unreachable. There is
   no arbitrary historical anchor, page navigation or bookmark-to-timeline jump.
3. Event retention orders by source wall time. Future-dated records can crowd
   out newly received evidence, including recorder gap warnings. Source clocks
   should not decide receipt order. Source timestamps must remain unmodified.
4. Event lanes show only loaded rows, without a full-interval density summary.
   Operators cannot distinguish “no match,” “not loaded,” and “not retained.”
5. Common investigations require rebuilding filters each time. There are no
   durable named views or quick error/audio/network presets.
6. Incident responses can replace note text; switching incidents resets it.
   Saving has no expected revision, and there is no durable separate draft.
   A concurrent edit can overwrite human work. Saved evidence copies cannot be
   inspected as deeply as live timeline rows.
7. Existing tests prove foundations, not these workflows. Make's auxiliary
   targets are not all phony. Installed acceptance remains intentionally pending.

## Research and resulting design decisions

- [SQLite row-value scrolling queries](https://www.sqlite.org/rowvalue.html):
  use `(time_us,id)` keyset paging with an aligned index instead of OFFSET.
  Add a persistent sequence ceiling so later arrivals do not slip into a frozen
  page set. Retention can still remove rows; disclose that explicitly.
- [SQLite transactions](https://www.sqlite.org/lang_transaction.html) and
  [isolation](https://www.sqlite.org/isolation.html): migrate atomically and use
  compare-and-save revisions under a write transaction. Preserve existing state
  on errors; no destructive schema reset or silent conflict resolution.
- [Qt Quick performance guidance](https://doc.qt.io/qt-6/qtquick-performance.html):
  keep large lists virtualized and models limited, coalesce queries, avoid
  repeatedly transferring the entire retained history or unlimited QML objects.
- [Omarchy shell plugin manual](https://omarchy.org/manual/shell-plugins/) and
  packaged native components: keep the existing service/bar-widget contract and
  native panel shell. Kept service code may require a coordinated shell restart;
  live hot-reload is not an adequate installation verification strategy.

The application-specific decisions below are engineering inferences from those
mechanisms, not claims that the upstream projects prescribe Chronicle's UI.

## Implementation tranche A — trustworthy history engine

### Features

- Atomic schema v1→v2 migration: durable AUTOINCREMENT receipt sequence and
  receipt timestamp on events. Keep IDs, payloads, source cursors, bookmarks,
  incidents and settings. Migrated receipt times are estimates, explicitly
  qualified; source timestamps remain exact recorded provenance.
- Count retention by receipt order, age retention by receipt timestamp. Prune
  age when a poll/ingest runs. Limited rows remain the hard protection against
  backwards wall-clock movement; elapsed wall age is not a monotonic guarantee.
- Stateless `history` command with literal casefold search, validated exact
  source/category/severity filters, inclusive time bounds, limit 1..500,
  stable `(time_us,id)` continuation and receipt ceiling.
- Return exact matching count, remaining-page indicator, retained time range,
  retention generation, and fixed 48-bin info/warning/error density across the
  whole requested interval. A changed retention generation warns of possible
  loss between pages; it does not fabricate missing events.
- No long-lived SQLite read transaction held while a human investigates. No
  write to the observed system, arbitrary SQL, shell expressions or new sources.

### TDD order / acceptance

RED tests for >500 records with an older time window; equal-time page ties;
new/backdated arrivals excluded by ceiling; deletion between pages; literal `%`,
Unicode search; all invalid protocol types/bounds; schema migration and state
preservation; future source timestamps cannot evict fresh receipt; rollback.
GREEN implement the smallest storage/query layer and protocol additions.
Refactor shared validation and predicates, then run all existing Python tests.
Commit and push a complete tested storage milestone, not failing tests alone.

## Implementation tranche B — human-paced exploration

### Features

- Per-cockpit request correlation: history results delivered to the requesting
  cockpit only, stale query responses ignored, one in-flight history request
  per cockpit, coalesced live refresh. Closing panels stops view queries, not
  collection. A backend restart clears page cursors and labels the refresh.
- Current/frozen interval controls, older/newer page buttons, preceding/following
  interval navigation, explicit local timestamp range label, bookmark Context
  action centered on the mark. Live is the existing header control.
- Density overview for the full matching interval, separately labeled loaded
  event lanes. Severity shapes/color are redundant; keyboard-focusable density
  inspection and textual counts supplement the graphic. No implied causality.
- Quick triage presets and up to 20 durable named filter views (label, literal
  search, exact filters, window length). Do not persist transient page cursors.
  Validate/redact saved text before persistence; removal is explicitly invoked.
- Preserve exact selection across refreshes; never substitute a different event.

### TDD order / acceptance

RED storage/protocol tests for saved-view bounds, validation and restart.
RED Qt/JS tests for per-owner replies, stale replies, live/frozen behavior,
page navigation, arbitrary anchors, bookmark context, query reset, saved views,
limited density rendering, title/font/rail regression at compact/full widths.
GREEN implement isolated reusable investigation model helpers and controls.
Test 1× and 1.5×, render fixtures and inspect actual images. Run native-import
lint and real offscreen Quickshell↔Python transport. Commit/push this milestone.

## Implementation tranche C — protect investigation work

### Features

- Incident revisions; note/status edits require the expected revision in the
  public protocol. Stale save fails visibly and preserves both stored notes and
  the operator's text. Pin/unpin changes also advance revisions.
- Separate limited redacted durable draft per incident. Stage on idle and
  navigation/close/destruction; keep local text until an acknowledgement arrives.
  “Draft saved” is not “notes committed.” No promise of keystroke-level crash
  persistence before acknowledgement. Storage/transport errors remain visible.
- Restore drafts on incident reopen; explicit Save notes commits a matching
  revision, explicit Discard draft returns to stored notes. Conflict recovery
  requires an explicit reload/review, never a blind automatic overwrite.
- Exports include committed notes only. Disable detail preview while there is
  an unresolved local draft; explain the distinction. Drafts never leak into
  metadata exports. Removal cleans up only the explicitly selected incident.
- Inspect saved pinned evidence, including source/boot/monotonic identity even
  when the original event has expired, with a separate read-only dialog.

### TDD order / acceptance

RED tests for two editors, revision conflicts, pin-during-edit, draft restart,
redaction, size/incident bounds, deletion cleanup, exact-export isolation.
RED Qt tests for switch/close staging, late responses, text preservation on
pin, explicit discard, stale-save recovery and saved-copy provenance display.
GREEN implement persistence and safe UI state transitions; regression-check
existing export and incident flows. Extend real transport harness to cover
history, saved views, draft→commit→export. Commit/push tested milestone.

## Final hardening and evidence

- Run Python + Node + Qt + native-import lint, fractional Qt, four-page fixture
  screenshots, real transport integration, and corrected 60s/50-cycle helper
  soak. Keep failure evidence and numerical metrics; a later pass does not
  explain away a prior failure. Inspect exact pushed commit's GitHub CI.
- Document protocol, schema/retention changes, workflows, limits and migration
  rollback constraints in the repository; keep this plan and a final report in
  this Documents directory. Commit a repository companion plan for provenance.
- Fix in-scope regressions discovered by these checks with another RED/GREEN
  cycle. Do not add dependencies or unrelated desktop mutations to hide gaps.

## Deferred work and explicit non-goals

Actual install/enable, native monitor/bar/theme matrices, keyboard/compositor
lifecycle, real human workflow review and native long soak belong to the HITL
handoff. No automatic repairs, AI diagnosis, clipboard tracking, config watchers,
network uploads, invented source-health claims or remote synchronization.
Longer-term opportunities: user-approved source adapters, time-range evidence
bundles, multi-incident comparison, signed export manifests, and richer unit
grouping. These require separate design/consent and are not acceptance criteria
for this implementation tranche.

## Completion gate

All planned tranche features implemented and isolated tests green; coherent
commits pushed; final evidence/restrictions recorded; installation/HITL handoff
written here with prerequisites, read-only preflight, explicit approval gate,
manual acceptance cases, failure capture, safe rollback and continuation loop.
“Ready for coordinated installed acceptance” is the truthful outcome, not
“100% polished” before that acceptance has occurred.

## Execution result

All three implementation tranches are complete and pushed. Additional TDD
hardening addressed live density/axis alignment, migration failure rollback,
unambiguous direct ISO time jumps and Unicode escape expansion at the persistence
boundary. The user's follow-up requested a full titlebar-free README preview;
`preview.png` is rendered from the real cockpit with synthetic evidence and
native-style test tokens, not generated artwork or an installed screenshot.

76 Python / 13 JS / 51 Qt cases pass; fractional Qt, native import resolution,
official read-only manifest validation and real windowless controller transport
pass. Final production checkpoint is `9e9e417`; final helper-only soak is 60.10s,
50 panel-state cycles, 23,156 KiB peak RSS, 8 baseline/final/max-ready FDs, zero
FD growth and 0.07 CPU seconds. Exact final CI/docs details are recorded in
`2026-09-07-completion-report.md` here.

Continuation is fully specified in `2026-09-07-installation-HITL-handoff.md`.
Installation, native compositor/monitor matrices and human polish acceptance
remain intentionally pending—not a hidden claim of completion for those gates.
