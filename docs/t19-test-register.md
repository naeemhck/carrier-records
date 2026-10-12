# T19 field-test register

Updated 2026-10-12. T19 **IN PROGRESS**, T20 **TODO**. Every executed assertion in the current continuation is listed in [the executed ledger](t19-executed-tests.md); earlier observations retain their source in [Windows release evidence](windows-release-evidence.md). PASS always has the scope below; preparation or automated local regression does not pass a missing field gate.

| ID | Test | Actual result | Scope / evidence / next action |
|---|---|---|---|
| F01 | Per-user installer/update and public-config preservation | PASS | Agent-executed on development PC, version 0.1.0+4; release evidence |
| F02 | Clean Windows installation and visible launch/login | NOT RUN | Separate clean PC/VM unavailable; development-PC execution is not a substitute |
| F03 | Existing administrator password change and fresh dashboard login | PASS | User-observed installed app plus completed backend password operation |
| F04 | Company setup and existing-admin office assignments | PASS | Read-only hosted verification and normal user saves; no duplicate identities |
| F05 | Signed-in close/reopen restores dashboard | PASS | User-observed development PC |
| F06 | Sign out then close/reopen requires login | PASS | User-observed development PC |
| F07 | Signed-in Windows restart restores session | DEFERRED | User cannot reboot now; no restart performed |
| F08 | Staff password changes, correct office labels, absent admin controls | PASS | User-observed development PC; live ready-profile metadata verified |
| F09 | Actual staff backend administration/global-balance denial and scoped reads | PASS | User-executed existing-account probes; 14 checks in ledger; empty-list limit applies |
| F10 | Hosted draft visible to both origin and destination | NOT RUN | No hosted trip yet; two vehicles now available; create intended new pilot draft |
| F11 | Karachi fare/dispatch allowed, arrival denied | NOT RUN | Existing-user `--trip-checks` once draft exists; local regression passes separately |
| F12 | Islamabad fare/dispatch denied, arrival allowed | NOT RUN | Same; no actual transition is claimed from an authorization probe |
| F13 | Staff excludes unrelated trips/reports | NOT RUN | Two-office shared trip is visible to both legitimately; need valid unrelated case or label isolated result |
| F14 | Installed destination fare save denied with unchanged server values | NOT RUN | Needs valid draft and installed UI; native inventory works but current capture/input geometry fails |
| F15 | Installed role switch does not reuse prior role/session/data | PARTIAL | Distinct dashboards reported; persisted cross-role/reopen sequence not explicitly observed |
| F16 | Disabled staff/removed office invalidates open installed access | NOT RUN | User must exercise designated staff with separate admin session; never disable only admin |
| F17 | Installed draft save during connection loss, no false success, one retry result | NOT RUN | Needs pilot draft/input and user-operated network/UI; see field walkthrough |
| F18 | Installed payment connection loss/recovery, one event/claim consumption | NOT RUN | Needs genuine new pilot financial records; don't post fake money into hosted pilot |
| F19 | Logout while offline cannot revive signed-out access on recovery | NOT RUN | User-operated installed network/session sequence |
| F20 | Cross-version update preserves authenticated secure session/access | PARTIAL | Public-config preservation verified; authenticated session across version upgrade not tested |
| F21 | Installed customized customer multi-page PDF/XLSX/Print-to-PDF | NOT RUN | Needs authorized pilot records and installed export/print execution |
| F22 | Installed customized owner multi-page PDF/XLSX/Print-to-PDF | NOT RUN | Same; must exclude gross customer fares/brokerage |
| F23 | Installed customized broker multi-page PDF/XLSX/Print-to-PDF | NOT RUN | Same; must exclude owner profitability |
| F24 | Installed customized internal multi-page PDF/XLSX/Print-to-PDF | NOT RUN | Same; role/office scope retained, required totals unaffected by hidden fields |
| F25 | Physical customer paper output/privacy/readability | NOT RUN | No physical printer; PDF cannot pass paper gate |
| F26 | Physical owner paper output/privacy/readability | NOT RUN | No physical printer |
| F27 | Physical broker paper output/privacy/readability | NOT RUN | No physical printer |
| F28 | Physical internal paper output/privacy/readability | NOT RUN | No physical printer |
| F29 | New-record pilot draft/consignments/stops/cars and actual dispatch/arrival | NOT RUN | Actual company inputs/operations required; preserve operational/financial distinction |
| F30 | Linked loaded/empty returns and actual expenses | NOT RUN | Genuine new records; no historical import/opening balances |
| F31 | Customer/owner/broker payments/held money/excess credits reconcile | NOT RUN | Actual agreements and private independent control sheet |
| F32 | Personal funding/owner-paid diesel/broker-funded offset remain distinct | NOT RUN | Pilot reconciliations required; prior isolated financial tests are not office sign-off |
| F33 | Audited correction/reversal/dependency unwind and evidence preservation | NOT RUN | Genuine required correction or isolated test labelled separately |
| F34 | Issued/reprinted/superseded customized statements immutable | NOT RUN | Actual pilot issuance; prior T13/T18 results retained separately |
| F35 | Monthly date bases/lifetime trip profit vs settlement reconcile | NOT RUN | Actual pilot records and independent reconciliation |
| F36 | Pilot operator approval | NOT SIGNED | Actual review/sign-off required; no approval invented |
| F37 | Recovery administrator approval | NOT SIGNED | Actual review of T17 evidence/material/limits required; no production scheduling configured |
| S01 | Current isolated office/account/direct-write/session regression | PASS | 169 real API assertions, synthetic empty-loopback fixtures cleaned; not installed field proof |
| S02 | Current isolated real connection-fault/concurrency regression | PASS ON RERUN | 199 assertions including 30 added fault assertions; first attempt fails before fault phase and is retained in ledger; exact initial cause unestablished |
| S03 | Probe-tool valid/invalid configuration/privacy/permission helper tests | PASS ON RERUN | Six mocked tests; first attempt five pass/one sandbox temp-write error, permitted rerun all pass; validation unchanged |
| S04 | Fresh hosted signup/anonymous/perimeter/RLS/ACL/hook/bucket/migration checks | PASS | 13 non-mutating checks, actual pilot endpoint/metadata; no content-privacy proof from bucket config alone |
| S05 | Current staged/installed payload bytes/hash/credential exclusion | PASS | 60 inspections, every file listed in ledger; no client/backend product behavior change or new build claimed |
| S06 | Native screen-control observation/input | PARTIAL / BLOCKED | Current native inventory and installed administrator accessibility observation work; captures time out and indexed click has no geometry. See CU26-01 through CU26-19; no master form/save |

Raw private logs/reports and actual operational result sheets remain excluded from Git. Record future checks by their ID with observed outcome, environment, executor, failure/fix/retest and private evidence reference. Keep all financial confirmations in normal reviewed workflows; do not make test transitions merely to fill a checklist.

Current continuation: [twenty-seven separately recorded installed/tooling attempts](t19-installed-continuation.md). Installed version/public-config validation and administrator accessibility observation PASS within their narrow scope; no draft or money workflow executed. Latest user authorizes labelled synthetic pilot records, superseding prior genuine-operation-only restrictions for this continuation. Clean machine and physical printing PENDING; restart DEFERRED; approvals unsigned.

Latest recovery: user manually opens Company and master records; actual installed accessibility observation confirms the page/configured company. Keyboard focus briefly reaches Back/Offices, later returns to root; latest indexed Parties click rejected as unavailable in cached app state. CU26-20 through CU26-27 recorded separately in docs/t19-installed-continuation.md; no party editor, new record or save. T19 IN PROGRESS; T20 TODO.
