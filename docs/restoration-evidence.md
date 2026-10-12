# T17 restoration evidence — working record

Status: DONE. The complete AT-32 rehearsal passed; T18 follows as a separate gate.

Executed command:

```powershell
python tools/tests/t03_api.py --corrections --reports --reports-functional --outputs --documents --restore
```

The guarded empty loopback source gets real managed synthetic identities, trips, corrections, expenses, documents and two private synthetic receipt objects. T16 generates its encrypted archive. The recovery file is separately wrapped; the original vault key and helper credentials are deleted before credential-free recovery inspection. Each attempt creates a unique carrier_restore_<random> stack on port 55321 and removes that target and temporary vault entries in finally. No existing environment is overwritten, no hosted deployment/schedule is configured, and no source push occurs.

## Actual failures and changes so far

1. `pg_restore --clean` failed on an inherited Realtime partition primary-key constraint. Changed to a pristine database inside the verified empty disposable target, preserving dump ownership/ACL/RLS instead of selectively skipping failed objects.
2. Removing the default public schema caused a missing-schema failure. Keep the template0 public schema; a regression covers that contract.
3. Schema fingerprint comparisons differed in Auth enum/default rendering. Compare system catalog fields under the same empty search path and sorted ACLs; intermediate complete schema comparisons now pass.
4. New CLI defaults started older Auth/REST/Storage runtimes than the source. Local encrypted backup metadata now records runtime image names (not environment/secrets). Version hints reuse installed image tags; compare actual image IDs before restore. Intermediate runs match all four source database/Auth/REST/Storage images.
5. Direct deletion of copied Storage metadata is blocked by the provider guard. Preserve those rows and recover original object bytes through authorized Storage upserts; application evidence references are retained.
6. Some attempts closed the restore database connection unexpectedly. Redacted headers confirm server closure; no Docker OOM events were observed. The exact server cause is still under investigation. Full restore uses a seekable mode-600 temporary dump inside the target, verifies its SHA-256 and deletes it in finally. A read-only archive-to-/dev/null stdin probe passed; no corrupt archive is claimed.
7. Receipt upload returned HTTP 502. Added a bounded readiness barrier for Auth, REST and Storage and safe provider startup error codes. At that attempt file recovery, fresh authentication and final privacy checks had not passed; the completed run below passes them.

Intermediate runs have actually passed schema/functions/policies/grants, exact application/private/Auth identity record fingerprints, office assignments, journal-purpose sums, absence of obsolete sessions/refresh tokens and NOLOGIN/NOBYPASSRLS command-owner checks. Those intermediate results alone did not satisfy the gate; the complete run below includes receipt/auth/reprint checks.

Boundary tests cover source/arbitrary target rejection, nonempty target refusal, unsafe roles, pristine/default-schema restore, temporary file discipline, safe errors and independent no-network/no-vault inspection. Backup regression covers runtime metadata without reading/logging container environment. Actual unit counts and final recovery time will be recorded after the full gate passes.

Ignored local logs: tools/.local/t17-api.log, t17-real.log, t17-unit.log and t17-backup-regression.log. Logs contain case labels, safe error headers/codes and metadata counts; no passwords, tokens or receipt contents are included in this evidence. Operational setup and the sequence are in [restoration-setup.md](restoration-setup.md).

## Startup diagnosis (2026-10-12)

Reproduced against the existing disposable work directory with the actual CLI `start --debug`, without changing configuration first. Exit 1: `ContainerStartError`, Windows denied binding TCP 55322 with a forbidden socket-access error. `netsh interface ipv4 show excludedportrange protocol=tcp` confirms 55280-55379 is reserved; no listener occupies the selected ports. The earlier error filter skipped JSON CLI errors. The encrypted archives and separately wrapped recovery files remain unchanged (32 files fingerprinted locally). No Windows reservation, administrator setting, development port or authentication configuration was changed.

The isolated runner now probes every port in candidate blocks 57320/58320/59320 before writing its target-only configuration and fails closed if none bind. Actual bind probes pass for these blocks. Eight restoration boundary tests pass, including reserved-port fallback, probe cleanup, unavailable-port refusal and development-port rejection; 12 backup-helper regression tests pass. The subsequent complete rehearsal result is recorded below. Earlier intermediate restore connection failures remain separately recorded rather than attributed to this confirmed startup cause.

## Completed actual rehearsal

The same complete fixture/rehearsal command exited 0 following target-only port selection. Recovery measured **121.834 seconds**, starting before wrapped-key recovery and ending after database/files/auth/authorization/reprint checks; it excludes synthetic fixture creation and initial backup generation. Target API used loopback 57321. All four database/Auth/REST/Storage image IDs matched encrypted backup metadata. PostgreSQL and gateway container health were healthy; restored Auth, REST and Storage endpoints all returned HTTP 200 before requests.

Verified 15 trips, 88 events including 20 linked reversals, 17 documents, 3 receipt objects, 13 Auth identities and 8 office assignments. Complete application/private/Auth record fingerprints, canonical schema/function/policy/grant fingerprints and exact journal-purpose balances match source. All receipt bytes match original SHA-256 and size. Issued snapshots/digests remain identical and authorized reprint succeeds. Obsolete access/refresh tokens are denied; fresh admin and two dedicated staff authenticate, live mappings resolve, restored office RLS matches assigned trips, unrelated fare operations/direct financial writes and private receipt access are denied. Anonymous receipts are denied. A second restore refuses the populated target. Eight boundary tests and 12 helper regressions pass.

The full harness removes only its synthetic source fixtures and target; temporary vault entries/signing material are removed. Previously retained 32 encrypted archive/recovery files match pre-run hashes. No existing environment reset, GitHub push, hosted change or production scheduling occurred.

Earlier connection closures had no observed Docker OOM events; their precise historical cause was not established and is not attributed to the reserved-port diagnosis. The final complete run does not reproduce them. This is a logical local isolated restoration using installed compatible provider images, not a physical spare-PC or hosted-production rehearsal. Recovery passphrases are test-only in-memory inputs; production must independently protect the wrapped recovery key and its passphrase off-PC. Archive creation alone remains insufficient.

Verification totals: 619 main-harness PASS lines plus 42 child restore PASS lines; exit 0. Source HTTP Auth/REST/Storage 200, PostgreSQL ready, 18 migrations, all synthetic public/private/Auth/Storage rows zero, no disabled triggers, temporary SET grants or native test config. Source/history audit: 230 tracked files, 6 intended untracked files and 378 historical blobs, no findings.
