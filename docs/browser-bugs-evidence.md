# Browser QA and delivery — 2026-10-12

Latest status: build6 local and fresh-live critical UI verification completed; installed checks confirmed by user (native capture unavailable). Rollback comparison mechanism reproduced and corrected without backend changes; 633 API checks pass. Private source push and Pages deployment completed. See [continuation evidence](qa-build6-resume.md) for every new result, failures, cleanup and delivery identifiers. Earlier pending statements below describe the interrupted prior turn. T19 IN PROGRESS, T20 TODO, restart DEFERRED; clean-PC, physical-printer and pilot/recovery sign-off gates remain pending. No production backup scheduling/reset/deletion.

## User-reported observations (not agent-executed)

Environment: hosted desktop-browser app https://carrier-records.pages.dev, 2026-10-12; actors administrator and Karachi-only staff. Islamabad-only staff was not tested. Source: the user's pasted QA request, no independent screenshot evidence supplied. These observations do not pass installed Windows/clean-machine/printer/pilot gates.

| ID | Steps | Reported result |
|---|---|---|
| R01 | Correct credentials, wrong password, empty login fields, logout | Login/validation/logout worked |
| R02 | Inspect Karachi staff navigation | Administrator account/backup controls absent |
| R03 | Review/save loaded Karachi-to-Islamabad draft TRP-000001; reload | Vehicle selected; customer charge50,000/brokerage0/owner50,000; draft persisted |
| R04 | Cancel draft with reason | Trip and consignment CANCELLED |
| R05 | Create/edit/archive TEST-VEH-DELETE | Hidden from default list, history retained |
| R06 | Open empty reports and party lists | Expected empty state/PKR0.00; lists rendered |
| R07 | End reported QA | Test trip cancelled; test vehicle archived |

Reported previously untested: dispatch/arrival and invalid arrival dates, overlap handling, excess decimals, expenses, receipts/allocations, owner settlement, recipient/PDF/XLSX outputs, imports, correction history, backup contents and administrator self-demotion/disabling. Keep these pending unless individually executed below. No new account or privileged configuration has been created for this work.

## Bugs and current findings

| Bug | Reproduction / cause / action |
|---|---|
| B01 confirmation never enables | Original hosted staff dialog stayed disabled after date/reason alone, then enabled after server review and acknowledgement. Permanent-disable allegation NOT REPRODUCED; required review is intentional. Improve instructions/current input validation and reason-change rebuilding; retain server review, prices, overlap acknowledgement, permissions, version/idempotency and commit guards. |
| B02 destination UUID | REPRODUCED in hosted Karachi staff form: authorized directory returns a readable destination, but selection loses its label; assigned-origin list lacks destination, so form falls back to UUID. Retain authorized picker label and detail destination_name in TripDraft; no hardcoded names/IDs or additional grants. Red regression fails original code. |
| B03 cannot dismiss | Hosted original Escape FAIL while idle; idle Cancel PASS on one click. Original route's non-dismissible barrier blocks default Escape. Busy flag also blocks cancellation during a review that posts no earnings. Add focused Escape handling and separate review busy from posting; allow cancelling review, block dismissal during actual posting. Red Escape regression fails original code. |
| B04 origin overlay | NOT REPRODUCED in initial hosted test: origin selection dismissed popup, next form actions worked. No speculative dropdown/hit-test rewrite. Continue release retest. |
| B05 repeated clicks | NOT REPRODUCED in initial hosted test: Trips, New draft, pickers and idle Cancel worked on one click. Loading/transitions observed separately; do not interpret async completion as missing click. Continue release mouse/keyboard retest. |
| B06 programmatic password fill | Rejection NOT REPRODUCED. Ordinary typing, keyboard clipboard paste and browser paste displayed masked synthetic input. AX setValue returned success, but authentication/persistence through that method was not tested. No synthetic credential submitted. Real passwords remain user-entered and never read/saved/logged. No authentication change. |

## Agent-executed checks and attempts

