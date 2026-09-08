# Continue with installed human acceptance

Chronicle remains **uninstalled and not natively accepted** in this development
session. Detailed machine-specific plan and handoff live at:

- `~/Documents/Chronicle/2026-09-07-community-stable-handoff.md` — start here;
  source work is paused at the operator's request, not awaiting more features.
- `~/Documents/Chronicle/2026-09-07-community-needs-plan.md`

- `~/Documents/Chronicle/2026-09-07-operator-investigation-plan.md`
- `~/Documents/Chronicle/2026-09-07-installation-HITL-handoff.md`
- `~/Documents/Chronicle/2026-09-07-completion-report.md`

The handoff specifies coordination, private-state backup/schema-v2 precautions,
exact-revision disabled-first installation, native visual/focus/monitor/theme
matrices, concurrent investigation/draft/export workflows, measured native
soak, failure capture, safe rollback and repeated human polish review.

The portable acceptance requirements remain in [RELEASE-GATE.md](RELEASE-GATE.md).
Never interpret a runbook as consent to install or restart a shared desktop.
Use a frozen checkout outside the watched plugin directory, review supported
installer behavior, and compare installed and tested SHAs before enabling.

Keep the native subtitle-sized heading and the existing top-right action rail.
Every fix should start with a failing test and end with pushed green CI plus
appropriate human acceptance. Do not mark the plugin “100% polished” while any
required native/human acceptance is still pending.

The portable copy of the latest handoff is [COMMUNITY-HANDOFF.md](COMMUNITY-HANDOFF.md).
