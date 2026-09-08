# Chronicle: stable-point continuation handoff

Date: 7 September 2026, Pacific/Honolulu.

## Start here

Work is paused at the operator's request after completing the community-driven
source milestone. Do not continue adding features automatically. Chronicle has
not been installed, enabled, reloaded or accepted on the live desktop.

- Checkout: `/home/home/src/omarchy-chronicle`
- Repository: https://github.com/nshkrdotcom/omarchy-chronicle
- Branch: `feat/chronicle-operator-cockpit`
- Plugin ID/version: `com.nshkr.chronicle` / `0.1.0`
- License: MIT, Copyright (c) 2026 nshkrdotcom
- Latest implementation checkpoint and final CI: see the completion receipt
  appended after the source commit. Never transfer a green result to another SHA.

The Documents directory is `/home/home/Documents/Chronicle`. Its files are
mirrored in the repository's `docs/project-records/` so continuation does not
depend on access to this machine. This handoff is also `docs/COMMUNITY-HANDOFF.md`.
Historical reports describe earlier checkpoints, not the current feature set.

## What was delivered

1. **Exact surrounding context.** Mixed levels, same source/unit/boot or all
   sources, selectable radius, chronological nearest neighbors, anchor preserved
   through dense bursts and tied timestamps, explicit total/displayed counts.
   Expired anchors fail explicitly. Select and pin an exact surrounding event.
2. **Reversible noise triage.** Exact stored-unit filter plus eight literal
   exclusion phrases, Unicode case-folded message/unit matching, validation and
   saved-view round trips. Source history and incident pins are unchanged.
3. **Full-interval comparison.** Repeat ranking and largest-change ranking across
   current and preceding equal-duration intervals. Counts include all retained
   matches, not only page one. Groups retain distinct source/unit/boot/category/
   severity/stored-message identities; every row links to exact event context.
   Shared-scale paired bars accompany text counts and first/last observation times.
4. **Portable handoff.** Metadata-first JSON or Markdown, exact reviewed bytes,
   private files, single-use expiring tokens and committed notes only. Literal
   content blocks keep embedded markup inactive in a CommonMark reader.
5. **Human-work and visual refinements.** An optional outline only inserts into
   empty notes. New dialogs use the popup palette for content, header and footer.
   Main subtitle-size title, top-right Search/Freeze/Mark/Close rail, native panel
   dimensions, font tokens and padding remain unchanged.
6. **Documentation.** Researched priorities, task-oriented walkthrough, examples,
   result interpretation, undo/recovery steps, protocol/privacy changes, updated
   README badges and License wording, and regenerated 1280×840 titlebar-free preview.
   The two prohibited terms were removed from project documentation and visible
   interface copy; repository regression tests enforce the constraint. GitHub's
   About description was corrected too.

No new source adapters, surveillance, cloud services, automatic repairs, shell
commands, clipboard writes, schema migrations or runtime dependencies were added.

## Research and documents

Read `2026-09-07-community-needs-plan.md` for sources, evidence strength and
the original TDD sequence. The research is a small qualitative sample of public
issues/discussions, not a survey or market-size claim. Context/filtering requests
are direct evidence; comparison and report choices also use established tool
and writing guidance. Indexed Reddit excerpts carry lower confidence.

In the repository:

- `docs/INVESTIGATE-AND-HANDOFF.md`: complete operator walkthrough.
- `docs/OPERATOR-GUIDE.md`: general use, historical navigation and draft recovery.
- `docs/PROTOCOL.md`: validated command contracts and export format semantics.
- `docs/PRIVACY-AND-SOURCES.md`: collection, privacy, capacities and limitations.
- `docs/TESTING.md`: current checks plus historical failures and results.
- `docs/RELEASE-GATE.md`: installed acceptance requirements.
- `docs/CONTINUATION.md`: index of machine-specific handoffs.

The older `2026-09-07-installation-HITL-handoff.md` remains the detailed
installation/rollback runbook. Combine it with the new acceptance cases below;
recheck installed command behavior before any approved installation.

## Implementation map

- `chronicle/history.py`: validated exact-unit/exclusion filters.
- `chronicle/store.py`: shared SQL selection, saved views, format-bound previews.
- `chronicle/investigation.py`: context and SQL aggregation/window comparison.
- `chronicle/report.py`: UTC timestamps and literal-content Markdown generation.
- `chronicle/recorder.py`: stateless `context`/`analyze` protocol routing.
- `qml/InvestigationController.qml`: per-dialog reply correlation, coalescing,
  stale-response rejection, restart/error reset.
