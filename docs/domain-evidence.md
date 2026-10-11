# T02 schema and domain verification

Date: 2026-10-11. Environment: local Supabase PostgreSQL 17 on this Windows workstation; Flutter 3.47.4 / Dart 3.13.3. Local Git only. No hosted database is linked.

Four migrations establish exact-value functions, 27 application tables, business-scoped foreign keys, operational versions, owner/price snapshots, immutable financial/document/audit history and indexes. Party-role foreign keys enforce owner, customer, broker and driver eligibility. Tables have RLS enabled and client grants revoked; T03 must deliberately implement staff/office policies and command authorization. A schema is not a usable account, posting engine or document workflow.

Dart domain values use integer paisa bounded to NUMERIC(18,2), with BigInt intermediate percentage multiplication and half-up rounding. Money interfaces accept decimal strings, reject extra decimal places/scientific notation/nonfinite values, and emit two-place strings. Percentages accept 0.00–100.00. Business dates validate calendar days without converting them through a device time zone. Quotes retain deducted/added bases and separate customer charge, owner entitlement and brokerage. UUID/context/version/envelope types prepare later commands without initializing a backend session.

Executed evidence:

| Check | Result |
|---|---|
| Initial `supabase db reset --local` | Failed during Supabase initialization, before app migrations; generic DbSetupError. Database logs included Realtime initialization errors. No app migration success claimed from this attempt |
| Reset retry, then reset after lint corrections | Exit 0; clean local database initialized and first three migrations applied |
| `supabase migration up --local` | Exit 0; fourth role-link migration applied to the empty database |
| First SQL test run | 41/42 assertions passed; one fixture UUID was malformed. Corrected the fixture |
| Final `supabase test db` | Exit 0; 43 assertions passed |
| Initial database lint | Two volatility warnings. Replaced the date cast with exact calendar construction and declared JSON quote construction STABLE |
| Final `supabase db lint --local --level warning` | Exit 0; empty issue list, no schema errors |
| `flutter analyze --no-pub` | Exit 0; no issues |
| `flutter test --no-pub` | Exit 0; five domain tests plus setup-route widget test, six total |
| Dart format / final format check | Five files formatted; final check reports zero changes |
| Fixture isolation | SQL fixtures wrapped in BEGIN/ROLLBACK; afterward business count 0, Auth user count 0, migration history count 4 |
| Post-reset local health | Auth, REST and Storage each HTTP 200; PostgreSQL accepting connections; health-checked containers healthy |

SQL checks execute AT-01/02/03 quote calculations and AT-17 decimal parsing/sum precision, including half-paisa boundaries and maximum values. They also exercise canonical server snapshots, cross-business links, party-role eligibility, version conflicts, default-deny grants/RLS, historical owner independence, immutable issued snapshots and a synthetic balanced/unbalanced journal constraint. Dart checks cover matching examples, overflow, invalid money/date formats and command versions.

These are T02 domain/schema checks. The actual dispatch/receipt/allocation commands, concurrency/idempotency consumption, staff permission matrix, output issuance and financial corrections remain later tasks. Do not mark full AT-01 dispatch workflow or AT-17 allocation-mismatch workflow passed from a fixture journal or a money parser. No production data, privileged credentials, native release or restoration is included.

Run from the repository root with `tools/supabase.ps1 test db` and `tools/supabase.ps1 db lint --local --level warning`. Run Flutter analyzer/tests from `app/` using `../tools/flutter.ps1`. Reset only the disposable local database; test fixtures are never production seed data.