| ID | Environment/actor and steps | Actual result |
|---|---|---|
| Q01 | Native skill inventory and launch installed0.1.0+4 | Inventory/launch exposed installed window; screenshot FrameArrived timeout. Fresh recovery selection no longer had exactly one window; no stale-coordinate input. Native QA BLOCKED at this stage. |
| Q02 | Original hosted app, user signs in as existing Karachi-only staff | Dashboard observed with Karachi assignment and absent administrator controls; no password read |
| Q03 | Single click Trips then New draft | Both pages opened; no duplicate click needed |
| Q04 | Pick authorized cross-office destination | Name in picker, raw UUID in form: B02 reproduced; no private IDs copied into Git |
| Q05 | Open/select origin | Popup dismissed; following notes/vehicle/customer actions worked: B04 unconfirmed |
| Q06 | AX setValue notes then real keyboard entry | AX value did not persist; ordinary click/typeText persisted labelled synthetic QA note |
| Q07 | Choose existing pilot vehicle/customer, type50,000.00 | Exact preview customer50,000/brokerage0/owner50,000 observed; typed fare persisted |
| Q08 | Draft review first attempt | Generic failure, inputs retained, no false save. Exact cause unestablished |
| Q09 | One unchanged draft-review retry and confirm | Review showed exact totals; saved TRP-000002 DRAFT/LOADED with one consignment and QA-20261012 label. No earnings posted |
| Q10 | Open Dispatch, type reason, request server review, acknowledge | Initially disabled; server review completed; acknowledgement enabled confirmation. No dispatch submitted |
| Q11 | Original idle dispatch Escape then Cancel | Escape no effect; Cancel one click dismissed; trip still DRAFT, no mutation |
| Q12 | Isolated backend acceptance initial attempt | Stopped before fixtures: Docker engine absent. Started existing installed Docker; no reset |
| Q13 | After startup, two isolated acceptance attempts | Seven setup/cleanup checks then503 at current-credential test; cleaned synthetic identities/business each time. Not lifecycle PASS |
| Q14 | Diagnose actual503 | Anonymous response “name resolution failed”; Kong DNS error for Edge container. Docker inspect confirmed existing Edge stopped255 with no network endpoint. Restarted that container; no permissions/configuration weakened |
| Q15 | Original-code regression tests for B02/B03 | Both FAIL as expected; retained ignored red log |
| Q16 | First fix/focused run | Destination passes; Escape focus and validation-frame test helpers fail. Added focused shortcut child and pumped the validation frame; eight focused tests then PASS |
| Q17 | Extend pending-review/validation regressions | First extension had misplaced Dart import; compilation fails, six existing lifecycle tests pass. Corrected import placement; final full suite passes at Q21 |
| Q18 | Financial backend run after Edge recovery | Draft/lifecycle/authorization/idempotent dispatch cases pass, then strict T07 rollback snapshot comparison fails. Cleanup passes. Added safe boolean/order diagnostic while retaining original assertion; no product/SQL change |
| Q19 | Isolated financial diagnostic retry |306 PASS assertions, exit0, original strict rollback assertion passes. No differing-row diagnostic emitted; initial failure cause remains unestablished |
| Q20 | Repeat original combined draft/lifecycle/finance conditions |615 PASS assertions, exit0, strict rollback, balanced journals, duplicate retries, authorization, arrival and fixture cleanup pass. No diagnostic emitted; retain initial failure as limitation rather than inventing a cause |
| Q21 | Full Flutter tests/build5 then final build6 |91 tests PASS each run (3m05s / 2m21s). Includes label, idle Escape, cancel/Escape during pending review, current input/review requirements and Escape blocked during posting; existing commit/idempotency/conflict tests retained |
| Q22 | Analyzer | Build5 initially one missing-braces formatting info; fixed. Final build6 analyzer no issues, exit0,25.0s. Flutter's documented SDK analysis-options migration added web/** alongside existing generated-platform exclusions; no application/test exclusion added |
| Q23 | Build5 candidate | Built and preserved, never installed/published. Final formatting fix required a fresh unused build6; no existing artifact overwritten |
| Q24 | Production web build6 |PASS exit0,261.3s, unchanged public-only defines; optional Wasm dry-run skipped. Exact LF SPA rule retained |
| Q25 | Web artifact/privacy audit |PASS43 files/45,078,529 bytes/no findings; main.js SHA2563d8fd319e2a2201311f2d5f417a2d818c152e9423de1c2659b1ddb5d0180cb37. version.json confirms build6 |
| Q26a | Original hosted password ordinary keyboard typing |Masked synthetic input displayed, PASS; no credential used or login submitted |
| Q26b | Password clipboard text plus keyboard Ctrl+V |Masked synthetic paste displayed, PASS; user clipboard contents not read |
| Q26c | Password browser paste action |Masked synthetic paste displayed, PASS; no authentication change |
| Q26d | Password AX programmatic setValue |Returns success; controller/authentication persistence UNVERIFIED. Synthetic text cleared, no login submitted |
| Q27 | Actual local release at127.0.0.1:8765 |User enters existing Karachi staff credentials; assigned-office dashboard/no admin controls observed. Single-click Trips and QA draft opening work. Updated destination picker/dispatch/dismissal/posting verification NOT COMPLETED |
| Q28 | Windows release6/Inno package |PASS289.7s native build/22.485s installer compilation; artifact14,127,143 bytes. Staged audit30 files PASS |
| Q29 | Authorized development-PC4→6 installation |Installer exit0, installed file version0.1.0+6, existing public-config SHA preserved. Installed+staged audit60 exact-hash/credential checks PASS. Not clean-PC or secure-session proof |
| Q30 | Launch updated installed app through Computer Use |User physical Escape stops Computer Use; stopped all screen input immediately. Launch outcome unknown, no native sign-in/affected-workflow PASS |
| Q31 | Source/history credential audit and private destination |275 tracked/two intended new files/518 historical blobs/no findings at that run. Existing credential-manager API verification confirms intended account, PRIVATE naeemhck/carrier-records/defaultmain; origin exact expected URL. No push |

