import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import '../../app/karvaan_design.dart';
import '../../app/karvaan_patterns.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/business_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/record_context.dart';
import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import 'financial_repository.dart';
import 'payment_model.dart';

Widget unguardedPayments(Widget child) => child;

/// One nonzero per-trip balance for the balances & custody summary.
class _BalanceLine {
  const _BalanceLine({
    required this.tripId,
    required this.tripNumber,
    required this.purpose,
    required this.partyId,
    required this.display,
  });
  final String tripId, tripNumber, purpose, partyId, display;
}

class PaymentRow {
  PaymentRow(this.trip, this.number, this.claims, this.consignments);
  final String trip, number;
  final List<Map<String, dynamic>> claims, consignments;
  final amount = TextEditingController();
  String? target, source, consignment;
  bool credit = false;
  Map<String, dynamic>? find(String? id) =>
      claims.where((c) => c['line_id'] == id).firstOrNull;
}

/// Explicit allocations across individually authorized trips; no silent netting.
class PaymentWorkspace extends StatefulWidget {
  const PaymentWorkspace({
    super.key,
    required this.finance,
    required this.trips,
    required this.masters,
    required this.offices,
    required this.initialTrip,
    this.guard = unguardedPayments,
  });
  final FinancialCommands finance;
  final TripRepository trips;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final String initialTrip;
  final Widget Function(Widget) guard;
  @override
  State<PaymentWorkspace> createState() => _PaymentWorkspaceState();
}

class _PaymentWorkspaceState extends State<PaymentWorkspace> {
  PaymentAction action = PaymentAction.receipt;
  final date = TextEditingController(),
      amount = TextEditingController(),
      reason = TextEditingController();
  final rows = <PaymentRow>[];
  final balances = <String, Map<String, dynamic>>{};
  final names = <String, String>{};
  String? payer, payee, payerName, payeeName, office, error;
  bool busy = true, conflict = false;
  String? pendingSignature, pendingRequest;
  Map<String, dynamic>? reviewed;
  @override
  void initState() {
    super.initState();
    date.text = DateTime.now().toIso8601String().substring(0, 10);
    office = widget.offices.firstOrNull?['id'] as String?;
    load(widget.initialTrip);
  }

