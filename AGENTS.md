# Development instructions

- Read memory.md, PRD.md and rules.md before implementing behavior. Use architecture.md, design.md and tasks.md for the relevant task.
- Follow the latest user instruction and the ordered task dependencies. Record completed work and actual verification in tasks.md and memory.md.
- Preserve the distinction between earnings, profit, customer debt, intermediary-held money and owner settlement.
- Calculate money exactly: decimal strings at interfaces, integer paisa in Dart, exact numeric values in PostgreSQL. Do not use binary floating-point for money.
- Enforce office permissions and recipient field eligibility in the backend. Restrict data in payloads and exports, including metadata and hidden sheets/columns.
- Keep confirmed financial history immutable through linked reversals/replacements. Require idempotency for financial commands and version checks for editable records.
- Preserve issued document snapshots, permanent numbers and historical owner/fare details.
- Do not introduce booking, taxes, public signup, external-party accounts, offline posting or paid services into v1.
- Do not commit production data, credentials, signing keys, receipts or backup archives. Privileged credentials must never enter ordinary client builds.
- Test the behavior being changed using the acceptance cases in tasks.md. Do not claim tests, native builds, deployment or restoration succeeded without executed evidence.
