# Chronicle — implementation completion evidence

Date: 2026-09-07, Pacific/Honolulu.
Repository: `/home/home/src/omarchy-chronicle`.
Remote: https://github.com/nshkrdotcom/omarchy-chronicle .
Feature branch: `feat/chronicle-operator-cockpit`.
Production checkpoint: `9e9e4174a15574d220ffec934cfe4cd6a67876bd`.

## Delivered and pushed

| Commit | Result |
| --- | --- |
| `b47f580` | Research-backed investigation plan and TDD milestones |
| `b9117a1` | Receipt-safe schema/retention and complete time-filtered history pages |
| `2c2d08c` | Independent cockpit queries, density, historical navigation and saved views |
| `f16a617` | Durable drafts, incident/draft revision checks, explicit conflict review and saved-copy inspector |
| `b6a1573` | Exact ISO time jumps, fixed density axes, full titlebar-free README preview |
| `9e9e417` | Unicode persistence-budget hardening and source gap preservation |

Documentation/handoff completion is a subsequent docs-only commit; see the final
repository status entry below. No merge, release tag or installation was performed.

## Verification

- `make check`: **76 Python tests, 13 Node tests, 51 offscreen Qt cases**, plus
  native-import lint. All pass. Qt totals include init/cleanup cases.
- `QT_SCALE_FACTOR=1.5 make test-qml`: same 51 Qt cases pass.
- `make integration`: real offscreen Quickshell, actual controllers and Python
  helper, isolated XDG roots, synthetic data; paging → bookmark → incident/pin →
  draft → revision-checked commit → saved view → exact metadata export → shutdown.
- Official read-only `omarchy plugin validate` passes the source checkout.
- Native imports resolve; 118 host/dynamic type advisories retained in
  `/tmp/chronicle-native-lint-0p3hbgu3.log`. No zero-warning/static-type-proof claim.
- Final production helper soak: **60.10s, 50 panel-state cycles, 112 snapshots,
  23,156 KiB peak RSS, 8 baseline/final/max-ready FDs, zero FD growth,
  0.07 CPU seconds**. `/tmp/chronicle-soak-report-00v5e2mn.json`.
- Earlier tranche soak also passed (23,228 KiB peak, same FD/cycle/CPU outcome),
  `/tmp/chronicle-soak-report-2u9e4c3h.json`. Neither is a native shell soak.
- Local versions: Python 3.14.7, Node 26.8.1, Qt 6.11.2, Quickshell 0.3.1.
  CI separately covers Python 3.11/3.14, Node 22, and Ubuntu offscreen Qt.

## README preview

`preview.png` is 1280×840, 137,037 bytes. It is the entire rendered client area,
including native-style padding and Chronicle's unchanged header, with no OS
window titlebar. It uses deterministic synthetic evidence and test style tokens.
It is linked near the top of README in the same relative-image form as Tactical
Display, and labeled as a synthetic pre-installation preview. `make preview`
regenerates it without opening or installing a desktop window.

SHA-256: `7ec222421d2ffabe112ef01d600cf1a0019217e071d863ecf09e727a1cc92416`.

## Research and honest boundaries

SQLite's keyset/transaction guidance informed pagination and conflict-safe
persistence; Qt performance guidance informed limited virtualized models.
Omarchy guidance and the packaged source informed native title/header/lifecycle
preservation and the disabled-first, coordinated installation runbook. Links
and reasoning are in the detailed plan and repository docs.

TDD exposed genuine history-limit, source-clock retention, note overwrite,
late-reply, density-axis and Unicode-budget bugs; regression tests now pass.
Development harness failures and the earlier foundation's unexplained failed
soak are preserved in `docs/TESTING.md`; later passes do not erase that history.

All new development stayed in this source repository plus the requested Documents
directory. `/usr/share/omarchy` and installed Tactical Display were read only.
No Chronicle install/enable, shell rescan/restart, installed plugin/config edit,
live desktop screenshot, upload of journal data or automatic remediation occurred.

Important remaining limits: one draft per incident, explicit reconciliation for
competing editors, no crash-durability promise before draft acknowledgement,
best-effort outside-dismiss/unload flush, retention can remove frozen-page rows,
legacy receipt age is estimated, source clocks can distort displayed chronology,
and redaction is not complete anonymization. All are documented in the handoff.

## Continuation

Use `2026-09-07-installation-HITL-handoff.md` in this directory. It includes
explicit human/cooperating-agent clearance, exact-SHA disabled-first installation,
backup/rollback cautions, native visual and keyboard matrices, real investigation
workflows, concurrent edits, failure capture, measured native soak, and the
TDD → push/CI → coordinated installed verification → human review polish loop.

The completed outcome is **ready for coordinated installed acceptance**, not
“100% polished” without that acceptance. The header font/rail invariants remain
mandatory throughout the continuation.

## Final repository/CI status

Final docs-only commit: `dfd4bfff142022b7aff89c9dba2061e95809f4a3`.
Pushed to `origin/feat/chronicle-operator-cockpit`; the worktree is clean.
All three jobs passed on the exact final revision in
[Actions run 34175114066](https://github.com/nshkrdotcom/omarchy-chronicle/actions/runs/34175114066).
The production checkpoint independently passed all three jobs in
[Actions run 34174875975](https://github.com/nshkrdotcom/omarchy-chronicle/actions/runs/34174875975).

Seven coherent commits were created and pushed during this improvement tranche.
The final commit changes documentation only; production/soak evidence above
applies to `9e9e417`, and final-head CI independently verifies the handoff revision.
No required source implementation remains in the current plan. Actual installation
and human/native acceptance remain the next explicitly coordinated stage.
