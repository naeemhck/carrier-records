# Karvaan UI restructure — Phase 1 evidence (app shell)

Date: 2026-10-19. Branch: update/karvaan-restructure @ c7beb6a (Phase 0).

## Audit result: no code changes required
The Phase 1 spec asks to "replace the vertical button-list home with an extended, collapsible NavigationRail". That replacement already happened on the bilingual branch: app/lib/app/workspace_shell.dart implements a persistent, extended (264px), collapsible (88px compact) glass sidebar. No vertical button-list home remains anywhere in the codebase (verified by grep).

Verified against the spec, all present:
- Grouped destinations: Workspace (Dashboard, Trips, Expenses, Money), Outputs (Reports, Documents), Manage (Masters, Excel imports, Backups) — via WorkspaceDestination enum with group labels rendered as section headers.
- One accent marks the active destination (green-tinted #EAF4ED selection fill + selected semantics).
- The rail itself is a KarvaanGlass surface (functional layer only) — glass discipline holds.
- Rail footer ("Signed in as…") already dropped; the account avatar menu lives in the frosted top bar, per the audit.
- Office-scope guarding, session refresh, and PopScope handling unchanged — chrome only, routes untouched.
- Narrow screens (<760px): hamburger opens the rail in a dialog; desktop keeps the persistent rail.

## Recorded deviation
The spec names NavigationRail literally. The branch uses a custom sidebar instead, deliberately: NavigationRail has no group-header support, and the Workspace/Outputs/Manage grouping is a spec requirement the custom rail satisfies. The custom rail replicates NavigationRail behavior (extended/compact, selection indicator, tooltips, keyboard-focusable InkWells with Semantics). Keeping it; rebuilding on NavigationRail would lose the groups for no user-visible gain.

## Verification
- `flutter analyze --no-pub`: No issues found (run during Phase 0, 78.2s; shell files untouched since).
- No behavioral change in this phase, so no test run beyond the Phase 10 full suite (shell covered by app/test/gui_foundation_test.dart and auth tests there).

## Notes for later phases
- Phase 9 will sweep the shell for keyboard tab order, visible focus indicators, and 200% text-scaling survival.
- The KPI-first dashboard content (Phase 7) plugs into the existing Dashboard destination; no shell change needed.
