import 'karvaan_typography.dart';

import 'package:flutter/material.dart';

import '../features/auth/staff_session.dart';
import '../features/backup/backup_workspace.dart';
import '../features/expenses/expense_repository.dart';
import '../features/expenses/expense_workspace.dart';
import '../features/finance/correction_repository.dart';
import '../features/finance/financial_repository.dart';
import '../features/finance/money_workspace.dart';
import '../features/imports/import_workspace.dart';
import '../features/masters/master_repository.dart';
import '../features/masters/master_workspace.dart';
import '../features/reports/document_repository.dart';
import '../features/reports/document_workspace.dart';
import '../features/reports/output_file_actions.dart';
import '../features/reports/output_export_service.dart';
import '../features/reports/output_repository.dart';
import '../features/reports/output_workspace.dart';
import '../features/reports/report_repository.dart';
import '../features/reports/report_workspace.dart';
import '../features/trips/trip_repository.dart';
import '../features/trips/trip_workspace.dart';
import 'bilingual.dart';
import 'karvaan_design.dart';
import 'shell_header.dart';

/// Account/root navigation must not circumvent any pending child PopScope.
class WorkspaceRouteObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];
  bool get canReturnHome => !_routes.any(
    (route) => route.popDisposition == RoutePopDisposition.doNotPop,
  );

  /// Reports the workspace navigator's current route so the shell
  /// header can show the spec registered for it (header compaction).
  void Function(Route<dynamic>? current)? onCurrentRouteChanged;
  void _reportCurrent() =>
      onCurrentRouteChanged?.call(_routes.isEmpty ? null : _routes.last);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _reportCurrent();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _reportCurrent();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _reportCurrent();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _reportCurrent();
  }
}

