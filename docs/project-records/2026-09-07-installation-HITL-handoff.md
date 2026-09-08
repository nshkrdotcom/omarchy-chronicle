# Chronicle — installation, HITL verification and polish handoff

Prepared 2026-09-07, Pacific/Honolulu. **Not installed or natively accepted.**
This document is a continuation plan, not permission to change the desktop.

## Start here

Project: `/home/home/src/omarchy-chronicle`.
Remote: https://github.com/nshkrdotcom/omarchy-chronicle .
Plugin: `nshkr.chronicle`, version `0.1.0`, MIT © 2026 nshkrdotcom.
Branch: `feat/chronicle-operator-cockpit` (also the current remote default).
Tested production checkpoint: `9e9e4174a15574d220ffec934cfe4cd6a67876bd`.
Read the completion report in this directory for final documentation/CI revisions.

Read before working:

1. `2026-09-07-operator-investigation-plan.md` in this directory.
2. Repository README, `docs/PROTOCOL.md`, `docs/OPERATOR-GUIDE.md`,
   `docs/PRIVACY-AND-SOURCES.md`, `docs/TESTING.md`, `docs/RELEASE-GATE.md`.
3. Current applicable AGENTS instructions and the Omarchy skill, including its
   plugin guidance. Read the capture guidance before actual desktop screenshots.
4. Read the installed Omarchy source/command implementation again if versions
   changed; do not assume a remembered IPC or installer flag is supported.

## What was delivered

- Schema v2: atomic event migration, monotonic receipt sequence, receipt-based
  retention, original source wall/boot/monotonic provenance preserved. Legacy
  receipt age explicitly estimated. Failed migration rolls event schema back.
- Complete time-filtered history paging, equal-time identity tie-breaking,
  receipt ceilings, retention-generation warnings and full-interval density.
- Per-cockpit requests and stale-response rejection; arbitrary unambiguous ISO
  time jumps, interval/page navigation, centered bookmark context, quick triage
  and 20 durable named views. No global-query cross-contamination of the UI.
- Incident revisions, one private redacted draft per incident, acknowledged
  navigation/Close, explicit conflict review, version-checked discard, and
  committed-only exports. Saved pins have a full provenance inspector.
- JSON-escaped Unicode evidence is limited before persistence. Oversized text
  is visibly shortened; unpersistable identity is a gap, not a recorder exit.
- `preview.png`: full 1280×840 synthetic client-area rendering with no OS
  titlebar. Linked near the top of README like Tactical Display. `make preview`
  reproduces it; it is not an installed screenshot or a fake live dashboard.

## Invariants the next agent must preserve

- The clicked Tactical Display panel is the visual reference. Keep Chronicle's
  title at `Style.font.subtitle`, DemiBold, 0.4 letter spacing. Keep existing
  top-right Search / Freeze-Live / Mark / Close buttons in that rail. No overlay
  font profile, enlarged heading, moved header buttons or desktop-wide scaling.
- Use native `Ui.Panel`/`Ui.KeyboardPanel`, `Style`/`Color.popups`, 8-unit padding,
  fitted 1280 / capped 840 content targets. New controls stay below the header.
- No automatic repairs, privileged commands, uploads, clipboard capture or new
  source adapters. Network/audio/etc lanes are journal classifications, not
  independent device monitors or causality claims.
- All development remains in `~/src/omarchy-chronicle`; never edit an active
  installed source tree or symlink a changing checkout into the watched plugin
  directory. Preserve other agents' files and the user's evidence/settings.
- TDD for every new behavioral fix: reproduce RED, make GREEN, refactor, run
  proportionate regression checks, commit, push, verify exact revision CI.

## Evidence already available and limits

The final local suite has 76 Python tests, 13 Node tests and 51 Qt cases
(including lifecycle cases). Qt passes at 1×/1.5×. Native-import lint resolves
the real packaged imports; 118 known host/dynamic-type advisories are retained,
not misrepresented as warning-free static typing. The official read-only
`omarchy plugin validate` succeeds against the source checkout.