- `qml/FilterDialog.qml`, `ContextDialog.qml`, `AnalysisDialog.qml`: operator tools.
- `qml/ChronicleDialog.qml`: shared palette-correct Qt dialog chrome.
- `qml/Cockpit.qml`: tool entry points, exact pinning, notes outline, export format.
- `tests/test_analysis.py`, `tests/test_reports.py`: query/export regressions.
- `tests/qml/tst_investigation.qml`, `tst_cockpit.qml`: ownership, notes and layout.
- `tests/fixtures/service-harness.qml.in`, `scripts/integration.py`: actual isolated
  Quickshell/Python transport including context, comparison and both exports.
- `tests/qml_preview/tst_preview.qml`: four page and three dialog fixture captures.

State remains schema 2. One recorder owns each state directory. Context and
analysis are stateless reads; they do not change the legacy shared query or
panel ownership. SQL aggregation returns only the requested ranked rows after
counting the full retained intervals. Similarity clustering is intentionally absent.

## Verification at the stable source tree

- `make check`: **95 Python tests, 13 JavaScript tests, 65 Qt cases** passed.
- `QT_SCALE_FACTOR=1.5 make test-qml`: **65 Qt cases** passed.
- `make integration`: actual windowless Quickshell/Python workflow passed,
  including JSON metadata and Markdown detailed export and clean helper shutdown.
- `make lint`: production imports resolved against read-only packaged Omarchy;
  **151 known host/dynamic typing advisories** retained, no unexpected lint failures.
- `omarchy plugin validate /home/home/src/omarchy-chronicle`: passed read-only.
- `make preview`: synthetic full-client image, 1280×840, 135158 bytes.
  SHA-256: `e240a80a13d96f69f7d78b5bd6bc24e2ca2db104349d48d7b1d8f0ff85cec696`.
  Main panel and dialog captures were visually inspected; default bright dialog
  chrome was identified and corrected with a regression test.
- `make soak`: **60.01 seconds, 50 panel-state cycles, 112 snapshots,
  23168 KiB peak helper RSS, 8/8/8 baseline/final/max-ready FDs, zero FD growth,
  0.07 CPU seconds**. Synthetic Python helper only, not native compositor soak.
  Report: `/tmp/chronicle-soak-report-dmu2g4f0.json`.
- Working diff whitespace and documentation/interface language checks passed.

Local evidence logs: `/tmp/chronicle-stable-check.log`,
`/tmp/chronicle-stable-scaled.log`, and
`/tmp/chronicle-native-lint-6151bh4q.log`. Temporary logs are not durable artifacts;
the essential results are recorded here. No host journal data was published.

### Genuine RED/GREEN and review fixes

New tests first failed on missing context/analysis/report/controller behavior,
ignored exclusions and missing panel actions. Later tests reproduced missing
recorder neighbors when boot metadata was null and invalid saved exclusions
after text cleanup. Fixes use null-safe boot equality and post-cleaning validation.
The palette test reproduced platform-default dialog chrome; the shared component
then passed. An intermediate duplicate font assignment caused QML compilation
failure and was corrected before the passing suite. Tests also cover exact
context pinning, notes overwrite refusal and compact/native-title invariants.

Earlier failed development/soak attempts remain in historical testing records;
later passing checks do not explain away those earlier failures.

## Continue efficiently when the operator resumes

1. Read this handoff, the community plan and repository `git status`/`git log`.
   Confirm the feature branch and the exact tested SHA. Preserve unrelated edits.
2. Confirm whether the operator wants source development or installed acceptance.
   The current instruction is to pause, not to install or build indefinitely.
3. If the source changed since this checkpoint, rerun `make check`, scaled Qt,
   `make integration`, validation and relevant preview/soak checks. Start fixes
   with failing tests. Keep title/font/rail and documentation wording constraints.
4. For installation, obtain explicit coordination with the operator and the
   agent owning the live Omarchy session. Follow the older detailed runbook:
   immutable exact-SHA checkout outside the watched directory, disabled-first
   add, verify installed SHA, then enable only with approval. Do not assume
   a hot reload replaces a keep-loaded service.
5. Use the installed acceptance matrix and the additions below. Record failures
   before retrying, fix with tests where possible and repeat human review.
