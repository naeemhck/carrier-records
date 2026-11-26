import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_components.dart';
import '../../app/karvaan_design.dart';
import '../../app/karvaan_patterns.dart';
import '../../app/karvaan_typography.dart';
import '../../app/shell_header.dart';

import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import '../trips/trip_workspace.dart';
import '../finance/financial_repository.dart';
import 'report_repository.dart';

/// Report KPI groupings (plan §5.7): every reportLabels key belongs to
/// exactly one themed section.
const _kpiGroups = <(Bilingual, List<String>)>[
  (
    L10n.earningsGroup,
    [
      'customer_fare',
      'owner_earnings',
      'brokerage',
      'vehicle_cost',
      'owner_cost',
      'operating_profit',
      'owner_profit',
    ],
  ),
  (
    L10n.payments,
    [
      'receipts',
      'refunds',
      'owner_settled',
      'commission_settled',
      'credit_created',
      'credit_applied',
    ],
  ),
  (
    L10n.moneyOwedGroup,
    [
      'customer_outstanding',
      'owner_due',
      'brokerage_due',
      'funding_due',
      'reimbursement_due',
      'owner_recovery',
      'brokerage_recovery',
      'cost_recovery',
    ],
  ),
  (L10n.moneyHeldGroup, ['customer_credit', 'custody']),
  (L10n.activityGroup, ['dispatched', 'arrived']),
];

class ReportWorkspace extends StatefulWidget {
  const ReportWorkspace({
    super.key,
    required this.reports,
    required this.trips,
    required this.masters,
    required this.offices,
    this.dashboard = false,
    this.guard = unguardedTrip,
    this.outputs,
    this.backupStatus,
  });
  final ReportCommands reports;
  final TripRepository trips;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final bool dashboard;
  final Widget Function(Widget) guard;
  final Widget? outputs;
  final Widget? backupStatus;
  @override
  State<ReportWorkspace> createState() => _ReportWorkspaceState();
}

