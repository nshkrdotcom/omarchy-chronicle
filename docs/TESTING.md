# Verification record

Date: 2026-09-07, Pacific/Honolulu. Source checkout only; no installed changes.

## TDD evidence

- Core tests were added first and failed on missing `chronicle` modules; the
  initial evidence/store implementation then passed 17 tests.
- Recorder/source/protocol tests next failed on missing source modules; the
  helper implementation reached 29 passing Python tests.
- Timeline and Qt tests initially failed on missing UI/model files. The first
  native-style cockpit passed eight JS and ten Qt cases after implementation.
- Hardening tests exposed missing measurement-age provenance, permissive
  existing-directory chmod behavior and lost read access after storage errors.
  Regression fixes preserve private state and readable saved evidence.
- Further RED/GREEN cycles cover source filtering, readable comparisons,
  storage recovery qualification, actual sample inspection, repainting frozen
  graphs after theme changes, and atomic gap/cursor evidence.

## Validation layers

| Check | Scope | Not proven |
| --- | --- | --- |
| Python unit/subprocess tests | Parsing, storage, privacy, limits, protocol, ownership, failures | Native rendering |
| Node model tests | Exact selection, filters, projection, buckets, gaps, comparison, inspection | Qt/Wayland behavior |
| Offscreen Qt tests | Actual cockpit components; injected style inputs; transport stub for service state | Installed imports/runtime integration |
| Native import lint | Read-only resolution of production QML against packaged Omarchy source | Runtime host behavior or warning-free static typing |
| Real Quickshell transport | Actual Service.qml copy, Python helper, SQLite and export in isolated XDG roots | Bar/popup/native compositor behavior |
| Fixture screenshots | Four implemented pages with synthetic data and test style tokens | Screenshots of the installed plugin |
| One-shot live probe | Accessible user journal and four scalar metrics, temporary private state | Exhaustive journal permissions/retention coverage |
| Synthetic helper soak | Bounded helper lifecycle and panel-state commands | Native shell soak or real journal burst performance |

`make check` runs Python/JS/offscreen Qt/native import lint. `make integration`
adds real windowless Quickshell transport. Native lint retains its host-dynamic
QObject and missing Quickshell exit-enum metadata advisories in a `/tmp` report;
other warnings and failed imports are errors. This is not a zero-warning claim.

## Observed results

### Investigation-workflow tranche (current production checkpoint `9e9e417`)

- 76 Python tests, 13 JavaScript tests, 51 offscreen Qt cases (including
  lifecycle cases) pass. The same QML implementation passes at 1× and 1.5×.
- Real isolated Quickshell transport exercises the actual history and incident
  controllers through paging, mark, create/pin, durable draft, revision-checked
  commit, saved view, metadata preview/export and owned helper shutdown.
- Native imports resolve with 118 retained host/dynamic advisories;
  `omarchy plugin validate /home/home/src/omarchy-chronicle` succeeds read-only.
- `make preview` renders a 1280×840 synthetic full client area with no OS
  titlebar, referenced near the top of README. PNG dimensions/link placement
  are regression-tested. The native title/font/header rail remains unchanged.
- Final helper soak at `9e9e417`: 60.10 seconds, 50 panel-state cycles, 112
  snapshots, **23,156 KiB peak RSS**, baseline/final/max-ready FDs **8/8/8**,
  zero FD growth, 0.07 CPU seconds. Report:
  `/tmp/chronicle-soak-report-00v5e2mn.json`. An earlier pass before the Unicode
  fix had 23,228 KiB peak RSS with the same zero-growth/CPU/cycle outcomes:
  `/tmp/chronicle-soak-report-2u9e4c3h.json`. Neither is native compositor acceptance.
- Green CI milestones: `b47f580` / `34173873427`, `b9117a1` / `34173971222`,
  `2c2d08c` / `34174195586`, `f16a617` / `34174542005`,
  `b6a1573` / `34174761058`, and production `9e9e417` / `34174875975`.
  All three jobs on that production run succeeded. Check later docs revisions
  independently rather than transferring a green status between SHAs.

New RED/GREEN evidence covers the old 500-before-window bug, future-clock
retention eviction, tied-time paging, receipt ceilings, mutation-free history
queries, full-interval aggregates, schema migration failure rollback, persisted
view limits, cross-cockpit replies, draft overwrite/version races, late stage
acknowledgements, typing spaces in notes, committed-only export, source provenance,
explicit timezone jumps, and chart axes moving ahead of returned data.

