# Chronicle: operator implementation plan

## Contract and working environment

- Repository: https://github.com/nshkrdotcom/omarchy-chronicle
- Checkout: `/home/home/src/omarchy-chronicle`.
- Feature branch: `feat/chronicle-operator-cockpit`; commit and push milestones.
- Identity: `nshkr.chronicle`; MIT, Copyright (c) 2026 nshkrdotcom.
- No installation, symlink into plugin directories, enabling, shell IPC,
  desktop restart, configuration writes, or live graphical acceptance yet.
  Another agent owns ongoing installed Omarchy work.
- Tests use temporary state, fixtures and offscreen Qt. Read-only inspection of
  packaged shell imports and Tactical Display is allowed. No changes to them.
- GitHub has 20 topics; `nshkr-omarchy` was last in the submitted topic list.
  GitHub alphabetizes returned/displayed topics; arbitrary order is not retained.

## Research and architectural decisions

1. [Omarchy shell plugins](https://omarchy.org/manual/shell-plugins/): service
   plus bar-widget, native Panel/KeyboardPanel, own service lookup. No new
   fullscreen overlay. Entry points are Items, not a second ShellRoot.
   Installed `/usr/share/omarchy/shell/README.md`, Ui components, and Tactical
   Display `Panel.qml`, `core/TacticalDisplayShell.qml`, `core/ThemeAdapter.qml`
   were inspected read-only on 2026-09-07. Keep the native title at
   `Style.font.subtitle`, DemiBold, 0.4 letter spacing; body/caption use native
   tokens, header actions stay right-aligned. Popup padding is `Style.space(8)`;
   target geometry is 1280×840, constrained by native screen fitting.
2. [journalctl](https://www.freedesktop.org/software/systemd/man/255/journalctl.html)
   and [journal fields](https://github.com/systemd/systemd/blob/main/man/systemd.journal-fields.xml):
   parse structured JSON, treat cursors as opaque identities, retain boot and
   monotonic timestamps. Read only accessible records. Journal permission and
   retention are not controlled by Chronicle. A missing message is not success.
   Bound command runtime and output, expose truncation and cursor invalidation.
3. [SQLite WAL](https://www.sqlite.org/wal.html) and
   [isolation](https://www.sqlite.org/isolation.html): one helper owns writes;
   durable transactions, schema versioning, busy timeout, bounded rows and page
   budget, private state directory. Cursor and events commit together. A second
   recorder must not concurrently ingest the same database.
4. [Linux PSI](https://docs.kernel.org/accounting/psi.html): pressure is time
   stalled, not utilization. Display qualified units and actual samples with
   gaps, never interpolate missing values as zero. Reading /proc does not need
   a privileged agent. Sample only scalar pressure/memory values, not commands.
5. [XDG base directories](https://specifications.freedesktop.org/basedir-spec/latest/):
   persistent local state belongs in `$XDG_STATE_HOME/nshkr.chronicle` or
   `~/.local/state/nshkr.chronicle`; temporary test state is explicitly supplied.

## Product scope

### A. Recorder and evidence integrity

Python standard-library helper; line-delimited JSON control channel. Bounded
user-journal batches, opt-in accessible system journal, cursor resume, durable
deduplication, exact source/boot/realtime/monotonic provenance. Classify service,
desktop, network, audio, power, and resource evidence conservatively, retaining
original source identity. Classifications are navigation labels, not diagnoses.
Periodic PSI and available-memory snapshots, recorder lifecycle/gap evidence,
explicit pause/resume. Reading continues when the panel is closed. Pausing
recording is distinct from freezing the investigation view.

Source status explains disabled, healthy, degraded, no accessible records,
timeout, truncated batch, unsupported data and freshness. No root requests,
automatic repairs, service restarts, packet capture, clipboard capture, process
command-line capture, arbitrary shell execution, or general filesystem crawler.

### B. Investigation cockpit

Native header and persistent right action rail. Timeline/category lanes with
severity shapes/colors, exact event selection, zoom windows, keyboard movement,
search, severity/source filters, explicit empty and stale states, source details.
Stable selected identity and scroll when recording updates arrive. Freeze locks
the visible evidence set without stopping collection; return-live is explicit.
Inspector displays evidence and cautions, never an invented root cause.

### C. Bookmarks and comparisons

Mark this moment with a bounded label and scalar snapshot. Durable bookmarks;
select exact A/B bookmarks, report time interval and only comparable numeric
fields, with units and missing-data qualification. No reconstructed state before
recording began and no extrapolated claims across missing samples.

### D. Incident workspaces

Create named incidents; save copied event evidence so normal recorder retention
does not silently destroy an investigation. Pin/unpin evidence, edit bounded
notes, close/reopen incidents. Saved incidents are independently capped; reaching
the cap requires explicit operator cleanup instead of silent eviction. Historical
inspection never controls the observed machine.

### E. Private evidence sharing

Allowlisted persisted fields, ingestion redaction for common secrets, paths,
addresses and control characters. Redaction is best-effort, not a secret detector.
Export defaults to structured metadata without journal messages or notes; opt-in
detail has a full text preview. Preview generates an immutable expiring token;
confirmation exports exactly the reviewed bytes to a private, unique local file.
No upload or clipboard copy. File size and export count capped; no overwritten
paths or arbitrary destination supplied by the UI.

### F. Refinement and delivery

Accessible named controls, visible keyboard focus, plain-text rendering of all
untrusted strings, scale-aware native font tokens, bounded virtualized lists,
lightweight canvas lanes and resource traces. No AI raster assets needed: these
are precise code-native data graphics. Operational documentation, source support
matrix, threat model, protocol, troubleshooting, release gate, and CI included.

## TDD sequence and acceptance

1. Commit plan/license/repository foundation.
2. RED: normalization, redaction, provenance, duplicate handling, retention,
   bookmarks, incidents, exact exports, filesystem security. GREEN: core modules.
3. RED: bounded subprocess adapter, cursor rollback/failure, pressure parser,
   daemon protocol, malformed/oversized input, pause, persistence, shutdown.
   GREEN: recorder and service transport; all tests use isolated state.
4. RED: pure JS filter/selection/buckets/gaps/comparison and Qt interaction/
   native typography contracts. GREEN: cockpit, bar widget, native host/service.
5. Iterate with regression tests: privacy, load, restart, rejected inputs,
   offscreen sizes/scales, fixture screenshots, packaged-import lint, CI.
6. Commit/push green milestones. Document exact test evidence and limitations.

Expected commands: `make test`, `make test-qml`, `make lint`, `make check`,
`make demo`. No target installs, reloads, or enables Chronicle.

### Installed gate — intentionally deferred, never reported as passed

After the operator releases the shared desktop for testing: validate manifest
with the host CLI, explicit install/enable approval, real click vs shortcut
appearance comparison, keyboard/outside dismissal, popup coordinator switching,
all bar positions, real themes and fractional scale, monitor hotplug, service
survival across close/open, clean disable, 50 cycles, 10-minute CPU/RSS/FD soak.
Do not edit installed files during a soak. Capture failure evidence before any
cleanup; passing retries do not erase earlier failures.

## Completion definition

All implemented milestones have passing isolated tests, committed/pushed code,
documented limitations, and a runnable fixture demonstration. Installed native
acceptance remains a separate release gate, not a reason to change the current
desktop or pretend this environment proves Wayland behavior.

## Build status after implementation

The recorder, cockpit, three pressure lenses, source filters, bookmarks with
measurement-age provenance, readable A/B comparison, durable incident workspaces,
notes, pinned evidence and exact-preview export are implemented. The full service
transport also runs in isolated windowless Quickshell against synthetic Python
state. Source failures and gap qualifications are covered by regression tests;
gap markers commit atomically with accepted events and cursor advancement.

The UI follows the inspected Omarchy/Tactical Display conventions. Offscreen
tests cover title sizing, header placement, caption changes, keyboard behavior,
identity stability, and frozen-chart theme repaint. Actual installed appearance
comparison remains pending. See TESTING.md for evidence and RELEASE-GATE.md for
the coordinated native matrix; neither is replaced by a synthetic soak.
