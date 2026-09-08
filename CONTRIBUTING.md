# Contributing to Chronicle

Work in the source checkout on a feature branch. The running desktop is a
shared environment; do not install, symlink, enable, reload, or restart it as
part of ordinary development. Obtain explicit coordination for installed
acceptance. Never edit packaged Omarchy sources.

Use TDD: write a failing behavioral test, observe the failure, implement the
smallest correct change, then run the broader suite. Include regression cases
for malformed input, missing measurements, identities that expire, privacy,
source errors and restart behavior. Commit and push green milestones.

Run `make test test-qml integration lint` locally. `make demo` creates synthetic
screenshots only; inspect all affected pages. Test `QT_SCALE_FACTOR=1.5 make
test-qml` after layout changes. `make live-readonly` is opt-in and uses temporary
state; never paste real log messages into tests, commits, CI or public issues.

The native title, top-right action alignment, popup geometry rules and common
font tokens are a compatibility contract. Do not add route-dependent font
profiles or an alternate fullscreen overlay. Prefer code-native data graphics,
plain text, accessible controls and evidence-qualified displays.

Changes to a kept Omarchy service may not apply on hot reload. Source changes
during an installed soak invalidate the measurement. Record the exact revision,
failed attempts and limitations; never call offscreen tests Wayland acceptance.

Production Python uses only the standard library. Keep storage and protocol
bounds explicit. No shell interpolation, arbitrary command dispatch, elevated
operations, automatic repair, telemetry uploads, or silent state resets.

Format QML with `qmlformat -i` from the Qt development tools. Keep generated
state, screenshots, caches and runtime artifacts out of Git. Runtime screenshots
are fixtures, not proof of native styling on every theme and monitor.
