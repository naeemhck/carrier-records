# Installed T19 continuation — 2026-10-12

T19 **IN PROGRESS**; T20 **TODO**. Initial HEAD `3ff991b`; initial working tree clean. Read AGENTS.md, all six planning documents, installation/release evidence, test register/ledger, handoff and restoration evidence. Previously completed staff office/menu/backend-denial and close/reopen/logout checks were retained without rerunning them.

The latest user request explicitly authorizes clearly labelled synthetic master/trip/financial pilot records through normal installed-app workflows. This supersedes earlier runbook restrictions against synthetic pilot examples for this continuation only. Existing accounts must be reused. No synthetic record was created in these attempts.

## Environment and evidence convention

Windows development PC; installed `%LOCALAPPDATA%/Programs/CarrierRecords/carrier_records.exe`; existing hosted Supabase pilot; normal administrator session supplied by the user. No clean Windows PC/VM or physical printer is available. Account U means unauthenticated/unobserved role; account A means the existing administrator observed in the installed accessibility tree. The agent used bundled `@oai/sky` through node_repl, with no alternate automation or development runner. Each E reference identifies the corresponding dated tool call/result in this conversation. No screenshot was obtained or retained; no password, token, key, actual operational identifier or contact field is copied into evidence. Tool attempts establish tooling behavior only, unless explicitly labelled as installed-app observation.

| ID / acceptance scenario | Account | Inputs / expected result | Actual observed result | Status | Evidence | Failure, fix and retest |
|---|---|---|---|---|---|---|
| CU26-01 / AT-35 installed discovery | U | list_apps; installed Carrier Records should be discoverable | Installed path returned; app initially not running | PASS | E01 native inventory | Prior missing-pipe condition no longer reproduced; does not pass launch/login |
| CU26-02 / AT-35 launch attempt 1 | U | launch returned app ID; window should open | Computer Use app approval timed out | BLOCKED | E02 launch tool | No launch inferred; checked outcome in CU26-03 |
| CU26-03 / launch outcome diagnostic | U | list_windows after uncertain launch; detect Carrier window | No matching window | PASS | E03 native window inventory | Confirms no target then; diagnostic only |
| CU26-04 / AT-35 launch attempt 2 | U | Same installed app ID; obtain one current window | One Carrier Records window returned from installed executable | PASS | E04 launch and list_windows | Resolves window discovery only; visible rendering/login unverified then |
| CU26-05 / AT-35 visual observation attempt 1 | U | Select returned window, activate, capture | FrameArrived timed out: timed out waiting on channel | BLOCKED | E05 capture | No screenshot; refreshed window selection for CU26-06 |
| CU26-06 / AT-35 capture recovery | U | Fresh list_windows/get_window; capture screenshot and text | window capture timed out: timed out waiting on channel | BLOCKED | E06 recovery capture | Recovery did not establish observable geometry; app input stopped |
| CU26-07 / AT-35 installed version | U | FileVersion/ProductVersion from installed executable; expect current candidate | Both 0.1.0+4, installed per-user path | PASS | E07 safe file metadata | File evidence, not UI/version-screen or fresh build proof |
| CU26-08 / public configuration shape | U | Inspect shape/booleans only; expect schema 1, HTTPS Supabase host, four fields | Expected shape, HTTPS host, key present, business identifier shape valid; values withheld | PASS | E08 safe config metadata | No network behavior inferred; strict validation follows CU26-12 |
| CU26-09 / permission-helper discovery | U | python tools/pilot_permissions.py --help; expect documented trip flag | Exit 0; existing account choices and --trip-checks available | PASS | E09 help output | No Auth or trip request executed |
| CU26-10 / user-reported repair reobservation | U | Fresh installed window selection and capture after user reports repair | Computer Use reports physical Escape stop | BLOCKED | E10 stopped tool | Stopped all Computer Use immediately; no observation/input inferred |
| CU26-11 / renewed installed window discovery | U | User reauthorizes with app open; list_windows | Exactly one installed Carrier Records window | PASS | E11 window inventory | Same installed executable; no source substitution |
| CU26-12 / strict installed pilot config validation | U | Existing helper load_config; expect exact pilot/schema/public key validation | Exit 0; strict validation PASS; values withheld | PASS | E12 helper validation | In-memory local validation only; no backend probe |
| CU26-13 / AT-35 renewed visual capture | U | Screenshot/text from current installed window | FrameArrived timed out: timed out waiting on channel | BLOCKED | E13 capture | Used documented accessibility-only observation next |
| CU26-14 / AT-35, AT-12 actual administrator observation | A | Refresh selection; accessibility-only get_window_state | Installed tree says signed in, Administrator — all offices; existing admin and two staff accounts; normal admin navigation present | PASS | E14 installed accessibility tree | Actual UI read, not screenshot/layout proof; no passwords entered |
| CU26-15 / master-workflow entry | A | Click observed Company and master records index; expect master page | coordinate input geometry is unavailable | BLOCKED | E15 click tool | Outcome reobserved in CU26-16; no record entry attempted |
| CU26-16 / master-click outcome | A | Accessibility refresh; expect master page if click succeeded | Same administrator landing screen; focus group; master page not opened | BLOCKED | E16 installed tree | Establishes no transition; no save or backend change |
| CU26-17 / keyboard recovery 1 | A | One Tab from observed group; expect a verifiable button focus | Tree refresh succeeds; focus reported at root window | BLOCKED | E17 key and refresh | No reliable selected control; no Enter or typing |
| CU26-18 / keyboard recovery 2 | A | One additional Tab; expect verifiable control focus | Tree refresh succeeds; focus remains root window | BLOCKED | E18 key and refresh | Same page; stopped blind keyboard navigation |
| CU26-19 / raised-window capture recovery | A | Observed root Raise secondary action then screenshot/text | window capture timed out: timed out waiting on channel | BLOCKED | E19 Raise and capture | No observable geometry; no further app input pending user-visible page |

