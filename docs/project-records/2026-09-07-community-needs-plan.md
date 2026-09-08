# Chronicle: community needs and operator workflow plan

Research date: 7 September 2026. Work stays in
`/home/home/src/omarchy-chronicle`, on `feat/chronicle-operator-cockpit`.
Starting checkpoint: `dfd4bfff142022b7aff89c9dba2061e95809f4a3`.

## What to build next

Make an investigation flow naturally: find an error, read its surroundings,
separate recurring noise from change, and hand another person a useful report.
The four priorities below form one complete source-development milestone.
Installation and human acceptance remain a separate coordinated step.

| Priority | Operator need | Deliverable |
|---|---|---|
| 1 | What happened around this exact error? | Context dialog with nearest earlier/later events, same unit/source/boot or all sources, explicit filter reset, exact selected identity |
| 2 | What is repeating, and what can I temporarily hide? | Full-interval repeat summary, reversible exclusions, exact unit filter, saved-view support |
| 3 | Did this start recently or was it already happening? | Equal-duration previous-window comparison with exact observed counts, signed changes, first/last times and evidence inspection |
| 4 | Can someone else pick this up without reconstructing my work? | Markdown export beside JSON, a safe notes outline, complete task-oriented documentation |

## Evidence and its limits

This is a small qualitative review of public requests and discussions, not a
survey of Chronicle users. Older requests identify persistent workflow problems;
they do not establish current market size. Product documentation validates
implementation patterns, not demand. Some Reddit pages were available only
through indexed excerpts; those observations carry less weight.

