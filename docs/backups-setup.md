# Administrator Windows backup helper

The ordinary Windows/Android app contains only authorized status reads and a launcher for a separately installed helper. It contains no database password, service key, encryption key or backup/recovery archive. Use a dedicated administrator Windows account that staff do not share. Credential Manager protection is per Windows logon account, not a boundary between programs running as that same account.

No production helper, credentials or schedule have been configured by development tests. Temporary isolated test tasks and vault entries are removed. These are the exact setup steps, run locally on the administrator PC after the real managed administrator and business exist:

1. Open PowerShell as the dedicated administrator Windows user. Use a Python installation with venv/pip (Python 3.13 is supported). Install the separate per-user helper:

   ```powershell
   & 'D:\portfolio\transport_project\tools\backup\install-helper.ps1' -PythonExe (Get-Command python).Source
   ```

2. Configure it using local hidden prompts. Enter the business UUID, backend URL, managed administrator username/password, publishable key and privileged service/secret key in that terminal. Do not paste these into chat or commit them. Choose a NEW dedicated empty backup folder outside every Git working tree, and a separate recovery key file location outside that folder and outside Git. Use a unique recovery passphrase of at least 12 characters; retain that passphrase separately.

   ```powershell
   $helperDir = Join-Path $env:LOCALAPPDATA 'CarrierRecords\BackupHelper'
   $helperPython = Join-Path $helperDir 'venv\Scripts\python.exe'
   $helperConfig = Join-Path $helperDir 'config.json'
   & $helperPython (Join-Path $helperDir 'backup.py') setup --config $helperConfig
   ```

   For the existing loopback stack, choose the existing Docker PostgreSQL utilities and container `supabase_db_transport_project`; no duplicate database installation is needed. For a hosted backend, provide a compatible PostgreSQL client bin directory, database connection parameters and database CA certificate. Remote connections require TLS verification. Database passwords are never command-line arguments. Configuration stores credential target names only; values and the AES-256 key live in Windows Credential Manager. The portable recovery key is wrapped with Scrypt and AES-256-GCM, so losing this PC's credential vault does not by itself destroy recovery capability. Losing the recovery passphrase does.

3. Run a manual backup, then read its result and administrator app status. A process starting or an archive filename is insufficient evidence:

   ```powershell
   & (Join-Path $helperDir 'run-backup.ps1')
   Get-Content (Join-Path $helperDir 'local-status.json')
   ```

4. Install the configurable daily schedule (default 18:00 in the explicitly displayed PC time zone):

   ```powershell
   & (Join-Path $helperDir 'install-schedule.ps1') -ConfigPath $helperConfig -PythonExe $helperPython -DailyTime '18:00'
   $scheduleName = (Get-Content $helperConfig -Raw | ConvertFrom-Json).task_name
   Get-ScheduledTask -TaskName $scheduleName
   Get-ScheduledTaskInfo -TaskName $scheduleName
   ```

   The script verifies the configured administrator, registers the current Windows account with Interactive/limited privileges, verifies that the task is enabled, and displays the actual time zone. It combines daily, logon and hourly retry triggers with StartWhenAvailable, network availability, duplicate-run prevention and bounded retries. The helper checks whether the daily backup is due before making network requests. It catches up after a missed run when this PC is online and the dedicated administrator Windows account has a logged-on session. It does not run while the PC is off or the account is logged out, wake the PC or keep a hosted backend awake artificially. Change the time through this script so the helper due calculation and schedule remain aligned.

   If registration reports Access denied, open PowerShell with **Run as administrator using the same dedicated Windows account**, recreate the three `$helper...` variables above and rerun step 4. Do not switch to another Windows account: its credential vault cannot read this account's entries. Until registration and `Get-ScheduledTask` succeed, no active schedule is claimed.

5. Copy both the `archives` and `objects` directories off the PC. Copy the encrypted recovery material to a separately held recovery location and keep its passphrase separately from those backups. Complete T17's isolated restoration rehearsal before production use. The helper has no production restore command.

Manual backup in the app invokes this helper and then refreshes the authoritative verification status. It shows success only after authenticated encryption, ZIP/dump integrity, receipt hashes and the trusted server success report complete. Missing-helper, interrupted, copy, export and reporting failures preserve the previous verified success. An abrupt process exit can leave RUNNING; the server labels it potentially interrupted after two hours and stale after 26 hours without success. Local `local-status.json` also records offline/credential failures that cannot be delivered to the server.

Each archive is an AES-256-GCM encrypted ZIP containing the custom-format database export, restore-role/schema/identity metadata and encrypted manifest. Required Auth users/identities are retained; active sessions, refresh tokens and pending authentication challenge/state data are excluded. Receipts use separately encrypted content-addressed blobs, opaque paths in the encrypted manifest and SHA-256/size verification. Reused blobs are decrypted and checked before being trusted. ZIP and `pg_restore --list` checks validate archive structure, not usable restoration.

Retention defaults to the latest successful snapshot for each of 30 successful local calendar days. Manual snapshots on the same day replace the older daily snapshot only after verified, reported success. Unreferenced local encrypted blobs are collected only after verifying retained manifests. Failed/interrupted attempts do not prune prior successful backups. Source database records and Storage receipts are never deleted by retention. A retention failure keeps the new verified backup and records a safe local warning; review available disk space and retry cleanup on the next run.

The administrator display includes database size, stored-file bytes and monthly reported backup traffic. Dump output is uncompressed before archive encryption; bytes include receipt downloads and helper HTTP response bodies. It remains an estimate/lower bound, excluding protocol overhead and possibly incomplete interrupted transfers. Other provider/application traffic is unknown unless separately supplied in trusted configuration; check the provider dashboard. Warnings use the documented free baseline (500 MB database, 1 GB files, 5 GB uncached egress), at 75% and 90%; no paid upgrade is enabled. Update known limits deliberately when provider terms change.

After an administrator password reset and required password change, update the helper's managed credentials without changing its backup encryption key:

```powershell
& $helperPython (Join-Path $helperDir 'backup.py') update-auth --config $helperConfig
```

Service/database credential rotation also requires securely updating the corresponding Credential Manager entries. Never recreate the key or point a newly generated key at old archives. Use the original separately held recovery material in the T17 recovery procedure.

Primary references: [Windows Credential Manager](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew), [Task Scheduler catch-up settings](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/new-scheduledtasksettingsset?view=windowsserver2025-ps), [authenticated encryption](https://cryptography.io/en/latest/hazmat/primitives/aead/), [Supabase backup limitations](https://supabase.com/docs/guides/platform/backups), [current provider quotas](https://supabase.com/pricing).

## Configuration contract (version 1)

Setup writes a JSON object with `format_version: 1`, the business UUID, required `supabase_url`, credential target prefix, backup/config/status paths, daily `HH:MM` time, displayed time zone and a `CarrierRecordsBackup-<UUID>` task name. `status_path` must be `local-status.json` beside the config. Endpoints must be HTTPS, or HTTP on localhost/127.0.0.1 only, without embedded credentials, query, fragment or path. Both setup and scheduled/manual checks validate the same contract before credential use.

Optional fields are `postgres_bin`, `docker_container`, `retention_days` (integer 1?365, default 30), `egress_budget_bytes`, `other_egress_bytes`, `python_exe` and the boolean `isolated_test` used solely by isolated development fixtures. Ordinary configuration and backup paths cannot be inside Git, the backup root cannot be the drive root or home folder, and unknown fields?including inline passwords/service keys?are rejected. Actual privileges still require an authenticated, enabled administrator for this business; the fixture flag never bypasses that authorization or credential protection.
