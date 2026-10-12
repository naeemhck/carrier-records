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

  Widget value(String key, Object? amount, {bool lifetime = false}) => Text(
    '${lifetime ? reportLabels[key]?.replaceAll('period end', 'current lifetime').replaceAll('period costs', 'all linked costs').replaceAll('expense date', 'all linked expense dates') : reportLabels[key]}: ${['dispatched', 'arrived'].contains(key) ? amount : 'PKR ${LedgerAmount.fromJson(amount)}'}',
  );
  Widget journeys(Future<TripPage>? future, String title) =>
      FutureBuilder<TripPage>(
        future: future,
        builder: (_, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (s.hasError)
              const Text('Unable to load current permitted journeys.'),
            if (s.hasData) ...[
              Text(s.data!.scope),
              for (final row in s.data!.rows.take(5))
                Text('${row['trip_number']} · ${row['state']}'),
              if (s.data!.rows.isEmpty)
                const Text('No records in this period/scope.'),
            ],
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.dashboard ? 'Dashboard' : 'Reports'),
      actions: [
        if (widget.outputs != null)
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => widget.guard(widget.outputs!)),
            ),
            child: const Text('Outputs'),
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
                  decoration: const InputDecoration(labelText: 'Report'),
                  items: const [
                    DropdownMenuItem(
                      value: 'MONTHLY_VEHICLE',
                      child: Text('Vehicle monthly'),
                    ),
                    DropdownMenuItem(
                      value: 'MONTHLY_OWNER',
                      child: Text('Owner monthly'),
                    ),
                    DropdownMenuItem(
                      value: 'CLAIMS',
                      child: Text('Party claims and held money'),
                    ),
                    DropdownMenuItem(
                      value: 'TRIP_PROFIT',
                      child: Text('Lifetime trip profit'),
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
                    decoration: InputDecoration(labelText: entry.$1),
                  ),
                ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: office,
                  decoration: const InputDecoration(labelText: 'Office scope'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All permitted offices'),
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
                child: Text(vehicleName ?? 'Select vehicle'),
              ),
              OutlinedButton(
                onPressed: () => pick('OWNER'),
                child: Text(ownerName ?? 'Select historical owner'),
              ),
              if (kind == 'TRIP_PROFIT')
                OutlinedButton(
                  onPressed: () => pick('TRIP'),
                  child: Text(tripName ?? 'Select trip'),
                ),
              TextButton(
                onPressed: () => setState(() {
                  vehicle = owner = trip = null;
                  vehicleName = ownerName = tripName = null;
                  search.clear();
                }),
                child: const Text('Clear record filters'),
              ),
              FilledButton(
                onPressed: () => reload(),
                child: const Text('Run report'),
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
                return const Text(
                  'Report unavailable. Check dates, trip selection and current office access, then retry.',
                );
              }
              final data = s.data!;
              final totals = Map<String, dynamic>.from(data['totals'] as Map);
              final rows = data['rows'] as List;
              final lifetime = data['lifetime'] == true;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['scope'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('Offices: ${(data['offices'] as List).join(', ')}'),
                  Text(
                    lifetime
                        ? 'Lifetime trip — all linked dates; current balances'
                        : '${(data['period'] as Map)['from']} to ${(data['period'] as Map)['to']}',
                  ),
                  Text(
                    'Generated ${data['generated_at']} · current effective records; corrections can change earlier periods',
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No records in this period/scope.'),
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
                  Text('${data['row_count']} groups · 50 rows per page'),
                  for (final row in rows)
                    ExpansionTile(
                      title: Text(row['name'] as String),
                      children: [
                        for (final key in reportLabels.keys)
                          ListTile(
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
                        child: const Text('Previous'),
                      ),
                      Text('Page ${offset ~/ 50 + 1}'),
                      TextButton(
                        onPressed: data['has_more'] == true
                            ? () => reload(start: offset + 50)
                            : null,
                        child: const Text('Next'),
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
    title: Text('Select ${widget.kind.toLowerCase()}'),
    content: SizedBox(
      width: 450,
      height: 450,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Search'),
            onSubmitted: (_) => setState(() {
              offset = 0;
              rows = fetch();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rows,
              builder: (_, s) {
                if (s.hasError) return const Text('Current access required.');
                if (!s.hasData) return const LinearProgressIndicator();
                return ListView(
                  children: [
                    for (final r in s.data!)
                      ListTile(
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
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  offset += 50;
                  rows = fetch();
                }),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
    ],
  );
}
