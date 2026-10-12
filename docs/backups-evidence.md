# T16 backup helper verification ? 2026-10-12

T16 completion gate PASS. T17 remains TODO: no database restoration or restored authentication has been executed. Production helper configuration, schedule installation and off-PC copies remain operational setup steps in [backups-setup.md](backups-setup.md). No production identities, credentials or receipt data were used. No GitHub push.

## Original scheduling failure, cause and fix

The original combined regression failed `AT31 last verified success truthful after failures`. Following the deliberate abrupt-exit fixture, the temporary schedule was not registered and the last attempt remained RUNNING. The helper test originally mislabeled any registration failure as `SCHEDULE_REGISTRATION_PENDING`, obscuring a configuration error rather than an administrator permission failure.

Setup and the real helper fixture both write `supabase_url`. Version-1 `validate_config` omitted that required field from its allowed-key set, so `backup.py check` returned `CONFIGURATION_INVALID` before credentials/admin verification. `install-schedule.ps1` correctly stopped registration. This was not an Access denied error and did not require elevation.

Fix: admit and require `supabase_url` in the same versioned contract; validate safe endpoints through one function shared by configuration and transport. Keep unknown/inline-secret fields rejected, drive/home/Git path restrictions, time/retention checks, protected credential storage and live managed-administrator authorization. Add type/UUID validation. Validate the real fixture configuration before using credentials and fail the test on unsuccessful task registration instead of silently reporting it as pending. Windows PowerShell's UTF-8 BOM configuration remains supported by the existing UTF-8-sig reader.

Regression red/green: the new setup-configuration and valid-boundary cases failed against the original validator (11 tests, two errors, `CONFIGURATION_INVALID`); after the fix all 11 tests pass (final 6.483s). Cases include local/hosted valid endpoints; required fields; unknown and inline-service-key fields; unsafe HTTP, embedded credentials, query/fragment/path, missing host and malformed port; invalid UUID, time and retention bounds/types; mismatched status path, home/drive/Git paths and a nonboolean fixture flag. An isolated fixture flag permits synthetic Git-contained test artifacts, without bypassing backend administrator checks.

## Executed verification

| Check | Actual result |
|---|---|
| Bundled Python `tools/tests/t16_helper_test.py` | 11 tests PASS; actual Windows Credential Manager write/read/delete; AES-GCM tamper/wrong-key denial, portable recovery passphrase checks, incremental blobs, interrupted/failure retention, 30-day retention and daily due handling |
| `python tools/tests/t03_api.py --backups` | Exit 0, 181 main-harness PASS lines; initial fixed scheduler verification and cleanup |
| Full T03?T16 regression below | Exit 0, 1,486 main-harness PASS lines plus 32 separately logged real-helper PASS checks; complete fixture cleanup |
| Real temporary Task Scheduler | Invalid config rejected without registering a task. Valid configuration checked as administrator, enabled daily/logon/hourly task, Interactive account and StartWhenAvailable verified. Actual scheduled backup succeeds after simulated 48-hour offline gap; immediate scheduled retry returns NOT_DUE without a new attempt |
| Actual backup artifacts | Local PostgreSQL custom dump, required Auth identities and staff-office data present in TOC; active sessions/refresh-token data absent. AES-256-GCM archive/receipt integrity, size and SHA-256 verification pass. Second backup downloads zero unchanged receipt bytes; one new receipt is copied once |
| Failure and authorization behavior | Controlled interruption, abrupt exit, missing receipt, success-report failure and configured staff identity denial do not invent success or erase prior verified success. Service-only status reporting, direct table mutation denial, administrator-only reads, report retry/body checks, stale and quota indicators pass. Backup does not alter financial events/journals/allocations |
| Local database | Clean 18-migration reset; latest `tools/supabase.ps1 test db`: 219 assertions/15 files PASS; `db lint --local`: exit 0, no errors. Default warning-level lint reports unused T16 `result`/`k` locals and existing import/correction/document/export warnings; these do not change behavior. Recorded security advisors empty |
| Flutter | Analyzer no issues (22.3s), 78 tests PASS (1m18s), including manual failure/status behavior |
| Native debug builds | Windows 53.1s and Android 63.0s, exit 0 using existing SDKs. These include the T16 UI; later fix changes only separately executed Python helper/configuration tests, requiring no client rebuild |
| Package/source audit | APK/Windows/source privileged-value audit: 809 entries in final audit, no actual privileged value. Source/history audit: 230 tracked files, zero intended untracked, 367 historical blobs, no findings; repeated after evidence updates before commit |
| Final health/cleanup | Auth/REST/Storage HTTP 200; PostgreSQL ready; 18 migrations; all public/private/Auth/Storage fixture rows zero; no disabled triggers, temporary SET privileges or native config. Actual temporary schedule and vault credentials removed; no production CarrierRecordsBackup task remains |

Full command:

```powershell
python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --corrections --reports --reports-functional --outputs --documents --exports --imports --backups
```

Safe local logs under ignored `tools/.local`: `t16-config-red.log`, `t16-helper-tests.log`, `t16-api-focused.log`, `t16-api-final.log`, `t16-real-helper.log`, `t16-db-tests.log`, `t16-db-lint.log`, `t16-analyze.log`, `t16-flutter-tests.log`, `t16-windows-build.log`, `t16-android-build.log`, `t16-package-audit.log`, `t16-source-audit.log`, `t16-health.log`. Synthetic archives and separately wrapped fixture recovery files stay ignored, and all fixture vault values are deleted. Credential bytes were inspected in memory and never included in evidence.

## Scope and remaining setup

Success requires authenticated encryption, ZIP/dump structure, every receipt hash and a committed trusted server success report. `pg_restore --list` is an integrity check, not restoration. Backup traffic is a lower-bound estimate including dump, downloaded objects and measured HTTP bodies; incomplete attempts and unknown other traffic are disclosed. No paid service is enabled. Retention removes only local backup artifacts after verified success, never source financial records or Storage receipts.

For real deployment, follow the exact installation/configuration/manual-run/scheduling commands in the setup guide. If real registration reports Access denied, run PowerShell as administrator **using the same dedicated Windows account** and rerun schedule installation. No administrator elevation was needed for the passing isolated task registration. No production schedule is claimed active. Physical-printer/Android-device checks stay T19/T20. T17 restoration rehearsal remains TODO and must precede production use.
