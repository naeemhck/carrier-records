# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T13 are complete, including scoped monthly/lifetime reports, dashboard navigation, authorized output previews and personal/company presets. Customer debt, custody, owner settlement, profit and brokerage stay distinct. Analyzer, 61 Flutter tests, 194 SQL assertions, 1,347 final backend checks, real Windows output/preset flow and both debug builds pass. The isolated five-user annual benchmark meets the local p95 targets. See [current tasks](tasks.md), [reports](docs/reports-setup.md) and [T11 evidence](docs/reports-evidence.md). See [outputs and presets](docs/outputs-setup.md) and [T12 evidence](docs/outputs-evidence.md). Immutable issuance is implemented; PDF/Excel files, production deployment and release distribution are pending.

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T14 in tasks.md. T11/T12 commits stay local; do not push automatically. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git and the user-authorized T10 [private source backup checkpoint](https://github.com/naeemhck/carrier-records). Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md) and the current checkpoint evidence in [T10 evidence](docs/corrections-evidence.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
