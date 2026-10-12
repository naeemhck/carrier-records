# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T16 are complete. T16 encrypted backup creation, incremental receipts, administrator-only status and real temporary scheduling checks pass; production helper setup and T17 restoration remain pending. Latest verification: 1,486 main-harness checks plus 32 real-helper checks, 219 SQL assertions, 78 Flutter tests and Windows/Android debug builds pass. Physical-printer/Android-device checks remain T19/T20. See [current tasks](tasks.md), [backup evidence](docs/backups-evidence.md) and [backup setup](docs/backups-setup.md).

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T17 in tasks.md when requested. T15/T16 are locally committed; do not push automatically. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git and the user-authorized T10 [private source backup checkpoint](https://github.com/naeemhck/carrier-records). Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md) and the current checkpoint evidence in [T10 evidence](docs/corrections-evidence.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