Financial records will be preserved through documented cancellation/reversal workflows; never delete posted QA events. The labelled draft currently remains available for updated-artifact tests. No receipts/payment/settlement/arrival or cleanup mutation is claimed yet. Exact identifiers/configuration/diagnostics remain ignored and local; no credentials or identifying operational screenshots committed.

## Delivery gates

Verified build6 installer: `app/build/windows/installer/0.1.0+6/CarrierRecords-0.1.0+6-windows-x64-setup.exe`; SHA-256 **14ab24e537845103e1692f5419f0b5a256ed5b1a9a62cdf65f624a48755df233**. Installed executable `%LOCALAPPDATA%\Programs\CarrierRecords\carrier_records.exe`. Public configuration remains outside binaries. Build5 and all earlier installers preserved. No GitHub release artifact upload requested/performed.

Remaining delivery gates: complete updated local release destination-label/origin/dispatch/dismissal/invalid-input/commit checks; observed installed launch/login/session/native workflows; any unavailable destination-account UI arrival check explicitly pending; final reviewed-source push/private remote-SHA verification; upload exactly this audited web artifact and verify new live assets/critical UI in fresh session. No Pages deployment for this delivery: prior production deployment9b1fcaf9-b04d-4251-a08a-dfef8472d2b3 remains untouched. Do not rebuild under different configuration or claim HTTP200 alone proves updated behavior. User-reported browser QA and this PC's update do not replace clean-PC/physical-paper/pilot/recovery sign-off.

Resume after the user authorizes screen control again: use the existing local release tab and labelled TRP-000002 draft (still DRAFT, no dispatch/receipt/settlement). Run updated UI checks, observe installed build6, then complete authorized push and Pages update after gates pass. Preserve financial records through audited correction/reversal; no synthetic posting was made in the hosted pilot during this turn. The initial rollback comparison failure remains recorded despite two subsequent strict passing runs.