class _ReportWorkspaceState extends State<ReportWorkspace> {
  late final from = TextEditingController(
    text:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01',
  );
  late final to = TextEditingController(
    text: DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).toIso8601String().substring(0, 10),
  );
  final search = TextEditingController();
  String kind = 'MONTHLY_VEHICLE';
  String? office, vehicle, owner, trip, vehicleName, ownerName, tripName;
  int offset = 0;
  Future<Map<String, dynamic>>? page;

  /// Dashboard KPI data: [scoped monthly report, dispatched trips, draft trips].
  Future<List<dynamic>>? kpis;

  /// Lazy claims breakdown for the money KPI drill-downs. Null until drilled.
  Future<Map<String, dynamic>>? claims;

  /// Selected KPI drill-down: 0 dispatched, 1 outstanding, 2 settlements,
  /// 3 drafts. Null shows the four cards only.
  int? drill;

  /// The measure the dashboard's by-vehicle bars rank.
  String chartMetric = 'customer_fare';

  /// Zero-value report cards stay hidden until the user asks for all of
  /// them (plan §5.7).
  bool showAllKpis = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Map<String, dynamic> get filters => {
    'from': from.text.trim(),
    'to': to.text.trim(),
    'office_id': office,
    'vehicle_id': vehicle,
    'owner_id': owner,
    'trip_id': kind == 'TRIP_PROFIT' ? trip : null,
    'search': search.text.trim(),
  };
  void reload({int start = 0}) {
    setState(() {
      offset = start;
      if (widget.dashboard) {
        // Dashboard KPIs always cover all permitted offices for the current
        // month; office/vehicle scoping lives in the report builder page.
        page = null;
        drill = null;
        claims = null;
        kpis = Future.wait([
          widget.reports.report('MONTHLY_VEHICLE', filters),
          widget.trips.list(state: 'DISPATCHED'),
          widget.trips.list(state: 'DRAFT'),
          widget.trips.list(state: 'ARRIVED'),
        ]);
      } else {
        page = widget.reports.report(kind, filters, offset: offset);
      }
    });
  }

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    search.dispose();
    super.dispose();
  }

  void selectDrill(int index) {
    setState(() {
      drill = drill == index ? null : index;
      if ((drill == 1 || drill == 2) && claims == null) {
        claims = widget.reports.report('CLAIMS', filters);
      }
    });
  }

  void openReportBuilder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.guard(
          ReportWorkspace(
            reports: widget.reports,
            trips: widget.trips,
            masters: widget.masters,
            offices: widget.offices,
            guard: widget.guard,
            outputs: widget.outputs,
          ),
        ),
      ),
    );
  }

  Future<void> pick(String target) async {
    final result = await showDialog<Map<String, dynamic>>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (_) => widget.guard(
        _ReportChoice(
          masters: widget.masters,
          trips: widget.trips,
          kind: target,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      switch (target) {
        case 'VEHICLE':
          vehicle = result['id'];
          vehicleName = result['label'];
        case 'OWNER':
          owner = result['id'];
          ownerName = result['label'];
        case 'TRIP':
          trip = result['id'];
          tripName = result['label'];
      }
    });
  }

  Widget value(
    String key,
    Object? amount, {
    bool lifetime = false,
    bool hero = false,
    bool compact = false,
    bool plainLabel = false,
  }) => KarvaanMetric(
    key: hero ? ValueKey('report-hero-$key') : null,
    hero: hero,
    compact: compact,
    label: _valueLabel(key, lifetime: lifetime, plainLabel: plainLabel),
    formattedValue: displayField(
      ['dispatched', 'arrived'].contains(key) ? 'INTEGER' : 'MONEY',
      amount,
    ),
  );

  /// Card labels drop the per-card date-basis suffix (plan §5.7: the period
  /// shows once in the header); both language sides carry the same ' — '
  /// separator, so both strip together and the pair stays bilingual. Drill
  /// rows keep the full label, basis included.
  Bilingual _valueLabel(
    String key, {
    required bool lifetime,
    required bool plainLabel,
  }) {
    final full = ownedMessage(
      lifetime
          ? reportLabels[key]
                ?.replaceAll('period end', 'current lifetime')
                .replaceAll('period costs', 'all linked costs')
                .replaceAll('expense date', 'all linked expense dates')
          : reportLabels[key],
    );
    if (!plainLabel || lifetime) return full;
    return Bilingual(
      '${full.key}.short',
      full.en.split(' — ').first,
      full.ur.split(' — ').first,
    );
  }

  /// Traceable totals (reports pass): a KPI card for a figure the CLAIMS
  /// report breaks down by party becomes tappable and opens that
  /// breakdown for the same filters — the records composing the total,
  /// without leaving the builder. Other figures stay plain cards: the
  /// payload carries no per-record drill-down for them.
  Widget _reportKpiCard(
    String key,
    Object? amount, {
    required bool lifetime,
    bool hero = false,
  }) {
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: value(
          key,
          amount,
          lifetime: lifetime,
          hero: hero,
          plainLabel: true,
        ),
      ),
    );
    final traceable =
        (key == 'customer_outstanding' || key == 'owner_due') &&
        kind != 'CLAIMS';
    if (!traceable) return card;
    return InkWell(
      key: ValueKey('report-trace-$key'),
      onTap: () => _claimsBreakdown(key),
      borderRadius: BorderRadius.circular(10),
      child: card,
    );
  }

  Future<void> _claimsBreakdown(String key) async {
    final future = widget.reports.report('CLAIMS', filters);
    await showDialog<void>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (dialogContext) => widget.guard(
        AlertDialog(
          title: BilingualText(
            _valueLabel(key, lifetime: false, plainLabel: false),
          ),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (_, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (s.hasError || !s.hasData) {
                  return const BilingualText(
                    L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
                  );
                }
                final rows = s.data!['rows'] as List;
                if (rows.isEmpty) {
                  return const BilingualText(L10n.noRecordsInThisPeriodScope);
                }
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final row in rows)
                        BilingualListTile(
                          dense: true,
                          title: Text(row['name'] as String),
                          trailing: Text(
                            displayField('MONEY', (row['values'] as Map)[key]),
                            textDirection: TextDirection.ltr,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const BilingualCaption(L10n.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Zero-value KPI cards are hidden to keep the grid scannable; the primary
  /// card always shows.
  bool _isZeroKpi(String key, Object? amount) {
    if (amount == null) return true;
    final text = amount.toString().trim();
    try {
      if (['dispatched', 'arrived'].contains(key)) {
        return BigInt.parse(text.split('.').first) == BigInt.zero;
      }
      return LedgerAmount.fromJson(amount).paisa == BigInt.zero;
    } on FormatException {
      return false;
    }
  }

  /// KPI-first dashboard (density pass): the four headline cards first
  /// (title + actions are in the shell header now), then movements and
  /// attention in an internally scrolling region — the page itself fits
  /// the desktop viewport.
  Widget dashboardBody() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The old toolbar row (Reports button) is gone — the action
        // lives in the shell header now. A supplied backup status keeps
        // a slim strip above the cards rather than a full row.
        if (widget.backupStatus != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: widget.backupStatus!,
          ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: kpis,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (s.hasError || !s.hasData) {
                return const BilingualText(
                  L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
                );
              }
              final data = s.data![0] as Map<String, dynamic>;
              final totals = Map<String, dynamic>.from(data['totals'] as Map);
              final dispatched = (s.data![1] as TripPage).rows;
              final drafts = (s.data![2] as TripPage).rows;
              final arrived = (s.data![3] as TripPage).rows;
              final now = DateTime.now();
              final today =
                  '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
              final period = '${from.text.trim()} — ${to.text.trim()}';
              final movements = todaysMovementRows(dispatched, arrived, today);
              final attention = attentionRows(totals, drafts);
              final caption = Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: KarvaanDesign.secondary);
              final head = <Widget>[
                kpiGrid([
                  KpiCard(
                    label: L10n.dispatchedNow,
                    figure: displayCount(dispatched.length),
                    detail: kpiDetail('dispatched', totals),
                    period: period,
                    selected: drill == 0,
                    onTap: () => selectDrill(0),
                  ),
                  KpiCard(
                    label: L10n.customerOutstanding,
                    figure: displayField(
                      'MONEY',
                      totals['customer_outstanding'],
                    ),
                    detail: kpiDetail('receipts', totals),
                    period: period,
                    selected: drill == 1,
                    onTap: () => selectDrill(1),
                  ),
                  KpiCard(
                    label: L10n.settlementsDue,
                    figure: displayField('MONEY', totals['owner_due']),
                    detail: kpiDetail('owner_settled', totals),
                    period: period,
                    selected: drill == 2,
                    onTap: () => selectDrill(2),
                  ),
                  KpiCard(
                    label: L10n.draftTrips,
                    figure: displayCount(drafts.length),
                    period: today,
                    selected: drill == 3,
                    onTap: () => selectDrill(3),
                  ),
                ]),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (_, c) {
                    final scope = BilingualOwnedText(
                      data['scope'] as String,
                      style: caption,
                    );
                    final generated = BilingualInlineLine(
                      L10n.generatedAt,
                      style: caption,
                      value: Bilingual.data(
                        displayTimestamp(data['generated_at']),
                      ),
                    );
                    if (c.maxWidth < 720) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [scope, const SizedBox(height: 2), generated],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: scope),
                        const SizedBox(width: 16),
                        generated,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
              ];
              final body = <Widget>[
                if (drill != null) ...[
                  drillPanel(totals, dispatched: dispatched, drafts: drafts),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (_, c) {
                    final chart = vehicleChart(
                      data['rows'] as List,
                      period,
                      inline: c.maxWidth >= 560,
                    );
                    final attentionPanel = dashboardPanel(
                      title: L10n.needsAttention,
                      rows: attention,
                      empty: L10n.nothingNeedsAttention,
                    );
                    if (c.maxWidth < 860) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          chart,
                          const SizedBox(height: 12),
                          attentionPanel,
                        ],
                      );
                    }
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: chart),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: attentionPanel),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (_, c) {
                    final table = c.maxWidth >= 640;
                    return dashboardPanel(
                      title: L10n.todaysMovements,
                      header: table ? movementHeader() : null,
                      rows: [
                        for (final r in movements)
                          panelRow(table ? movementCells(r) : movementRow(r)),
                      ],
                      empty: L10n.noMovementsToday,
                    );
                  },
                ),
              ];
              // With four cards across, the cards stay pinned and only the
              // panels scroll. Once the cards stack they can outgrow the
              // window, so the whole dashboard scrolls as one page instead.
              return LayoutBuilder(
                builder: (_, c) {
                  if (c.maxWidth >= 996) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...head,
                        Expanded(child: ListView(children: body)),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...head, ...body],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  /// The headline cards as an even grid: four across on desktop, two by
  /// two on a narrow window, one per row on a phone. Every card in a row
  /// shares the tallest card's height, so a caption that wraps onto a
  /// second line no longer leaves its neighbours ragged.
  Widget kpiGrid(List<Widget> cards) => LayoutBuilder(
    builder: (_, c) {
      const gap = 12.0;
      final columns = (c.maxWidth - 3 * gap) / 4 >= 240
          ? 4
          : (c.maxWidth - gap) / 2 >= 240
          ? 2
          : 1;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var start = 0; start < cards.length; start += columns) ...[
            if (start > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: gap),
                    Expanded(
                      child: i < cards.length ? cards[i] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  /// One titled dashboard panel: a header with the row count, then the
  /// rows separated by hairlines, or a quiet empty line. A bordered
  /// surface rather than a [Card], so the panel reads as a list and the
  /// drill-down above it stays the only card on the page.
  Widget dashboardPanel({
    required Bilingual title,
    required List<Widget> rows,
    required Bilingual empty,
    Widget? header,
  }) {
    final type = Theme.of(context).textTheme;
    return KarvaanGlass(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(child: BilingualText(title, style: type.titleSmall)),
                  if (rows.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: KarvaanDesign.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          displayCount(rows.length),
                          textDirection: TextDirection.ltr,
                          style: type.labelSmall?.copyWith(
                            color: KarvaanDesign.secondary,
                            fontFeatures: KarvaanTypography.figureFeatures,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            if (header != null && rows.isNotEmpty) ...[
              ColoredBox(
                color: KarvaanDesign.muted,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: header,
                ),
              ),
              const Divider(height: 1),
            ],
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: BilingualText(
                  empty,
                  style: type.bodySmall?.copyWith(
                    color: KarvaanDesign.secondary,
                  ),
                ),
              ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  /// A panel row: uniform inset, optionally tappable across its full width.
  Widget panelRow(Widget child, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    ),
  );

  /// The drill-down panel: the records behind the tapped KPI figure.
  Widget drillPanel(
    Map<String, dynamic> totals, {
    required List<Map<String, dynamic>> dispatched,
    required List<Map<String, dynamic>> drafts,
  }) {
    final heading = switch (drill) {
      0 => L10n.dispatchedNow,
      1 => L10n.customerOutstanding,
      2 => L10n.settlementsDue,
      _ => L10n.draftTrips,
    };
    Widget content;
    if (drill == 0) {
      content = tripDrillRows(dispatched);
    } else if (drill == 3) {
      content = tripDrillRows(drafts);
    } else {
      content = moneyDrillRows(
        drill == 1 ? 'customer_outstanding' : 'owner_due',
        totals,
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: BilingualText(
                    heading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: L10n.close.inline,
                  onPressed: () => setState(() => drill = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget tripDrillRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: BilingualText(L10n.noRecordsInThisPeriodScope),
      );
    }
    return Column(
      children: [
        for (final row in rows)
          BilingualListTile(
            dense: true,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${row['trip_number']}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
                const SizedBox(width: 8),
                TripStatusBadge('${row['state']}'),
              ],
            ),
          ),
      ],
    );
  }

  /// Today's movements (plan §5.2): trips dispatched or arrived today.
  /// Reads only the already-fetched state lists.
  List<Map<String, dynamic>> todaysMovementRows(
    List<Map<String, dynamic>> dispatched,
    List<Map<String, dynamic>> arrived,
    String today,
  ) {
    bool isToday(Object? value) => (value ?? '').toString().startsWith(today);
    return [
      for (final r in dispatched)
        if (isToday(r['dispatch_date'])) r,
      for (final r in arrived)
        if (isToday(r['arrival_date'])) r,
    ].take(6).toList();
  }

  Widget movementRow(Map<String, dynamic> r) {
    final type = Theme.of(context).textTheme;
    final origin = (r['origin_name'] ?? '').toString();
    final destination = (r['destination_name'] ?? '').toString();
    final route = [
      if (origin.isNotEmpty) origin,
      if (destination.isNotEmpty) destination,
    ].join(' → ');
    final meta = [
      (r['trip_number'] ?? '').toString(),
      (r['registration'] ?? '').toString(),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                route.isEmpty ? meta : route,
                textDirection: TextDirection.ltr,
                style: type.titleSmall,
              ),
              if (route.isNotEmpty && meta.isNotEmpty)
                Text(
                  meta,
                  textDirection: TextDirection.ltr,
                  style: type.bodySmall?.copyWith(
                    color: KarvaanDesign.secondary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TripStatusBadge((r['state'] ?? '').toString()),
      ],
    );
  }

  /// Column heads for the movements table; widths mirror [movementCells].
  Widget movementHeader() {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: KarvaanDesign.secondary);
    return Row(
      children: [
        Expanded(flex: 3, child: BilingualText(L10n.trip, style: style)),
        Expanded(flex: 4, child: BilingualText(L10n.routeLabel, style: style)),
        Expanded(flex: 3, child: BilingualText(L10n.vehicle, style: style)),
        Expanded(
          flex: 3,
          child: BilingualText(
            L10n.historyFieldStatus,
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  /// One movement as a table row: trip, route, vehicle, status.
  Widget movementCells(Map<String, dynamic> r) {
    final type = Theme.of(context).textTheme;
    final origin = (r['origin_name'] ?? '').toString();
    final destination = (r['destination_name'] ?? '').toString();
    final route = [
      if (origin.isNotEmpty) origin,
      if (destination.isNotEmpty) destination,
    ].join(' → ');
    Widget cell(String text, TextStyle? style) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        text.isEmpty ? '—' : text,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: cell((r['trip_number'] ?? '').toString(), type.titleSmall),
        ),
        Expanded(flex: 4, child: cell(route, type.bodyMedium)),
        Expanded(
          flex: 3,
          child: cell(
            (r['registration'] ?? '').toString(),
            type.bodyMedium?.copyWith(color: KarvaanDesign.secondary),
          ),
        ),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: TripStatusBadge((r['state'] ?? '').toString()),
          ),
        ),
      ],
    );
  }

  /// The supporting fact on a headline card: a period figure the report
  /// already carries, under its own catalogue label.
  Widget kpiDetail(String key, Map<String, dynamic> totals) => Wrap(
    spacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      BilingualText(_valueLabel(key, lifetime: false, plainLabel: true)),
      Text(
        displayField(
          ['dispatched', 'arrived'].contains(key) ? 'INTEGER' : 'MONEY',
          totals[key],
        ),
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontFeatures: KarvaanTypography.figureFeatures),
      ),
    ],
  );

  static const _chartMetrics = [
    'customer_fare',
    'vehicle_cost',
    'operating_profit',
  ];

  BigInt _paisa(Object? amount) {
    if (amount == null) return BigInt.zero;
    try {
      return LedgerAmount.fromJson(amount).paisa;
    } on FormatException {
      return BigInt.zero;
    }
  }

  /// The period by vehicle: the six largest figures of the chosen measure
  /// as bars scaled to the largest. Reads the report rows the dashboard
  /// already fetched; vehicles with nothing for the measure are left out.
  Widget vehicleChart(
    List<dynamic> rows,
    String period, {
    required bool inline,
  }) {
    final type = Theme.of(context).textTheme;
    final quiet = type.bodySmall?.copyWith(color: KarvaanDesign.secondary);
    final ranked =
        <(Map<dynamic, dynamic>, BigInt)>[
            for (final row in rows)
              (row as Map, _paisa((row['values'] as Map)[chartMetric])),
          ]
          ..removeWhere((entry) => entry.$2 == BigInt.zero)
          ..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
    final shown = ranked.take(6).toList();
    final peak = shown.isEmpty ? BigInt.one : shown.first.$2.abs();

    Widget bar(BigInt amount) => Container(
      height: 8,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: KarvaanDesign.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        widthFactor: ((amount.abs() * BigInt.from(1000) ~/ peak).toInt() / 1000)
            .clamp(0.02, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: amount.isNegative
                ? KarvaanDesign.destructive
                : KarvaanDesign.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    Widget chartRow((Map<dynamic, dynamic>, BigInt) entry) {
      final name = Text(
        '${entry.$1['name']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: type.bodyMedium,
      );
      final figure = Text(
        displayField('MONEY', (entry.$1['values'] as Map)[chartMetric]),
        textDirection: TextDirection.ltr,
        style: type.bodyMedium?.copyWith(
          fontFamily: KarvaanTypography.figureFamily,
          fontFamilyFallback: KarvaanTypography.latinFallback,
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: inline
            ? Row(
                children: [
                  SizedBox(width: 150, child: name),
                  const SizedBox(width: 12),
                  Expanded(child: bar(entry.$2)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: figure,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: name),
                      const SizedBox(width: 12),
                      figure,
                    ],
                  ),
                  const SizedBox(height: 6),
                  bar(entry.$2),
                ],
              ),
      );
    }

    return KarvaanGlass(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              BilingualText(L10n.vehicles, style: type.titleSmall),
              const SizedBox(height: 2),
              Text(period, textDirection: TextDirection.ltr, style: quiet),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in _chartMetrics)
                    ChoiceChip(
                      key: ValueKey('dashboard-chart-$key'),
                      label: BilingualText(
                        _valueLabel(key, lifetime: false, plainLabel: true),
                      ),
                      selected: chartMetric == key,
                      onSelected: (_) => setState(() => chartMetric = key),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: BilingualText(
                    L10n.noRecordsInThisPeriodScope,
                    style: quiet,
                  ),
                ),
              for (final entry in shown) chartRow(entry),
            ],
          ),
        ),
      ),
    );
  }

  /// The attention rows (plan §5.2): draft trips waiting on the office and
  /// money owed, each row opening its KPI drill-down. Empty on a clear day.
  List<Widget> attentionRows(
    Map<String, dynamic> totals,
    List<Map<String, dynamic>> drafts,
  ) {
    final type = Theme.of(context).textTheme;
    Widget moneyRow(Bilingual label, String key, Color color, int target) =>
        panelRow(
          Row(
            children: [
              Expanded(child: BilingualText(label, style: type.titleSmall)),
              const SizedBox(width: 8),
              KarvaanFigure(
                displayField('MONEY', totals[key]),
                style: type.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
          onTap: () => selectDrill(target),
        );
    return [
      for (final r in drafts.take(5))
        panelRow(movementRow(r), onTap: () => selectDrill(3)),
      if (!_isZeroKpi('owner_due', totals['owner_due']))
        moneyRow(L10n.settlementsDue, 'owner_due', KarvaanDesign.attention, 2),
      if (!_isZeroKpi('customer_outstanding', totals['customer_outstanding']))
        moneyRow(
          L10n.customerOutstanding,
          'customer_outstanding',
          KarvaanDesign.money,
          1,
        ),
    ];
  }

  Widget moneyDrillRows(String key, Map<String, dynamic> totals) =>
      FutureBuilder<Map<String, dynamic>>(
        future: claims,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (s.hasError || !s.hasData) {
            return const BilingualText(
              L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
            );
          }
          final data = s.data!;
          final rows = data['rows'] as List;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              value(key, totals[key], hero: true),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: BilingualText(L10n.noRecordsInThisPeriodScope),
                ),
              for (final row in rows)
                BilingualListTile(
                  dense: true,
                  title: Text(row['name'] as String),
                  trailing: KarvaanFigure(
                    displayField('MONEY', (row['values'] as Map)[key]),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          );
        },
      );

  /// Density pass: the controls stay fixed in a compact section and the
  /// results scroll inside their own region, so the Reports page fits
  /// the desktop viewport instead of page-scrolling. On short windows
  /// the controls section scrolls internally (owner-approved panel
  /// scroll) rather than overflowing.
  Widget reportBuilderBody() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: KarvaanSection(
              padding: const EdgeInsets.all(16),
              title: L10n.reportPeriod,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: KarvaanChoiceField<String>(
                      initialValue: kind,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(label: BilingualCaption(L10n.report)),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'MONTHLY_VEHICLE',
                          child: BilingualText(L10n.vehicleMonthly),
                        ),
                        DropdownMenuItem(
                          value: 'MONTHLY_OWNER',
                          child: BilingualText(L10n.ownerMonthly),
                        ),
                        DropdownMenuItem(
                          value: 'CLAIMS',
                          child: BilingualText(L10n.partyClaimsAndHeldMoney),
                        ),
                        DropdownMenuItem(
                          value: 'TRIP_PROFIT',
                          child: BilingualText(L10n.lifetimeTripProfit),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          kind = v!;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: KarvaanDateField(
                      controller: from,
                      label: L10n.dateFrom,
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: KarvaanDateField(controller: to, label: L10n.dateTo),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: search,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(L10n.tripVehicleSearch),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: KarvaanChoiceField<String>(
                      initialValue: office,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(L10n.officeScope),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: BilingualText(L10n.allPermittedOffices),
                        ),
                        for (final o in widget.offices)
                          DropdownMenuItem(
                            value: o['id'] as String,
                            child: Text(o['name'] as String),
                          ),
                      ],
                      onChanged: (v) => setState(() => office = v),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => pick('VEHICLE'),
                    child: BilingualCaption(
                      (vehicleName != null
                          ? Bilingual.data(vehicleName)
                          : L10n.selectVehicle),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => pick('OWNER'),
                    child: BilingualCaption(
                      (ownerName != null
                          ? Bilingual.data(ownerName)
                          : L10n.selectHistoricalOwner),
                    ),
                  ),
                  if (kind == 'TRIP_PROFIT')
                    OutlinedButton(
                      onPressed: () => pick('TRIP'),
                      child: BilingualCaption(
                        (tripName != null
                            ? Bilingual.data(tripName)
                            : L10n.selectTrip),
                      ),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      vehicle = owner = trip = null;
                      vehicleName = ownerName = tripName = null;
                      search.clear();
                    }),
                    child: const BilingualCaption(L10n.clearRecordFilters),
                  ),
                  FilledButton(
                    onPressed: () => reload(),
                    child: const BilingualCaption(L10n.runReport),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: page,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (s.hasError) {
                return const BilingualText(
                  L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
                );
              }
              final data = s.data!;
              final totals = Map<String, dynamic>.from(data['totals'] as Map);
              final rows = data['rows'] as List;
              final lifetime = data['lifetime'] == true;
              final primary = switch (kind) {
                'MONTHLY_OWNER' || 'TRIP_PROFIT' => 'owner_profit',
                'CLAIMS' => 'customer_outstanding',
                _ => 'operating_profit',
              };
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilingualOwnedText(
                      data['scope'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    BilingualText(
                      L10n.offices024b84.withValues([
                        (data['offices'] as List).join(', '),
                      ]),
                    ),
                    BilingualText(
                      (lifetime
                          ? L10n.lifetimeTripAllLinkedDatesCurrentBalances
                          : L10n.to.withValues([
                              (data['period'] as Map)['from'],
                              (data['period'] as Map)['to'],
                            ])),
                    ),
                    BilingualInlineLine(
                      L10n.generatedAt,
                      value: Bilingual.data(
                        displayTimestamp(data['generated_at']),
                      ),
                    ),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: BilingualText(L10n.noRecordsInThisPeriodScope),
                      ),
                    // One hero figure per report (plan §5.7); the remaining
                    // metrics sit in themed groups, zero values behind the
                    // Show-all toggle.
                    SizedBox(
                      width: 280,
                      child: _reportKpiCard(
                        primary,
                        totals[primary],
                        lifetime: lifetime,
                        hero: true,
                      ),
                    ),
                    Row(
                      children: [
                        Switch(
                          value: showAllKpis,
                          onChanged: (v) => setState(() => showAllKpis = v),
                        ),
                        const BilingualText(L10n.showAll),
                      ],
                    ),
                    for (final (heading, keys) in _kpiGroups)
                      if (keys.any(
                        (key) =>
                            key != primary &&
                            (showAllKpis || !_isZeroKpi(key, totals[key])),
                      )) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: BilingualText(
                            heading,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final key in keys)
                              if (key != primary &&
                                  (showAllKpis ||
                                      !_isZeroKpi(key, totals[key])))
                                SizedBox(
                                  width: 280,
                                  child: _reportKpiCard(
                                    key,
                                    totals[key],
                                    lifetime: lifetime,
                                  ),
                                ),
                          ],
                        ),
                      ],
                    BilingualText(
                      L10n.groupsRowsPerPage.withValues([data['row_count']]),
                    ),
                    for (final row in rows)
                      ExpansionTile(
                        expansionAnimationStyle: AnimationStyle.noAnimation,
                        title: Text(row['name'] as String),
                        children: [
                          for (final key in reportLabels.keys)
                            BilingualListTile(
                              dense: true,
                              title: value(
                                key,
                                (row['values'] as Map)[key],
                                lifetime: lifetime,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    // Wrap, not Row: at 200% text scale the bilingual buttons
                    // plus the page label exceed a phone-width row.
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          onPressed: offset > 0
                              ? () => reload(start: offset - 50)
                              : null,
                          child: const BilingualCaption(L10n.previous),
                        ),
                        BilingualText(L10n.page.withValues([offset ~/ 50 + 1])),
                        TextButton(
                          onPressed: data['has_more'] == true
                              ? () => reload(start: offset + 50)
                              : null,
                          child: const BilingualCaption(L10n.next),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ShellHeader(
    // Title + actions live in the shell's single header row (header
    // compaction); the Dashboard's Reports action moved up beside
    // Create report and its old in-body button row is deleted.
    title: widget.dashboard ? L10n.dashboard : L10n.reports,
    actions: [
      if (widget.dashboard)
        ShellHeaderAction(
          // A shortcut to the same destination the rail's Reports item
          // opens; on phone bars it yields its room to the title (the
          // rail/menu keeps it reachable) rather than crushing it.
          hideOnNarrow: true,
          child: TextButton.icon(
            onPressed: openReportBuilder,
            icon: const Icon(Icons.assessment_outlined),
            label: const BilingualCaption(L10n.reports),
          ),
        ),
      if (widget.outputs != null)
        ShellHeaderAction(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => widget.guard(widget.outputs!)),
            ),
            child: const BilingualCaption(L10n.createReport),
          ),
          compactChild: IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => widget.guard(widget.outputs!)),
            ),
            icon: const Icon(Icons.post_add_outlined),
            tooltip: L10n.createReport.inMode(
              LanguageModeStore.instance.mode.value,
            ),
          ),
        ),
    ],
    child: Scaffold(
      body: widget.dashboard ? dashboardBody() : reportBuilderBody(),
    ),
  );
}

