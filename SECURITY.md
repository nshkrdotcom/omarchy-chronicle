# Security and privacy

Do not attach real journal exports, database files, private-key material,
tokens, addresses or incident notes to a public issue. Use GitHub's private
vulnerability reporting if available for this repository; otherwise open a
minimal issue asking for a private reporting channel without disclosing the
vulnerability or sensitive evidence publicly.

Provide the Chronicle revision, platform/runtime versions, a synthetic
reproducer, and the boundary affected. Redaction is best-effort and export
preview is mandatory; neither is a promise that arbitrary input is secret-free.

Chronicle runs with the user's authority inside Omarchy and through its owned
Python helper. It has no sandbox boundary against other code running as the
same user. It never requests elevated privileges, executes arbitrary submitted
commands, uploads evidence, or repairs the observed system automatically.

See [the threat model and source matrix](docs/PRIVACY-AND-SOURCES.md).
