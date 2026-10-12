import 'dart:convert';

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(correctionError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Corrections and history')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          trip == null
              ? 'Standalone expenses in your permitted offices'
              : 'Selected permitted trip',
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(onPressed: pick, child: const Text('Choose trip')),
            TextButton(
              onPressed: () => setState(() {
                trip = null;
                offset = 0;
                reload();
              }),
              child: const Text('Standalone expenses'),
            ),
            TextButton(
              onPressed: () => setState(reload),
              child: const Text('Reload'),
            ),
            if (trip != null)
              TextButton(
                onPressed: () => form(null),
                child: const Text('Review cancellation'),
              ),
          ],
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(correctionError(snapshot.error!));
            }
            if (!snapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final data = snapshot.data!;
            return Column(
              children: [
                if (data.isEmpty)
                  const Text('No recorded events in this scope.'),
                for (final row in data)
                  Card(
                    child: ListTile(
                      title: Text(
                        '${eventLabel(row['kind'] as String)} - PKR ${row['amount']} - ${row['effective_date']}',
                      ),
                      subtitle: Text(
                        '${row['actor']} - ${row['recorded_at']}\n${row['reason'] ?? ''}\n${row['reversed'] == true ? 'Reversed. ' : ''}${row['reversal_of_id'] != null ? 'Reverses ${row['reversal_of_id']}. ' : ''}${row['replacement_of_id'] != null ? 'Replaces ${row['replacement_of_id']}. ' : ''}',
                      ),
                      trailing: row['can_correct'] == true
                          ? TextButton(
                              onPressed: () => form(row),
                              child: const Text('Correct'),
                            )
                          : null,
                    ),
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
                      child: const Text('Previous'),
                    ),
                    TextButton(
                      onPressed: data.length < 50
                          ? null
                          : () => setState(() {
                              offset += 50;
                              reload();
                            }),
                      child: const Text('Next'),
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
    title: const Text('Choose permitted trip'),
    content: SizedBox(
      width: 650,
      height: 450,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(
              labelText: 'Search trip or vehicle',
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
                  return Text(correctionError(s.error!));
                }
                if (!s.hasData) {
                  return const LinearProgressIndicator();
                }
                return ListView(
                  children: [
                    for (final t in s.data!.rows)
                      ListTile(
                        title: Text(
                          '${t['trip_number']} - ${t['registration']} - ${t['state']}',
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
                          child: const Text('Previous'),
                        ),
                        TextButton(
                          onPressed: s.data!.rows.length < 50
                              ? null
                              : () => setState(() {
                                  offset += 50;
                                  reload();
                                }),
                          child: const Text('Next'),
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
        child: const Text('Close'),
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
          content: Text(
            cancellation
                ? 'Cancellation and adjustments committed. Actual expenses retained; refunds require separate confirmation.'
                : 'Correction committed. Original records and evidence retained.',
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
      title: Text(
        cancellation ? 'Cancellation review' : 'Correct recorded entry',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Original records, reasons and attachments remain in history. Financial changes are posted as new entries.',
        ),
        if (cancellation)
          const Text(
            'Review agreed fees for every consignment. Actual payments and incurred expenses remain recorded. Customer credits and owner/broker recoveries remain separate; refunds need available held funds.',
          ),
        if (!cancellation)
          Text(
            '${eventLabel(widget.event!['kind'] as String)} - original PKR ${widget.event!['amount']} on ${widget.event!['effective_date']}\n${widget.event!['payer'] ?? ''} to ${widget.event!['payee'] ?? ''}',
          ),
        if (!cancellation && !quoteCorrection)
          SwitchListTile(
            title: const Text('Replace with corrected entry'),
            subtitle: const Text(
              'Turn off only to explicitly void an incorrect entry.',
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
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        TextField(
          controller: date,
          enabled: request == null && reviewed == null && !earnings,
          decoration: InputDecoration(
            labelText: cancellation
                ? 'Cancellation effective date (YYYY-MM-DD)'
                : 'Corrected effective date (YYYY-MM-DD)',
          ),
        ),
        if (!cancellation && replace) ...[
          TextField(
            controller: amount,
            enabled: request == null && reviewed == null,
            decoration: InputDecoration(
              labelText: quoteCorrection
                  ? 'Corrected agreed quote'
                  : 'Corrected amount',
            ),
          ),
          if (quoteCorrection)
            TextField(
              controller: commission,
              enabled: request == null && reviewed == null,
              decoration: const InputDecoration(
                labelText: 'Corrected brokerage value (existing method)',
              ),
            ),
          for (var n = 0; n < allocations.length; n++)
            TextField(
              controller: allocations[n],
              enabled: request == null && reviewed == null,
              decoration: InputDecoration(
                labelText:
                    'Allocation ${n + 1} amount - ${originalAllocations[n]['component'] ?? 'cash / credit'}',
              ),
            ),
        ],
        for (final e in dependents)
          CheckboxListTile(
            title: Text(
              'Reverse dependent ${eventLabel(e['kind'] as String)} - PKR ${e['amount']} on ${e['effective_date']}',
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
          Text(
            '${consignments[n]['customer_name']} - original charge PKR ${consignments[n]['customer_charge']}',
          ),
          TextField(
            controller: fees[n],
            enabled: request == null && reviewed == null,
            decoration: const InputDecoration(
              labelText: 'Agreed cancellation charge',
            ),
          ),
          TextField(
            controller: brokerFees[n],
            enabled:
                request == null &&
                reviewed == null &&
                consignments[n]['broker_id'] != null,
            decoration: const InputDecoration(
              labelText: 'Broker share within cancellation charge',
            ),
          ),
        ],
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
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
            child: const Text('Review correction'),
          )
        else ...[
          Text(
            'Reason: ${reviewed!['reason']}\n${cancellation ? 'Cancellation effective date: ${reviewed!['effective_date']}' : 'Explicit dependent reversals: $unwind\n${replace ? 'Replacement PKR ${amount.text} on ${date.text}' : 'Void original entry; no replacement'}'}',
          ),
          if (cancellation)
            for (var n = 0; n < fees.length; n++)
              Text(
                'Charge PKR ${fees[n].text}; broker PKR ${brokerFees[n].text}; owner PKR ${AllocationTotals.decimal(Money.parse(fees[n].text).paisa - Money.parse(brokerFees[n].text).paisa)}',
              ),
          FilledButton(
            onPressed: busy || conflict ? null : confirm,
            child: Text(
              busy
                  ? 'Confirming...'
                  : request == null
                  ? 'Confirm reviewed correction'
                  : 'Retry reviewed correction',
            ),
          ),
          if (request == null)
            TextButton(
              onPressed: () => setState(() => reviewed = null),
              child: const Text('Edit review'),
            ),
        ],
      ],
    ),
  );
}
