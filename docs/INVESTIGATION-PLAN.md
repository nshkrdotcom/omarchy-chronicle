# Investigation workflow refinement — 2026-09-07

Authoritative detailed working plan:
`~/Documents/Chronicle/2026-09-07-operator-investigation-plan.md`.

Starting revision `4fdbf08`; feature branch `feat/chronicle-operator-cockpit`.
No installation, enable/reload or running desktop changes are authorized here.

1. TDD: atomic receipt-sequence schema migration, receipt-based retention,
   time-bounded keyset history queries, ceiling-stable pagination, full-interval
   density/counts and retention-loss qualification.
2. TDD: per-cockpit result correlation, historical interval/page navigation,
   bookmark context, named saved views, accessible density graphics. Preserve
   native title font and top-right action rail.
3. TDD: revision-checked incident edits, durable separate drafts, conflict-safe
   navigation/recovery, committed-only export and saved evidence inspection.
4. Verify all suites, native import lint, fractional rendering, real windowless
   transport, helper soak and exact pushed revision CI. Write installation/HITL
   continuation handoff in the Documents directory; installed acceptance stays
   pending until coordinated operator approval.

Design references: [SQLite keyset queries](https://www.sqlite.org/rowvalue.html),
[transactions](https://www.sqlite.org/lang_transaction.html),
[Qt Quick performance](https://doc.qt.io/qt-6/qtquick-performance.html),
[Omarchy plugin contract](https://omarchy.org/manual/shell-plugins/).

Prefer bounded, explicit evidence over inferred health or causality. Retention
may remove frozen-page rows; disclose loss rather than keeping a long read
transaction open. Draft acknowledgement means durable staging, not committed
notes. No new data sources, desktop mutations or uploads.