6. Commit/push coherent fixes on the feature branch; check CI for the exact SHA.
   Update these documents with actual observed outcomes, not inferred acceptance.

## Additional installed human acceptance cases

- Click and supported summon route must retain the same title, fonts and rail.
  Check popup header/footer palette in dark/light themes and at fractional scale.
- Find an error and open context: other levels must appear, anchor must remain
  visible, scope/radius controls must work, and Timeline filters must survive close.
- From Patterns, inspect context, choose a different neighbor and pin it. Confirm
  the incident copy has that exact ID and close/focus behavior is sensible.
- Apply/clear exclusions, save/reopen a view, and explain what was hidden.
  Verify text entry, tab order, long phrases, empty results and compact widths.
- Read paired counts and interval labels with a human. Confirm the meaning of
  newly observed/not seen again is clear and not confused with fault/recovery.
- Try two panels simultaneously, slow replies, helper restart and expired anchors.
  No panel may accept another panel's result or substitute a different event.
- Insert the notes outline, edit, stage and save. Existing text must not change
  if the outline action is attempted again. Verify conflict recovery as before.
- Preview both formats, optional detail and metadata-only mode. Test replacement
  by another panel and expiry. Verify the actual saved bytes and permissions.
- Run the older 50-cycle/10-minute native lifecycle/performance matrix only after
  coordinated installation; this source helper soak is not its replacement.

## Remaining scope and limits

The selected source features are implemented. Remaining work is installation,
live compositor/popup/focus/theme/monitor verification and human-led polish.
Offscreen stubs do not prove installed accessibility, popup coordination or
performance under real journal bursts. No new maximum-volume benchmark or
installed load claim is made. Redaction is best effort; event counts and temporal
proximity are not proof of completeness, recovery or causation.

Do not call the plugin “100% polished” until the operator accepts the installed
workflow. Similarity clustering, automatic anomaly scoring, uploads, alerts,
new sources and remediation remain outside this completed milestone.

## Completion receipt

Implementation checkpoint: `0da3a51456ad8c817a861ddb66e5a1760ec46429`.
All three jobs passed in [CI run 34180711106](https://github.com/nshkrdotcom/omarchy-chronicle/actions/runs/34180711106):
Python 3.11, Python 3.14, and offscreen Qt (both scales and fixture captures).

Milestones pushed on the feature branch:

- `66054235d727c0d939697590c0c5ce9b903b33b5`: research/wording/README, CI 34175869206 passed.
- `1ef804205b3944b1e94fb8a74fe1702d2c4b1f49`: backend context/analysis/Markdown, CI 34176076805 passed.
- `e12e3e0ede73d259ad3d1263feabd65f0887251f`: operator UI and mirrored handoffs.
  CI 34180539311 failed its new palette assertion on the older Qt runner.
- `0da3a51456ad8c817a861ddb66e5a1760ec46429`: explicit native color namespace,
  a new regression check, repeated local verification and green CI.

The failed CI run exposed unqualified `Color` resolving to Qt Controls'
internal color utility instead of Omarchy's palette in older Qt. Earlier green
CI logs also contained those color errors; the new palette assertion made them
observable as a failure. Production QML now uses `Native.Color`. Corrected CI
has no “Cannot read property” color errors. Final local suite: **95 Python,
13 JS and 65 Qt cases**, with the same 65 Qt cases at 1.5×.

Final local logs: `/tmp/chronicle-stable-check-final.log`,
`/tmp/chronicle-stable-scaled-final.log`,
`/tmp/chronicle-native-lint-hr2qh7m_.log`.
CI logs: `/tmp/chronicle-stable-ci-failed.log` and
`/tmp/chronicle-stable-ci-corrected.log`.

The older Qt CI runner still emits **18 implicit-size binding-loop warnings**
across its normal/scaled/fixture commands, involving Notes/ScrollView and dialog
implicit sizing. Tests pass; local Qt 6.11 does not reproduce these warnings.
This is not a warning-free cross-version claim. Preserve this finding for the
next approved compatibility/layout pass and installed human review; do not
silence warnings or change title/font sizes to hide it. No installed acceptance
was attempted.

The final documentation-only commit records this receipt and does not change
the tested runtime. Resolve that descendant's SHA with `git rev-parse HEAD`
and verify its own CI before selecting an installed revision. All Documents
Markdown is mirrored in `docs/project-records/`; no private database or journal
content is tracked. Work is paused after the final commit/push and CI check.
