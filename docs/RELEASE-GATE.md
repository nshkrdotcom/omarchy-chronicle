# Installed acceptance — pending operator coordination

This gate has **not** been executed. Another agent owns active installed
Omarchy/plugin work. Do not run it implicitly from a build target, test,
automation hook or unattended continuation.

The [continuation guide](CONTINUATION.md) locates the detailed machine-specific
installation/HITL runbook. The new history/draft workflow additionally requires:

- schema-v1 backup and v2 migration/rollback review before upgrading real state;
- exact-time jumps, >500-match paging, retained-density/coverage qualification;
- independent cockpit queries and incident results, late-response handling;
- acknowledged drafts, concurrent revision/token conflicts and explicit review;
- committed-only exports and independently inspectable retained pin copies;
- titlebar-free README preview remains labeled synthetic until installed review.

## Preconditions

- Operator explicitly releases the installed desktop for testing.
- Chronicle source revision is committed, source tree is clean, and isolated
  tests plus real windowless transport integration pass.
- Identify current Omarchy/Quickshell versions, theme, scale, monitor geometry,
  bar positions, and other agents' active changes without overwriting them.
- Review manifest validation and the installer behavior. Decide the exact
  tested feature-branch revision, private state location and retention policy.
- Obtain explicit approval to install/enable. Never use a mutable symlink from
  active development sources into the installed hot-reload directory during soak.

## Native interaction matrix

1. Click CH in the native bar. Capture title, status, top-right actions and
   frame geometry. Compare to Tactical Display's clicked-panel conventions.
2. Close and summon through the supported shell shortcut/IPC route. Verify
   the same panel implementation, font sizes, header rail and styling.
3. Test Escape, outside-click dismissal, keyboard focus, switching to another
   native panel, repeated reopen during fade-out, and multiple monitors.
4. Test all four bar edges, a compact display, large native font tokens,
   1×/fractional/high scale, light/dark themes and monitor hotplug.
5. Verify keyboard search, event navigation, graph sample inspection, freeze/
   live, source controls, bookmark comparison, saved notes, removal confirmation,
   exact-preview export and expired-token handling with synthetic incidents.
6. With explicit live-source consent, verify real journal provenance, coverage,
   pause/resume, bounded gaps, unsupported sources, and no sensitive public logs.
7. Verify recorder continuation when panels close, multiple-owner handling,
   helper restart qualification, clean disable and no orphan helper processes.

## Lifecycle and performance

Run 50 native open/close cycles followed by a 10-minute stationary soak. Record
shell/helper RSS, CPU, FD and child counts, elapsed time and panel visibility.
Separate whole-shell noise from helper measurements; record baseline and peak,
not only final values. No edits, source hot reload or theme changes during a
stationary soak. Unexpected closure/unload is a failed attempt: preserve its
evidence before retrying. A later pass does not explain away an earlier failure.

## Handoff

Only after this matrix is complete should the build be described as installed
and natively accepted. Report deviations and untested cases. Restore only
test-induced settings/state with operator approval; do not overwrite another
agent's work or erase operator evidence. Creating this document does not
authorize execution of its installation steps.