class _ReportChoice extends StatefulWidget {
  const _ReportChoice({
    required this.masters,
    required this.trips,
    required this.kind,
  });
  final MasterRepository masters;
  final TripRepository trips;
  final String kind;
  @override
  State<_ReportChoice> createState() => _ReportChoiceState();
}

class _ReportChoiceState extends State<_ReportChoice> {
  final search = TextEditingController();
  int offset = 0;
  late Future<List<Map<String, dynamic>>> rows;
  @override
  void initState() {
    super.initState();
    rows = fetch();
  }

  Future<List<Map<String, dynamic>>> fetch() async {
    if (widget.kind == 'TRIP') {
      final p = await widget.trips.list(search: search.text, offset: offset);
      return p.rows
          .map((r) => {'id': r['id'], 'label': r['trip_number']})
          .toList();
    }
    final p = await widget.masters.list(
      widget.kind == 'VEHICLE' ? MasterKind.vehicle : MasterKind.party,
      search: search.text,
      offset: offset,
    );
    return p
        .where((r) => widget.kind != 'OWNER' || r.roles.contains('OWNER'))
        .map((r) => {'id': r.id, 'label': r.label})
        .toList();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    scrollable: true,
    title: BilingualText(L10n.select.withValues([widget.kind.toLowerCase()])),
    content: SizedBox(
      width: 450,
      height: 450,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.search)),
            ),
            onSubmitted: (_) => setState(() {
              offset = 0;
              rows = fetch();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rows,
              builder: (_, s) {
                if (s.hasError) {
                  return const BilingualText(L10n.currentAccessRequired);
                }
                if (!s.hasData) return const LinearProgressIndicator();
                return ListView(
                  children: [
                    for (final r in s.data!)
                      BilingualListTile(
                        title: Text(r['label'] as String),
                        onTap: () => Navigator.pop(c, r),
                      ),
                  ],
                );
              },
            ),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: offset > 0
                    ? () => setState(() {
                        offset -= 50;
                        rows = fetch();
                      })
                    : null,
                child: const BilingualCaption(L10n.previous),
              ),
              TextButton(
                onPressed: () => setState(() {
                  offset += 50;
                  rows = fetch();
                }),
                child: const BilingualCaption(L10n.next),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const BilingualCaption(L10n.close),
      ),
    ],
  );
}