| CU26-20 / restored-page visual retry | A | User opens master page; fresh window selection/capture expected | window capture timed out: timed out waiting on channel | BLOCKED | E20 capture after user page navigation | Accessibility recovery in CU26-21 |
| CU26-21 / actual master-page observation | A | Accessibility-only fresh window observation; expect requested page | Company and master records page, six master navigation controls and configured company label observed | PASS | E21 installed accessibility tree | User performed page navigation; agent did not create or edit company |
| CU26-22 / restored-page keyboard focus 1 | A | One Tab; verify focus before next action | Back button focus observed | PASS | E22 key/refresh | Narrow focus observation only |
| CU26-23 / restored-page keyboard focus 2 | A | One further Tab; expect next control | Back button still reported | BLOCKED | E23 key/refresh | No activation/typing from uncertain focus |
| CU26-24 / restored-page keyboard focus 3 | A | One further Tab; verify next control | Offices button focus observed | PASS | E24 key/refresh | Narrow focus observation only |
| CU26-25 / restored-page keyboard focus 4 | A | One Tab from Offices; expect Parties focus | Focus reported at root window | BLOCKED | E25 key/refresh | No Enter/typing; reobserve next |
| CU26-26 / focus recovery observation | A | Fresh accessibility observation; verify focus and page | Root-window focus and same master navigation page | BLOCKED | E26 installed tree | Could not establish intended editable control |
| CU26-27 / restored-page indexed click | A | Click Parties index from CU26-26; expect party list | element is not available in cached app state for carrier_records.exe | BLOCKED | E27 click tool | No party form/save; reliable control still unavailable |

These timeouts/geometry failures do not establish a Carrier Records application defect. No source fix, regression run or new build is claimed. Accessibility alone successfully reads the live installed session, but the available click path cannot act without geometry. A user-reported logged-in state was independently verified at CU26-14. No permission/lifecycle/financial/export gate is inferred from that observation.

## Unfinished work and retained gates

The requested master records, one Karachi-to-Islamabad synthetic draft, staff matrix, consignments/stops/quotes, returns/overlap, dispatch/arrival, concurrency/corrections, reviewed finance, connection faults, reports and customized outputs remain unexecuted. No record identifiers exist to retain privately yet. Run the documented staff --trip-checks only after the normal UI draft exists and before dispatch; it selects exactly one visible matching draft on an untruncated page. Hidden password entry belongs in the user's local interactive terminal. Prior preflight results remain separate.

No fault was injected. Before a future connection test, explain and review a method limited to this app and its synthetic records; do not disable host networking/security or affect unrelated work. Preserve the original request/form and inspect actual permitted backend state before any canonical retry. Deterministic lost-response injection must be reviewed for feasibility on the installed HTTPS client; the prior isolated T18 proxy tests cannot pass the hosted installed gate.

T17 evidence was reviewed, not rerun: 121.834s original local isolated recovery; T18 current-schema recovery 88.202s. It covers separate-key recovery, schema/history/balances, Auth/office permissions, receipt byte hashes and issued digests. It does not prove recovery of this hosted pilot, a clean/spare PC, or that this pilot's recovery material is protected off-PC. Pilot/operator and recovery administrator approvals remain unsigned and require actual review after results.

Windows restart **DEFERRED**; no reboot. Clean-machine installation and all four physical-printer gates **PENDING**. PDF virtual printing remains a separate unexecuted check. T19 cannot complete while required gates remain open; T20 stays TODO. No push, web redeploy, hosted reset/deletion, extra accounts, financial posting or production backup scheduling.

## Documentation verification before local commit

| ID / scenario | Account/environment | Inputs / expected result | Actual result | Status | Evidence | Failure/fix/retest |
|---|---|---|---|---|---|---|
| CU26-DOC01 / evidence integrity | Agent, source workspace | Unique attempt IDs and linked evidence | Twenty-seven unique CU26 IDs; ten relative links resolve | PASS | Local Python documentation check, exit 0 | No repair needed |
| CU26-DOC02 / release gates | Agent, source workspace | T19 IN PROGRESS and T20 TODO retained | Both task statuses verified | PASS | Local task-state assertions, exit 0 | No missing gate marked passed |
| CU26-DOC03 / whitespace | Agent, source workspace | git diff --check | Exit 0; line-ending normalization warnings only | PASS | Git diff check | No whitespace defect |
| CU26-AUDIT01 / credential exclusion | Agent, source/history | Existing source_backup_audit.py; no findings | Exit 0; 274 tracked files, one intended new evidence file, 511 historical blobs, no findings | PASS | Ignored tools/.local/t10-source-audit.json | No credential/private file included |

Only seven intended documentation files are committed for this continuation. No application source, build or operational data is included.

After the user manually opened Company and master records, the agent independently observed that page. Keyboard focus briefly reached Back and Offices but later reverted to root; the Parties click used the latest observed index and was rejected by the helper cache. No reliable party editor or save was reached. CU26-20 through CU26-27 retain these attempts individually.

Final recovery-document retest: CU26-DOC04 PASS — 27 unique attempt IDs, all ten relative links and T19/T20 gate assertions verified, exit 0. CU26-AUDIT02 PASS — existing source/history audit rerun after recovery edits: 275 tracked files, zero intended untracked files, 511 historical blobs, no findings, exit 0. CU26-DOC05 PASS — staged diff whitespace check exit 0; only line-ending normalization warnings. These checks verify documentation/credential exclusions, not app workflows.
