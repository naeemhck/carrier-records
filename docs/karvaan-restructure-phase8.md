# Karvaan UI restructure — Phase 8 evidence (Masters, Excel imports, Backups, auth)

Date: 2026-10-19. Branch: update/karvaan-restructure. Changes left UNCOMMITTED
per task instructions. No push, merge, deploy, or hosted Supabase contact.

Baseline: stacked bilingual (EN semibold above UR regular ~85%, LTR layout,
RTL only on Urdu runs, Latin digits) — the prompt's <language-toggle> block is
superseded per the 2026-10-19 user decision; no toggle exists. Global rule from
the competitor addendum applies: blue = movement, green = money.

## Scope

Presentation only. No repository, RPC, migration, RLS, calculation,
authorization, or auth-behavior change. Sign-in, password change, account
management, and session guards behave exactly as before; only layout/labels
changed. Auth screen edits are confined to StaffHome, PasswordDialog,
AccountsPanel/AccountRow, and AccountDialog in
app/lib/app/carrier_records_app.dart — the GoRouter/shell wiring at the top of
that file is untouched.

Files touched (this phase):
- app/lib/features/masters/master_workspace.dart
- app/lib/features/imports/import_workspace.dart
- app/lib/features/backup/backup_workspace.dart
- app/lib/app/carrier_records_app.dart (auth screens only)
- app/lib/app/ui_catalogue.dart (12 new strings + values entries; duplicate
  declarations removed — see "Concurrent-edit collisions")
- tools/karvaan/phrases.json (12 new entries, origins ["ui-restructure-phase8"])

New catalogue strings: masterRecordTypeSection, findRecordsSection,
recordsSection, importSetupNotLoadedYet, noExpenseDraftsAwaitingReview,
noExpenseCategoryCodesReturned, backupStatus, backupSchedule, backupTraffic,
manualBackup, accountRole, confirmImportBlocked. generate_catalogue.py was NOT
run; entries were hand-appended per the branch convention.

## What changed

### Masters (master_workspace.dart)
- Record-type chips + per-kind guidance captions grouped in
  KarvaanSection("Record type"); search field + New record / Search-refresh /
  Include-archived grouped in KarvaanSection("Find records") for non-company
  kinds. Company kind keeps its single-record treatment (no search UI, as
  before).
- Empty state on the records list: "No records found." guidance plus the
  primary action (FilledButton "New record") for every kind except company
  (company has no create flow; guidance only).
- Replaced the fixed 65%-viewport inner scroll region with a naturally
  scrolling outer list (no nested scrollable); pagination range now uses
  displayCount with the tabular bodyMedium role (was a plain Text).
- MasterDialog / PartyChoiceDialog: structure unchanged (5–7 controls each —
  not mega-forms); stacked labels and label economy already held.

### Excel imports (import_workspace.dart)
- QA FIX (must): every disabled button now explains why, with a visible
  stacked caption adjacent (the existing pending-requirement captions) PLUS a
  bilingual tooltip (Tooltip message = Bilingual.inline, i.e. EN newline UR):
  - Download template → disabled while the setup/field list hasn't loaded:
    "The import setup has not loaded yet…" (new string).
  - Choose XLSX → disabled until an authorized recording office is chosen:
    reuses importOfficeRequired.
  - Validate and preview → disabled until a file is parsed with no local
    errors and the batch is uncommitted: reuses importFileRequired /
    importErrorsRequired / importAlreadyCommitted, selected for the actual
    pending requirement.
  - Confirm reviewed import → disabled until validation errors are resolved
    or overlap warnings acknowledged: new string confirmImportBlocked.
  Enablement gating is byte-identical to before; only explanations were added.
- Expense drafts moved into KarvaanSection titled "Imported expense drafts
  awaiting normal review · <count>" (count via displayCount). Empty state:
  "No expense drafts are waiting for review." guidance + primary action
  ("Choose XLSX", same enablement/tooltip as the main button).
- Draft rows are now figure-led per the type hierarchy: amount as a
  headlineSmall tabular-numeral figure (displayMoney), date | reason as a
  quiet bodySmall caption — was a single concatenated Text line.
- Expense category codes ExpansionTile shows a guidance line when the server
  returns none (was a blank expansion).

### Backups (backup_workspace.dart)
- QA FIX (must): "Run manual Windows backup" stays disabled in this isolated
  candidate (capability genuinely absent — the administrator helper is
  disabled here), but now explains why twice: the existing visible stacked
  caption (administratorHelperIsDisabledInThisIsolatedCandidate, or
  runBackupsOnTheConfiguredAdministratorWindowsPC on non-Windows) plus a
  bilingual tooltip on the button naming the reason. The button still cannot
  invoke the helper (backup_workspace_test asserts onPressed == null and zero
  invocations).
- Summary-first: BackupSummary now leads with the answer — run state at
  headline size + last-verified-success at title size — then discloses detail
  in KarvaanSections: "Backup status" (last attempt, stale/failed/interrupted
  warnings, pending receipts, quota/traffic warnings), "Schedule", "Monthly
  traffic", with the off-site advisory caption retained. All existing strings
  kept (domain_status_qa_test and backup_workspace_test assertions unchanged).
