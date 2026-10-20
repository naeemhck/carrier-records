import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_components.dart';
import 'package:carrier_records/app/karvaan_patterns.dart';
import 'package:carrier_records/core/domain/record_context.dart';

import 'dart:convert';

import '../../app/karvaan_design.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

String _decimalString(BigInt paisa) {
  final negative = paisa.isNegative;
  final abs = paisa.abs();
  return '${negative ? '-' : ''}${abs ~/ BigInt.from(100)}.${(abs % BigInt.from(100)).toString().padLeft(2, '0')}';
}

/// Presentation-only read of get_trip_financials: the trip's customer
/// outstanding is the sum of open CUSTOMER_RECEIVABLE claim remainders — the
/// same figure the Money workspace labels "Customer outstanding". Returns a
/// canonical decimal string, or null when the payload carries no claims.
String? tripCustomerOutstanding(Map<String, dynamic> financials) {
  final claims = financials['claims'];
  if (claims is! List) return null;
  var total = BigInt.zero;
  for (final c in claims) {
    if (c is Map && c['account_purpose'] == 'CUSTOMER_RECEIVABLE') {
      final remaining = c['remaining'];
      if (remaining is String) {
        total += LedgerAmount.fromJson(remaining).paisa;
      }
    }
  }
  return _decimalString(total);
}

bool _looksLikeUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

/// Long user-entered notes truncate behind a Read more control instead of
/// stretching the card. One-way expansion; the full note stays on screen.
class ExpandableNote extends StatefulWidget {
  const ExpandableNote(this.note, {super.key});
  final String note;
  @override
  State<ExpandableNote> createState() => _ExpandableNoteState();
}