  @override
  void dispose() {
    for (final c in [date, amount, reason, ...rows.map((r) => r.amount)]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> load(String trip) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final detail = await widget.trips.detail(trip);
      final ledger = await widget.finance.trip(RecordId(trip));
      if (!mounted) return;
      setState(() {
        final owner = detail['owner_snapshot'] as Map?;
        if (detail['owner_id'] is String && owner?['display_name'] is String) {
          names[detail['owner_id'] as String] =
              owner!['display_name'] as String;
        }
        rows.add(
          PaymentRow(
            trip,
            detail['trip_number'] as String,
            (ledger['claims'] as List)
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList(),
            (detail['consignments'] as List)
                .map((c) => Map<String, dynamic>.from(c as Map))
                .toList(),
          ),
        );
        balances[trip] = ledger;
        reviewed = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  String message(Object e) => e is FormatException
      ? e.message
      : e is PostgrestException
      ? (e.code == 'PT409'
            ? 'Balances or permissions changed. Reload and review before confirming.'
            : const {
                    'ALLOCATION_MISMATCH':
                        'Total must equal allocations and credit remainder.',
                    'INSUFFICIENT_SOURCE': 'Held funds are insufficient. Choose available funds or declare personal funding.',
                    'INSUFFICIENT_SOURCE_OR_CLAIM':
                        'Available source or claim is insufficient.',
                    'FORBIDDEN': 'Your current office permissions do not allow this payment.',
                    'CLAIM_EXHAUSTED': 'The claim has already been consumed.',
                    'INVALID_SOURCE': 'Select eligible funds from this trip and the actual payer.',
                    'INVALID_CLAIM':
                        'Select a claim belonging to the identified party.',
                    'CUSTOMER_TRIP_REQUIRED':
                        'Select this customer’s trip or consignment.',
                    'PAYMENT_PRECEDES_CLAIM': 'Payment predates earnings. Record a customer advance instead.',
                    'PAYMENT_PRECEDES_SOURCE':
                        'Payment predates its funding source.',
                    'ACTIVE_RECIPIENT_OR_OFFICE_REQUIRED':
                        'Select an active recipient and recording office.',
                  }[e.message] ??
                  'Payment was not confirmed. Input is retained; check the selections or retry.')
      : 'Payment was not confirmed. Input is retained. Retry the same reviewed request.';

  Future<void> chooseParty(bool isPayer) async {
    final result = await showDialog<MasterRecord>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (_) => widget.guard(_PartyPicker(widget.masters)),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (isPayer) {
        payer = result.id;
        payerName = result.label;
      } else {
        payee = result.id;
        payeeName = result.label;
      }
      reviewed = null;
      for (final r in rows) {
        r.target = null;
        r.source = null;
        r.consignment = null;
      }
    });
  }

  Future<void> addTrip() async {
    final trip = await showDialog<String>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (_) => widget.guard(_TripPicker(widget.trips)),
    );
    if (mounted && trip != null) await load(trip);
  }

  List<Map<String, dynamic>> eligible(PaymentRow row, bool source) {
    final purpose = source ? action.source : action.target;
    final party =
        source ||
            action == PaymentAction.receipt ||
            action == PaymentAction.cancellationRecovery ||
            action == PaymentAction.application
        ? payer
        : payee;
    return row.claims
        .where(
          (c) =>
              (action == PaymentAction.cancellationRecovery
                  ? c['direction'] == 'RECOVERY'
                  : c['direction'] != 'RECOVERY' &&
                        c['account_purpose'] == purpose) &&
              c['party_id'] == party,
        )
        .toList();
  }

  Map<String, dynamic> payload() {
    if (payer == null || payee == null || office == null) {
      throw const FormatException(
        'Choose payer, recipient and recording office.',
      );
    }
    final businessDate = BusinessDate.parse(date.text.trim());
    if (reason.text.trim().isEmpty || reason.text.trim().length > 500) {
      throw const FormatException('Enter a reason up to 500 characters.');
    }
    final allocations = <Map<String, dynamic>>[],
        credits = <Map<String, dynamic>>[];
    final cash = <String>[], offsets = <String>[], creditValues = <String>[];
    final used = <String, BigInt>{};
    for (final row in rows) {
      if (row.amount.text.trim().isEmpty) continue;
      final value = Money.parse(row.amount.text.trim());
      if (value.paisa <= BigInt.zero) {
        throw const FormatException('Allocation must be positive.');
      }
      final item = <String, dynamic>{'amount': value.toString()};
      final credit = action == PaymentAction.receipt && row.credit;
      if (action == PaymentAction.advance || credit) {
        if (!row.consignments.any(
          (c) =>
              c['customer_id'] == payer &&
              (row.consignment == null || c['id'] == row.consignment),
        )) {
          throw const FormatException(
            'Credit must belong to this customer and trip.',
          );
        }
        item.addAll({'trip_id': row.trip, 'consignment_id': row.consignment});
      } else if (action.target != null) {
        final target = row.find(row.target);
        if (target == null || !eligible(row, false).contains(target)) {
          throw const FormatException('Select an eligible target claim.');
        }
        item.addAll({
          'target_line_id': target['line_id'],
          'target_version': target['version'],
        });
      }
      if (action.source != null) {
        final source = row.find(row.source);
        if (source == null || !eligible(row, true).contains(source)) {
          throw const FormatException('Select an eligible funding source.');
        }
        item.addAll({
          'source_line_id': source['line_id'],
          'source_version': source['version'],
        });
        if (action == PaymentAction.application &&
            source['consignment_id'] != null &&
            source['consignment_id'] !=
                row.find(row.target)?['consignment_id']) {
          throw const FormatException(
            'This credit is restricted to its original consignment.',
          );
        }
      }
      for (final id in [
        item['target_line_id'],
        item['source_line_id'],
      ].whereType<String>()) {
        used[id] = (used[id] ?? BigInt.zero) + value.paisa;
        if (used[id]! > Money.fromJson(row.find(id)!['remaining']).paisa) {
          throw const FormatException(
            'Allocated amount exceeds the remaining claim or source.',
          );
        }
      }
      if (credit) {
        credits.add(item);
        creditValues.add(value.toString());
      } else {
        allocations.add(item);
        (action.offset ? offsets : cash).add(value.toString());
      }
    }
    AllocationTotals(
      cash,
      offsets,
      creditValues,
    ).validate(amount.text.trim(), action.offset);
    if (allocations.length + credits.length > 100) {
      throw const FormatException('At most 100 allocations per payment.');
    }
    return {
      'payer_id': payer,
      'payee_id': payee,
      'office_id': office,
      'effective_date': businessDate.toString(),
      'amount': Money.parse(amount.text.trim()).toString(),
      'reason': reason.text.trim(),
      'allocations': allocations,
      if (credits.isNotEmpty) 'credits': credits,
    };
  }

  void review() {
    try {
      final p = payload();
      setState(() {
        reviewed = p;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = message(e);
        reviewed = null;
      });
    }
  }

  Future<void> confirm() async {
    final p = reviewed!;
    final signature = jsonEncode({'kind': action.key, 'payload': p});
    if (pendingSignature != null && pendingSignature != signature) {
      setState(() {
        error = 'An earlier request may have committed. Retry that request or reload balances before changing it.';
      });
      return;
    }
    pendingSignature = signature;
    pendingRequest ??= newRecordId();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.finance.post(action.key, pendingRequest!, p);
      if (!mounted) return;
      pendingSignature = null;
      pendingRequest = null;
      amount.clear();
      reason.clear();
      for (final r in rows) {
        r.amount.clear();
        r.target = null;
        r.source = null;
      }
      final reloaded = await refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BilingualText(
            (reloaded
                ? L10n.paymentConfirmedBalancesReloaded
                : L10n.paymentConfirmedBalanceReloadFailedReloadBeforeAnotherPayment),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          conflict = e is PostgrestException && e.code == 'PT409';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<bool> refresh() async {
    setState(() {
      busy = true;
      reviewed = null;
    });
    try {
      final loaded = <String, Map<String, dynamic>>{};
      for (final id in rows.map((r) => r.trip).toSet()) {
        loaded[id] = await widget.finance.trip(RecordId(id));
      }
      if (!mounted) return false;
      setState(() {
        for (final row in rows) {
          row.claims
            ..clear()
            ..addAll(
              (loaded[row.trip]!['claims'] as List).map(
                (c) => Map<String, dynamic>.from(c as Map),
              ),
            );
          row.target = null;
          row.source = null;
        }
        balances
          ..clear()
          ..addAll(loaded);
        pendingSignature = null;
        pendingRequest = null;
        conflict = false;
        error = null;
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          error = message(e);
          conflict = true;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  /// Presentation-only sums of the already-fetched per-trip ledgers.
  /// Nothing here posts, allocates, or reinterprets backend figures.
  BigInt _heldPaisa() {
    var total = BigInt.zero;
    for (final entry in balances.entries) {
      for (final b in entry.value['balances'] as List) {
        if (b['account_purpose'] == 'CUSTODY_RECEIVABLE') {
          total += LedgerAmount.fromJson(b['balance'] as String).paisa;
        }
      }
    }
    return total;
  }

  /// One paper-trail line per nonzero balance: money-state chip, party and
  /// trip, and the figure deep-linking to that trip's balances.
  List<Widget> _balanceLines() {
    final lines = <_BalanceLine>[];
    for (final entry in balances.entries) {
      final number = rows.firstWhere((r) => r.trip == entry.key).number;
      for (final b in entry.value['balances'] as List) {
        final purpose = b['account_purpose'] as String;
        final paisa = LedgerAmount.fromJson(b['balance'] as String).paisa;
        if (paisa == BigInt.zero) continue;
        lines.add(
          _BalanceLine(
            tripId: entry.key,
            tripNumber: number,
            purpose: purpose,
            partyId: b['party_id'] as String,
            display: displayBalance(purpose, b['balance'] as String),
          ),
        );
      }
    }
    lines.sort(
      (a, b) => accountPurposeRank(a.purpose).compareTo(
        accountPurposeRank(b.purpose),
      ),
    );
    return [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              MoneyStateChip(line.purpose),
              const SizedBox(width: 8),
              Expanded(
                child: BilingualText(
                  Bilingual.data(
                    '${partyLabel(line.partyId)} · ${line.tripNumber}',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              PaperTrailAmount(
                formatted: line.display,
                onTap: busy || pendingRequest != null
                    ? () {}
                    : () => _focusTrip(line.tripId),
                semanticLabel:
                    '${accountPurposeLabel(line.purpose).en} '
                    '${partyLabel(line.partyId)} ${line.tripNumber}: '
                    '${line.display}',
              ),
            ],
          ),
        ),
    ];
  }

  /// Paper-trail target: rescope this workspace to the single trip whose
  /// ledger the figure came from. Its balances card below is the record.
  Future<void> _focusTrip(String tripId) async {
    for (final r in rows) {
      r.amount.dispose();
    }
    setState(() {
      rows.clear();
      balances.clear();
      reviewed = null;
      pendingSignature = null;
      pendingRequest = null;
      conflict = false;
      error = null;
    });
    await load(tripId);
  }

  /// Balances & custody summary: the intermediary-held figure leads as the
  /// one hero amount per viewport; per-party balances follow with paper-trail
  /// links to their source trips. Summary-first, tabular figures.
  Widget _balancesSummary() {
    // Don't flash a zero hero / "no records" before the first ledger load.
    if (busy && balances.isEmpty) return const SizedBox.shrink();
    return KarvaanSection(
      title: L10n.partyClaimsAndHeldMoney,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KarvaanMetric(
            hero: true,
            label: L10n.intermediaryHeldMoney,
            formattedValue: displayMoney(
              AllocationTotals.decimal(_heldPaisa()),
            ),
          ),
          const SizedBox(height: 12),
          ..._balanceLines(),
          if (balances.isEmpty && !busy)
            const BilingualText(L10n.noRecordsFound),
        ],
      ),
    );
  }

  Bilingual totals() {
    try {
      final values = rows
          .where((r) => r.amount.text.trim().isNotEmpty)
          .toList();
      final t = AllocationTotals(
        values
            .where((r) => !r.credit && !action.offset)
            .map((r) => r.amount.text)
            .toList(),
        values.where((r) => action.offset).map((r) => r.amount.text).toList(),
        values.where((r) => r.credit).map((r) => r.amount.text).toList(),
      );
      return moneyMessage(
        L10n.cashAllocatedPKRNonCashCreditOffsetPKRCredit,
        [
          AllocationTotals.decimal(t.cash),
          AllocationTotals.decimal(t.offsets),
          AllocationTotals.decimal(t.credits),
        ],
        {0, 1, 2},
      );
    } catch (_) {
      return L10n.enterPositiveAmountsWithAtMostTwoDecimalPlaces;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
        title: const BilingualText(L10n.paymentsAndAllocations),
        actions: [
          IconButton(
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh),
            tooltip: L10n.reloadBalancesAccessibility,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BilingualText(
            L10n.permittedTripsOnlyNotACompletePartyOrBusiness,
          ),
          const BilingualText(
            L10n.collectionsHeldFundsOwnerSettlementAndEarningsAreSeparate,
          ),
          _balancesSummary(),
          if (busy) const LinearProgressIndicator(),
          KarvaanChoiceField<PaymentAction>(
            initialValue: action,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.action)),
            ),
            items: PaymentAction.values
                .map(
                  (a) => DropdownMenuItem(
                    value: a,
                    child: BilingualOwnedText(a.label),
                  ),
                )
                .toList(),
            onChanged: busy || pendingRequest != null
                ? null
                : (v) => setState(() {
                    action = v!;
                    reviewed = null;
                    for (final r in rows) {
                      r.target = null;
                      r.source = null;
                      r.credit = false;
                    }
                  }),
          ),
          Wrap(
            spacing: 16,
            children: [
              TextButton(
                onPressed: busy || pendingRequest != null
                    ? null
                    : () => chooseParty(true),
                child: BilingualCaption(
                  L10n.payer.withValues([payerName ?? 'Choose']),
                ),
              ),
              TextButton(
                onPressed: busy || pendingRequest != null
                    ? null
                    : () => chooseParty(false),
                child: BilingualCaption(
                  L10n.recipient.withValues([payeeName ?? 'Choose']),
                ),
              ),
            ],
          ),
          KarvaanChoiceField<String>(
            initialValue: office,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.recordingOffice)),
            ),
            items: widget.offices
                .map(
                  (o) => DropdownMenuItem(
                    value: o['id'] as String,
                    child: Text(o['name'] as String),
                  ),
                )
                .toList(),
            onChanged: busy || pendingRequest != null
                ? null
                : (v) => setState(() {
                    office = v;
                    reviewed = null;
                  }),
          ),
          for (final field in [
            (date, 'Payment date (YYYY-MM-DD)'),
            (amount, 'Total amount (PKR)'),
            (reason, 'Reason / reference'),
          ])
            TextField(
              controller: field.$1,
              style: identical(field.$1, amount)
                  ? Theme.of(context).textTheme.displaySmall
                  : Theme.of(context).textTheme.bodyMedium,
              textDirection: identical(field.$1, amount)
                  ? TextDirection.ltr
                  : null,
              enabled: !busy && pendingRequest == null,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualOwnedCaption(field.$2)),
              ),
              onChanged: (_) => setState(() {
                reviewed = null;
              }),
            ),
          BilingualText(totals()),
          for (final entry in balances.entries)
            KarvaanSection(
              title: Bilingual.data(
                rows.firstWhere((r) => r.trip == entry.key).number,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final b in entry.value['balances'] as List)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MoneyStateChip(b['account_purpose'] as String),
                        KarvaanAmount(
                          label: Bilingual.data(
                            partyLabel(b['party_id'] as String),
                          ),
                          value: displayBalance(
                            b['account_purpose'] as String,
                            b['balance'] as String,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilingualText(L10n.allocation.withValues([row.number])),
                    if (action == PaymentAction.receipt)
                      CheckboxListTile(
                        title: const BilingualText(L10n.identifiedExcessCredit),
                        value: row.credit,
                        onChanged: busy || pendingRequest != null
                            ? null
                            : (v) => setState(() {
                                row.credit = v!;
                                row.target = null;
                                reviewed = null;
                              }),
                      ),
                    if (action == PaymentAction.advance || row.credit)
                      KarvaanChoiceField<String>(
                        key: ValueKey(
                          '${rows.indexOf(row)}-consignment-$payer',
                        ),
                        initialValue: row.consignment,
                        decoration: bilingualDecoration(
                          context,
                          InputDecoration(
                            label: BilingualCaption(L10n.creditBelongsTo),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: BilingualText(L10n.thisCustomerSTrip),
                          ),
                          for (final c in row.consignments.where(
                            (c) => c['customer_id'] == payer,
                          ))
                            DropdownMenuItem(
                              value: c['id'] as String,
                              child: BilingualText(
                                L10n.cars.withValues([
                                  c['customer_name'],
                                  c['car_count'],
                                ]),
                              ),
                            ),
                        ],
                        onChanged: busy || pendingRequest != null
                            ? null
                            : (v) => setState(() {
                                row.consignment = v;
                                reviewed = null;
                              }),
                      ),
                    if (action.target != null && !row.credit)
                      claimPicker(row, false),
                    if (action.source != null) claimPicker(row, true),
                    TextField(
                      controller: row.amount,
                      enabled: !busy && pendingRequest == null,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(
                            (action.offset
                                ? L10n.nonCashOffsetPKR
                                : L10n.allocatedAmountPKR),
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        reviewed = null;
                      }),
                    ),
                    for (final id in [
                      row.target,
                      row.source,
                    ].whereType<String>())
                      BilingualText(
                        moneyMessage(
                          L10n.remainingPKRAfterAllocationPKR,
                          [row.find(id)?['remaining'], remaining(row, id)],
                          {0, 1},
                        ),
                      ),
                    TextButton(
                      onPressed: busy || pendingRequest != null
                          ? null
                          : () => setState(() {
                              rows.remove(row);
                              row.amount.dispose();
                              reviewed = null;
                            }),
                      child: const BilingualCaption(L10n.removeAllocation),
                    ),
                  ],
                ),
              ),
            ),
          Wrap(
            children: [
              TextButton(
                onPressed: busy || pendingRequest != null ? null : addTrip,
                child: const BilingualCaption(L10n.addTripAllocation),
              ),
              for (final id in rows.map((r) => r.trip).toSet())
                TextButton(
                  onPressed: busy || pendingRequest != null
                      ? null
                      : () => load(id),
                  child: BilingualCaption(
                    L10n.addAnotherAllocation.withValues([
                      rows.firstWhere((r) => r.trip == id).number,
                    ]),
                  ),
                ),
            ],
          ),
          if (error != null)
            BilingualOwnedText(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (reviewed == null)
            FilledButton(
              onPressed: busy || conflict ? null : review,
              child: const BilingualCaption(L10n.reviewPayment),
            ),
          if (reviewed != null) ...[
            BilingualText(
              moneyMessage(
                L10n.reviewPKR,
                [
                  action.label,
                  date.text,
                  payerName,
                  payeeName,
                  reviewed!['amount'],
                ],
                {4},
              ),
            ),
            const BilingualText(
              L10n.confirmTheAllocationsAndResultingBalancesAboveArrivalAnd,
            ),
            FilledButton(
              onPressed: busy || conflict ? null : confirm,
              child: const BilingualCaption(L10n.confirmPayment),
            ),
            if (pendingRequest == null)
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        reviewed = null;
                      }),
                child: const BilingualCaption(L10n.changeSelections),
              ),
          ],
        ],
      ),
    ),
  );
  String partyLabel(String id) {
    if (id == payer) return payerName ?? 'Payer';
    if (id == payee) return payeeName ?? 'Recipient';
    if (names[id] != null) return names[id]!;
    for (final row in rows) {
      for (final c in row.consignments) {
        if (c['customer_id'] == id) return c['customer_name'] as String;
        if (c['broker_id'] == id) return c['broker_name'] as String;
      }
    }
    return 'Related party';
  }

  String remaining(PaymentRow row, String id) {
    try {
      final original = Money.fromJson(row.find(id)!['remaining']);
      final consumed = rows
          .where((r) => r.target == id || r.source == id)
          .fold(
            BigInt.zero,
            (n, r) =>
                n +
                (r.amount.text.isEmpty
                    ? BigInt.zero
                    : Money.parse(r.amount.text).paisa),
          );
      return AllocationTotals.decimal(original.paisa - consumed);
    } catch (_) {
      return 'Check amount';
    }
  }

  Widget claimPicker(PaymentRow row, bool source) => KarvaanChoiceField<String>(
    key: ValueKey(
      '${rows.indexOf(row)}-$source-${action.key}-$payer-$payee-${row.credit}-${row.claims.hashCode}-${source ? row.source : row.target}',
    ),
    initialValue: source ? row.source : row.target,
    decoration: bilingualDecoration(
      context,
      InputDecoration(
        label: BilingualCaption(
          (source ? L10n.availableSource : L10n.outstandingClaim),
        ),
      ),
    ),
    items: eligible(row, source)
        .map(
          (c) => DropdownMenuItem(
            value: c['line_id'] as String,
            child: BilingualText(
              moneyMessage(
                L10n.pkrd24bdd,
                [
                  accountPurposeLabel(c['account_purpose'] as String),
                  c['effective_date'],
                  c['remaining'],
                ],
                {2},
              ),
            ),
          ),
        )
        .toList(),
    onChanged: busy || pendingRequest != null
        ? null
        : (v) => setState(() {
            if (source) {
              row.source = v;
            } else {
              row.target = v;
            }
            reviewed = null;
          }),
  );
}

