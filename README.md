# Carrier Records

Internal records, trip billing, expenses and monthly reporting for a car-carrier transport business in Pakistan. Initial rollout: two offices, five staff accounts and twenty vehicles, with PKR as the currency.

## Project status

T00-T09 are complete: local tooling, managed accounts, masters, scoped trips/lifecycle, immutable finance/payments and confirmed expenses with private receipts and original-expense reimbursement/offsets. Customer debt, custody, owner settlement, profit and brokerage stay distinct. Analyzer, 50 Flutter tests, 148 SQL assertions, 890 combined backend/native assertions, 309 final expense authorization checks and both debug builds pass. See [current tasks](tasks.md), [expense entry](docs/expenses-setup.md) and [T09 evidence](docs/expenses-evidence.md). Production deployment and release distribution are pending.

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

Open this repository folder in VS Code and use the Codex extension. Read memory.md, PRD.md and rules.md first, then continue from T10 in tasks.md. Use the existing Flutter SDK and local Supabase setup documented in [tooling setup](docs/tooling.md).

Flutter/Dart is the client stack; Supabase provides the local backend during implementation. Core package versions and the application lockfile are pinned. Use local Git; the T05-T09 commits are not pushed. An earlier user-authorized [private source backup](https://github.com/naeemhck/carrier-records) is configured. Keep secrets, signing material, live customer records and backup archives outside version control. Public publication is not authorized. See [source backup review](docs/source-backup.md).

Update the affected planning documents and memory.md when requirements or implementation status change. Record actual test and build results; defined tests are not passed tests.