class _ExpandableNoteState extends State<ExpandableNote> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final text = widget.note.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    if (expanded) {
      return Text(text, textDirection: TextDirection.ltr);
    }
    // Only offer "Read more" when the note actually overflows two lines;
    // otherwise the control is dead weight.
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: DefaultTextStyle.of(context).style),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textDirection: TextDirection.ltr,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => expanded = true),
                child: const BilingualCaption(L10n.readMore),
              ),
          ],
        );
      },
    );
  }
}

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

  /// Per-trip get_trip_financials futures, memoized so list rebuilds do not
  /// refetch. Cleared on every reload; entries are presentation-only reads.
  final _moneyFutures = <String, Future<Map<String, dynamic>>>{};

  Future<Map<String, dynamic>> _tripFinancials(String id) {
    final finance = widget.finance;
    if (finance == null || !_looksLikeUuid(id)) {
      return Future.value(const <String, dynamic>{});
    }
    return _moneyFutures.putIfAbsent(id, () => finance.trip(RecordId(id)));
  }

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
      _moneyFutures.clear();
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

  Future<void> detail(
    String id, {
    bool saved = false,
    int initialTab = 0,
  }) async {
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
            initialTab: initialTab,
            finance: widget.finance,
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

  /// Route-drawn trip card (competitor pattern 1): the route line answers
  /// "where", the badge answers "what state", and the single headline figure
  /// answers "what is owed" — deep-linking to the trip's Money tab.
  /// Cards stay solid; glass never touches content.
  Widget _tripCard(Map<String, dynamic> r) {
    final id = (r['id'] ?? '').toString();
    final dispatchDate = (r['dispatch_date'] ?? '').toString();
    final plannedDate = (r['planned_dispatch_date'] ?? '').toString();
    final arrivalDate = (r['arrival_date'] ?? '').toString();
    final legDate = dispatchDate.isNotEmpty ? dispatchDate : plannedDate;
    final destDate = arrivalDate.isNotEmpty ? arrivalDate : legDate;
    final registration = (r['registration'] ?? '').toString();
    final owner = (r['owner_name'] ?? '').toString();
    final captionStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: KarvaanDesign.secondary);
    return Card(
      key: ValueKey('trip:$id'),
      child: InkWell(
        onTap: () => detail(id),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BilingualText(
                      Bilingual.data((r['trip_number'] ?? '').toString()),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TripStatusBadge((r['state'] ?? '').toString()),
                ],
              ),
              const SizedBox(height: 12),
              // Money view leads with the money figure; the operational
              // view leads with the route.
              if (widget.moneyMode) ...[
                _outstandingFigure(id),
                const SizedBox(height: 8),
              ],
              TripRouteLine(
                origin: (r['origin_name'] ?? '').toString(),
                originMeta: legDate,
                destination: (r['destination_name'] ?? '').toString(),
                destinationMeta: destDate,
              ),
              const SizedBox(height: 8),
              BilingualText(
                owner.isEmpty
                    ? Bilingual.data(registration)
                    : L10n.labelValuescd55a9.withValues([
                        Bilingual.data(registration),
                        Bilingual.data(owner),
                      ]),
                style: captionStyle,
              ),
              BilingualText(
                L10n.labelValues10866a.withValues([
                  L10n.carCount04a594.withValues([
                    displayCount(r['car_count'] ?? 0),
                  ]),
                  loadKindLabel(r['load_kind']),
                ]),
                style: captionStyle,
              ),
              ExpandableNote((r['notes'] ?? '').toString()),
              if (!widget.moneyMode) ...[
                const SizedBox(height: 8),
                _outstandingFigure(id),
                const SizedBox(height: 8),
              ],
              // updated_at is not returned by list_trips; only stamps with
              // real data render.
              TimestampFooter(
                created: (r['created_at'] ?? '').toString().split('T').first,
                dispatched: dispatchDate.isNotEmpty ? dispatchDate : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The card's one headline figure: customer outstanding from the existing
  /// get_trip_financials read, rendered as a paper-trail amount deep-linking
  /// to the trip's Money tab. Zero outstanding renders the settled
  /// zero-state wording; loading and error states render nothing rather than
  /// a guessed figure.
  Widget _outstandingFigure(String id) {
    if (widget.finance == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: _tripFinancials(id),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        String outstanding;
        try {
          outstanding = tripCustomerOutstanding(snapshot.data!) ?? '0.00';
        } on FormatException {
          return const SizedBox.shrink();
        }
        final settled = LedgerAmount.fromJson(outstanding).paisa == BigInt.zero;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (settled)
              BilingualText(
                L10n.settled,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: KarvaanDesign.accent),
              )
            else
              PaperTrailAmount(
                formatted: displayMoney(outstanding),
                onTap: () => detail(id, initialTab: 1),
                semanticLabel:
                    '${L10n.customerOutstandingAccessibility} ${displayMoney(outstanding)}',
              ),
            const SizedBox(height: 2),
            BilingualText(
              L10n.customerOutstanding,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: KarvaanDesign.secondary),
            ),
          ],
        );
      },
    );
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
              style: Theme.of(context).textTheme.titleMedium,
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
        if (widget.moneyMode) ...[
          const BilingualText(L10n.moneyWorkspacePurpose),
          const SizedBox(height: 8),
          const BilingualText(
            L10n.permittedTripsOnlyNotACompletePartyOrBusiness,
          ),
          const SizedBox(height: 8),
        ],
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
        const SizedBox(height: 16),
        // Status filter chips. "All" clears the filter; the remaining chips
        // map 1:1 to the backend trip states, including Cancelled.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in const [
              null,
              'DRAFT',
              'DISPATCHED',
              'ARRIVED',
              'CANCELLED',
            ])
              ChoiceChip(
                key: ValueKey('trip-filter-${s ?? 'ALL'}'),
                label: BilingualText(s == null ? L10n.all : tripStateLabel(s)),
                selected: status == s,
                showCheckmark: false,
                selectedColor: KarvaanDesign.borderColor,
                onSelected: (_) {
                  status = s;
                  reload(start: 0);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Compact secondary filters: office, vehicle, and date range stay
        // fully working, restyled to share one row instead of full-width rows.
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: KarvaanChoiceField<String>(
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
            ),
            SizedBox(
              width: 320,
              child: BilingualListTile(
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
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: from,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualOwnedCaption(TripStrings.labels['from']),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: to,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualOwnedCaption(TripStrings.labels['to']),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => reload(start: 0),
              child: const BilingualCaption(L10n.searchRefresh),
            ),
          ],
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BilingualText(
                  (result.scope == 'ALL_OFFICES'
                      ? L10n.allOffices
                      : widget.moneyMode
                      ? L10n.tripsWithMoneyScope
                      : L10n.assignedOfficeTrips),
                ),
                const SizedBox(height: 12),
                if (result.rows.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BilingualText(L10n.noTripsInThisScope),
                          if (!widget.moneyMode) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => edit(TripDraft()),
                              icon: const Icon(Icons.add),
                              label: const BilingualText(L10n.newDraft),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                for (final r in result.rows) _tripCard(r),
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
  animationStyle: AnimationStyle.noAnimation,
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

  /// Session-scoped selection frequency per picker (kind + role). The most
  /// used records sort first; nothing is persisted. Presentation only.
  static final _usage = <String, Map<String, int>>{};
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
                final usageKey = '${widget.kind}:${widget.role ?? ''}';
                final counts = _usage[usageKey] ?? const <String, int>{};
                final choices =
                    all
                        .where(
                          (r) =>
                              !r.archived &&
                              (widget.role == null ||
                                  r.roles.contains(widget.role)),
                        )
                        .toList()
                      // Most-used first, then alphabetical. The five most-used
                      // records therefore always lead the searchable list.
                      ..sort((a, b) {
                        final byUse = (counts[b.id] ?? 0).compareTo(
                          counts[a.id] ?? 0,
                        );
                        return byUse != 0 ? byUse : a.label.compareTo(b.label);
                      });
                return ListView(
                  children: [
                    if (choices.isEmpty)
                      const BilingualText(L10n.noChoicesOnThisPage),
                    for (final r in choices)
                      BilingualListTile(
                        title: Text(r.label),
                        subtitle: Text(r.value('code')),
                        onTap: () {
                          final seen = _usage.putIfAbsent(
                            usageKey,
                            () => <String, int>{},
                          );
                          seen[r.id] = (seen[r.id] ?? 0) + 1;
                          Navigator.pop(context, r);
                        },
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

/// One recorded date fact for the hero grid: short format, or "None".
Bilingual _dateFact(Object? value) => value == null
    ? ownedMessage(TripStrings.none)
    : Bilingual.data(displayTimestamp(value.toString()));

/// Definition grid for the trip hero (plan §5.4): a bilingual label column
/// and a single value per fact. No paragraphs, no repeated labels.
class _FactGrid extends StatelessWidget {
  const _FactGrid({required this.facts});
  final List<(Bilingual, Bilingual)> facts;
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in facts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: BilingualText(label, style: type.labelLarge),
                ),
                Expanded(child: BilingualText(value, style: type.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Existing quote totals, with one optional primary customer figure.
class TripTotalsStrip extends StatelessWidget {
  const TripTotalsStrip({
    super.key,
    required this.values,
    this.hero = false,
    this.outstanding,
  });
  final Map values;
  final bool hero;

  /// Canonical decimal-string customer outstanding. Null hides the cell;
  /// zero renders the settled zero-state wording, highlighted.
  final String? outstanding;

  @override
  Widget build(BuildContext context) {
    final pending = outstanding;
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        for (final key in [
          'customer_charge',
          'commission',
          'owner_entitlement',
        ])
          SizedBox(
            width: 280,
            child: KarvaanMetric(
              key: ValueKey('trip-total-$key'),
              label: ownedMessage(TripStrings.labels[key]),
              formattedValue: displayMoney(values[key]),
              hero: hero && key == 'customer_charge',
            ),
          ),
        if (pending != null)
          SizedBox(
            width: 280,
            child: _OutstandingCell(value: pending, hero: hero),
          ),
      ],
    );
  }
}

/// Highlighted outstanding cell: the money-green #EAF4ED treatment marks the
/// amount owed. A settled trip shows the settled wording instead of a
/// zero figure — arrival never implies payment, and neither does a zero here
/// without the claims behind it.
class _OutstandingCell extends StatelessWidget {
  const _OutstandingCell({required this.value, required this.hero});
  final String value;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final settled = LedgerAmount.fromJson(value).paisa == BigInt.zero;
    final type = Theme.of(context).textTheme;
    final figureStyle = type.headlineSmall?.copyWith(
      color: KarvaanDesign.accent,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KarvaanDesign.moneySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settled)
            BilingualText(L10n.settled, style: figureStyle)
          else
            KarvaanFigure(displayMoney(value), style: figureStyle),
          const SizedBox(height: 4),
          BilingualText(L10n.customerOutstanding, style: type.bodySmall),
        ],
      ),
    );
  }
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
      totals = TripTotalsStrip(values: values, hero: true);
    } catch (e) {
      totals = BilingualOwnedText(tripError(e));
    }
    return KarvaanSection(
      title: L10n.reviewStep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.registration ?? TripStrings.none),
          RouteLabel(
            origin:
                (widget.offices
                            .where((o) => o['id'] == d.origin)
                            .firstOrNull?['name'] ??
                        TripStrings.none)
                    .toString(),
            destination:
                (widget.offices
                            .where((o) => o['id'] == d.destination)
                            .firstOrNull?['name'] ??
                        d.destinationName ??
                        TripStrings.none)
                    .toString(),
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

  /// Keyboard: Enter advances a step, Esc goes back. Single-line text fields
  /// consume Enter themselves, and focused buttons handle their own
  /// activation, so the shortcut only fires from non-editing focus — never
  /// mid-typing. Step 2 keeps save as an explicit tap.
  void advanceKeyboard() {
    if (busy) return;
    if (step < 2) moveStep(step + 1);
  }

  void backKeyboard() {
    if (busy) return;
    if (step > 0) moveStep(step - 1);
  }

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
    child: KarvaanChoiceField<String>(
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
    return KarvaanChoiceField<String>(
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
      onChanged: busy ? null : (v) => setState(() => update(v)),
    );
  }

  Widget amounts(Map values) => TripTotalsStrip(values: values);
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
                moneyLabel([
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
          animationStyle: AnimationStyle.noAnimation,
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
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): advanceKeyboard,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): advanceKeyboard,
        const SingleActivator(LogicalKeyboardKey.escape): backKeyboard,
      },
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
                                  ? KarvaanDesign.borderColor
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
                            () => pick(
                              'driver',
                              MasterKind.party,
                              role: 'DRIVER',
                            ),
                            clear: () {
                              d.driver = null;
                              d.driverName = null;
                            },
                          ),
                          KarvaanChoiceField<String>(
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
                                                    error =
                                                        TripStrings.stopInUse;
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
                                : () =>
                                      setState(() => d.stops.add(DraftStop())),
                            child: const BilingualCaption(L10n.addStop),
                          ),
                          for (final c in d.consignments) consignment(c),
                          if (d.kind == 'LOADED')
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(
                                      () => d.consignments.add(
                                        DraftConsignment(),
                                      ),
                                    ),
                              child: const BilingualCaption(
                                L10n.addConsignment,
                              ),
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
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .4),
            child: SingleChildScrollView(
              child: SafeArea(
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (step > 0)
                                    OutlinedButton(
                                      key: const Key('trip-previous'),
                                      onPressed: busy
                                          ? null
                                          : () => moveStep(step - 1),
                                      child: const BilingualCaption(
                                        L10n.previous,
                                      ),
                                    ),
                                  OutlinedButton(
                                    key: const Key('trip-cancel'),
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: const BilingualCaption(L10n.cancel),
                                  ),
                                ],
                              ),
                              if (step < 2)
                                FilledButton(
                                  key: const Key('trip-next'),
                                  onPressed: busy
                                      ? null
                                      : () => moveStep(step + 1),
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
            TripTotalsStrip(values: widget.totals, hero: true),
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
    this.initialTab = 0,
    this.finance,
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
  final int initialTab;
  final FinancialCommands? finance;
  final bool Function(String) canReturn;
  final Future<void> Function(TripDraft) onEdit;
  @override
  State<TripDetail> createState() => _TripDetailState();
}