/// Rail groups follow the plan (§4): Operations / Records / Manage.
/// Outputs is a tool, not a destination — it lives in the top bar of the
/// Dashboard and Reports screens.
enum WorkspaceDestination {
  dashboard(Icons.dashboard_outlined, L10n.dashboard, L10n.operationsGroup),
  trips(Icons.local_shipping_outlined, L10n.trips, L10n.operationsGroup),
  money(
    Icons.account_balance_wallet_outlined,
    L10n.moneyNavigation,
    L10n.operationsGroup,
  ),
  expenses(
    Icons.receipt_long_outlined,
    L10n.expensesAndReimbursements,
    L10n.recordsGroup,
  ),
  documents(
    Icons.description_outlined,
    L10n.issuedDocuments,
    L10n.recordsGroup,
  ),
  reports(Icons.assessment_outlined, L10n.reports, L10n.recordsGroup),
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
    this.canReturnHome,
    this.headerRegistry,
  });
  final StaffSession? session;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool Function()? canReturnHome;

  /// Shared with the route observer so the header tracks the current
  /// workspace route. When omitted the shell owns a private registry
  /// (unit hosts); the most recent registration then wins.
  final ShellHeaderRegistry? headerRegistry;
  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  bool collapsed = false;
  WorkspaceDestination? selected;
  late final ShellHeaderRegistry _headers =
      widget.headerRegistry ?? ShellHeaderRegistry();
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
    final exporter = OutputExportService(ExportRepository(client), documents);
    Widget outputPage({
      Map<String, dynamic>? initialCommand,
      String? supersedesId,
    }) => OutputWorkspace(
      commands: OutputRepository(client),
      masters: masters,
      trips: trips,
      offices: offices,
      administrator: p['role'] == 'ADMIN',
      guard: guard,
      documents: documents,
      exporter: exporter,
      initialCommand: initialCommand,
      supersedesId: supersedesId,
    );
    void configure({Map<String, dynamic>? command, String? supersedesId}) {
      widget.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => guard(
            outputPage(initialCommand: command, supersedesId: supersedesId),
          ),
        ),
      );
    }

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
    Widget tripsPage({bool moneyMode = false}) => TripWorkspace(
      repository: trips,
      masters: masters,
      offices: offices,
      guard: guard,
      corrections: CorrectionRepository(client),
      finance: FinancialRepository(client),
      moneyMode: moneyMode,
      onExpenses: () => widget.navigatorKey.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => guard(expensesPage())),
      ),
    );
    final page = switch (destination) {
      WorkspaceDestination.trips => tripsPage(),
      // Money is balances-first (plan §5.5): party balances up front, the
      // money-mode trip list one tap away inside it.
      WorkspaceDestination.money => MoneyWorkspace(
        reports: ReportRepository(client),
        onViewTrips: () => widget.navigatorKey.currentState!.push<void>(
          MaterialPageRoute(builder: (_) => guard(tripsPage(moneyMode: true))),
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
        outputs: outputPage(),
      ),
      WorkspaceDestination.documents => DocumentWorkspace(
        commands: documents,
        guard: guard,
        onConfigure: () => configure(),
        onSupersede: (command, id) =>
            configure(command: command, supersedesId: id),
        fileActions: (doc) => OutputFileActions(
          service: exporter,
          load: () => exporter.issued(doc['id'] as String),
        ),
      ),
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
    if (mounted) {
      setState(
        () => selected = widget.navigatorKey.currentState?.canPop() == true
            ? previous
            : null,
      );
      await session.refresh();
    }
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
            // Rail narrowed toward the mockup (reports pass): 264 -> 208.
            width: compact ? 88 : 208,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: compact
                      ? const Icon(Icons.route, color: KarvaanDesign.accent)
                      : const BilingualText(
                          L10n.brand,
                          style: KarvaanTypography.sectionTitle,
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
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            // Section headers are uppercase and non-interactive
                            // so they are never mistaken for navigation items.
                            child: BilingualText(
                              Bilingual(
                                destinations[i].group.key,
                                destinations[i].group.en.toUpperCase(),
                                destinations[i].group.ur,
                              ),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: KarvaanDesign.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Material(
                            color: selected == destinations[i]
                                ? KarvaanDesign.borderColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: compact
                                ? IconButton(
                                    key: ValueKey(
                                      'nav:${destinations[i].name}',
                                    ),
                                    tooltip: destinations[i].label.inMode(
                                      LanguageModeStore.instance.mode.value,
                                    ),
                                    icon: Icon(destinations[i].icon),
                                    isSelected: selected == destinations[i],
                                    onPressed: () {
                                      dismiss?.call();
                                      open(destinations[i]);
                                    },
                                  )
                                : InkWell(
                                    key: ValueKey(
                                      'nav:${destinations[i].name}',
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      dismiss?.call();
                                      open(destinations[i]);
                                    },
                                    child: Semantics(
                                      button: true,
                                      selected: selected == destinations[i],
                                      child: Padding(
                                        // Density pass: rows land at ~44–48px
                                        // in single-language modes and stay
                                        // visibly shorter than the old ~78px
                                        // in bilingual mode.
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              destinations[i].icon,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: BilingualText(
                                                destinations[i].label,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
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
                          .inMode(LanguageModeStore.instance.mode.value),
                  icon: Icon(
                    compact ? Icons.chevron_right : Icons.chevron_left,
                  ),
                ),
              ],
            ),
          ),
        );
        final account = PopupMenuButton<String>(
          popUpAnimationStyle: AnimationStyle.noAnimation,
          tooltip: L10n.accountNavigation.inMode(
            LanguageModeStore.instance.mode.value,
          ),
          icon: const Icon(Icons.account_circle_outlined),
          onSelected: (value) async {
            if (widget.canReturnHome?.call() == false) return;
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
        return ShellHeaderScope(
          registry: _headers,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final narrow = width < 760;
              // Tablet band (GUI handoff group 8): between 760 and 1024
              // the rail is always the compact icon rail — the full 208px
              // rail left too little room for content at 768–1023px. The
              // manual collapse toggle still applies at desktop widths.
              final compactRail = collapsed || (!narrow && width < 1024);
              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      if (!narrow)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: navigation(compactRail),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            // ONE header row (header compaction pass): the
                            // current screen's one-line title + its primary
                            // actions live here, beside the language menu
                            // and account control. The signed-in name is a
                            // compact chip, never a full-width bar of its
                            // own; screens register their spec through
                            // ShellHeader instead of stacking an AppBar.
                            ListenableBuilder(
                              listenable: _headers,
                              builder: (context, _) {
                                final spec = _headers.current;
                                final canPop =
                                    widget.navigatorKey.currentState
                                        ?.canPop() ??
                                    false;
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    6,
                                    8,
                                    6,
                                  ),
                                  child: KarvaanGlass(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          if (narrow)
                                            Builder(
                                              builder: (context) => IconButton(
                                                tooltip: L10n.expandNavigation
                                                    .inMode(
                                                      LanguageModeStore
                                                          .instance
                                                          .mode
                                                          .value,
                                                    ),
                                                icon: const Icon(Icons.menu),
                                                onPressed: () =>
                                                    showDialog<void>(
                                                      animationStyle:
                                                          AnimationStyle
                                                              .noAnimation,
                                                      context: context,
                                                      builder: (overlay) =>
                                                          Dialog(
                                                            child: navigation(
                                                              false,
                                                              dismiss: () =>
                                                                  Navigator.pop(
                                                                    overlay,
                                                                  ),
                                                            ),
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          if (spec != null && canPop)
                                            IconButton(
                                              tooltip: MaterialLocalizations.of(
                                                context,
                                              ).backButtonTooltip,
                                              icon: const Icon(
                                                Icons.arrow_back,
                                              ),
                                              onPressed: () => widget
                                                  .navigatorKey
                                                  .currentState
                                                  ?.maybePop(),
                                            ),
                                          Expanded(
                                            child: spec == null
                                                ? const SizedBox.shrink()
                                                : Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                        ),
                                                    child: BilingualHeaderTitle(
                                                      spec.title,
                                                      key: const ValueKey(
                                                        'shell-header-title',
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                          if (spec != null)
                                            for (final action in spec.actions)
                                              if (action.form(narrow) != null)
                                                action.form(narrow)!,
                                          if (!narrow)
                                            Padding(
                                              key: const ValueKey(
                                                'shell-user-chip',
                                              ),
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: KarvaanDesign.muted,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.person_outline,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      ConstrainedBox(
                                                        constraints:
                                                            const BoxConstraints(
                                                              maxWidth: 160,
                                                            ),
                                                        child: Text(
                                                          p['display_name']
                                                              .toString(),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                          textDirection:
                                                              TextDirection.ltr,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          const LanguageModeMenuButton(),
                                          account,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
          ),
        );
      },
    );
  }
}