Real **windowless**, isolated-XDG Quickshell transport passed history paging,
bookmark, incident creation/pin, draft staging, revision-checked commit, saved
view, metadata preview/export and clean shutdown. No installed shell IPC, live
window or desktop mutation occurs in that harness.

Local versions at verification: Python 3.14.7, Node 26.8.1, Qt 6.11.2,
Quickshell 0.3.1; CI separately tests Python 3.11/3.14, Node 22 and Ubuntu Qt.
See the completion report for the newest 60-second helper-soak metrics and CI.
These are **not** native lifecycle, ten-minute compositor soak, accessibility
reader, real journal burst or multi-monitor acceptance evidence.

## Gate 0 — coordination (must be explicit)

Ask the human and the agent currently working on installed Omarchy to release
the desktop for a named test window. Obtain approval for all of:

- installing Chronicle, enabling its service/bar widget and chosen placement;
- collecting accessible user-journal messages and pressure into private state;
- any shell restart needed for kept-service code refresh;
- temporary theme/scale/bar/monitor changes and their restoration;
- screenshots/log collection and private storage of human acceptance evidence.

Do not execute the following installation steps just because this file exists.
If another agent still owns the desktop, continue only isolated development.

## Gate 1 — read-only preflight

Run from the source checkout:

```sh
git status --short --branch
git branch --show-current
git rev-parse HEAD
git remote -v
gh run list --branch feat/chronicle-operator-cockpit --limit 5
make check
QT_SCALE_FACTOR=1.5 make test-qml
make integration
omarchy plugin validate /home/home/src/omarchy-chronicle
```

Require a clean feature branch, pushed commit and green CI on that exact SHA.
Select a full 40-character acceptance SHA deliberately; do not silently accept
a newer untested default-branch tip. Confirm the plugin ID is not already
installed; if it is, inspect its revision/config/state and use a separately
agreed update procedure rather than overwriting or calling add again.

Record Omarchy/Quickshell/Qt/Python versions, current theme, native font tokens,
display scale and geometries, bar edges, current plugin list and relevant shell
configuration. Do not publish hostnames, monitor serials or journal messages.
Establish where state actually resolves: absolute `XDG_STATE_HOME` overrides
`~/.local/state`; a relative/unset value does not.

If existing Chronicle state is present, back it up privately before any schema
migration, with the owned helper stopped or SQLite's supported backup mechanism.
Do not copy only the main SQLite file while an active WAL contains committed
data. Verify a recoverable backup before proceeding. Schema v1→v2 is not an
in-place downgrade path; old code must not be pointed at migrated state.

## Gate 2 — deliberate installation, disabled first

Installer behavior verified from the packaged scripts on 2026-09-07:

- `omarchy plugin add` accepts a Git URL or local Git checkout, clones it into
  the plugin directory, validates, and triggers a shell rescan even if disabled.
- `--yes` without `--enable` adds without enabling. There is no `--ref` flag in
  this installed implementation; do not invent one.
- Local source paths are accepted by `omarchy-git-url-check`.
- Enabling supports `--section`; disable is per exact plugin ID.

After approval, create a separate immutable acceptance checkout outside the
watched configuration tree. The example directory must not already exist; if
it does, inspect and choose another new directory. Set the selected SHA in the
checkout, then add that local repository disabled:

```sh
git clone --no-hardlinks --branch feat/chronicle-operator-cockpit https://github.com/nshkrdotcom/omarchy-chronicle.git /home/home/src/omarchy-chronicle-acceptance
git -C /home/home/src/omarchy-chronicle-acceptance switch --detach SELECTED_FULL_SHA
omarchy plugin add /home/home/src/omarchy-chronicle-acceptance --yes
git -C /home/home/.config/omarchy/plugins/nshkr.chronicle rev-parse HEAD
```

`SELECTED_FULL_SHA` is a required human-reviewed substitution, not a literal
command argument. Compare the installed SHA to it before enabling. If cloning
a detached source behaves differently on the current Git/installer version,
stop and resolve that mismatch while disabled. Do not continue with unknown code.

