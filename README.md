# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T07 are complete: local Windows/Android tooling, exact schema/domain contracts, managed accounts, master records, scoped trip drafts, atomic lifecycle, and the immutable financial/claim engine with customer receipts. Customer debt, held funds and owner settlement remain distinct. Analysis, 36 Flutter tests, 121 SQL assertions, 602 combined backend assertions and both debug builds pass. Transfer/settlement/credit and expense entry workflows remain T08/T09; production deployment and release distribution are pending. See [current tasks](tasks.md) and [T07 evidence](docs/financial-engine-evidence.md).

## Planning documents

| File | Purpose |
|---|---|
| [PRD.md](PRD.md) | Requirements and acceptance criteria |
| [architecture.md](architecture.md) | Flutter/Supabase architecture, interfaces, access and recovery |
| [rules.md](rules.md) | Financial calculations, permissions and lifecycle rules |
| [design.md](design.md) | Screens, forms and customizable output design |
| [tasks.md](tasks.md) | Ordered implementation work and verification evidence |
| [memory.md](memory.md) | Confirmed decisions and current state |

## Continue in VS Code

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T08 in tasks.md. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git; the T05, T06 and T07 commits are not pushed. An earlier user-authorized [private source backup](https://github.com/naeemhck/carrier-records) is configured. Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
