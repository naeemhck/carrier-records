# Development instructions

## Current local-only Karvaan update

- Work only in update/karvaan-bilingual, separate worktree based on committed main. Earlier shipping authorization does not apply.
- No push/merge/installation/hosted Supabase or Cloudflare contact/change for app/backend tests; do not change production scheduling. Official package/font downloads are permitted.
- Before running the candidate, verify its distinct local backend identity/ports; APP_ENV=test alone is insufficient. Fail closed for hosted configuration; never load installed client.json or production sessions/defines.
- Preserve production config/session identity, installer AppId/install path, Android application ID, company names, historical records and document numbers. Keep legacy issued renderers/assets.
- Typed stable bilingual catalogue, LTR overall layout and Latin digits; RTL only within Urdu runs. User data remains unchanged. New issued bilingual snapshots use a new template version.
- Record U-series progress separately from T00–T20; T19 stays IN PROGRESS and T20 TODO. See docs/karvaan-update.md and bilingual-glossary.md.

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
