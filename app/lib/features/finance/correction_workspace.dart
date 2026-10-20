import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import '../../app/karvaan_patterns.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/business_date.dart';
import '../../core/domain/money.dart';
import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import 'correction_repository.dart';
import 'payment_model.dart';

String correctionError(Object e) => e is FormatException
    ? e.message
    : e is PostgrestException
    ? switch (e.message) {
        'FORBIDDEN' => 'Current office access and creator or administrator permission required.',
        'CORRECT_DEPENDENT_EXPENSE_SEPARATELY' => 'Correct the dependent expense separately before changing its funding.',
        'CANCELLED_TRIP_REQUIRES_REVIEWED_ADJUSTMENT' => 'This record belongs to a cancelled trip. Its cancellation adjustments must be resolved first.',
        'ALREADY_REVERSED' => 'This entry has already been reversed.',
        _ =>
          e.code == 'PT409'
              ? 'Records changed. Close this form and reload before reviewing again.'
              : 'Correction was rejected. Check the reviewed amounts and dependencies.',
      }
    : 'Confirmation could not be verified. Retry this same reviewed correction.';
String eventLabel(String key) => key.toLowerCase().replaceAll('_', ' ');

class CorrectionWorkspace extends StatefulWidget {
  const CorrectionWorkspace({
    super.key,
    required this.commands,
    required this.trips,
    required this.guard,
    this.initialTrip,
  });
  final CorrectionCommands commands;
  final TripRepository trips;
  final Widget Function(Widget) guard;
  final String? initialTrip;
  @override
  State<CorrectionWorkspace> createState() => _CorrectionWorkspaceState();
}

class _CorrectionWorkspaceState extends State<CorrectionWorkspace> {
  String? trip;
  int offset = 0;
  late Future<List<Map<String, dynamic>>> rows;
  @override
  void initState() {
    super.initState();
    trip = widget.initialTrip;
    reload();
  }

  void reload() {
    rows = widget.commands.history(trip, offset);
  }

