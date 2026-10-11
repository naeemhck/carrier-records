# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T05 are complete: local Windows/Android tooling, exact domain/schema contracts, managed staff accounts and authorization, company/master records, and office-scoped trip drafts with multiple customers, stops, reviewed returns and server-calculated quotes. Analysis, 26 unit/widget tests, 95 SQL assertions, 344 HTTP/native assertions and both debug builds pass. Production deployment, release distribution and T06 onward remain pending. See [current tasks](tasks.md) and [T05 evidence](docs/trips-evidence.md).

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T06 in tasks.md. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git; this T05 commit is not pushed. An earlier user-authorized [private source backup](https://github.com/naeemhck/carrier-records) is configured. Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
