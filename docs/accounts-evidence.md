# T03 executed account and permission evidence

Date: 2026-10-11. Local Windows development, Flutter 3.47.4 / Dart 3.13.3, Supabase CLI 2.120.0, disposable loopback backend. Migration: `20261011000500_accounts.sql`, after T02 migrations 001–004. No hosted deployment, real staff identities or GitHub publication.

Implemented username/password sign-in, administrator create/edit/disable/enable/office assignment/reset, required temporary-password changes, protected persistence and logout. Ordinary clients contain only public configuration. Admin Auth calls are confined to the Edge runtime and trusted local setup/recovery tool. The server derives business/actor identity from verified sessions; mutable user metadata never grants permissions.

Backend checks include active account, assigned non-archived offices, credential revision, live Auth session, ban state and password-change gate. Status/role/assignment/password changes invalidate target sessions. All ordinary direct table writes remain revoked, including administrator JWTs; future trip/financial commands must use the authorization contract. Three fixed private Auth helpers use the trusted migration owner; other account/authorization functions use a NOLOGIN/NOBYPASSRLS role. Every definer pins an empty search path. Neither role nor private Auth helpers is available for clients to assume/invoke.

## Executed verification

| Check | Actual result |
|---|---|
| Final `supabase db reset --local` | Exit 0; all five committed migrations applied to a clean database |
| `supabase test db` | Exit 0; 69 assertions, including the preserved 43 T02 checks and 26 T03 privilege/RLS checks |
| `supabase db lint --local` | Exit 0; empty issue list, no schema errors |
| `python tools/tests/t03_api.py --native` | Exit 0; account lifecycle, access, recovery and Windows username sign-in/logout UI pass; fixtures removed |
| Final `python tools/tests/t03_api.py` | Exit 0; filtered direct write attempts require HTTP 401/403 and PostgreSQL `42501`, not merely a validation failure |
| `flutter analyze --no-pub` | Exit 0; no issues |
| `flutter test --no-pub` | Exit 0; ten domain, public-config, persistence/error and application harness tests |
| Windows protected-store integration test | Exit 0; real native write/reopen/namespace isolation/delete; synthetic data removed |
| Windows sign-in integration test | Exit 0; username/password UI uses real local Auth/RPC, shows verified assigned offices, persists protected session and clears it on global logout |

AT-12: origin authorization for fare/dispatch and both-office money/expense permissions succeeds; origin arrival and destination fare/dispatch are denied. Unrelated offices cannot access the journey, and direct trip mutation cannot bypass the command contract. RLS returns 1/2/1 permitted trips for origin/destination/unrelated-office fixture staff. Unknown operations are denied.

AT-13: signup, anonymous/disabled access, client account registration/recovery, staff admin elevation, profile/password-flag edits, direct assignment edits and forged JWTs are denied. Changing Auth user metadata cannot grant admin access. POST/PATCH/DELETE attempts against events, journal lines, allocations and idempotency results are denied for origin, destination, admin and anonymous callers. A private synthetic receipt downloads only for permitted office staff; unrelated/anonymous/disabled retrieval and persistent signed-URL creation fail. Lost assignments, resets, changed passwords and logout invalidate old access/refresh paths. Self-disable/demotion, stale versions and null versions are rejected. Audit/account-list JSON contains no passwords/tokens/Auth identities.

AT-14: staff requesting `ALL` or a null scope is denied. `ASSIGNED` returns explicit incomplete-scope labelling and exact decimal-string totals: customer receivable `100.00`, owner payable signed journal total `-100.00`. Admin `ALL` returns complete totals `800.00` / `-800.00`. Raw global event metadata is closed. These are authorization-layer journal fixtures, not a completed T07 posting engine or T11 report interface.

A simulated interrupted Auth/database password operation locks the target before the external update. Direct client recovery fails; trusted recovery sets a new temporary password, unlocks with an audit, revokes sessions and retains the mandatory-change gate. No partial update is reported as success and no password is stored in the operation table.

## Failures and corrections retained

- Initial migration ownership/execute grants failed; temporarily granted the dedicated role to the migration runner, assigned owners/grants, then revoked membership. Client role membership stays denied.
- Local CLI restart reset Auth ACLs and Auth RLS prevented direct custom-role lookups. Replaced those accesses with three fixed, private, trusted helpers. Verified after clean reset; no bypass-RLS application role was introduced.
- Disabling the local email provider also disabled password login (`email_provider_disabled`). Enabled that provider while keeping global signup disabled; actual signup requests remain rejected. This CLI mapping is described in the [Supabase issue](https://github.com/supabase/supabase/issues/40582).
- One function-serve launch overlapped stack startup and caused an Edge container-name conflict. Stopped the failed runtime and restarted sequentially; no installer/download duplicates were started.
- An empty PATCH produced a successful no-op, and unfiltered updates/deletes hit PostgreSQL's safe-update guard. Final tests change a real column with a WHERE filter and demand permission-denied `42501`.
- SQL serialization code did not give the expected HTTP conflict status. Account RPCs now use explicit `PT409`; stale and null version requests are tested.
- Recovery initially had an ambiguous `target_id`; qualified the operation-table column. Database lint and trusted recovery tests pass after the fix.
- UTF-8 shell/script encoding and brace-style analyzer findings were corrected; no lint rule was suppressed. T02 behavior remains covered.

Windows persistence uses the native secure-storage plugin's encrypted storage with a Windows Credential Manager protected encryption key; the actual native test passed. Android uses its protected platform store, disables backup and fails storage errors without a plaintext fallback. Android device execution, release signing/installation, hosted configuration, T06 dispatch/arrival state transitions, T07 financial commands, T09 uploads and T11 full reports remain NOT RUN. The first real administrator still requires the user's actual setup inputs; see [accounts-setup.md](accounts-setup.md).

## Final builds, package audit and cleanup

- Windows debug build: exit 0, 39.1 seconds. Android debug build: exit 0, 42.2 seconds.
- Final package/source scan: 658 APK entries, Windows files and tracked source files; no actual local service-role/secret/JWT-signing/S3-secret values (UTF-8 or UTF-16) found. No server code is placed in client configuration.
- Final HTTP suite: 156 passing assertions, including filtered mutation requests returning PostgreSQL permission error 42501. Windows integration run also passed; logs stay ignored under tools/.local.
- Post-test Auth/REST/Storage each HTTP 200; PostgreSQL ready. Auth users, businesses, private password operations and receipt objects: all zero. Migration history: five.

Final debug artifact SHA-256 values (the executable loader is unchanged when only Dart assets change):

- `app/build/windows/x64/runner/Debug/carrier_records.exe`: `7040a70dfc5fb01749ca31af9fe25585a3d1a3db83bf858a39f2e3104b18bec2`

- `app/build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin`: `68a8c2e34e5419cd70eeca89e2b3b11b7ca4b4724b3795850570e3ff4dbf3b9d`

- `app/build/app/outputs/flutter-apk/app-debug.apk`: `27c82c70be3ec95f6f2957610f489d086f495300185d8cd9cc8a605bcbd1f6c1`