/// Bilingual label for each ledger account purpose, from the branch
/// catalogue/glossary — never English-only. Used by money-state chips and
/// picker rows alike.
Bilingual accountPurposeLabel(String key) => switch (key) {
  'CUSTOMER_RECEIVABLE' => L10n.customerOutstanding,
  'CUSTODY_RECEIVABLE' => L10n.heldFunds,
  'OWNER_PAYABLE' => L10n.ownerSettlement,
  'BROKER_COMMISSION_PAYABLE' => L10n.commissionDue,
  'TRIP_FUNDING_PAYABLE' => L10n.personalFundingDue,
  'CUSTOMER_ADVANCE_CREDIT' => L10n.customerCredit,
  'EXPENSE_REIMBURSEMENT_PAYABLE' => L10n.expenseReimbursementDue,
  'PARTY_COST_RECOVERY' => L10n.costRecovery,
  _ => Bilingual.data(key),
};

/// Display order for money states: held funds first (the custody figure the
/// balances view leads with), then receivables, credits, and payables.
int accountPurposeRank(String key) => const {
  'CUSTODY_RECEIVABLE': 0,
  'CUSTOMER_RECEIVABLE': 1,
  'CUSTOMER_ADVANCE_CREDIT': 2,
  'OWNER_PAYABLE': 3,
  'BROKER_COMMISSION_PAYABLE': 4,
  'EXPENSE_REIMBURSEMENT_PAYABLE': 5,
  'TRIP_FUNDING_PAYABLE': 6,
  'PARTY_COST_RECOVERY': 7,
}[key] ?? 99;