- **Context:** Grafana users describe finding an ERROR but losing nearby
  INFO/DEBUG evidence because context retained the level restriction. Later
  comments also describe needing stdout and stderr together. This directly
  supports explicit scope and lifting text/level filters.
  [Grafana discussion 45685](https://github.com/grafana/grafana/discussions/45685).
- **Noise control:** an lnav user requests multiple include/exclude expressions.
  The practical need is combining a useful search with removal of known noise.
  [lnav issue 485](https://github.com/tstack/lnav/issues/485).
- **Repeat counts:** a Splunk user asks to combine similar messages for counting.
  Chronicle will start with exact stored-message groups, not similarity guesses.
  [Splunk community question](https://www.reddit.com/r/Splunk/comments/uxr7xm/).
- **Do not erase distinctions:** a Loki report describes distinct observations
  disappearing when timestamp and body matched. Grouping must be presentation
  only, with individual identities preserved.
  [Loki issue 15425](https://github.com/grafana/loki/issues/15425).
- **Portable investigation notes:** debugging-logbook discussion participants
  describe attaching notes to tickets and keeping Markdown files. A report that
  travels with the issue is an inferred fit for Chronicle.
  [Programming community discussion](https://www.reddit.com/r/programming/comments/s6tuei/).

### Implementation and writing references

- lnav provides temporary inclusion/exclusion and reset workflows. Chronicle
  uses literal text, not regular expressions, to keep operation predictable.
  [lnav command reference](https://docs.lnav.org/en/latest/commands.html).
- CloudWatch compares equal-duration intervals and supports inspection after
  aggregate results. Chronicle adopts that timing/inspection pattern but counts
  exact retained records; it does not claim complete system coverage.
  [CloudWatch comparison guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData_Compare.html).
- Google's incident-writing guidance supports recording impact, evidence,
  follow-up actions and learning without blame. Chronicle's optional outline
  separates observations from hypotheses.
  [SRE postmortem culture](https://sre.google/workbook/postmortem-culture/).
- Use task headings, direct verbs, short procedures and concrete outcomes.
  Explain a limit beside the action it affects, not only in a technical appendix.
  [Google documentation headings](https://developers.google.com/style/headings).

## Product boundaries

Preserve the native subtitle-sized title, top-right Search/Freeze/Mark/Close
rail, popup palette, padding and panel geometry. New actions belong in the
Timeline tools or incident workspace. Keep charts restrained, text-readable,
keyboard usable and honest about missing observations. Never infer a root
cause from temporal proximity or present zero observations as healthy.

Do not install, enable, rescan, reload or modify the running desktop. No new
data sources, command execution, alerts, cloud services, clipboard writes or
automatic repairs. No dependencies or schema migration are needed for this
milestone. Existing incident drafts and privacy safeguards remain intact.

The two terms prohibited by the operator must not appear in documentation or
interface copy. Enforce this in repository tests. Match Tactical Display's
README Version/License/Platform badge style, using Chronicle's actual version,
and its License sentence with the product name changed.

## Detailed TDD implementation sequence

### Milestone A: language and plan

1. RED: documentation/interface language check and README badge/license tests.
2. GREEN: revise all project Markdown, Documents handoff files, manifest,
   source status messages and QML copy. Preserve precise numeric limits.
3. Publish this plan in Documents and a tracked copy in the repository.
4. Run repository tests, inspect the diff, commit and push on the feature branch.

### Milestone B: query and evidence tools

Write tests before each behavior, record the failing output, implement the
smallest complete behavior, then refactor shared predicates.

**Shared query contract**

- Extend validated filters with exact `unit` (empty means all) and up to eight
  nonempty literal `exclude` terms, each at most 200 characters.
- Search/exclusions use Unicode case-folding across stored message and unit.
  SQL wildcards and regex punctuation remain literal. Exclusions use OR:
  an event containing any term is hidden. Existing views restore defaults.
- Save only redacted text. Exact unit matching operates on the stored unit.
- Reuse the same filters and receipt ceiling for pages, counts and comparison.
  Parameterize all SQL. No silent 500-row aggregation of a larger interval.

**Surrounding context**

- Command `context`: exact event ID, scope `unit` or `all`, radius 1–3600
  seconds (default 120), per-side limit 1–100 (default 30), optional receipt ceiling.
- Default scope matches the selected event's source, unit and boot.
  If boot is absent, disclose that the grouping cannot establish process identity.
- Do not inherit search, exclusion, severity or category restrictions.
- Fetch closest predecessors and successors by (time,id), then display oldest
  first with the selected event always included exactly once.
- Return total eligible counts on each side, displayed counts and truncation
  flags. Report expired/missing identity; never substitute another event.
- Verify tied timestamps, dense later bursts, cross-boot/source events, empty
  neighbors, immutable source rows, late arrivals and bad arguments.

**Repeat summary and previous-window comparison**

- Command `analyze`: existing history interval/filters/ceiling and row limit
  1–100 (default 50). Count all matches in each interval.
- Previous interval has the exact same inclusive microsecond duration and ends
  one microsecond before the current interval. Reject requests before epoch
  instead of shortening one side.
- Group by exact stored source, unit, boot, category, severity and message.
  Redaction can make different raw messages equal: label this explicitly.
  Never change, delete or replace individual events.
- Return current/previous counts, signed delta, new/not-seen-again/changed/
  unchanged labels, current first/last times, and exact latest evidence ID.
- Order by current count for repeats or absolute delta for changes, with stable
  tie ordering. Return group total, shown count and omission indication.
- Count recorder notices independently of user filters and expose retained
  source-time range and retention generation. Coverage remains unproven even
  when no notice exists.
- Verify more than 500 rows, literal exclusions, ties, exact group distinctions,
  absent-side zero counts, interval endpoints, receipt ceilings and no mutation.

### Milestone C: human-readable handoff

- RED tests for format validation, private extension, exact reviewed bytes,
  metadata-only omission, malicious Markdown/HTML, notes drafts, token expiry
  and replacement, Unicode and existing JSON compatibility.
- Add `format: json|markdown` to preview_export; JSON remains the default.
  Bind selected format/extension to the expiring single-use preview token.
- Markdown reports include title, status, revision, UTC times, coverage/privacy
  caution, committed notes and ordered pinned evidence with exact IDs.
- Render user content as literal text blocks (no active HTML/images/links);
  keep preview as plain text. Metadata mode omits messages and notes.
- An optional notes outline is offered only for empty notes. Insert it as an
  unsaved draft through the existing controller; never overwrite human text.

### Milestone D: native UX

- RED controller tests for correlated replies, independent panels, stale results,
  unavailable service, helper restart, scope changes and exact event selection.
- Add one reusable per-cockpit request controller for analysis/context dialogs.
  Reset prior results at each request; do not display a stale result as current.
- Add Timeline tools below the existing header: Filters and Patterns.
  Context lives beside selected evidence. Filters show exact unit and exclusion
  fields with visible clear/reset actions; saved views include both.
- Repeat/change dialog shows counts and intervals, scope and coverage warnings,
  ranked rows, first/last observations and exact-context inspection.
- Context dialog shows selected identity, scope control, time radius,
  chronological neighbors and visible display limits. Main Timeline state
  remains unchanged when the dialog closes.
- Markdown/JSON selection stays in the incident export row.
- Test title/rail invariants, compact widths, text-entry shortcuts, dialog
  scrolling, accessible names and fixture rendering. Regenerate preview.png.

### Milestone E: complete documentation and QC

Write operator procedures with each UI feature, not afterwards as an index.
Include concrete worked examples, what the result means, how to undo a filter,
why history may be missing, and safe steps when a request fails. Expand protocol,
privacy, testing and handoff references. Keep README a concise entry point.

Run Python + JS tests, offscreen Qt at 1× and 1.5×, actual Quickshell/Python
transport integration, native import lint, plugin validation, preview inspection,
synthetic soak and exact-SHA GitHub Actions. Extend transport integration to
exercise new commands and Markdown output in private temporary state.

Commit/push coherent passing milestones. Before each push confirm the branch.
Record red/green evidence and discovered fixes honestly. Create a new completion
and installation/HITL addendum in Documents with exact commits, checks and
remaining native acceptance work. Do not claim installed polish from stubs.

## Acceptance checklist

- [x] Existing header/font/panel geometry preserved.
- [x] Context includes other levels and never loses its anchor to a dense burst.
- [x] Temporary exclusions do not affect retained history or pinned copies.
- [x] Repeat/comparison totals cover all matching retained records.
- [x] New/decreased counts carry missing-history and redaction qualifications.
- [x] Every aggregate can inspect an exact retained representative.
- [x] Both export formats write only reviewed bytes with private permissions.
- [x] Notes outline cannot overwrite existing work.
- [x] Docs cover every new workflow and comply with operator wording.
- [x] Offscreen, transport, lint, preview, soak and exact-SHA CI results recorded.
- [x] Installation remains deferred with actionable human acceptance steps.

## Deliberately deferred

Similarity clustering, automatic anomaly scoring, trace ingestion, report
uploads, alerts and system remediation need additional evidence and explicit
scope. The current plan delivers all four selected priorities without those
capabilities. Human acceptance can then establish which refinements matter on
the actual desktop.