class _TripDetailState extends State<TripDetail> {
  final scroll = ScrollController();
  final summaryKey = GlobalKey();
  late int tab;

  /// Memoized get_trip_financials read for the outstanding figure and the
  /// Money tab. Presentation-only; null when no finance commands are wired.
  Future<Map<String, dynamic>>? _financials;

  Future<Map<String, dynamic>>? _loadFinancials() {
    final finance = widget.finance;
    if (finance == null || !_looksLikeUuid(widget.id)) return null;
    return finance.trip(RecordId(widget.id));
  }

  void selectTab(int value) {
    setState(() => tab = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients) return;
      final summary = summaryKey.currentContext?.findRenderObject();
      if (summary is! RenderBox || !summary.hasSize) return;
      // The summary is the first sliver. Its actual laid-out height is exactly
      // the scroll offset where the pinned tabs begin, at any text scale.
      final offset = summary.size.height;
      scroll.jumpTo(
        offset.clamp(
          scroll.position.minScrollExtent,
          scroll.position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  late Future<Map<String, dynamic>> data;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    data = widget.repository.detail(widget.id);
    _financials = _loadFinancials();
  }

  void reload() {
    setState(() {
      data = widget.repository.detail(widget.id);
      _financials = _loadFinancials();
    });
  }

  /// Hero totals strip. The outstanding cell renders once get_trip_financials
  /// resolves; until then the three quote cells stand alone. Nothing is
  /// guessed while loading or on error.
  Widget _heroTotals(Map totals) {
    final financials = _financials;
    if (financials == null) {
      return TripTotalsStrip(values: totals, hero: true);
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: financials,
      builder: (context, snapshot) {
        String? outstanding;
        if (snapshot.hasData && !snapshot.hasError) {
          try {
            outstanding = tripCustomerOutstanding(snapshot.data!);
          } on FormatException {
            outstanding = null;
          }
        }
        return TripTotalsStrip(
          values: totals,
          hero: true,
          outstanding: outstanding,
        );
      },
    );
  }

  /// Per-trip paid-vs-outstanding in the Money tab. The billed total is the
  /// totals strip above; this section shows the open customer outstanding
  /// (highlighted, with the settled zero-state) plus the open claims behind
  /// it, each deep-linking to Payments & allocations. No "paid" figure is
  /// computed here — the backend owns that arithmetic.
  Widget _moneyOutstanding(List consignments) {
    final financials = _financials;
    if (financials == null) return const SizedBox.shrink();
    return FutureBuilder<Map<String, dynamic>>(
      future: financials,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: BilingualOwnedText(tripError(snapshot.error!)),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          );
        }
        try {
          return _moneyOutstandingBody(snapshot.data!, consignments);
        } on FormatException {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _moneyOutstandingBody(Map<String, dynamic> data, List consignments) {
    final outstanding = tripCustomerOutstanding(data) ?? '0.00';
    final settled = LedgerAmount.fromJson(outstanding).paisa == BigInt.zero;
    final claims = <Map>[];
    for (final c in (data['claims'] as List? ?? [])) {
      if (c is Map && c['account_purpose'] == 'CUSTOMER_RECEIVABLE') {
        claims.add(c);
      }
    }
    final type = Theme.of(context).textTheme;
    Bilingual claimLabel(Map c) {
      final consignment = consignments
          .where((s) => s is Map && s['id'] == c['consignment_id'])
          .firstOrNull;
      final customer = consignment is Map
          ? (consignment['customer_name'] ?? '').toString()
          : '';
      // The branch catalogue owns the bilingual purpose wording; only
      // CUSTOMER_RECEIVABLE claims reach this section.
      const purpose = L10n.customerOutstanding;
      if (customer.isEmpty) return purpose;
      return L10n.labelValuescd55a9.withValues([
        Bilingual.data(customer),
        purpose,
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KarvaanDesign.moneySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settled)
                BilingualText(
                  L10n.settled,
                  style: type.headlineSmall?.copyWith(
                    color: KarvaanDesign.accent,
                  ),
                )
              else
                KarvaanFigure(
                  displayMoney(outstanding),
                  style: type.headlineSmall?.copyWith(
                    color: KarvaanDesign.accent,
                  ),
                ),
              const SizedBox(height: 4),
              BilingualText(L10n.customerOutstanding, style: type.bodySmall),
            ],
          ),
        ),
        if (claims.isNotEmpty && widget.onPayments != null) ...[
          const SizedBox(height: 8),
          for (final c in claims)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: BilingualText(
                      claimLabel(c),
                      style: type.bodySmall?.copyWith(
                        color: KarvaanDesign.secondary,
                      ),
                    ),
                  ),
                  PaperTrailAmount(
                    formatted: displayMoney(c['remaining']),
                    onTap: widget.onPayments!,
                    semanticLabel:
                        '${L10n.customerOutstandingAccessibility} ${displayMoney(c['remaining'])}',
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Future<void> operate(
    TripAction action,
    Map<String, dynamic> trip, {
    String? consignment,
  }) async {
    final committed = await showDialog<Map<String, dynamic>>(
      animationStyle: AnimationStyle.noAnimation,
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
        Bilingual stopLabel(dynamic id) {
          final stop = stops.where((s) => s['id'] == id).firstOrNull;
          if (id == null || stop == null) return ownedMessage(TripStrings.none);
          return Bilingual.data('${stop['position']}. ${stop['address']}');
        }

        return CustomScrollView(
          controller: scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                key: summaryKey,
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
                        // Pure identifiers print once, LTR, with no Urdu mirror.
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${r['trip_number']} · ${r['registration']}',
                              style: Theme.of(context).textTheme.titleMedium,
                              textDirection: TextDirection.ltr,
                            ),
                            TripStatusBadge(r['state'] as String),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _heroTotals(r['totals'] as Map),
                        const SizedBox(height: 16),
                        TripRouteLine(
                          origin: (r['origin_name'] ?? '').toString(),
                          originMeta: displayTimestamp(
                            (r['dispatch_date'] ??
                                    r['planned_dispatch_date'] ??
                                    '')
                                .toString(),
                          ),
                          destination: (r['destination_name'] ?? '').toString(),
                          destinationMeta: displayTimestamp(
                            (r['arrival_date'] ??
                                    r['dispatch_date'] ??
                                    r['planned_dispatch_date'] ??
                                    '')
                                .toString(),
                          ),
                          stopDots: stops.length,
                        ),
                        const SizedBox(height: 16),
                        _FactGrid(
                          facts: [
                            (
                              L10n.ownerName,
                              Bilingual.data(
                                (r['owner_snapshot'] as Map)['display_name']
                                    .toString(),
                              ),
                            ),
                            (
                              L10n.driverName,
                              r['driver_name'] == null
                                  ? ownedMessage(TripStrings.none)
                                  : Bilingual.data(r['driver_name'].toString()),
                            ),
                            (
                              L10n.vehicle,
                              Bilingual.data(
                                (r['registration'] ?? '').toString(),
                              ),
                            ),
                            (
                              L10n.routeLabel,
                              (r['route_snapshot'] as Map)['code'] == null
                                  ? ownedMessage(TripStrings.none)
                                  : Bilingual.data(
                                      (r['route_snapshot'] as Map)['code']
                                          .toString(),
                                    ),
                            ),
                            (
                              L10n.historyFieldLoad,
                              loadKindLabel(r['load_kind']),
                            ),
                            (
                              L10n.plannedDateLabel,
                              _dateFact(r['planned_dispatch_date']),
                            ),
                            (L10n.dispatchDate, _dateFact(r['dispatch_date'])),
                            (L10n.arrivalDate, _dateFact(r['arrival_date'])),
                            (
                              L10n.historyFieldCars,
                              Bilingual.data(
                                '${(r['totals'] as Map)['car_count']}',
                              ),
                            ),
                          ],
                        ),
                        if (r['state'] == 'DRAFT')
                          const BilingualText(
                            L10n.draftQuotesArePotentialFareNoEarningsOrPayment,
                          ),
                        if (r['earnings_recognized'] == true)
                          const BilingualText(
                            L10n.dispatchPostsDebtShareBrokerageShort,
                          ),
                        const BilingualText(
                          L10n.arrivalSettlementIndependentShort,
                        ),
                        ExpandableNote((r['notes'] ?? '').toString()),
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
                                popUpAnimationStyle: AnimationStyle.noAnimation,
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
                onSelected: selectTab,
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      // Single bilingual line: values stay in
                                      // place, only the label is translated.
                                      child: BilingualInlineLine(
                                        L10n.customerLine,
                                        value: Bilingual.data(
                                          '${c['customer_name']} · ${consignmentStateLabel(c['state']).en} · ${c['car_count']}',
                                        ),
                                      ),
                                    ),
                                    // Destructive actions never sit next to
                                    // ordinary buttons: cancellation lives in
                                    // an overflow menu whose confirmation
                                    // sheet narrates what will be reversed.
                                    if (r['can_cancel_consignment'] == true &&
                                        c['state'] == 'ACTIVE')
                                      PopupMenuButton<String>(
                                        key: ValueKey(
                                          'consignment-menu-${c['id']}',
                                        ),
                                        popUpAnimationStyle:
                                            AnimationStyle.noAnimation,
                                        tooltip: L10n
                                            .correctionsAndCancellationAccessibility,
                                        onSelected: (_) => operate(
                                          TripAction.cancelConsignment,
                                          r,
                                          consignment: c['id'] as String,
                                        ),
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                            value: 'cancel',
                                            child: BilingualOwnedCaption(
                                              TripAction
                                                  .cancelConsignment
                                                  .label,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                BilingualInlineLine(
                                  L10n.brokerLine,
                                  value: c['broker_name'] == null
                                      ? ownedMessage(TripStrings.none)
                                      : Bilingual.data(
                                          c['broker_name'].toString(),
                                        ),
                                ),
                                // The ledger strip (plan §5.4): fare →
                                // −commission → =net, each amount once.
                                LedgerStrip(
                                  segments: [
                                    LedgerSegment(
                                      label: L10n.agreedFare,
                                      formattedValue: displayMoney(
                                        c['quoted_amount'],
                                      ),
                                    ),
                                    LedgerSegment(
                                      label: c['commission_method'] == 'FIXED'
                                          ? L10n.brokerCommissionFixed
                                          : L10n.brokerCommissionPercent,
                                      formattedValue:
                                          '− ${displayMoney(c['commission'])}',
                                    ),
                                    LedgerSegment(
                                      label: L10n.netOwnerShare,
                                      formattedValue:
                                          '= ${displayMoney(c['owner_entitlement'])}',
                                    ),
                                  ],
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
                            const BilingualText(L10n.moneySummaryHint),
                            // Ledger strip on top (plan §5.4); the open
                            // outstanding stays a separate green callout.
                            LedgerStrip(
                              segments: [
                                LedgerSegment(
                                  label: ownedMessage(
                                    TripStrings.labels['customer_charge'],
                                  ),
                                  formattedValue: displayMoney(
                                    (r['totals'] as Map)['customer_charge'],
                                  ),
                                ),
                                LedgerSegment(
                                  label: ownedMessage(
                                    TripStrings.labels['commission'],
                                  ),
                                  formattedValue:
                                      '− ${displayMoney((r['totals'] as Map)['commission'])}',
                                ),
                                LedgerSegment(
                                  label: ownedMessage(
                                    TripStrings.labels['owner_entitlement'],
                                  ),
                                  formattedValue:
                                      '= ${displayMoney((r['totals'] as Map)['owner_entitlement'])}',
                                ),
                              ],
                            ),
                            _moneyOutstanding(
                              r['consignments'] as List? ?? const [],
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
                            const BilingualText(L10n.noTripExpensesRecorded),
                            const BilingualText(L10n.openOfficeExpenseListHint),
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
          finance: widget.finance,
          guard: widget.guard,
        ),
      ),
    ),
  );
}
