import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../masters/master_repository.dart';
import 'trip_draft.dart';
import 'trip_repository.dart';
import 'trip_lifecycle.dart';
import 'trip_operation_dialog.dart';
import '../finance/financial_repository.dart';
import '../finance/payment_workspace.dart';
import '../finance/correction_repository.dart';
import '../finance/correction_workspace.dart';

Widget unguardedTrip(Widget child) => child;

String tripError(Object e) => e is FormatException
    ? e.message
    : e is PostgrestException
    ? (e.code == '40001' || e.code == 'PT409'
          ? TripStrings.conflict
          : TripStrings.serverErrors[e.message] ?? TripStrings.failed)
    : TripStrings.failed;

class TripWorkspace extends StatefulWidget {
  const TripWorkspace({
    super.key,
    required this.repository,
    required this.masters,
    required this.offices,
    this.guard = unguardedTrip,
    this.finance,
    this.corrections,
  });
  final TripRepository repository;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final Widget Function(Widget) guard;
  final FinancialCommands? finance;
  final CorrectionCommands? corrections;
  @override
  State<TripWorkspace> createState() => _TripWorkspaceState();
}

class _TripWorkspaceState extends State<TripWorkspace> {
  final search = TextEditingController(),
      from = TextEditingController(),
      to = TextEditingController();
  late Future<TripPage> page;
  String? office, vehicle, vehicleName, status;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    page = fetch();
  }

  Future<TripPage> fetch() => widget.repository.list(
    search: search.text.trim(),
    offset: offset,
    office: office,
    vehicle: vehicle,
    state: status,
    from: from.text.trim().isEmpty ? null : from.text.trim(),
    to: to.text.trim().isEmpty ? null : to.text.trim(),
  );
  void reload({int? start}) {
    setState(() {
      offset = start ?? offset;
      page = fetch();
    });
  }

  @override
  void dispose() {
    search.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<void> edit(TripDraft draft) async {
    final saved = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.guard(
          TripEditor(
            repository: widget.repository,
            masters: widget.masters,
            offices: widget.offices,
            draft: draft,
          ),
        ),
      ),
    );
    if (!mounted) return;
    reload(start: 0);
    if (saved != null) await detail(saved['id'] as String, saved: true);
  }

  Future<void> detail(String id, {bool saved = false}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.guard(
          TripDetail(
            repository: widget.repository,
            id: id,
            saved: saved,
            canReturn: (o) => widget.offices.any((a) => a['id'] == o),
            onEdit: edit,
            guard: widget.guard,
            onCorrections: widget.corrections == null
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => widget.guard(
                        CorrectionWorkspace(
                          commands: widget.corrections!,
                          trips: widget.repository,
                          guard: widget.guard,
                          initialTrip: id,
                        ),
                      ),
                    ),
                  ),
            onPayments: widget.finance == null
                ? null
                : () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => widget.guard(
                        PaymentWorkspace(
                          guard: widget.guard,
                          finance: widget.finance!,
                          trips: widget.repository,
                          masters: widget.masters,
                          offices: widget.offices,
                          initialTrip: id,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(TripStrings.trips)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => edit(TripDraft()),
          icon: const Icon(Icons.add),
          label: const Text(TripStrings.newTrip),
        ),
        TextField(
          controller: search,
          decoration: const InputDecoration(labelText: TripStrings.search),
          onSubmitted: (_) => reload(start: 0),
        ),
        DropdownButtonFormField<String>(
          initialValue: office,
          decoration: const InputDecoration(labelText: 'Office filter'),
          items: [
            const DropdownMenuItem(value: null, child: Text(TripStrings.all)),
            for (final o in widget.offices)
              DropdownMenuItem(
                value: o['id'] as String,
                child: Text(o['name'] as String),
              ),
          ],
          onChanged: (v) {
            office = v;
            reload(start: 0);
          },
        ),
        ListTile(
          title: Text(vehicleName ?? 'Vehicle filter: all'),
          trailing: Wrap(
            children: [
              TextButton(
                onPressed: () async {
                  final v = await chooseMaster(
                    context,
                    widget.masters,
                    MasterKind.vehicle,
                  );
                  if (v != null && mounted) {
                    vehicle = v.id;
                    vehicleName = v.label;
                    reload(start: 0);
                  }
                },
                child: const Text(TripStrings.choose),
              ),
              TextButton(
                onPressed: () {
                  vehicle = null;
                  vehicleName = null;
                  reload(start: 0);
                },
                child: const Text(TripStrings.clear),
              ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Trip state'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All states')),
            for (final s in ['DRAFT', 'DISPATCHED', 'ARRIVED', 'CANCELLED'])
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) {
            status = v;
            reload(start: 0);
          },
        ),
        TextField(
          controller: from,
          decoration: InputDecoration(labelText: TripStrings.labels['from']),
        ),
        TextField(
          controller: to,
          decoration: InputDecoration(labelText: TripStrings.labels['to']),
        ),
        TextButton(
          onPressed: () => reload(start: 0),
          child: const Text(TripStrings.refresh),
        ),
        FutureBuilder<TripPage>(
          future: page,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(tripError(snapshot.error!));
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final result = snapshot.data!;
            return Column(
              children: [
                Text(
                  result.scope == 'ALL_OFFICES'
                      ? TripStrings.all
                      : TripStrings.scope,
                ),
                if (result.rows.isEmpty) const Text(TripStrings.empty),
                for (final r in result.rows)
                  Card(
                    child: ListTile(
                      key: ValueKey('trip:${r['id']}'),
                      title: Text('${r['trip_number']} · ${r['registration']}'),
                      subtitle: Text(
                        '${r['origin_name']} → ${r['destination_name']}\n${r['state']} · ${r['load_kind']} · ${r['dispatch_date'] ?? r['planned_dispatch_date'] ?? ''}',
                      ),
                      onTap: () => detail(r['id'] as String),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: offset == 0
                          ? null
                          : () => reload(start: offset - 50),
                      child: const Text(TripStrings.previous),
                    ),
                    TextButton(
                      onPressed: result.rows.length < 50
                          ? null
                          : () => reload(start: offset + 50),
                      child: const Text(TripStrings.next),
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
}

Future<MasterRecord?> chooseMaster(
  BuildContext context,
  MasterRepository repository,
  MasterKind kind, {
  String? role,
}) => showDialog<MasterRecord>(
  context: context,
  builder: (_) => _MasterChoice(repository: repository, kind: kind, role: role),
);

class _MasterChoice extends StatefulWidget {
  const _MasterChoice({
    required this.repository,
    required this.kind,
    this.role,
  });
  final MasterRepository repository;
  final MasterKind kind;
  final String? role;
  @override
  State<_MasterChoice> createState() => _MasterChoiceState();
}

class _MasterChoiceState extends State<_MasterChoice> {
  final search = TextEditingController();
  late Future<List<MasterRecord>> rows;
  int offset = 0;
  @override
  void initState() {
    super.initState();
    rows = fetch();
  }

  Future<List<MasterRecord>> fetch() => widget.repository.list(
    widget.kind,
    search: search.text.trim(),
    offset: offset,
  );
  void reload(int start) {
    setState(() {
      offset = start;
      rows = fetch();
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('${TripStrings.choose} ${widget.role ?? widget.kind.label}'),
    content: SizedBox(
      width: 480,
      height: 420,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(
              labelText: TripStrings.searchChoices,
            ),
            onSubmitted: (_) => reload(0),
          ),
          TextButton(
            onPressed: () => reload(0),
            child: const Text(TripStrings.refresh),
          ),
          Expanded(
            child: FutureBuilder<List<MasterRecord>>(
              future: rows,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text(tripError(snapshot.error!));
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!;
                final choices = all
                    .where(
                      (r) =>
                          !r.archived &&
                          (widget.role == null ||
                              r.roles.contains(widget.role)),
                    )
                    .toList();
                return ListView(
                  children: [
                    if (choices.isEmpty) const Text(TripStrings.noChoices),
                    for (final r in choices)
                      ListTile(
                        title: Text(r.label),
                        subtitle: Text(r.value('code')),
                        onTap: () => Navigator.pop(context, r),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: offset == 0
                              ? null
                              : () => reload(offset - 50),
                          child: const Text(TripStrings.previous),
                        ),
                        TextButton(
                          onPressed: all.length < 50
                              ? null
                              : () => reload(offset + 50),
                          child: const Text(TripStrings.next),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(TripStrings.close),
      ),
    ],
  );
}

class TripEditor extends StatefulWidget {
  const TripEditor({
    super.key,
    required this.repository,
    required this.masters,
    required this.offices,
    required this.draft,
  });
  final TripRepository repository;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final TripDraft draft;
  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  TripDraft get d => widget.draft;
  bool busy = false, conflicted = false;
  String? error, pendingBase, pendingRequest;
  Map<String, dynamic>? pendingPayload;
  Future<void> defaults({bool replaceOwner = false}) async {
    if (d.vehicle == null ||
        d.origin == null ||
        d.destination == null ||
        d.origin == d.destination) {
      return;
    }
    try {
      final v = await widget.repository.defaults(d);
      if (!mounted) return;
      setState(() {
        if (replaceOwner || d.version == 0) {
          d.ownerName =
              (v['owner_snapshot'] as Map?)?['display_name'] as String?;
        }
        d.suggestedFare = v['suggested_fare'] as String?;
      });
    } catch (e) {
      if (mounted) setState(() => error = tripError(e));
    }
  }

  Future<void> pick(String field, MasterKind kind, {String? role}) async {
    final r = await chooseMaster(context, widget.masters, kind, role: role);
    if (r == null || !mounted) return;
    if (field == 'vehicle' && d.vehicle == r.id) return;
    setState(() {
      switch (field) {
        case 'vehicle':
          d.vehicle = r.id;
          d.registration = r.label;
          d.driver = r.data['default_driver_id'] as String?;
          d.driverName = null;
        case 'driver':
          d.driver = r.id;
          d.driverName = r.label;
        case 'destination':
          d.destination = r.id;
          d.destinationName = r.label;
        case 'route':
          d.route = r.id;
          d.routeName = r.label;
          d.suggestedFare = r.data['suggested_fare'] as String?;
      }
    });
    // Only explicit vehicle/route selection refreshes master defaults; editing a
    // saved draft must retain its recorded owner and fare until that selection.
    if (field == 'vehicle') {
      await defaults(replaceOwner: true);
    } else if (d.version == 0 && (field == 'route' || field == 'destination')) {
      await defaults();
    }
  }

  Widget field(
    String key,
    String value,
    ValueChanged<String> change, {
    String? label,
    Object? revision,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      key: ValueKey('$key:${revision ?? ''}'),
      initialValue: value,
      enabled: !busy,
      decoration: InputDecoration(labelText: label ?? TripStrings.labels[key]),
      onChanged: (v) => setState(() => change(v)),
    ),
  );
  Widget choice(
    String key,
    String? value,
    List<String> choices,
    ValueChanged<String?> change, {
    String? label,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key:$value:${choices.join(',')}'),
      initialValue: choices.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label ?? TripStrings.labels[key]),
      items: [
        for (final v in choices) DropdownMenuItem(value: v, child: Text(v)),
      ],
      onChanged: busy ? null : (v) => setState(() => change(v)),
    ),
  );
  Widget picker(
    String key,
    String? label,
    VoidCallback select, {
    VoidCallback? clear,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('${TripStrings.labels[key]}: ${label ?? TripStrings.none}'),
    trailing: Wrap(
      children: [
        TextButton(
          onPressed: busy ? null : select,
          child: const Text(TripStrings.choose),
        ),
        if (clear != null)
          TextButton(
            onPressed: busy ? null : () => setState(clear),
            child: const Text(TripStrings.clear),
          ),
      ],
    ),
  );
  Widget stopChoice(
    String key,
    String? id,
    String kind,
    ValueChanged<String?> update,
  ) {
    final rows = d.stops.where((s) => s.kind == kind).toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('$key:$id:${rows.map((s) => s.id).join(',')}'),
      initialValue: rows.any((s) => s.id == id) ? id : null,
      decoration: InputDecoration(
        labelText: kind == 'PICKUP'
            ? TripStrings.labels['pickup']
            : TripStrings.labels['drop'],
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text(TripStrings.none)),
        for (final s in rows)
          DropdownMenuItem(
            value: s.id,
            child: Text(
              '${d.stops.indexOf(s) + 1}. ${s.address}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      isExpanded: true,
      onChanged: busy ? null : (v) => setState(() => update(v)),
    );
  }

  Widget amounts(Map values) => Wrap(
    spacing: 24,
    runSpacing: 8,
    children: [
      for (final k in ['customer_charge', 'commission', 'owner_entitlement'])
        Text('${TripStrings.labels[k]}: PKR ${values[k]}'),
    ],
  );
  Widget preview(DraftConsignment c) {
    try {
      final q = c.preview();
      return amounts({
        'customer_charge': q.customerCharge,
        'commission': q.commission,
        'owner_entitlement': q.ownerEntitlement,
      });
    } catch (_) {
      return const Text(TripStrings.fareInvalid);
    }
  }

  Widget consignment(DraftConsignment c) => Card(
    key: ValueKey(c.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consignment ${d.consignments.indexOf(c) + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          picker('customer', c.customerName, () async {
            final r = await chooseMaster(
              context,
              widget.masters,
              MasterKind.party,
              role: 'CUSTOMER',
            );
            if (r != null && mounted) {
              setState(() {
                c.customer = r.id;
                c.customerName = r.label;
              });
            }
          }),
          picker(
            'broker',
            c.brokerName,
            () async {
              final r = await chooseMaster(
                context,
                widget.masters,
                MasterKind.party,
                role: 'BROKER',
              );
              if (r != null && mounted) {
                setState(() {
                  c.broker = r.id;
                  c.brokerName = r.label;
                });
              }
            },
            clear: () {
              c.broker = null;
              c.brokerName = null;
              c.commissionValue = '0.00';
              c.fareRevision++;
            },
          ),
          field(
            '${c.id}:count',
            c.count,
            (v) => c.count = v,
            label: TripStrings.labels['count'],
          ),
          field(
            '${c.id}:amount',
            c.amount,
            (v) => c.amount = v,
            label: TripStrings.labels['amount'],
            revision: c.fareRevision,
          ),
          if (d.suggestedFare != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      c.amount = d.suggestedFare!;
                      c.fareRevision++;
                    }),
              child: Text(
                '${TripStrings.applySuggestion}: PKR ${d.suggestedFare}',
              ),
            ),
          choice(
            '${c.id}:mode',
            c.mode,
            ['DEDUCTED', 'ADDED'],
            (v) {
              if (v != null) c.mode = v;
            },
            label: 'Quote basis: DEDUCTED = customer quote; ADDED = owner fare',
          ),
          choice('${c.id}:method', c.method, ['FIXED', 'PERCENTAGE'], (v) {
            if (v != null) c.method = v;
          }, label: TripStrings.labels['method']),
          field(
            '${c.id}:value',
            c.commissionValue,
            (v) => c.commissionValue = v,
            label: TripStrings.labels['value'],
            revision: c.fareRevision,
          ),
          preview(c),
          stopChoice('${c.id}:pickup', c.pickup, 'PICKUP', (v) => c.pickup = v),
          stopChoice('${c.id}:drop', c.drop, 'DROP', (v) => c.drop = v),
          field(
            '${c.id}:notes',
            c.notes,
            (v) => c.notes = v,
            label: TripStrings.labels['notes'],
          ),
          const Text(TripStrings.carsHelp),
          for (final a in c.cars)
            Card(
              key: ValueKey(a.id),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    field(
                      '${a.id}:identifier',
                      a.identifier,
                      (v) => a.identifier = v,
                      label: TripStrings.labels['identifier'],
                    ),
                    stopChoice(
                      '${a.id}:pickup',
                      a.pickup,
                      'PICKUP',
                      (v) => a.pickup = v,
                    ),
                    stopChoice(
                      '${a.id}:drop',
                      a.drop,
                      'DROP',
                      (v) => a.drop = v,
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => c.cars.remove(a)),
                      child: const Text(TripStrings.remove),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => c.cars.add(DraftCar())),
                child: const Text(TripStrings.addCar),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => d.consignments.remove(c)),
                child: const Text(TripStrings.removeConsignment),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final base = d.toJson();
      final signature = jsonEncode(base);
      if (pendingBase != signature || pendingPayload == null) {
        final warning = await widget.repository.overlap(d);
        if (!mounted) return;
        final confirmation = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) =>
              _DraftReview(warning: warning, totals: d.previewTotals()),
        );
        if (confirmation == null) return;
        pendingBase = signature;
        pendingRequest = newRecordId();
        pendingPayload = {
          ...base,
          ...confirmation,
          'review_token': warning['review_token'],
        };
      }
      // Keep the entire request across ambiguous network failures, including
      // the overlap ticket: the server may already have committed this draft.
      final saved = await widget.repository.save(
        d.id,
        pendingRequest!,
        d.version,
        pendingPayload!,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (e is PostgrestException && ['40001', 'PT409'].contains(e.code)) {
        pendingPayload = null;
        pendingBase = null;
        conflicted = true;
      }
      if (mounted) setState(() => error = tripError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(d.number ?? TripStrings.newTrip)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(TripStrings.potential),
              if (d.parent != null)
                Text('Linked return of ${d.parentNumber ?? d.parent}'),
              picker(
                'vehicle',
                d.registration,
                () => pick('vehicle', MasterKind.vehicle),
              ),
              Text(
                '${TripStrings.labels['owner']}: ${d.ownerName ?? 'Reconciled on save'}',
              ),
              picker(
                'driver',
                d.driverName ??
                    (d.driver == null ? null : TripStrings.defaultDriver),
                () => pick('driver', MasterKind.party, role: 'DRIVER'),
                clear: () {
                  d.driver = null;
                  d.driverName = null;
                },
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('origin:${d.origin}'),
                initialValue: widget.offices.any((o) => o['id'] == d.origin)
                    ? d.origin
                    : null,
                decoration: InputDecoration(
                  labelText: TripStrings.labels['origin'],
                ),
                items: [
                  for (final o in widget.offices)
                    DropdownMenuItem(
                      value: o['id'] as String,
                      child: Text(o['name'] as String),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) async {
                        setState(() => d.origin = v);
                        if (d.version == 0) await defaults();
                      },
              ),
              picker(
                'destination',
                widget.offices
                        .where((o) => o['id'] == d.destination)
                        .map((o) => o['name'])
                        .firstOrNull
                        ?.toString() ??
                    d.destinationName ??
                    (d.destination == null ? null : 'Selected office'),
                () => pick('destination', MasterKind.office),
              ),
              picker(
                'route',
                d.routeName,
                () => pick('route', MasterKind.route),
                clear: () {
                  d.route = null;
                  d.routeName = null;
                  d.suggestedFare = null;
                },
              ),
              field('planned', d.planned, (v) => d.planned = v),
              choice('load', d.kind, ['LOADED', 'EMPTY'], (v) {
                if (v == 'EMPTY' && d.consignments.isNotEmpty) {
                  error = TripStrings.emptySwitch;
                } else if (v != null) {
                  d.kind = v;
                }
              }),
              field('notes', d.notes, (v) => d.notes = v),
              const Divider(),
              const Text(TripStrings.stops),
              for (final s in d.stops)
                Card(
                  key: ValueKey(s.id),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text('Stop ${d.stops.indexOf(s) + 1}'),
                        choice(
                          '${s.id}:kind',
                          s.kind,
                          ['PICKUP', 'DROP', 'OTHER'],
                          (v) {
                            if (v != null) s.kind = v;
                          },
                          label: 'Stop kind',
                        ),
                        field(
                          '${s.id}:address',
                          s.address,
                          (v) => s.address = v,
                          label: TripStrings.address,
                        ),
                        Wrap(
                          children: [
                            TextButton(
                              onPressed: busy || d.stops.indexOf(s) == 0
                                  ? null
                                  : () => setState(() {
                                      final i = d.stops.indexOf(s);
                                      d.stops.removeAt(i);
                                      d.stops.insert(i - 1, s);
                                    }),
                              child: const Text(TripStrings.up),
                            ),
                            TextButton(
                              onPressed:
                                  busy ||
                                      d.stops.indexOf(s) == d.stops.length - 1
                                  ? null
                                  : () => setState(() {
                                      final i = d.stops.indexOf(s);
                                      d.stops.removeAt(i);
                                      d.stops.insert(i + 1, s);
                                    }),
                              child: const Text(TripStrings.down),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                      if (d.stopUsed(s.id)) {
                                        error = TripStrings.stopInUse;
                                      } else {
                                        d.stops.remove(s);
                                      }
                                    }),
                              child: const Text(TripStrings.remove),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => d.stops.add(DraftStop())),
                child: const Text(TripStrings.addStop),
              ),
              for (final c in d.consignments) consignment(c),
              if (d.kind == 'LOADED')
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => d.consignments.add(DraftConsignment()),
                        ),
                  child: const Text(TripStrings.addConsignment),
                ),
              if (d.version > 0) field('reason', d.reason, (v) => d.reason = v),
              if (error != null) Text(error!, key: const Key('trip-error')),
              if (busy) const LinearProgressIndicator(),
              FilledButton(
                onPressed: busy || conflicted ? null : save,
                child: const Text(TripStrings.save),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DraftReview extends StatefulWidget {
  const _DraftReview({required this.warning, required this.totals});
  final Map<String, dynamic> warning;
  final Map<String, String> totals;
  @override
  State<_DraftReview> createState() => _DraftReviewState();
}

class _DraftReviewState extends State<_DraftReview> {
  bool confirmed = false;
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needed = widget.warning['requires_confirmation'] == true;
    return AlertDialog(
      title: const Text(TripStrings.review),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStrings.potential),
            for (final k in widget.totals.keys)
              Text('${TripStrings.labels[k]}: PKR ${widget.totals[k]}'),
            if (needed) ...[
              const Text(TripStrings.overlap),
              for (final t in widget.warning['visible_trips'] as List)
                Text('${t['trip_number']} · ${t['dispatch_date']}'),
              if (widget.warning['restricted_conflict'] == true)
                const Text(TripStrings.restricted),
              CheckboxListTile(
                value: confirmed,
                onChanged: (v) => setState(() => confirmed = v!),
                title: const Text(TripStrings.confirmOverlap),
              ),
              TextField(
                controller: reason,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: TripStrings.reviewReason,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(TripStrings.cancel),
        ),
        FilledButton(
          onPressed: needed && (!confirmed || reason.text.trim().isEmpty)
              ? null
              : () => Navigator.pop(context, <String, dynamic>{
                  'overlap_confirmed': needed,
                  'overlap_reason': needed ? reason.text.trim() : null,
                }),
          child: const Text(TripStrings.confirm),
        ),
      ],
    );
  }
}

class TripDetail extends StatefulWidget {
  const TripDetail({
    super.key,
    required this.repository,
    required this.id,
    required this.canReturn,
    required this.onEdit,
    this.saved = false,
    this.guard = unguardedTrip,
    this.onPayments,
    this.onCorrections,
  });
  final TripRepository repository;
  final Future<void> Function()? onPayments, onCorrections;
  final Widget Function(Widget) guard;
  final String id;
  final bool saved;
  final bool Function(String) canReturn;
  final Future<void> Function(TripDraft) onEdit;
  @override
  State<TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends State<TripDetail> {
  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    data = widget.repository.detail(widget.id);
  }

  void reload() {
    setState(() {
      data = widget.repository.detail(widget.id);
    });
  }

  Future<void> operate(
    TripAction action,
    Map<String, dynamic> trip, {
    String? consignment,
  }) async {
    final committed = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => widget.guard(
        TripOperationDialog(
          repository: widget.repository,
          trip: trip,
          action: action,
          consignment: consignment,
        ),
      ),
    );
    if (committed != null && mounted) {
      reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(LifecycleStrings.success)));
    }
  }

  Future<void> history() => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => widget.guard(
        TripHistory(repository: widget.repository, id: widget.id),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Trip details'),
      actions: [
        IconButton(
          onPressed: reload,
          icon: const Icon(Icons.refresh),
          tooltip: TripStrings.refresh,
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(tripError(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snapshot.data!;
        final stops = r['stops'] as List;
        String stopLabel(dynamic id) => id == null
            ? TripStrings.none
            : stops
                      .where((s) => s['id'] == id)
                      .map((s) => '${s['position']}. ${s['address']}')
                      .firstOrNull ??
                  TripStrings.none;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.saved) const Text(TripStrings.saved),
            Text(
              '${r['trip_number']} · ${r['registration']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${r['origin_name']} → ${r['destination_name']}'),
            Text('${r['state']} · ${r['load_kind']}'),
            Text(
              'Recorded owner: ${(r['owner_snapshot'] as Map)['display_name']}',
            ),
            Text(
              'Recorded route: ${(r['route_snapshot'] as Map)['code'] ?? TripStrings.none}',
            ),
            Text('Driver: ${r['driver_name'] ?? TripStrings.none}'),
            Text(
              'Planned date: ${r['planned_dispatch_date'] ?? TripStrings.none}',
            ),
            Text(
              'Dispatch: ${r['dispatch_date'] ?? TripStrings.none} · Arrival: ${r['arrival_date'] ?? TripStrings.none}',
            ),
            if (r['state'] == 'DRAFT') const Text(TripStrings.potential),
            if (r['earnings_recognized'] == true)
              const Text(LifecycleStrings.recognition),
            const Text(LifecycleStrings.independent),
            for (final k in [
              'customer_charge',
              'commission',
              'owner_entitlement',
            ])
              Text('${TripStrings.labels[k]}: PKR ${(r['totals'] as Map)[k]}'),
            Text('Car count: ${(r['totals'] as Map)['car_count']}'),
            Text('${r['notes']}'),
            if (r['overlap_confirmed'] == true)
              Text('Overlap reviewed: ${r['overlap_reason']}'),
            Wrap(
              children: [
                for (final action in TripAction.values.where(
                  (a) => a != TripAction.cancelConsignment,
                ))
                  if (r[action.permission] == true)
                    TextButton(
                      onPressed: () => operate(action, r),
                      child: Text(action.label),
                    ),
                TextButton(
                  onPressed: history,
                  child: const Text(LifecycleStrings.history),
                ),
                if (widget.onCorrections != null)
                  TextButton(
                    onPressed: widget.onCorrections,
                    child: const Text('Corrections and cancellation'),
                  ),
                if (widget.onPayments != null)
                  TextButton(
                    onPressed: widget.onPayments,
                    child: const Text('Payments and allocations'),
                  ),
                if (r['can_edit'] == true)
                  TextButton(
                    onPressed: () async {
                      await widget.onEdit(TripDraft.fromDetail(r));
                      if (mounted) reload();
                    },
                    child: const Text(TripStrings.edit),
                  ),
                if (r['state'] != 'CANCELLED' &&
                    widget.canReturn(r['destination_office_id'] as String))
                  TextButton(
                    onPressed: () => widget.onEdit(TripDraft.returnFrom(r)),
                    child: const Text(TripStrings.linkedReturn),
                  ),
              ],
            ),
            if (r['return_of_trip_id'] != null)
              TextButton(
                onPressed: () => openLinked(r['return_of_trip_id'] as String),
                child: const Text('Original trip'),
              ),
            for (final t in r['linked_returns'] as List)
              TextButton(
                onPressed: () => openLinked(t['id'] as String),
                child: Text('Return ${t['trip_number']} · ${t['load_kind']}'),
              ),
            const Text(TripStrings.stops),
            for (final s in stops)
              Text('${s['position']}. ${s['kind']}: ${s['address']}'),
            for (final c in r['consignments'] as List)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['customer_name']} · ${c['state']} · ${c['car_count']} cars',
                      ),
                      if (r['can_cancel_consignment'] == true &&
                          c['state'] == 'ACTIVE')
                        TextButton(
                          onPressed: () => operate(
                            TripAction.cancelConsignment,
                            r,
                            consignment: c['id'] as String,
                          ),
                          child: Text(TripAction.cancelConsignment.label),
                        ),
                      Text('Broker: ${c['broker_name'] ?? TripStrings.none}'),
                      Text(
                        'Quoted: PKR ${c['quoted_amount']} · ${c['quote_mode']} · ${c['commission_method']} ${c['commission_value']}',
                      ),
                      for (final k in [
                        'customer_charge',
                        'commission',
                        'owner_entitlement',
                      ])
                        Text('${TripStrings.labels[k]}: PKR ${c[k]}'),
                      Text(
                        'Pickup: ${stopLabel(c['pickup_stop_id'])}\nDrop: ${stopLabel(c['drop_stop_id'])}',
                      ),
                      Text('${c['notes']}'),
                      for (final a in c['cars'] as List)
                        Text(
                          '${a['identifier']} · Pickup: ${stopLabel(a['pickup_stop_id'])} · Drop: ${stopLabel(a['drop_stop_id'])}',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
  Future<void> openLinked(String id) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => widget.guard(
        TripDetail(
          repository: widget.repository,
          id: id,
          canReturn: widget.canReturn,
          onEdit: widget.onEdit,
          guard: widget.guard,
        ),
      ),
    ),
  );
}
