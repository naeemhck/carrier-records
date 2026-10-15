import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import '../../app/karvaan_design.dart';

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
    this.moneyMode = false,
    this.onExpenses,
  });
  final Future<void> Function()? onExpenses;
  final bool moneyMode;
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
    if (widget.moneyMode && widget.finance != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.guard(
            PaymentWorkspace(
              finance: widget.finance!,
              trips: widget.repository,
              masters: widget.masters,
              offices: widget.offices,
              initialTrip: id,
              guard: widget.guard,
            ),
          ),
        ),
      );
      if (mounted) reload();
      return;
    }
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
            onExpenses: widget.onExpenses,
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
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: BilingualText(
        widget.moneyMode ? L10n.moneyNavigation : L10n.trips,
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 24,
          runSpacing: 16,
          children: [
            BilingualText(
              widget.moneyMode ? L10n.moneyNavigation : L10n.trips,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (!widget.moneyMode)
              FilledButton.icon(
                onPressed: () => edit(TripDraft()),
                icon: const Icon(Icons.add),
                label: const BilingualText(L10n.newDraft),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: search,
          decoration: bilingualDecoration(
            context,
            InputDecoration(
              label: BilingualCaption(L10n.searchTripVehicleOrParty),
            ),
          ),
          onSubmitted: (_) => reload(start: 0),
        ),
        DropdownButtonFormField<String>(
          isDense: false,
          isExpanded: true,
          itemHeight: null,
          initialValue: office,
          decoration: bilingualDecoration(
            context,
            InputDecoration(label: BilingualCaption(L10n.officeFilter)),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: BilingualText(L10n.allOffices),
            ),
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
        BilingualListTile(
          title: BilingualText(
            (vehicleName != null
                ? Bilingual.data(vehicleName)
                : L10n.vehicleFilterAll),
          ),
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
                child: const BilingualCaption(L10n.choose),
              ),
              TextButton(
                onPressed: () {
                  vehicle = null;
                  vehicleName = null;
                  reload(start: 0);
                },
                child: const BilingualCaption(L10n.clear),
              ),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          isDense: false,
          isExpanded: true,
          itemHeight: null,
          initialValue: status,
          decoration: bilingualDecoration(
            context,
            InputDecoration(label: BilingualCaption(L10n.tripState)),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: BilingualText(L10n.allStates),
            ),
            for (final s in ['DRAFT', 'DISPATCHED', 'ARRIVED', 'CANCELLED'])
              DropdownMenuItem(value: s, child: BilingualOwnedText(s)),
          ],
          onChanged: (v) {
            status = v;
            reload(start: 0);
          },
        ),
        TextField(
          controller: from,
          decoration: bilingualDecoration(
            context,
            InputDecoration(
              label: BilingualOwnedCaption(TripStrings.labels['from']),
            ),
          ),
        ),
        TextField(
          controller: to,
          decoration: bilingualDecoration(
            context,
            InputDecoration(
              label: BilingualOwnedCaption(TripStrings.labels['to']),
            ),
          ),
        ),
        TextButton(
          onPressed: () => reload(start: 0),
          child: const BilingualCaption(L10n.searchRefresh),
        ),
        FutureBuilder<TripPage>(
          future: page,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return BilingualOwnedText(tripError(snapshot.error!));
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final result = snapshot.data!;
            return Column(
              children: [
                BilingualText(
                  (result.scope == 'ALL_OFFICES'
                      ? L10n.allOffices
                      : L10n.assignedOfficeTrips),
                ),
                if (result.rows.isEmpty)
                  const BilingualText(L10n.noTripsInThisScope),
                for (final r in result.rows)
                  Card(
                    child: BilingualListTile(
                      key: ValueKey('trip:${r['id']}'),
                      title: BilingualText(
                        L10n.labelValuescd55a9.withValues([
                          r['trip_number'],
                          r['registration'],
                        ]),
                      ),
                      subtitle: BilingualText(
                        L10n.labelValues8a6c87.withValues([
                          r['origin_name'],
                          r['destination_name'],
                          ownedMessage(r['state']),
                          ownedMessage(r['load_kind']),
                          r['dispatch_date'] ??
                              r['planned_dispatch_date'] ??
                              '',
                        ]),
                      ),
                      trailingBelow: true,
                      trailing: TripStatusBadge(r['state'] as String),
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
                      child: const BilingualCaption(L10n.previous),
                    ),
                    TextButton(
                      onPressed: result.rows.length < 50
                          ? null
                          : () => reload(start: offset + 50),
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
    scrollable: true,
    title: BilingualText(
      L10n.labelValues10866a.withValues([
        ownedMessage(TripStrings.choose),
        widget.role ?? widget.kind.label,
      ]),
    ),
    content: SizedBox(
      width: 480,
      height: 420,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.searchNameCode)),
            ),
            onSubmitted: (_) => reload(0),
          ),
          TextButton(
            onPressed: () => reload(0),
            child: const BilingualCaption(L10n.searchRefresh),
          ),
          Expanded(
            child: FutureBuilder<List<MasterRecord>>(
              future: rows,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return BilingualOwnedText(tripError(snapshot.error!));
                }
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
                    if (choices.isEmpty)
                      const BilingualText(L10n.noChoicesOnThisPage),
                    for (final r in choices)
                      BilingualListTile(
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
                          child: const BilingualCaption(L10n.previous),
                        ),
                        TextButton(
                          onPressed: all.length < 50
                              ? null
                              : () => reload(offset + 50),
                          child: const BilingualCaption(L10n.next),
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
        child: const BilingualCaption(L10n.close),
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
  int step = 0;
  void moveStep(int value) {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => step = value);
  }

  Widget reviewSummary() {
    Widget totals;
    try {
      final values = d.previewTotals();
      totals = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in [
            'customer_charge',
            'commission',
            'owner_entitlement',
          ])
            BilingualText(
              L10n.pkr274c89.withValues([
                ownedMessage(TripStrings.labels[key]),
                values[key],
              ]),
            ),
        ],
      );
    } catch (e) {
      totals = BilingualOwnedText(tripError(e));
    }
    return KarvaanSection(
      title: L10n.reviewStep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.registration ?? TripStrings.none),
          Text(
            '${widget.offices.where((o) => o['id'] == d.origin).firstOrNull?['name'] ?? TripStrings.none} → ${widget.offices.where((o) => o['id'] == d.destination).firstOrNull?['name'] ?? d.destinationName ?? TripStrings.none}',
          ),
          Text(d.driverName ?? TripStrings.none),
          Text(d.planned),
          BilingualOwnedText(d.kind),
          Text(d.notes),
          for (final c in d.consignments) ...[
            const Divider(),
            Text(c.customerName ?? TripStrings.none),
            BilingualText(L10n.carCount04a594.withValues([c.count])),
            Text(c.notes),
            for (final car in c.cars) Text(car.identifier),
          ],
          const Divider(),
          totals,
          const BilingualText(
            L10n.draftQuotesArePotentialFareNoEarningsOrPayment,
          ),
        ],
      ),
    );
  }

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
      decoration: bilingualDecoration(
        context,
        InputDecoration(
          label: BilingualCaption(
            (label != null
                ? ownedMessage(label)
                : ownedMessage(TripStrings.labels[key])),
          ),
        ),
      ),
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
      isDense: false,
      isExpanded: true,
      itemHeight: null,
      key: ValueKey('$key:$value:${choices.join(',')}'),
      initialValue: choices.contains(value) ? value : null,
      decoration: bilingualDecoration(
        context,
        InputDecoration(
          label: BilingualCaption(
            (label != null
                ? ownedMessage(label)
                : ownedMessage(TripStrings.labels[key])),
          ),
        ),
      ),
      items: [
        for (final v in choices)
          DropdownMenuItem(value: v, child: BilingualOwnedText(v)),
      ],
      onChanged: busy ? null : (v) => setState(() => change(v)),
    ),
  );
  Widget picker(
    String key,
    String? label,
    VoidCallback select, {
    VoidCallback? clear,
  }) => BilingualListTile(
    contentPadding: EdgeInsets.zero,
    title: BilingualText(
      L10n.labelValuesfb62fe.withValues([
        ownedMessage(TripStrings.labels[key]),
        label ?? ownedMessage(TripStrings.none),
      ]),
    ),
    trailing: Wrap(
      children: [
        TextButton(
          onPressed: busy ? null : select,
          child: const BilingualCaption(L10n.choose),
        ),
        if (clear != null)
          TextButton(
            onPressed: busy ? null : () => setState(clear),
            child: const BilingualCaption(L10n.clear),
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
      isDense: false,
      itemHeight: null,
      key: ValueKey('$key:$id:${rows.map((s) => s.id).join(',')}'),
      initialValue: rows.any((s) => s.id == id) ? id : null,
      decoration: bilingualDecoration(
        context,
        InputDecoration(
          label: BilingualCaption(
            (kind == 'PICKUP'
                ? ownedMessage(TripStrings.labels['pickup'])
                : ownedMessage(TripStrings.labels['drop'])),
          ),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: BilingualText(L10n.none)),
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
        BilingualText(
          L10n.pkr274c89.withValues([
            ownedMessage(TripStrings.labels[k]),
            values[k],
          ]),
        ),
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
      return const BilingualText(L10n.checkTheQuoteAndBrokerageValues);
    }
  }

  Widget consignment(DraftConsignment c) => Card(
    key: ValueKey(c.id),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BilingualText(
            L10n.consignment.withValues([d.consignments.indexOf(c) + 1]),
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
              child: BilingualCaption(
                L10n.pkr274c89.withValues([
                  ownedMessage(TripStrings.applySuggestion),
                  d.suggestedFare,
                ]),
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
          const BilingualText(
            L10n.countIncludesAllCarsIdentifiersAreOptionalCarStops,
          ),
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
                      child: const BilingualCaption(L10n.remove),
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
                child: const BilingualCaption(L10n.addOptionalIdentifier),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() => d.consignments.remove(c)),
                child: const BilingualCaption(L10n.removeConsignment),
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
      appBar: AppBar(
        toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
        title: BilingualText(
          d.number != null ? Bilingual.data(d.number) : L10n.newDraft,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: OutlinedButton(
                          key: ValueKey('trip-step-$i'),
                          onPressed: busy ? null : () => moveStep(i),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(8),
                            backgroundColor: step == i
                                ? const Color(0xFFEAF4ED)
                                : Colors.white,
                          ),
                          child: BilingualText(
                            [
                              L10n.journeyStep,
                              L10n.consignmentsStep,
                              L10n.reviewStep,
                            ][i],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration:
                      MediaQuery.disableAnimationsOf(context) ||
                          MediaQuery.accessibleNavigationOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: ListView(
                    key: ValueKey('trip-step-content-$step'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (step == 0) ...[
                        const BilingualText(
                          L10n.draftQuotesArePotentialFareNoEarningsOrPayment,
                        ),
                        if (d.parent != null)
                          BilingualText(
                            L10n.linkedReturnOf.withValues([
                              d.parentNumber ?? d.parent,
                            ]),
                          ),
                        picker(
                          'vehicle',
                          d.registration,
                          () => pick('vehicle', MasterKind.vehicle),
                        ),
                        BilingualText(
                          L10n.labelValuesfb62fe.withValues([
                            ownedMessage(TripStrings.labels['owner']),
                            d.ownerName ?? L10n.reconciledOnSave,
                          ]),
                        ),
                        picker(
                          'driver',
                          d.driverName ??
                              (d.driver == null
                                  ? null
                                  : TripStrings.defaultDriver),
                          () =>
                              pick('driver', MasterKind.party, role: 'DRIVER'),
                          clear: () {
                            d.driver = null;
                            d.driverName = null;
                          },
                        ),
                        DropdownButtonFormField<String>(
                          isDense: false,
                          isExpanded: true,
                          itemHeight: null,
                          key: ValueKey('origin:${d.origin}'),
                          initialValue:
                              widget.offices.any((o) => o['id'] == d.origin)
                              ? d.origin
                              : null,
                          decoration: bilingualDecoration(
                            context,
                            InputDecoration(
                              label: BilingualOwnedCaption(
                                TripStrings.labels['origin'],
                              ),
                            ),
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
                              (d.destination == null
                                  ? null
                                  : 'Selected office'),
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

                        if (d.version > 0)
                          field('reason', d.reason, (v) => d.reason = v),
                      ],
                      if (step == 1) ...[
                        const BilingualText(L10n.pickupDropStops),
                        for (final s in d.stops)
                          Card(
                            key: ValueKey(s.id),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  BilingualText(
                                    L10n.stop.withValues([
                                      d.stops.indexOf(s) + 1,
                                    ]),
                                  ),
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
                                        onPressed:
                                            busy || d.stops.indexOf(s) == 0
                                            ? null
                                            : () => setState(() {
                                                final i = d.stops.indexOf(s);
                                                d.stops.removeAt(i);
                                                d.stops.insert(i - 1, s);
                                              }),
                                        child: const BilingualCaption(
                                          L10n.moveUp,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            busy ||
                                                d.stops.indexOf(s) ==
                                                    d.stops.length - 1
                                            ? null
                                            : () => setState(() {
                                                final i = d.stops.indexOf(s);
                                                d.stops.removeAt(i);
                                                d.stops.insert(i + 1, s);
                                              }),
                                        child: const BilingualCaption(
                                          L10n.moveDown,
                                        ),
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
                                        child: const BilingualCaption(
                                          L10n.remove,
                                        ),
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
                          child: const BilingualCaption(L10n.addStop),
                        ),
                        for (final c in d.consignments) consignment(c),
                        if (d.kind == 'LOADED')
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(
                                    () =>
                                        d.consignments.add(DraftConsignment()),
                                  ),
                            child: const BilingualCaption(L10n.addConsignment),
                          ),
                      ],
                      if (step == 2) reviewSummary(),
                      if (busy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: KarvaanGlass(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (error != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: SingleChildScrollView(
                        child: BilingualOwnedText(
                          error!,
                          key: const Key('trip-error'),
                        ),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (step > 0)
                        OutlinedButton(
                          key: const Key('trip-previous'),
                          onPressed: busy ? null : () => moveStep(step - 1),
                          child: const BilingualCaption(L10n.previous),
                        ),
                      if (step < 2)
                        FilledButton(
                          key: const Key('trip-next'),
                          onPressed: busy ? null : () => moveStep(step + 1),
                          child: const BilingualCaption(L10n.next),
                        )
                      else
                        FilledButton(
                          onPressed: busy || conflicted ? null : save,
                          child: const BilingualCaption(
                            L10n.reviewAndSaveDraft,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
      scrollable: true,
      title: const BilingualText(L10n.reviewDraft),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BilingualText(
              L10n.draftQuotesArePotentialFareNoEarningsOrPayment,
            ),
            for (final k in widget.totals.keys)
              BilingualText(
                L10n.pkr274c89.withValues([
                  ownedMessage(TripStrings.labels[k]),
                  widget.totals[k],
                ]),
              ),
            if (needed) ...[
              const BilingualText(
                L10n.anotherDispatchedJourneyUsesThisVehicleReviewAndConfirm,
              ),
              for (final t in widget.warning['visible_trips'] as List)
                BilingualText(
                  L10n.labelValuescd55a9.withValues([
                    t['trip_number'],
                    t['dispatch_date'],
                  ]),
                ),
              if (widget.warning['restricted_conflict'] == true)
                const BilingualText(
                  L10n.anActiveJourneyOutsideYourOfficeScopeAlsoUses,
                ),
              CheckboxListTile(
                value: confirmed,
                onChanged: (v) => setState(() => confirmed = v!),
                title: const BilingualText(L10n.iReviewedThisVehicleOverlap),
              ),
              TextField(
                controller: reason,
                maxLength: 500,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualCaption(L10n.reasonForAllowingTheOverlap),
                  ),
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
          child: const BilingualCaption(L10n.cancel),
        ),
        FilledButton(
          onPressed: needed && (!confirmed || reason.text.trim().isEmpty)
              ? null
              : () => Navigator.pop(context, <String, dynamic>{
                  'overlap_confirmed': needed,
                  'overlap_reason': needed ? reason.text.trim() : null,
                }),
          child: const BilingualCaption(L10n.confirmSave),
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
    this.onExpenses,
  });
  final TripRepository repository;
  final Future<void> Function()? onPayments, onCorrections, onExpenses;
  final Widget Function(Widget) guard;
  final String id;
  final bool saved;
  final bool Function(String) canReturn;
  final Future<void> Function(TripDraft) onEdit;
  @override
  State<TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends State<TripDetail> {
  int tab = 0;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: BilingualText(
            L10n.operationCommittedCurrentServerRecordShown,
          ),
        ),
      );
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
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.tripDetails),
      actions: [
        IconButton(
          onPressed: reload,
          icon: const Icon(Icons.refresh),
          tooltip: L10n.searchRefreshAccessibility,
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: BilingualOwnedText(tripError(snapshot.error!)));
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
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.saved)
                          const BilingualText(
                            L10n.draftSavedServerCalculatedAmountsShownBelow,
                          ),
                        BilingualText(
                          L10n.labelValuescd55a9.withValues([
                            r['trip_number'],
                            r['registration'],
                          ]),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        TripStatusBadge(r['state'] as String),
                        const SizedBox(height: 16),
                        Text('${r['origin_name']} → ${r['destination_name']}'),
                        BilingualText(
                          L10n.labelValuescd55a9.withValues([
                            r['state'],
                            r['load_kind'],
                          ]),
                        ),
                        BilingualText(
                          L10n.recordedOwnere34286.withValues([
                            (r['owner_snapshot'] as Map)['display_name'],
                          ]),
                        ),
                        BilingualText(
                          L10n.recordedRoute.withValues([
                            (r['route_snapshot'] as Map)['code'] ??
                                ownedMessage(TripStrings.none),
                          ]),
                        ),
                        BilingualText(
                          L10n.driver.withValues([
                            r['driver_name'] ?? ownedMessage(TripStrings.none),
                          ]),
                        ),
                        BilingualText(
                          L10n.plannedDate.withValues([
                            r['planned_dispatch_date'] ??
                                ownedMessage(TripStrings.none),
                          ]),
                        ),
                        BilingualText(
                          L10n.dispatchArrival.withValues([
                            r['dispatch_date'] ??
                                ownedMessage(TripStrings.none),
                            r['arrival_date'] ?? ownedMessage(TripStrings.none),
                          ]),
                        ),
                        if (r['state'] == 'DRAFT')
                          const BilingualText(
                            L10n.draftQuotesArePotentialFareNoEarningsOrPayment,
                          ),
                        if (r['earnings_recognized'] == true)
                          const BilingualText(
                            L10n.dispatchRecognizesCustomerDebtOwnerFareShareAndBrokerage,
                          ),
                        const BilingualText(
                          L10n.operationalCompletionAndFinancialSettlementAreIndependentArrivalCreates,
                        ),
                        for (final k in [
                          'customer_charge',
                          'commission',
                          'owner_entitlement',
                        ])
                          BilingualText(
                            L10n.pkr274c89.withValues([
                              ownedMessage(TripStrings.labels[k]),
                              (r['totals'] as Map)[k],
                            ]),
                          ),
                        BilingualText(
                          L10n.carCount04a594.withValues([
                            (r['totals'] as Map)['car_count'],
                          ]),
                        ),
                        Text((r['notes']).toString()),
                        if (r['overlap_confirmed'] == true)
                          BilingualText(
                            L10n.overlapReviewed.withValues([
                              r['overlap_reason'],
                            ]),
                          ),
                        Wrap(
                          children: [
                            for (final action in [
                              TripAction.dispatch,
                              TripAction.arrive,
                            ])
                              if (r[action.permission] == true)
                                FilledButton(
                                  onPressed: () => operate(action, r),
                                  child: BilingualOwnedCaption(action.label),
                                ),
                            if (widget.onCorrections != null ||
                                TripAction.values.any(
                                  (a) =>
                                      a != TripAction.dispatch &&
                                      a != TripAction.arrive &&
                                      a != TripAction.cancelConsignment &&
                                      r[a.permission] == true,
                                ))
                              PopupMenuButton<String>(
                                tooltip: L10n
                                    .correctionsAndCancellationAccessibility,
                                onSelected: (key) {
                                  if (key == 'financial') {
                                    widget.onCorrections?.call();
                                  } else {
                                    operate(
                                      TripAction.values.firstWhere(
                                        (a) => a.key == key,
                                      ),
                                      r,
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (widget.onCorrections != null)
                                    const PopupMenuItem(
                                      value: 'financial',
                                      child: BilingualText(
                                        L10n.correctionsAndCancellation,
                                      ),
                                    ),
                                  for (final action in TripAction.values.where(
                                    (a) =>
                                        a != TripAction.dispatch &&
                                        a != TripAction.arrive &&
                                        a != TripAction.cancelConsignment,
                                  ))
                                    if (r[action.permission] == true)
                                      PopupMenuItem(
                                        value: action.key,
                                        child: BilingualOwnedText(action.label),
                                      ),
                                ],
                              ),
                            TextButton(
                              onPressed: history,
                              child: const BilingualCaption(L10n.history),
                            ),
                            if (widget.onPayments != null)
                              TextButton(
                                onPressed: widget.onPayments,
                                child: const BilingualCaption(
                                  L10n.paymentsAndAllocations,
                                ),
                              ),
                            if (r['can_edit'] == true)
                              TextButton(
                                onPressed: () async {
                                  await widget.onEdit(TripDraft.fromDetail(r));
                                  if (mounted) reload();
                                },
                                child: const BilingualCaption(L10n.editDraft),
                              ),
                            if (r['state'] != 'CANCELLED' &&
                                widget.canReturn(
                                  r['destination_office_id'] as String,
                                ))
                              TextButton(
                                onPressed: () =>
                                    widget.onEdit(TripDraft.returnFrom(r)),
                                child: const BilingualCaption(
                                  L10n.createLinkedReturn,
                                ),
                              ),
                          ],
                        ),
                        if (r['return_of_trip_id'] != null)
                          TextButton(
                            onPressed: () =>
                                openLinked(r['return_of_trip_id'] as String),
                            child: const BilingualCaption(L10n.originalTrip),
                          ),
                        for (final t in r['linked_returns'] as List)
                          TextButton(
                            onPressed: () => openLinked(t['id'] as String),
                            child: BilingualCaption(
                              L10n.returnMessage.withValues([
                                t['trip_number'],
                                t['load_kind'],
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: KarvaanPinnedTabs(
                labels: const [
                  L10n.consignmentsStep,
                  L10n.moneyNavigation,
                  L10n.expensesTab,
                  L10n.history,
                ],
                selected: tab,
                onSelected: (value) => setState(() => tab = value),
                height: 80 * MediaQuery.textScalerOf(context).scale(1) + 16,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (tab == 0) ...[
                      const BilingualText(L10n.pickupDropStops),
                      for (final s in stops)
                        BilingualText(
                          L10n.stopRecordIdentity.withValues([
                            s['position'],
                            ownedMessage(s['kind']),
                            s['address'],
                          ]),
                        ),
                      for (final c in r['consignments'] as List)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                BilingualText(
                                  L10n.cars7b7a19.withValues([
                                    c['customer_name'],
                                    c['state'],
                                    c['car_count'],
                                  ]),
                                ),
                                if (r['can_cancel_consignment'] == true &&
                                    c['state'] == 'ACTIVE')
                                  TextButton(
                                    onPressed: () => operate(
                                      TripAction.cancelConsignment,
                                      r,
                                      consignment: c['id'] as String,
                                    ),
                                    child: BilingualOwnedCaption(
                                      TripAction.cancelConsignment.label,
                                    ),
                                  ),
                                BilingualText(
                                  L10n.broker.withValues([
                                    c['broker_name'] ??
                                        ownedMessage(TripStrings.none),
                                  ]),
                                ),
                                BilingualText(
                                  L10n.quotedPKR.withValues([
                                    c['quoted_amount'],
                                    c['quote_mode'],
                                    c['commission_method'],
                                    c['commission_value'],
                                  ]),
                                ),
                                for (final k in [
                                  'customer_charge',
                                  'commission',
                                  'owner_entitlement',
                                ])
                                  BilingualText(
                                    L10n.pkr274c89.withValues([
                                      ownedMessage(TripStrings.labels[k]),
                                      c[k],
                                    ]),
                                  ),
                                BilingualText(
                                  L10n.pickupDrop.withValues([
                                    stopLabel(c['pickup_stop_id']),
                                    stopLabel(c['drop_stop_id']),
                                  ]),
                                ),
                                Text((c['notes']).toString()),
                                for (final a in c['cars'] as List)
                                  BilingualText(
                                    L10n.pickupDrop68b36c.withValues([
                                      a['identifier'],
                                      stopLabel(a['pickup_stop_id']),
                                      stopLabel(a['drop_stop_id']),
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    if (tab == 1)
                      KarvaanSection(
                        title: L10n.moneyNavigation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BilingualText(
                              L10n.operationalCompletionAndFinancialSettlementAreIndependentArrivalCreates,
                            ),
                            for (final key in [
                              'customer_charge',
                              'commission',
                              'owner_entitlement',
                            ])
                              BilingualText(
                                L10n.pkr274c89.withValues([
                                  ownedMessage(TripStrings.labels[key]),
                                  (r['totals'] as Map)[key],
                                ]),
                              ),
                            if (widget.onPayments != null)
                              OutlinedButton(
                                onPressed: widget.onPayments,
                                child: const BilingualCaption(
                                  L10n.paymentsAndAllocations,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (tab == 2)
                      KarvaanSection(
                        title: L10n.expensesTab,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const BilingualText(L10n.tripExpensesScopeNotice),
                            if (widget.onExpenses != null)
                              OutlinedButton(
                                onPressed: widget.onExpenses,
                                child: const BilingualCaption(
                                  L10n.expensesAndReimbursements,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (tab == 3)
                      SizedBox(
                        height: 600 * MediaQuery.textScalerOf(context).scale(1),
                        child: TripHistory(
                          repository: widget.repository,
                          id: widget.id,
                        ),
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
          onExpenses: widget.onExpenses,
          guard: widget.guard,
        ),
      ),
    ),
  );
}