The local add leaves the installed Git origin pointing at the acceptance clone.
Either deliberately retain that frozen update source for the acceptance cycle,
or, after review, change the installed origin back to the public GitHub URL.
Do not run automatic updates during acceptance. No installed code edits.

```sh
omarchy plugin enable nshkr.chronicle --section right
```

Confirm the chosen bar placement with the human first. Keep other bar entries
where they were. The service records while the panel is closed. System-journal
collection stays disabled unless separately opted into by the operator.

## Gate 3 — native visual and interaction acceptance

For each row record Pass/Fail/Not available, exact revision, environment,
human observation, evidence path and any defect ID. Untested is not Pass.

| Case | Acceptance condition |
| --- | --- |
| Click CH | Native panel opens, usable bounds, no alternate title font or header rail |
| Compare clicked TD | Native title/body/caption tokens, padding and top-right alignment match conventions; do not require identical content |
| Supported summon route | Inspect current shell widget invocation API; same Chronicle panel, no overlay styling branch |
| Escape/Close/outside click | Focus and dismissal correct; explicit close waits for unsent draft acknowledgement; outside-dismiss limitations visible |
| Reopen/fade/panel switching | No accidental unload, duplicate panel, focus trap, stale captured input or orphan process |
| Multiple monitors | Each popup anchors/clamps appropriately; another cockpit's filters/replies do not overwrite this one's query or notes |
| Four bar edges | Position and outside-click ownership correct; no new typography profile |
| 1×/1.25×/1.5×/2× | Main title untouched; labels/buttons sharp and unclipped; no overlap or unreachable actions |
| Compact window/large tokens | Controls, notes, list scrollbars and dialogs remain reachable; do not shrink title to hide overflow |
| Dark/light/theme switch | Foreground/background contrast, focused controls, frozen graph repaint; density readable without color alone |
| Keyboard | Search, normal spaces in search/notes, freeze outside input, row navigation, Tab order, density/pressure arrows, Close |
| Monitor hotplug/reposition | Popup follows supported native lifecycle, no stranded window or input grab |

The bundled image proves only synthetic client-area rendering. Capture installed
images privately using the current Omarchy capture workflow. Avoid secrets and
leave public `preview.png` synthetic unless the human explicitly approves a
reviewed installed replacement. Preserve the CHRONICLE heading: “no titlebar”
means no OS window decoration, not deleting the application header.

## Gate 4 — human investigative workflows

1. **Before/after:** mark A, perform an independently user-approved change, mark
   B, compare signed units and missing observations. No automated change actions.
2. **Time navigation:** Context on A, step intervals/pages, Jump with explicit
   timezone. Check >500-match synthetic history in isolation, exact same-time
   event IDs, density totals, clear no-result state, and return via Live.
3. **Saved views:** save/restore/remove a named query, restart and restore again.
   Verify redacted saved search text is understandable and filters aren't hidden.
4. **Freeze:** select/scroll freezes only the view; recording and marks continue.
   After retention removes history, show loss/absence, never a substituted event.
5. **Incident notes:** create/pin; type; wait for draft acknowledgement; switch,
   reopen, commit; restart helper after acknowledgement and recover. Test a
   failed stage without leaving the incident or losing the local buffer.
6. **Concurrent edit:** two editors on one incident; save one, conflict the other;
   review committed/saved/local versions; explicitly resolve; no silent overwrite.
   Pin/unpin changes also advance the revision and require review for stale text.
7. **Saved evidence:** expire original rows in isolated fixtures, inspect the
   copied pin's source/boot/monotonic identity. No substitute or reconstruction.
8. **Export:** metadata excludes notes/messages; detailed preview uses committed
   notes only; no other cockpit opens that preview. Confirm writes exact reviewed
   bytes privately; repeat/expiry/new-preview invalidation rejects stale tokens.
9. **Sources:** permission-denied/empty/disabled/degraded remain distinct. Pause/
   resume qualification, receipt-clock vs source-clock labels and visible gap
   evidence. Do not create system-wide load or alter host clocks to test this;
   use injectable sources/clocks in isolated tests for destructive scenarios.
