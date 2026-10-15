import 'package:flutter/material.dart';

import '../features/auth/staff_session.dart';
import '../features/backup/backup_workspace.dart';
import '../features/expenses/expense_repository.dart';
import '../features/expenses/expense_workspace.dart';
import '../features/finance/correction_repository.dart';
import '../features/finance/financial_repository.dart';
import '../features/imports/import_workspace.dart';
import '../features/masters/master_repository.dart';
import '../features/masters/master_workspace.dart';
import '../features/reports/document_repository.dart';
import '../features/reports/output_export_service.dart';
import '../features/reports/output_repository.dart';
import '../features/reports/output_workspace.dart';
import '../features/reports/report_repository.dart';
import '../features/reports/report_workspace.dart';
import '../features/trips/trip_repository.dart';
import '../features/trips/trip_workspace.dart';
import 'bilingual.dart';
import 'karvaan_design.dart';

enum WorkspaceDestination {
  dashboard(Icons.dashboard_outlined, L10n.dashboard, L10n.workspaceGroup),
  trips(Icons.local_shipping_outlined, L10n.trips, L10n.workspaceGroup),
  expenses(
    Icons.receipt_long_outlined,
    L10n.expensesAndReimbursements,
    L10n.workspaceGroup,
  ),
  money(
    Icons.account_balance_wallet_outlined,
    L10n.moneyNavigation,
    L10n.workspaceGroup,
  ),
  reports(Icons.assessment_outlined, L10n.reports, L10n.outputsGroup),
  documents(
    Icons.description_outlined,
    L10n.issuedDocuments,
    L10n.outputsGroup,
  ),
  masters(
    Icons.settings_outlined,
    L10n.companyAndMasterRecords,
    L10n.manageGroup,
  ),
  imports(Icons.upload_file_outlined, L10n.excelImports, L10n.manageGroup),
  backups(Icons.backup_outlined, L10n.administratorBackups, L10n.manageGroup);

  const WorkspaceDestination(this.icon, this.label, this.group);
  final IconData icon;
  final Bilingual label, group;
  bool allowed(bool admin) => admin || (this != masters && this != backups);
}

