import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';
import '../../app/karvaan_patterns.dart';

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

  /// KPI-first dashboard: four headline cards answering "what needs me right
  /// now" on one viewport. The report builder is one tap away on its own page.
  Widget dashboardBody() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (widget.backupStatus != null) widget.backupStatus!,
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          onPressed: openReportBuilder,
          icon: const Icon(Icons.assessment_outlined),
          label: const BilingualCaption(L10n.reports),
        ),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<dynamic>>(
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (_, c) {
                  final width = (c.maxWidth - 3 * 12) / 4;
                  Widget card(Widget child) => SizedBox(
                    width: width < 240 ? c.maxWidth : width,
                    child: child,
                  );
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      card(
                        KpiCard(
                          label: L10n.dispatchedNow,
                          figure: displayCount(dispatched.length),
                          period: today,
                          filled: true,
                          onTap: () => selectDrill(0),
                        ),
                      ),
                      card(
                        KpiCard(
                          label: L10n.customerOutstanding,
                          figure: displayField(
                            'MONEY',
                            totals['customer_outstanding'],
                          ),
                          period: period,
                          onTap: () => selectDrill(1),
                        ),
                      ),
                      card(
                        KpiCard(
                          label: L10n.settlementsDue,
                          figure: displayField('MONEY', totals['owner_due']),
                          period: period,
                          onTap: () => selectDrill(2),
                        ),
                      ),
                      card(
                        KpiCard(
                          label: L10n.draftTrips,
                          figure: displayCount(drafts.length),
                          period: today,
                          onTap: () => selectDrill(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              BilingualOwnedText(
                data['scope'] as String,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              BilingualInlineLine(
                L10n.generatedAt,
                value: Bilingual.data(displayTimestamp(data['generated_at'])),
              ),
              if (drill != null) ...[
                const SizedBox(height: 16),
                drillPanel(totals, dispatched: dispatched, drafts: drafts),
              ],
              const SizedBox(height: 24),
              BilingualText(
                L10n.todaysMovements,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              movementsList(dispatched, arrived, today),
              const SizedBox(height: 24),
              BilingualText(
                L10n.needsAttention,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              attentionList(totals, drafts),
            ],
          );
        },
      ),
    ],
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

  /// Today's movements (plan §5.2): trips dispatched or arrived today as
  /// compact route rows. Reads only the already-fetched state lists.
  Widget movementsList(
    List<Map<String, dynamic>> dispatched,
    List<Map<String, dynamic>> arrived,
    String today,
  ) {
    bool isToday(Object? value) => (value ?? '').toString().startsWith(today);
    final rows = [
      for (final r in dispatched)
        if (isToday(r['dispatch_date'])) r,
      for (final r in arrived)
        if (isToday(r['arrival_date'])) r,
    ];
    if (rows.isEmpty) {
      return BilingualText(
        L10n.noMovementsToday,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: KarvaanDesign.secondary),
      );
    }
    return Column(children: [for (final r in rows.take(6)) movementRow(r)]);
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
      ),
    );
  }

  /// The attention list (plan §5.2): draft trips waiting on the office and
  /// money owed, each row opening its KPI drill-down. A clear day says so.
  Widget attentionList(
    Map<String, dynamic> totals,
    List<Map<String, dynamic>> drafts,
  ) {
    final type = Theme.of(context).textTheme;
    final rows = <Widget>[];
    for (final r in drafts.take(5)) {
      rows.add(InkWell(onTap: () => selectDrill(3), child: movementRow(r)));
    }
    if (!_isZeroKpi('owner_due', totals['owner_due'])) {
      rows.add(
        InkWell(
          onTap: () => selectDrill(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: BilingualText(
                    L10n.settlementsDue,
                    style: type.titleSmall,
                  ),
                ),
                KarvaanFigure(
                  displayField('MONEY', totals['owner_due']),
                  style: type.titleMedium?.copyWith(
                    color: KarvaanDesign.attention,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_isZeroKpi('customer_outstanding', totals['customer_outstanding'])) {
      rows.add(
        InkWell(
          onTap: () => selectDrill(1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: BilingualText(
                    L10n.customerOutstanding,
                    style: type.titleSmall,
                  ),
                ),
                KarvaanFigure(
                  displayField('MONEY', totals['customer_outstanding']),
                  style: type.titleMedium?.copyWith(color: KarvaanDesign.money),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return BilingualText(
        L10n.nothingNeedsAttention,
        style: type.bodySmall?.copyWith(color: KarvaanDesign.secondary),
      );
    }
    return Column(children: rows);
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

  Widget reportBuilderBody() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KarvaanSection(
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
              for (final entry in <(Object, TextEditingController)>[
                ('From (YYYY-MM-DD)', from),
                ('To (YYYY-MM-DD)', to),
                (L10n.tripVehicleSearch, search),
              ])
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: entry.$2,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: entry.$1 is Bilingual
                            ? BilingualCaption(entry.$1 as Bilingual)
                            : BilingualOwnedCaption(entry.$1),
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
                    InputDecoration(label: BilingualCaption(L10n.officeScope)),
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
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
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
            return Column(
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
                  value: Bilingual.data(displayTimestamp(data['generated_at'])),
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
                  width: 310,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: value(
                        primary,
                        totals[primary],
                        lifetime: lifetime,
                        hero: true,
                        plainLabel: true,
                      ),
                    ),
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
                              (showAllKpis || !_isZeroKpi(key, totals[key])))
                            SizedBox(
                              width: 310,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: value(
                                    key,
                                    totals[key],
                                    lifetime: lifetime,
                                    plainLabel: true,
                                  ),
                                ),
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
            );
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: BilingualText((widget.dashboard ? L10n.dashboard : L10n.reports)),
      actions: [
        if (widget.outputs != null)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => widget.guard(widget.outputs!)),
            ),
            child: const BilingualCaption(L10n.outputs),
          ),
      ],
    ),
    body: widget.dashboard ? dashboardBody() : reportBuilderBody(),
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