  Future<void> pick() async {
    final selected = await showDialog<String>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (_) => widget.guard(_CorrectionTripPicker(widget.trips)),
    );
    if (selected != null && mounted) {
      setState(() {
        trip = selected;
        offset = 0;
        reload();
      });
    }
  }

  Future<void> form(Map<String, dynamic>? row) async {
    try {
      final id = row?['id'] as String? ?? trip!;
      final review = await widget.commands.review(
        id,
        cancellation: row == null,
      );
      final detail = row == null ? await widget.trips.detail(id) : null;
      if (!mounted) {
        return;
      }
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.guard(
            CorrectionForm(
              commands: widget.commands,
              id: id,
              review: review,
              event: row,
              trip: detail,
            ),
          ),
        ),
      );
      if (saved == true && mounted) {
        setState(reload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: BilingualOwnedText(correctionError(e))),
        );
      }
    }
  }

  /// One correction-history row. The recorded amount is a PaperTrailAmount:
  /// tapping it deep-links to this record's correction review form, so no
  /// money figure is a dead end. Tabular numerals, money-green per the
  /// blue-is-movement/green-is-money rule.
  Widget _historyCard(Map<String, dynamic> row) {
    final eventName = ownedMessage(eventLabel(row['kind'] as String));
    final eventUr = eventName.ur.isEmpty ? eventName.en : eventName.ur;
    return Card(
      child: BilingualListTile(
        title: BilingualText(
          Bilingual(
            L10n.pkr.key,
            '${eventName.en} · ${row['effective_date']}',
            '$eventUr · ${row['effective_date']}',
          ),
        ),
        subtitle: BilingualText(
          L10n.correctionTrace.withValues([
            row['actor'],
            displayTimestamp(row['recorded_at']),
            row['reason'] ?? '',
            row['reversed'] == true ? L10n.reversedEntry : Bilingual.data(''),
            row['reversal_of_id'] != null
                ? L10n.reversesEntry.withValues([row['reversal_of_id']])
                : Bilingual.data(''),
            row['replacement_of_id'] != null
                ? L10n.replacesEntry.withValues([row['replacement_of_id']])
                : Bilingual.data(''),
          ]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PaperTrailAmount(
              formatted: displayMoney(row['amount']),
              onTap: () => form(row),
              semanticLabel: '${eventName.en}: ${displayMoney(row['amount'])}',
            ),
            if (row['can_correct'] == true)
              TextButton(
                onPressed: () => form(row),
                child: const BilingualCaption(L10n.correct),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.correctionsAndHistory),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BilingualText(
          (trip == null
              ? L10n.standaloneExpensesInYourPermittedOffices
              : L10n.selectedPermittedTrip),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: pick,
              child: const BilingualCaption(L10n.chooseTrip),
            ),
            TextButton(
              onPressed: () => setState(() {
                trip = null;
                offset = 0;
                reload();
              }),
              child: const BilingualCaption(L10n.standaloneExpenses),
            ),
            TextButton(
              onPressed: () => setState(reload),
              child: const BilingualCaption(L10n.reload),
            ),
            if (trip != null)
              TextButton(
                onPressed: () => form(null),
                child: const BilingualCaption(L10n.reviewCancellation),
              ),
          ],
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return BilingualOwnedText(correctionError(snapshot.error!));
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final data = snapshot.data!;
            return Column(
              children: [
                if (data.isEmpty)
                  const BilingualText(L10n.noRecordedEventsInThisScope),
                for (final row in data) _historyCard(row),
                // Wrap: bilingual buttons overflow a fixed Row at 200%.
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: offset == 0
                          ? null
                          : () => setState(() {
                              offset -= 50;
                              reload();
                            }),
                      child: const BilingualCaption(L10n.previous),
                    ),
                    TextButton(
                      onPressed: data.length < 50
                          ? null
                          : () => setState(() {
                              offset += 50;
                              reload();
                            }),
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

class _CorrectionTripPicker extends StatefulWidget {
  const _CorrectionTripPicker(this.trips);
  final TripRepository trips;
  @override
  State<_CorrectionTripPicker> createState() => _CorrectionTripPickerState();
}

class _CorrectionTripPickerState extends State<_CorrectionTripPicker> {
  final search = TextEditingController();
  int offset = 0;
  late Future<TripPage> page;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    page = widget.trips.list(search: search.text.trim(), offset: offset);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const BilingualText(L10n.choosePermittedTrip),
    content: SizedBox(
      width: 650,
      height: 450,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(L10n.searchTripOrVehicle),
              ),
            ),
            onSubmitted: (_) => setState(() {
              offset = 0;
              reload();
            }),
          ),
          Expanded(
            child: FutureBuilder<TripPage>(
              future: page,
              builder: (_, s) {
                if (s.hasError) {
                  return BilingualOwnedText(correctionError(s.error!));
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator();
                }
                if (s.data!.rows.isEmpty) {
                  return const BilingualText(L10n.noRecordsFound);
                }
                return ListView(
                  children: [
                    for (final t in s.data!.rows)
                      BilingualListTile(
                        title: BilingualText(
                          L10n.labelValues2bd17e.withValues([
                            t['trip_number'],
                            t['registration'],
                            t['state'],
                          ]),
                        ),
                        onTap: () => Navigator.pop(context, t['id']),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: offset == 0
                              ? null
                              : () => setState(() {
                                  offset -= 50;
                                  reload();
                                }),
                          child: const BilingualCaption(L10n.previous),
                        ),
                        TextButton(
                          onPressed: s.data!.rows.length < 50
                              ? null
                              : () => setState(() {
                                  offset += 50;
                                  reload();
                                }),
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

/// Keeps one reviewed command across an ambiguous response. Success is shown
/// only after the transactional RPC returns its committed result.
class CorrectionForm extends StatefulWidget {
  const CorrectionForm({
    super.key,
    required this.commands,
    required this.id,
    required this.review,
    this.event,
    this.trip,
  });
  final CorrectionCommands commands;
  final String id;
  final Map<String, dynamic> review;
  final Map<String, dynamic>? event, trip;
  @override
  State<CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends State<CorrectionForm> {
  final reason = TextEditingController(),
      date = TextEditingController(),
      amount = TextEditingController(),
      commission = TextEditingController();
  final allocations = <TextEditingController>[],
      fees = <TextEditingController>[],
      brokerFees = <TextEditingController>[];
  final unwind = <String>{};
  Map<String, dynamic>? original, reviewed;
  String? request, error;
  bool replace = true, busy = false, conflict = false;
  bool get cancellation => widget.event == null;
  bool get earnings => widget.event?['kind'] == 'DISPATCH';
  bool get quoteCorrection => earnings || widget.event?['kind'] == 'ADJUSTMENT';
  List<Map<String, dynamic>> get dependents =>
      (widget.review['events'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['id'] != widget.id)
          .toList();
  List<Map<String, dynamic>> get consignments =>
      (widget.trip?['consignments'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((e) => e['state'] != 'CANCELLED')
          .toList();
  List<dynamic> get originalAllocations => [
    ...original?['allocations'] as List? ?? [],
    ...original?['credits'] as List? ?? [],
  ];
  @override
  void initState() {
    super.initState();
    original = widget.event?['payload'] == null
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(jsonEncode(widget.event!['payload'])) as Map,
          );
    date.text = cancellation
        ? DateTime.now()
              .toUtc()
              .add(const Duration(hours: 5))
              .toIso8601String()
              .substring(0, 10)
        : widget.event!['effective_date'] as String;
    final initialAmount = quoteCorrection
        ? (original?['quoted_amount'])
        : (original?['amount']);
    amount.text = initialAmount is String
        ? initialAmount
        : (widget.event?['amount'] as String? ?? '0.00');
    commission.text = original?['commission_value'] as String? ?? '0.00';
    for (final a in originalAllocations) {
      allocations.add(
        TextEditingController(text: (a as Map)['amount'] as String),
      );
    }
    for (final _ in consignments) {
      fees.add(TextEditingController(text: '0.00'));
      brokerFees.add(TextEditingController(text: '0.00'));
    }
  }

  @override
  void dispose() {
    for (final c in [
      reason,
      date,
      amount,
      commission,
      ...allocations,
      ...fees,
      ...brokerFees,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> payload() {
    if (reason.text.trim().isEmpty || reason.text.trim().length > 500) {
      throw const FormatException(
        'Enter a correction reason up to 500 characters.',
      );
    }
    BusinessDate.parse(date.text.trim());
    if (cancellation) {
      final plans = <Map<String, dynamic>>[];
      for (var n = 0; n < consignments.length; n++) {
        final fee = Money.parse(fees[n].text),
            broker = Money.parse(brokerFees[n].text);
        if (fee.paisa < BigInt.zero ||
            broker.paisa < BigInt.zero ||
            broker.paisa > fee.paisa ||
            consignments[n]['broker_id'] == null &&
                broker.paisa != BigInt.zero) {
          throw const FormatException(
            'Agreed brokerage must be within the cancellation charge and have a broker.',
          );
        }
        plans.add({
          'id': consignments[n]['id'],
          'quoted_amount': fee.toString(),
          'quote_mode': 'DEDUCTED',
          'commission_method': 'FIXED',
          'commission_value': broker.toString(),
        });
      }
      return {
        'reason': reason.text.trim(),
        'effective_date': date.text.trim(),
        'review_token': widget.review['review_token'],
        'consignments': plans,
      };
    }
    if (dependents.any((e) => !unwind.contains(e['id']))) {
      throw const FormatException(
        'Explicitly review every dependent settlement.',
      );
    }
    Map<String, dynamic>? replacement;
    if (replace) {
      if (original == null) {
        throw const FormatException(
          'This entry has no editable source. Choose an explicit reversal.',
        );
      }
      replacement = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(original)) as Map,
      );
      replacement[quoteCorrection ? 'quoted_amount' : 'amount'] = Money.parse(
        amount.text.trim(),
      ).toString();
      replacement['effective_date'] = date.text.trim();
      if (quoteCorrection) {
        replacement['commission_value'] = Money.parse(commission.text.trim())
            .toString();
      } else {
        replacement['reason'] = reason.text.trim();
      }
      final states = {
        for (final c in widget.review['claims'] as List)
          (c as Map)['line_id']: c['state'],
      };
      var n = 0;
      for (final key in ['allocations', 'credits']) {
        for (final a in replacement[key] as List? ?? []) {
          (a as Map)['amount'] = Money.parse(allocations[n++].text.trim())
              .toString();
          for (final field in ['target_line_id', 'source_line_id', 'line_id']) {
            if (a[field] != null && states[a[field]] != null) {
              a[field == 'line_id'
                      ? 'version'
                      : field == 'target_line_id'
                      ? 'target_version'
                      : 'source_version'] =
                  (states[a[field]] as Map)['version'];
            }
          }
        }
      }
    }
    return {
      'reason': reason.text.trim(),
      'review_token': widget.review['review_token'],
      'unwind_event_ids': unwind.toList()..sort(),
      'replacement': replacement,
    };
  }

  Future<void> confirm() async {
    request ??= newRecordId();
    setState(() => busy = true);
    try {
      await widget.commands.confirm(
        widget.id,
        request!,
        cancellation ? widget.trip!['version'] as int : 1,
        reviewed!,
        cancellation: cancellation,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BilingualText(
            (cancellation
                ? L10n.cancellationAndAdjustmentsCommittedActualExpensesRetainedRefundsRequire
                : L10n.correctionCommittedOriginalRecordsAndEvidenceRetained),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = correctionError(e);
          conflict = e is PostgrestException && e.code == 'PT409';
          if (e is PostgrestException && !conflict) {
            request = null;
            reviewed = null;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: BilingualText(
        (cancellation ? L10n.cancellationReview : L10n.correctRecordedEntry),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const BilingualText(
          L10n.originalRecordsReasonsAndAttachmentsRemainInHistoryFinancial,
        ),
        if (cancellation)
          const BilingualText(
            L10n.reviewAgreedFeesForEveryConsignmentActualPaymentsAnd,
          ),
        if (!cancellation)
          BilingualText(
            moneyMessage(
              L10n.originalPKROnTo,
              [
                ownedMessage(eventLabel(widget.event!['kind'] as String)),
                widget.event!['amount'],
                widget.event!['effective_date'],
                widget.event!['payer'] ?? '',
                widget.event!['payee'] ?? '',
              ],
              {1},
            ),
          ),
        if (!cancellation && !quoteCorrection)
          SwitchListTile(
            title: const BilingualText(L10n.replaceWithCorrectedEntry),
            subtitle: const BilingualText(
              L10n.turnOffOnlyToExplicitlyVoidAnIncorrectEntry,
            ),
            value: replace,
            onChanged: request != null || reviewed != null
                ? null
                : (v) => setState(() {
                    replace = v;
                    reviewed = null;
                  }),
          ),
        TextField(
          controller: reason,
          enabled: request == null && reviewed == null,
          decoration: bilingualDecoration(
            context,
            InputDecoration(label: BilingualCaption(L10n.reason)),
          ),
        ),
        TextField(
          controller: date,
          enabled: request == null && reviewed == null && !earnings,
          decoration: bilingualDecoration(
            context,
            InputDecoration(
              label: BilingualCaption(
                (cancellation
                    ? L10n.cancellationEffectiveDateYYYYMMDD
                    : L10n.correctedEffectiveDateYYYYMMDD),
              ),
            ),
          ),
        ),
        if (!cancellation && replace) ...[
          TextField(
            controller: amount,
            enabled: request == null && reviewed == null,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(
                  (quoteCorrection
                      ? L10n.correctedAgreedQuote
                      : L10n.correctedAmount),
                ),
              ),
            ),
          ),
          if (quoteCorrection)
            TextField(
              controller: commission,
              enabled: request == null && reviewed == null,
              decoration: bilingualDecoration(
                context,
                InputDecoration(
                  label: BilingualCaption(
                    L10n.correctedBrokerageValueExistingMethod,
                  ),
                ),
              ),
            ),
          for (var n = 0; n < allocations.length; n++)
            TextField(
              controller: allocations[n],
              enabled: request == null && reviewed == null,
              decoration: bilingualDecoration(
                context,
                InputDecoration(
                  label: BilingualCaption(
                    L10n.allocationAmount.withValues([
                      n + 1,
                      originalAllocations[n]['component'] ?? 'cash / credit',
                    ]),
                  ),
                ),
              ),
            ),
        ],
        for (final e in dependents)
          CheckboxListTile(
            title: BilingualText(
              moneyMessage(
                L10n.reverseDependentPKROn,
                [
                  ownedMessage(eventLabel(e['kind'] as String)),
                  e['amount'],
                  e['effective_date'],
                ],
                {1},
              ),
            ),
            value: unwind.contains(e['id']),
            onChanged: request != null || reviewed != null
                ? null
                : (v) => setState(() {
                    v == true
                        ? unwind.add(e['id'] as String)
                        : unwind.remove(e['id']);
                    reviewed = null;
                  }),
          ),
        for (var n = 0; n < consignments.length; n++) ...[
          BilingualText(
            moneyMessage(
              L10n.originalChargePKR,
              [
                consignments[n]['customer_name'],
                consignments[n]['customer_charge'],
              ],
              {1},
            ),
          ),
          TextField(
            controller: fees[n],
            enabled: request == null && reviewed == null,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(L10n.agreedCancellationCharge),
              ),
            ),
          ),
          TextField(
            controller: brokerFees[n],
            enabled:
                request == null &&
                reviewed == null &&
                consignments[n]['broker_id'] != null,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(
                  L10n.brokerShareWithinCancellationCharge,
                ),
              ),
            ),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          BilingualOwnedText(error!, style: const TextStyle(color: Colors.red)),
        if (reviewed == null)
          FilledButton(
            onPressed: busy
                ? null
                : () {
                    try {
                      setState(() {
                        reviewed = payload();
                        error = null;
                      });
                    } catch (e) {
                      setState(() => error = correctionError(e));
                    }
                  },
            child: const BilingualCaption(L10n.reviewCorrection),
          )
        else ...[
          BilingualText(
            L10n.reason99c1ea.withValues([
              reviewed!['reason'],
              cancellation
                  ? 'Cancellation effective date: ${reviewed!['effective_date']}'
                  : 'Explicit dependent reversals: $unwind\n${replace ? 'Replacement ${displayMoney(Money.parse(amount.text))} on ${date.text}' : 'Void original entry; no replacement'}',
            ]),
          ),
          if (cancellation)
            for (var n = 0; n < fees.length; n++)
              BilingualText(
                moneyMessage(
                  L10n.chargePKRBrokerPKROwnerPKR,
                  [
                    Money.parse(fees[n].text),
                    Money.parse(brokerFees[n].text),
                    AllocationTotals.decimal(
                      Money.parse(fees[n].text).paisa -
                          Money.parse(brokerFees[n].text).paisa,
                    ),
                  ],
                  {0, 1, 2},
                ),
              ),
          FilledButton(
            onPressed: busy || conflict ? null : confirm,
            child: BilingualCaption(
              (busy
                  ? L10n.confirming
                  : (request == null
                        ? L10n.confirmReviewedCorrection
                        : L10n.retryReviewedCorrection)),
            ),
          ),
          if (request == null)
            TextButton(
              onPressed: () => setState(() => reviewed = null),
              child: const BilingualCaption(L10n.editReview),
            ),
        ],
      ],
    ),
  );
}