/// Outside the route navigator: child editors, dialogs and back behavior retain
/// their existing routes while desktop navigation stays available.
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.session,
    required this.navigatorKey,
    required this.child,
  });
  final StaffSession? session;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  bool collapsed = false;
  WorkspaceDestination? selected;
  String scope(Map<String, dynamic>? p) {
    final offices =
        (p?['offices'] as List? ?? []).map((o) => o['id'].toString()).toList()
          ..sort();
    return '${p?['id']}:${p?['role']}:$offices';
  }

  Future<void> open(WorkspaceDestination destination) async {
    final session = widget.session!, p = session.profile!;
    if (!destination.allowed(p['role'] == 'ADMIN')) return;
    final granted = scope(p);
    Widget guard(Widget child) => ListenableBuilder(
      listenable: session,
      builder: (_, _) =>
          scope(session.profile) == granted &&
              session.profile?['must_change_password'] == false
          ? child
          : const Scaffold(
              body: Center(
                child: BilingualText(L10n.currentOfficeAccessRequired),
              ),
            ),
    );
    final client = session.client;
    final offices = (p['offices'] as List)
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList();
    final masters = SupabaseMasterRepository(client),
        trips = SupabaseTripRepository(client);
    final documents = DocumentRepository(client);
    final outputs = OutputWorkspace(
      commands: OutputRepository(client),
      masters: masters,
      trips: trips,
      offices: offices,
      administrator: p['role'] == 'ADMIN',
      guard: guard,
      documents: documents,
      exporter: OutputExportService(ExportRepository(client), documents),
    );
    Widget expensesPage() => ExpenseWorkspace(
      expenses: ExpenseRepository(client),
      finance: FinancialRepository(client),
      corrections: CorrectionRepository(client),
      administrator: p['role'] == 'ADMIN',
      trips: trips,
      masters: masters,
      offices: offices,
      guard: guard,
    );
    final page = switch (destination) {
      WorkspaceDestination.trips || WorkspaceDestination.money => TripWorkspace(
        repository: trips,
        masters: masters,
        offices: offices,
        guard: guard,
        corrections: CorrectionRepository(client),
        finance: FinancialRepository(client),
        moneyMode: destination == WorkspaceDestination.money,
        onExpenses: () => widget.navigatorKey.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => guard(expensesPage())),
        ),
      ),
      WorkspaceDestination.expenses => expensesPage(),
      WorkspaceDestination.dashboard ||
      WorkspaceDestination.reports => ReportWorkspace(
        reports: ReportRepository(client),
        trips: trips,
        masters: masters,
        offices: offices,
        dashboard: destination == WorkspaceDestination.dashboard,
        guard: guard,
        outputs: outputs,
      ),
      WorkspaceDestination.documents => outputs,
      WorkspaceDestination.masters => MasterWorkspace(repository: masters),
      WorkspaceDestination.imports => ImportWorkspace(
        client: client,
        offices: offices,
        guard: guard,
      ),
      WorkspaceDestination.backups => BackupWorkspace(
        commands: BackupRepository(client),
      ),
    };
    final previous = selected;
    setState(() => selected = destination);
    // Preserve unsaved forms and their in-flight PopScopes in the route stack.
    await widget.navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: 'workspace:${destination.name}'),
        builder: (_) => guard(page),
      ),
    );
    if (mounted) setState(() => selected = previous);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) return widget.child;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final p = session.profile;
        if (p == null || p['must_change_password'] != false) {
          return widget.child;
        }
        final admin = p['role'] == 'ADMIN';
        final destinations = WorkspaceDestination.values
            .where((d) => d.allowed(admin))
            .toList();
        Widget navigation(
          bool compact, {
          VoidCallback? dismiss,
        }) => KarvaanGlass(
          child: SizedBox(
            width: compact ? 88 : 264,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: compact
                      ? const Icon(Icons.route, color: KarvaanDesign.accent)
                      : const BilingualText(
                          L10n.brand,
                          style: TextStyle(fontSize: 22),
                        ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < destinations.length; i++) ...[
                        if (!compact &&
                            (i == 0 ||
                                destinations[i].group !=
                                    destinations[i - 1].group))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: BilingualText(
                              destinations[i].group,
                              style: const TextStyle(
                                color: KarvaanDesign.secondary,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Material(
                            color: selected == destinations[i]
                                ? const Color(0xFFEAF4ED)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: compact
                                ? IconButton(
                                    key: ValueKey(
                                      'nav:${destinations[i].name}',
                                    ),
                                    tooltip: destinations[i].label.inline,
                                    icon: Icon(destinations[i].icon),
                                    isSelected: selected == destinations[i],
                                    onPressed: () {
                                      dismiss?.call();
                                      open(destinations[i]);
                                    },
                                  )
                                : ListTile(
                                    key: ValueKey(
                                      'nav:${destinations[i].name}',
                                    ),
                                    selected: selected == destinations[i],
                                    leading: Icon(destinations[i].icon),
                                    title: BilingualText(destinations[i].label),
                                    onTap: () {
                                      dismiss?.call();
                                      open(destinations[i]);
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => collapsed = !collapsed),
                  tooltip:
                      (compact
                              ? L10n.expandNavigation
                              : L10n.collapseNavigation)
                          .inline,
                  icon: Icon(
                    compact ? Icons.chevron_right : Icons.chevron_left,
                  ),
                ),
              ],
            ),
          ),
        );
        final account = PopupMenuButton<String>(
          tooltip: L10n.accountNavigation.inline,
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) async {
            if (value == 'account') {
              widget.navigatorKey.currentState!.popUntil((r) => r.isFirst);
              setState(() => selected = null);
            } else {
              await session.signOut();
              widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'account',
              child: BilingualText(L10n.accountNavigation),
            ),
            PopupMenuItem(value: 'logout', child: BilingualText(L10n.signOut)),
          ],
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    if (!narrow)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: navigation(collapsed),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: KarvaanGlass(
                              child: Row(
                                children: [
                                  if (narrow)
                                    Builder(
                                      builder: (context) => IconButton(
                                        tooltip: L10n.expandNavigation.inline,
                                        icon: const Icon(Icons.menu),
                                        onPressed: () => showDialog<void>(
                                          context: context,
                                          animationStyle:
                                              AnimationStyle.noAnimation,
                                          builder: (overlay) => Dialog(
                                            child: navigation(
                                              false,
                                              dismiss: () =>
                                                  Navigator.pop(overlay),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        p['display_name'].toString(),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  account,
                                ],
                              ),
                            ),
                          ),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
