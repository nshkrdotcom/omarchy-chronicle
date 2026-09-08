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

- Final local suite at the acceptance refinement stage: 46 Python tests, 11
  JavaScript tests, and 27 Qt cases including init/cleanup cases. All pass;
  the Qt suite also passes at 1.5× scale. Real transport integration and native
  import resolution are independent checks, not counted as unit tests.

- First GitHub Actions run `34172156337` passed all jobs: Python 3.11, Python
  3.14, and offscreen Qt (normal and 1.5× scale). Subsequent revisions must be
  checked independently; see the repository's Actions page for exact SHAs.
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