/// Money-state chip: stacked bilingual purpose label in the money-green
/// family (blue is reserved for the physical/journey flow). Held funds render
/// filled; every other state renders on the outstanding highlight.
class MoneyStateChip extends StatelessWidget {
  const MoneyStateChip(this.purpose, {super.key});
  final String purpose;
  @override
  Widget build(BuildContext context) {
    final held = purpose == 'CUSTODY_RECEIVABLE';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: held ? KarvaanDesign.accent : KarvaanDesign.moneySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: BilingualText(
          accountPurposeLabel(purpose),
          style: TextStyle(
            color: held ? Colors.white : const Color(0xFF0B5C2E),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String displayBalance(String purpose, String value) {
  final amount = LedgerAmount.fromJson(value).paisa;
  const credits = {
    'OWNER_PAYABLE',
    'BROKER_COMMISSION_PAYABLE',
    'TRIP_FUNDING_PAYABLE',
    'CUSTOMER_ADVANCE_CREDIT',
    'EXPENSE_REIMBURSEMENT_PAYABLE',
  };
  return AllocationTotals.decimal(credits.contains(purpose) ? -amount : amount);
}

class _PartyPicker extends StatefulWidget {
  const _PartyPicker(this.repository);
  final MasterRepository repository;
  @override
  State<_PartyPicker> createState() => _PartyPickerState();
}

class _PartyPickerState extends State<_PartyPicker> {
  String search = '';
  int offset = 0;
  late Future<List<MasterRecord>> page;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    page = widget.repository.list(
      MasterKind.party,
      search: search,
      offset: offset,
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const BilingualText(L10n.chooseParty),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.searchParties)),
            ),
            onSubmitted: (v) => setState(() {
              search = v;
              offset = 0;
              reload();
            }),
          ),
          Expanded(
            child: FutureBuilder<List<MasterRecord>>(
              future: page,
              builder: (context, s) => s.hasError
                  ? const BilingualText(L10n.partyChoicesUnavailable)
                  : !s.hasData
                  ? const Center(child: CircularProgressIndicator())
                  // NOTE: "most-used first" needs a backend change:
                  // list_master_records returns name-ordered pages with no
                  // usage counts. Flagged in docs/karvaan-restructure-phase6.md.
                  : s.data!.isEmpty
                  ? const BilingualText(L10n.noRecordsFound)
                  : ListView(
                      children: [
                        for (final p in s.data!)
                          BilingualListTile(
                            title: Text(p.label),
                            onTap: () => Navigator.pop(context, p),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() {
          offset = offset >= 50 ? offset - 50 : 0;
          reload();
        }),
        child: const BilingualCaption(L10n.previous),
      ),
      TextButton(
        onPressed: () => setState(() {
          offset += 50;
          reload();
        }),
        child: const BilingualCaption(L10n.next),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const BilingualCaption(L10n.close),
      ),
    ],
  );
}

class _TripPicker extends StatefulWidget {
  const _TripPicker(this.repository);
  final TripRepository repository;
  @override
  State<_TripPicker> createState() => _TripPickerState();
}

class _TripPickerState extends State<_TripPicker> {
  String search = '';
  int offset = 0;
  late Future<TripPage> page;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    page = widget.repository.list(search: search, offset: offset);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const BilingualText(L10n.choosePermittedTrip),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.searchTrips)),
            ),
            onSubmitted: (v) => setState(() {
              search = v;
              offset = 0;
              reload();
            }),
          ),
          Expanded(
            child: FutureBuilder<TripPage>(
              future: page,
              builder: (context, s) => s.hasError
                  ? const BilingualText(L10n.tripChoicesUnavailable)
                  : !s.hasData
                  ? const Center(child: CircularProgressIndicator())
                  : s.data!.rows.isEmpty
                  ? const BilingualText(L10n.noRecordsFound)
                  : ListView(
                      children: [
                        BilingualOwnedText(s.data!.scope),
                        for (final t in s.data!.rows)
                          BilingualListTile(
                            title: BilingualText(
                              L10n.labelValuescd55a9.withValues([
                                t['trip_number'],
                                t['registration'],
                              ]),
                            ),
                            onTap: () => Navigator.pop(context, t['id']),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => setState(() {
          offset = offset >= 50 ? offset - 50 : 0;
          reload();
        }),
        child: const BilingualCaption(L10n.previous),
      ),
      TextButton(
        onPressed: () => setState(() {
          offset += 50;
          reload();
        }),
        child: const BilingualCaption(L10n.next),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const BilingualCaption(L10n.close),
      ),
    ],
  );
}
