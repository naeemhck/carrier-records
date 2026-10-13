import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../finance/financial_repository.dart';
import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import '../trips/trip_workspace.dart';
import 'report_repository.dart';

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
  late Future<Map<String, dynamic>> page;
  Future<TripPage>? recent, pending;
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
      page = widget.reports.report(kind, filters, offset: offset);
      if (widget.dashboard) {
        recent = widget.trips.list(
          office: office,
          vehicle: vehicle,
          from: from.text,
          to: to.text,
        );
        pending = widget.trips.list(
          office: office,
          vehicle: vehicle,
          state: 'DISPATCHED',
        );
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

  Future<void> pick(String target) async {
    final result = await showDialog<Map<String, dynamic>>(
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

  Widget value(String key, Object? amount, {bool lifetime = false}) =>
      BilingualText(
        L10n.labelValuesfb62fe.withValues([
          ownedMessage(
            lifetime
                ? reportLabels[key]
                      ?.replaceAll('period end', 'current lifetime')
                      .replaceAll('period costs', 'all linked costs')
                      .replaceAll('expense date', 'all linked expense dates')
                : reportLabels[key],
          ),
          ['dispatched', 'arrived'].contains(key)
              ? amount
              : 'PKR ${LedgerAmount.fromJson(amount)}',
        ]),
      );
  Widget journeys(Future<TripPage>? future, String title) =>
      FutureBuilder<TripPage>(
        future: future,
        builder: (_, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BilingualOwnedText(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (s.hasError)
              const BilingualText(L10n.unableToLoadCurrentPermittedJourneys),
            if (s.hasData) ...[
              BilingualOwnedText(s.data!.scope),
              for (final row in s.data!.rows.take(5))
                BilingualText(
                  L10n.labelValuescd55a9.withValues([
                    row['trip_number'],
                    row['state'],
                  ]),
                ),
              if (s.data!.rows.isEmpty)
                const BilingualText(L10n.noRecordsInThisPeriodScope),
            ],
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
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.dashboard && widget.backupStatus != null)
            widget.backupStatus!,
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
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
              for (final entry in [
                ('From (YYYY-MM-DD)', from),
                ('To (YYYY-MM-DD)', to),
                ('Trip / vehicle search', search),
              ])
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: entry.$2,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(label: BilingualOwnedCaption(entry.$1)),
                    ),
                  ),
                ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BilingualOwnedText(
                    data['scope'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
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
                  BilingualText(
                    L10n.generatedCurrentEffectiveRecordsCorrectionsCanChangeEarlierPeriods
                        .withValues([data['generated_at']]),
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: BilingualText(L10n.noRecordsInThisPeriodScope),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final key
                          in widget.dashboard
                              ? [
                                  'dispatched',
                                  'arrived',
                                  'owner_earnings',
                                  'vehicle_cost',
                                  'operating_profit',
                                  'customer_outstanding',
                                  'owner_due',
                                ]
                              : reportLabels.keys)
                        SizedBox(
                          width: 310,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: InkWell(
                                onTap: widget.dashboard
                                    ? () {
                                        setState(
                                          () => kind =
                                              [
                                                'customer_outstanding',
                                                'owner_due',
                                              ].contains(key)
                                              ? 'CLAIMS'
                                              : 'MONTHLY_VEHICLE',
                                        );
                                        reload();
                                      }
                                    : null,
                                child: value(
                                  key,
                                  totals[key],
                                  lifetime: lifetime,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  BilingualText(
                    L10n.groupsRowsPerPage.withValues([data['row_count']]),
                  ),
                  for (final row in rows)
                    ExpansionTile(
                      title: Text(row['name'] as String),
                      children: [
                        for (final key in reportLabels.keys)
                          BilingualListTile(
                            dense: true,
                            title: value(
                              key,
                              (row['values'] as Map)[key],
                              lifetime: lifetime,
                            ),
                          ),
                      ],
                    ),
                  Row(
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
                  if (widget.dashboard) ...[
                    journeys(recent, 'Recent journeys (up to 5)'),
                    journeys(pending, 'Pending arrivals (up to 5; all dates)'),
                  ],
                ],
              );
            },
          ),
        ],
      ),
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
          Row(
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