Adversarial Unicode tests reproduced an additional actual recorder exception:
escaped JSON could exceed the store's 12,000-byte event budget even after the
message character cap. Normalization now fits that same byte budget, visibly
shortens text where possible, and lets the source adapter qualify unpersistable
identity as rejected/gap evidence instead of crashing collection.

The expanded fixture harness initially rendered an empty loading state because
it lacked a history reply; it now supplies the correct bounded model and asserts
loaded evidence/selection before capture. Native lint rejected unqualified
delegate access in the new graphic, corrected with explicit IDs. The expanded
transport harness initially omitted the new controller copies, corrected before
the successful real transport run. Python 3.14 also revealed unclosed database
connections in new test/inspection code; those now use explicit closing scopes.
These development failures are recorded, not relabeled as installed failures.

### Earlier foundation results (retained for provenance)

- Final local suite at the acceptance refinement stage: 48 Python tests, 11
  JavaScript tests, and 27 Qt cases including init/cleanup cases. All pass;
  the Qt suite also passes at 1.5× scale. Real transport integration and native
  import resolution are independent checks, not counted as unit tests.

- First GitHub Actions run `34172156337` passed all jobs: Python 3.11, Python
  3.14, and offscreen Qt (normal and 1.5× scale). Subsequent revisions must be
  checked independently; see the repository's Actions page for exact SHAs.
- Acceptance refinement `4275429` also passed all jobs in run `34172900630`.
  That run exposed Node 20 deprecation advisories in the older action pins.
  The workflow was subsequently moved to verified full-SHA v7 pins from the
  official [checkout](https://github.com/actions/checkout),
  [setup-python](https://github.com/actions/setup-python), and
  [setup-node](https://github.com/actions/setup-node) releases (Node 24 action
  runtime), with bounded job timeouts. This does not change the Node 22 version
  used to test Chronicle's pure JavaScript model.
- The actual offscreen Quickshell-to-helper integration passed bookmark,
  incident creation, exact pin, metadata preview, export and graceful shutdown.
  An initial harness import used an invalid absolute QML URL; it was corrected
  to a file URL. An inherited GTK platform theme also attempted display access;
  the harness now explicitly sets an offscreen-compatible style and removes
  display/compositor environment variables. These were harness failures, not
  installed acceptance results.
- One read-only temporary-state probe found 45 retained events (including the
  recorder lifecycle marker), user-journal status `ok`, system journal disabled,
  pressure status `ok`, four available scalar metrics, no storage error. No real
  message contents were printed or committed. Counts are time-specific.
- The 60-second synthetic helper soak passed in 60.10 seconds with 50 panel-state
  cycles, 112 snapshots, 22,976 KiB peak RSS, zero FD growth, and 0.07 CPU seconds.
  It used demo data, not host journal traffic. This is not a native 10-minute soak.
- A repeat against `50bd5a2` failed the harness's combined RSS/FD assertion.
  That harness did not print the failed measurements, so the exact threshold
  cannot be recovered or attributed retrospectively. Review found it could
  baseline FDs before the helper created its stdin selector. The corrected
  harness waits for a command-response snapshot before the steady-state FD
  baseline, retains the same zero-growth/96-MiB limits, and preserves numeric
  reports on both pass and fail. Regression tests cover premature baselines,
  actual FD growth and absent readiness. This failed attempt is not erased by
  a successful retry; the original incomplete failure report is a limitation.
- The corrected harness passed against `8c8844b` in 60.01 seconds: 50 panel-state
  cycles, 112 snapshots, 22,968 KiB peak RSS, baseline/final/maximum-ready FD count
  all 8, zero FD growth, and 0.07 CPU seconds. The numeric report is retained
  locally at `/tmp/chronicle-soak-report-utpv97qt.json`. GitHub Actions run
  `34173160700` passed all jobs on that same revision. Subsequent documentation
  commits do not change the tested production implementation or soak harness.
- Fixture previews of Timeline, Bookmarks, Incidents and Sources were inspected.
  Follow-up refinements included left-aligned event rows, native notes styling,
  readable comparisons, only relevant search controls, pressure lenses and
  keyboard/pointer sample inspection. Title sizing and header alignment were
  retained. An offscreen theme-change regression verifies repaint with frozen data.

## Reproduce

```sh
make test
make test-qml
QT_SCALE_FACTOR=1.5 make test-qml
make lint
make integration
make demo
make soak
# Optional: reads real sources, but only into disposable private state.
make live-readonly
```

No command above installs, enables, reloads or contacts the installed shell.
The service integration uses its own temporary Quickshell config/runtime roots
with no windows and only synthetic data. All pending native acceptance is
listed explicitly in [RELEASE-GATE.md](RELEASE-GATE.md).
