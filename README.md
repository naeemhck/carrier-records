# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T15 are complete, including authorized PDF and Excel generation from redacted live payloads and immutable issued-document snapshots. AT-24/28/29, 70 Flutter tests, 198 SQL assertions and 1,383 backend/native checks pass. Windows and Android debug builds pass. Physical-printer and Android-device export checks remain at their T19/T20 release gates. See [current tasks](tasks.md), [T14 evidence](docs/exports-evidence.md) and [export setup](docs/exports-setup.md).

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T16 in tasks.md. T14 is locally committed; do not push automatically. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git and the user-authorized T10 [private source backup checkpoint](https://github.com/naeemhck/carrier-records). Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md) and the current checkpoint evidence in [T10 evidence](docs/corrections-evidence.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