- The actions section is retitled "Manual backup" (was the redundant screen
  title "Administrator backups"); BackupStatusPanel no longer double-wraps
  the summary in a Card (summary now provides its own sections). Panel has no
  in-repo usages.

### Auth (carrier_records_app.dart — StaffHome, PasswordDialog, AccountsPanel, AccountDialog)
- QA FIX (must): failed-login error visibility hardened. The sign-in
  (p == null) and must-change-password branches already rendered feedback()
  directly under the title with feedbackKey + Scrollable.ensureVisible —
  verified unchanged and passing. Hardening: the signed-in branch previously
  rendered feedback() at the BOTTOM of the card (below AccountsPanel), so a
  session/refresh error required scrolling; it now renders at the TOP of the
  signed-in card, above "Signed in as". No behavior change.
- AccountsPanel: empty state ("No records found." guidance) if the account
  list ever comes back empty; create/refresh buttons unchanged.
- AccountDialog: the Role dropdown (KarvaanChoiceField) had NO visible label;
  it now has a stacked bilingual label (new string accountRole: "Role" /
  "کردار"). Label economy otherwise held: one stacked label per field, helper
  text only where the label genuinely cannot explain (password rules, office
  requirement).
- Type scale: screen titles already used KarvaanTypography.screenTitle (22);
  error text, captions, and list rows use the central roles; Urdu floor
  (11pt) untouched.

## Verification — actual command outputs

`flutter analyze --no-pub` on the five touched files:
- "No issues found!" (40.8s). Full-repo analyze reports only other agents'
  in-progress issues (unused import in test/expense_phase5_test.dart;
  conflicting field/method in test/trip_restructure_p234_test.dart) — none in
  Phase 8 files.

Tests (flutter test --no-pub), all with synthetic data, no backend:
- test/masters_test.dart, test/import_workbook_test.dart,
  test/backup_workspace_test.dart, test/auth_test.dart,
  test/account_error_test.dart: ALL 20 PASSED (71s).
- test/gui_manage_screens_test.dart: 2 PASSED — masters scrollable at
  320px/200% text; backup failure explicit at narrow/large text.
- test/auth_feedback_qa_test.dart: 4 PASSED (360/1280 × 100%/200%) — failed
  login error renders below the AppBar and inside the viewport after tapping
  Sign in; password field obscured; live-region semantics present.
- test/account_presentation_test.dart: 2 PASSED (320/1280) — account rows
  unchanged (ADMIN · Active · Password change required, etc.).
- Extra hardening check (temporary scratch test, deleted after): failed-login
  error visible without scrolling at 320px width at 100% AND 200% scale —
  2 PASSED. At 320px/200% the sign-in button itself sits below the fold
  (lazy ListView) so the scratch test scrolls it into view before tapping;
  the error still lands in-viewport via the app's ensureVisible.

Failures encountered and fixed:
1. First full test run failed to compile: ui_catalogue.dart had duplicate
   declarations (expenseReimbursementDue, personalFundingDue, costRecovery,
   commissionDue + accessibility variants) added by the concurrent Phase 5/6
   agent's block. Removed the duplicate declarations and duplicate values-list
   entries; kept the original declarations and the one values entry each.
   Verified: zero duplicate declaration names, zero duplicate values keys,
   867 values entries.
2. Scratch 320px/200% test initially failed with "Bad state: No element" —
   a test-harness artifact (lazy ListView hadn't built the below-fold button),
   not an app defect; fixed the scratch test to scrollUntilVisible first.

## Concurrent-edit collisions (flagged, not fully mine)

- ui_catalogue.dart / tools/karvaan/phrases.json are shared: the Phase 5
  agent added 5 entries (mostUsed, clearSearch, expenseActive,
  expenseHistorical, pageExpensesTotal) while I added my 12 — no key
  collisions; both sets intact.
- payment_workspace.dart (another agent, in progress) had an unused import
  and undefined accountLabel method during my first analyze; trip_workspace.dart
  (another agent, in progress) had a String?/String type error that briefly
  blocked compilation of shell widget tests. Both were fixed by their owners
  during this session — I did not touch those files. If either regresses,
  gui_manage_screens / auth_feedback_qa / account_presentation tests will
  fail to load (they transitively import trip_workspace via workspace_shell).

## Intentionally left out

- MasterDialog/PartyChoiceDialog were NOT restructured into step flows: at
  5–7 controls they are not mega-forms, and Phase 8 calls for "no structural
  changes beyond what the audit patterns clearly require."
- No KPI strip was added to Imports/Backups: neither screen has an
  authoritative server-provided total to headline; inventing aggregates would
  violate the no-fabrication rule.
- The disabled manual-backup button was NOT enabled: the capability (Windows
  administrator helper) is genuinely absent in this isolated candidate; the
  fix is explanation, per the QA-fix instruction.
- generate_catalogue.py was NOT run (explicit instruction); catalogue and
  phrases.json were hand-updated in matching pairs.
- No visual screenshot QA claimed: text_layout_qa capture helpers exist but
  no captures were produced in this phase; verification is via widget tests
  at 320/360/1280px and 100%/200% text scale.
