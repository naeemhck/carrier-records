# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

The six planning documents are complete. T01 has a Windows/Android Flutter scaffold and local Supabase tooling. Analysis and the application harness test pass; native builds and backend deployment are not complete. Windows is the first release; Android follows the Windows pilot. See [tooling setup](docs/tooling.md) and [executed evidence](docs/tooling-evidence.md).

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T01 in tasks.md. Verify the existing Flutter SDK with flutter --version and flutter doctor before creating the Windows/Android application.

Flutter/Dart is the client stack; Supabase will provide the shared online backend. Core package versions and the application lockfile are pinned. Use local Git; do not publish to GitHub. Keep secrets, signing material, live customer records and backup archives outside version control.

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