10. **Caps/failure:** use temporary state to test disk-limit failure, large Unicode
    records, view/incident/draft caps and schema failure. Never fill the user's
    actual filesystem or corrupt/delete their evidence as a test technique.

Ask the human to conduct at least one real investigation without coaching.
Record confusing labels, excess clicks, hidden focus, unreadable graphics,
unexpected motion and unclear state. Fix the specific friction with TDD, then
repeat that workflow and all affected visual/lifecycle cases.

## Gate 5 — native lifecycle and measured soak

After controlled setup, freeze the installed revision/config. Do 50 real native
open/close cycles and a ten-minute stationary soak, then a normal-workload soak
agreed with the human. Measure owned helper and whole-shell separately:

- baseline/peak/final RSS, CPU time, FD counts and owned child counts;
- timestamps, cycles, visibility, source state and revision;
- errors, unexpected panel disappearance, restarts and their exact timing.

Keep the existing helper 96-MiB/zero-steady-FD-growth regression criteria. Agree
whole-shell limits before testing; unrelated plugins make a universal threshold
misleading. Do not claim the earlier helper-only soak proved compositor health.
No source saves, theme edits, config hot reload or other-agent work during the
stationary run. Record disturbed runs as inconclusive/failed with reasons.

Disable only Chronicle at the end of a lifecycle test and verify its owned
helper exits. The packaged shell preserves `keepLoaded` services during code
hot reload but destroys disabled services during synchronization; verify this
on the installed version. Do not issue broad pkill commands. A coordinated
`omarchy restart shell` may be required to load a new service implementation;
this affects other plugins and needs explicit approval, not an automatic retry.

## Failure handling and rollback

Preserve each failed attempt before retrying. Record minimal reproduction,
expected/actual result, timing, exact SHA, environment and private evidence.
If a crash/core dump occurs, follow the crash-diagnosis skill then; do not infer
a cause from a successful retry. Do not publish sensitive core/log contents.

The least invasive rollback is `omarchy plugin disable nshkr.chronicle` after
the operator approves it. Confirm owned-process exit and preserve private
Chronicle data. Restore only Chronicle-specific/test-induced settings using
the saved baseline and a reviewed diff; never replace the entire shell config
over concurrent edits. Removing code or restoring old state needs separate
approval. No recursive deletion of home/src/config/state roots, no destructive
Git reset, and no old helper against schema-v2 state.

## Continue-until-polished loop and exit criteria

For every failed case: reproduce safely → add failing test → implement locally →
regression/preview review → commit/push → green exact-SHA CI → coordinate a
frozen installed update → rerun failed and adjacent cases → ask the human again.
Never hot-edit the installed plugin to speed up this loop.

Release acceptance requires every applicable matrix/workflow case passed,
unsupported cases explicitly accepted by the operator, no unexplained lifecycle
failure, measured stable native soak, privacy/export review, and human approval
that the layout/readability/workflow are polished. Only then change the README
status from pre-installation acceptance. Do not automatically merge, tag or
publish a release unless the user authorizes that additional step.

Acceptance record to fill:

- Installed SHA / configuration baseline:
- Human operator / test date / cooperating-agent clearance:
- Visual matrix and workflow evidence:
- Native soak reports and all failed attempts:
- Remaining limitations accepted explicitly:
- Final human sign-off (pending):

## Source references

- https://omarchy.org/manual/shell-plugins/
- Packaged `omarchy-plugin-add`, `omarchy-git-url-check`, `omarchy-plugin-enable`,
  `omarchy-plugin-disable`, `omarchy-plugin-validate`, `shell/shell.qml` read only.
- https://www.sqlite.org/rowvalue.html
- https://www.sqlite.org/lang_transaction.html
- https://www.sqlite.org/backup.html
- https://doc.qt.io/qt-6/qtquick-performance.html

Recheck current implementations before installed actions. These references
support mechanisms, not a claim that native acceptance has already occurred.
