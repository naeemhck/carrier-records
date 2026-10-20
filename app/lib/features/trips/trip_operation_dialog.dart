import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_components.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../masters/master_repository.dart';
import 'trip_draft.dart';
import 'trip_lifecycle.dart';
import 'trip_repository.dart';
import 'trip_workspace.dart';

class TripOperationDialog extends StatefulWidget {
  const TripOperationDialog({
    super.key,
    required this.repository,
    required this.trip,
    required this.action,
    this.consignment,
  });
  final TripRepository repository;
  final Map<String, dynamic> trip;
  final TripAction action;
  final String? consignment;
  @override
  State<TripOperationDialog> createState() => _TripOperationDialogState();
}

class _TripOperationDialogState extends State<TripOperationDialog> {
  final date = TextEditingController(),
      reason = TextEditingController(),
      notes = TextEditingController(),
      overlapReason = TextEditingController();
  Map<String, dynamic>? warning, pendingPayload;
  String? reviewDate, pendingBase, requestId, error;
  bool reviewed = false,
      overlapApproved = false,
      busy = false,
      posting = false,
      conflict = false;

  bool get inputsValid {
    try {
      lifecyclePayload(
        widget.action,
        widget.trip,
        reason: reason.text,
        date: date.text,
        notes: notes.text,
        consignment: widget.consignment,
      );
      return true;
    } on FormatException {
      return false;
    }
  }

  void dismiss() {
    if (posting) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    final field = widget.action.dateField;
    date.text = field == null
        ? ''
        : widget.action == TripAction.dispatch ||
              widget.action == TripAction.arrive
        ? DateTime.now()
              .toUtc()
              .add(const Duration(hours: 5))
              .toIso8601String()
              .substring(0, 10)
        : widget.trip[field] as String;
    notes.text = widget.trip['notes'] as String;
  }

  @override
  void dispose() {
    date.dispose();
    reason.dispose();
    notes.dispose();
    overlapReason.dispose();
    super.dispose();
  }

  Future<void> reviewDispatch() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = lifecyclePayload(
        widget.action,
        widget.trip,
        reason: reason.text,
        date: date.text,
      );
      final d = TripDraft.fromDetail(widget.trip)
        ..planned = p['dispatch_date'] as String;
      final response = await widget.repository.overlap(d);
      if (mounted) {
        setState(() {
          warning = response;
          pendingPayload = null;
          pendingBase = null;
          requestId = null;
          reviewDate = date.text.trim();
          reviewed = false;
          overlapApproved = false;
          overlapReason.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = tripError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      posting = true;
      error = null;
    });
    try {
      final base = lifecyclePayload(
        widget.action,
        widget.trip,
        reason: reason.text,
        date: date.text,
        notes: notes.text,
        consignment: widget.consignment,
      );
      final signature = jsonEncode({
        ...base,
        'overlap_reason': overlapReason.text.trim(),
      });
      if (pendingBase != signature || pendingPayload == null) {
        if (widget.action == TripAction.dispatch &&
            (!reviewed ||
                reviewDate != date.text.trim() ||
                warning == null ||
                (warning!['requires_confirmation'] == true &&
                    (!overlapApproved || overlapReason.text.trim().isEmpty)))) {
          throw const FormatException(TripStrings.overlap);
        }
        pendingPayload = {
          ...base,
          if (widget.action == TripAction.dispatch) ...{
            'review_token': warning!['review_token'],
            'overlap_confirmed': warning!['requires_confirmation'] == true,
            'overlap_reason': warning!['requires_confirmation'] == true
                ? overlapReason.text.trim()
                : null,
          },
        };
        pendingBase = signature;
        requestId = newRecordId();
      }
      final result = await widget.repository.operate(
        widget.action.key,
        widget.trip['id'] as String,
        requestId!,
        widget.trip['version'] as int,
        pendingPayload!,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (e is PostgrestException && ['PT409', '40001'].contains(e.code)) {
        conflict = true;
      }
      if (mounted) {
        setState(
          () => error = e is PostgrestException
              ? LifecycleStrings.errorMessages[e.message] ?? tripError(e)
              : tripError(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          posting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): dismiss},
    child: Focus(
      autofocus: true,
      skipTraversal: true,
      child: PopScope(
        canPop: !posting,
        child: AlertDialog(
          scrollable: true,
          title: BilingualOwnedText(widget.action.label),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BilingualText(
                    L10n.labelValuescd55a9.withValues([
                      widget.trip['trip_number'],
                      widget.trip['state'],
                    ]),
                  ),
                  if (widget.action.dateField != null)
                    TextField(
                      key: const Key('operation-date'),
                      controller: date,
                      enabled: !busy,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(
                            L10n.actualBusinessDateYYYYMMDD,
                          ),
                        ),
                      ),
                      onChanged: (_) => setState(() {
                        reviewed = false;
                        warning = null;
                        reviewDate = null;
                      }),
                    ),
                  TextField(
                    key: const Key('operation-reason'),
                    controller: reason,
                    enabled: !busy,
                    maxLength: 500,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(
                          L10n.reasonForRecordingOrCorrectingThisOperation,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (widget.action == TripAction.correctOperation)
                    TextField(
                      key: const Key('operation-notes'),
                      controller: notes,
                      enabled: !busy,
                      maxLength: 2000,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualOwnedCaption(
                            TripStrings.labels['notes'],
                          ),
                        ),
                      ),
                    ),
                  const BilingualText(
                    L10n.operationalCompletionAndFinancialSettlementAreIndependentArrivalCreates,
                  ),
                  if (widget.action == TripAction.correctDispatch ||
                      widget.action == TripAction.correctArrival)
                    const BilingualText(
                      L10n.confirmedFareChangesAndDependentFinancialCorrectionsNeedThe,
                    ),
                  if (widget.action == TripAction.cancelConsignment)
                    const BilingualText(
                      L10n.cancelledConsignmentsStayOnTheTripAndAreNot,
                    ),
                  if (widget.action == TripAction.dispatch) ...[
                    const BilingualText(
                      L10n.enterAnActualDateAndReasonReviewDispatchEarnings,
                    ),
                    const BilingualText(
                      L10n.dispatchRecognizesCustomerDebtOwnerFareShareAndBrokerage,
                    ),
                    for (final k in [
                      'customer_charge',
                      'commission',
                      'owner_entitlement',
                    ])
                      BilingualText(
                        moneyLabel([
                          ownedMessage(TripStrings.labels[k]),
                          (widget.trip['totals'] as Map)[k],
                        ]),
                      ),
                    TextButton(
                      onPressed: busy || !inputsValid ? null : reviewDispatch,
                      child: const BilingualCaption(
                        L10n.reviewDispatchEarnings,
                      ),
                    ),
                    if (warning != null) ...[
                      if (warning!['requires_confirmation'] == true) ...[
                        const BilingualText(
                          L10n.anotherDispatchedJourneyUsesThisVehicleReviewAndConfirm,
                        ),
                        for (final t in warning!['visible_trips'] as List)
                          BilingualText(
                            L10n.labelValuescd55a9.withValues([
                              t['trip_number'],
                              t['dispatch_date'],
                            ]),
                          ),
                        if (warning!['restricted_conflict'] == true)
                          const BilingualText(
                            L10n.anActiveJourneyOutsideYourOfficeScopeAlsoUses,
                          ),
                        CheckboxListTile(
                          value: overlapApproved,
                          onChanged: busy
                              ? null
                              : (v) => setState(() => overlapApproved = v!),
                          title: const BilingualText(
                            L10n.iReviewedThisVehicleOverlap,
                          ),
                        ),
                        TextField(
                          controller: overlapReason,
                          enabled: !busy,
                          maxLength: 500,
                          decoration: bilingualDecoration(
                            context,
                            InputDecoration(
                              label: BilingualCaption(
                                L10n.reasonForAllowingTheOverlap,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      CheckboxListTile(
                        value: reviewed,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => reviewed = v!),
                        title: const BilingualText(
                          L10n.iReviewedTheActualDateAndTheFareBrokerage,
                        ),
                      ),
                    ],
                  ],
                  if (error != null) BilingualOwnedText(error!),
                  if (busy) ...[
                    BilingualText(
                      (posting
                          ? L10n.waitingForTheServerTransactionToCommit
                          : L10n.checkingTheDispatchReview),
                    ),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: posting ? null : dismiss,
              child: const BilingualCaption(L10n.cancel),
            ),
            FilledButton(
              onPressed:
                  busy ||
                      conflict ||
                      !inputsValid ||
                      (widget.action == TripAction.dispatch &&
                          (!reviewed ||
                              (warning?['requires_confirmation'] == true &&
                                  (!overlapApproved ||
                                      overlapReason.text.trim().isEmpty))))
                  ? null
                  : submit,
              child: const BilingualCaption(L10n.confirmOperation),
            ),
          ],
        ),
      ),
    ),
  );
}

class TripHistory extends StatefulWidget {
  const TripHistory({super.key, required this.repository, required this.id});
  final TripRepository repository;
  final String id;
  @override
  State<TripHistory> createState() => _TripHistoryState();
}

/// Internal audit fields that carry no meaning for staff; never rendered.
const _historyHiddenFields = {'version', 'totals'};

/// Human action label for the history feed. Known backend action names resolve
/// through the catalogue; raw SCREAMING_CASE codes are prettified instead of
/// being shown verbatim.
Bilingual _historyActionLabel(Object? action) {
  final resolved = ownedMessage(action);
  if (resolved.key != 'unresolved.presentation') return resolved;
  return Bilingual.data(_prettifyKey(action.toString()));
}

String _prettifyKey(String key) => key
    .replaceAll('_', ' ')
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Human field label for the history feed. Raw internal field names never
/// reach the UI; unknown fields fall back to a prettified label.
Bilingual _historyFieldLabel(String key) => switch (key) {
  'dispatch_date' => L10n.historyFieldDispatchDate,
  'arrival_date' => L10n.historyFieldArrivalDate,
  'planned_dispatch_date' => L10n.historyFieldPlannedDate,
  'state' => L10n.historyFieldStatus,
  'load_kind' => L10n.historyFieldLoad,
  'car_count' => L10n.historyFieldCars,
  'driver_name' => L10n.historyFieldDriver,
  'notes' => L10n.historyFieldNotes,
  _ => Bilingual.data(_prettifyKey(key)),
};

/// Keys whose value actually changed in a history event, excluding the
/// hidden internal fields.
List<String> _historyChangedKeys(Map<String, dynamic> h) => [
  for (final k in (h['after'] as Map).keys)
    if ((h['before'] as Map)[k] != (h['after'] as Map)[k] &&
        !_historyHiddenFields.contains(k))
      k as String,
];

/// Timeline dot kind for a history action (plan §5.4 colors).
TimelineKind _historyKind(Object? action) {
  final a = (action ?? '').toString().toUpperCase();
  if (a.contains('CREATE')) return TimelineKind.create;
  if (a.contains('DISPATCH') || a.contains('ARRIV')) {
    return TimelineKind.dispatch;
  }
  if (const [
    'PAYMENT',
    'CHARGE',
    'COMMISSION',
    'SETTLEMENT',
    'RECEIPT',
    'REFUND',
    'ALLOCATION',
    'CREDIT',
    'EXPENSE',
  ].any(a.contains)) {
    return TimelineKind.money;
  }
  return TimelineKind.edit;
}

/// Human value for the history feed: state/load codes become their labels,
/// timestamps become short date-times, nulls become "None".
Object _historyFieldValue(String key, Object? value) {
  if (value == null) return ownedMessage(TripStrings.none);
  final text = value.toString();
  return switch (key) {
    'state' => tripStateLabel(text),
    'load_kind' => loadKindLabel(text),
    _ when RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T').hasMatch(text) =>
      displayTimestamp(text),
    _ => text,
  };
}

class _TripHistoryState extends State<TripHistory> {
  int offset = 0;
  late Future<List<Map<String, dynamic>>> rows;
  @override
  void initState() {
    super.initState();
    rows = widget.repository.history(widget.id);
  }

  void reload(int start) {
    setState(() {
      offset = start;
      rows = widget.repository.history(widget.id, offset: offset);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.history),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: BilingualOwnedText(tripError(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final history = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (history.isEmpty)
              const BilingualText(L10n.noRecordedHistoryInThisScope),
            if (history.isNotEmpty)
              TimelineFeed(
                entries: [
                  for (final h in history)
                    TimelineEntry(
                      kind: _historyKind(h['action']),
                      title: _historyActionLabel(h['action']),
                      actor: (h['actor_name'] ?? '').toString(),
                      timestamp: displayTimestamp(h['recorded_at']),
                      note: (h['reason'] ?? '').toString().isNotEmpty
                          ? Bilingual.data((h['reason'] ?? '').toString())
                          : _historyChangedKeys(h).isEmpty
                          ? L10n.historyNoChanges
                          : null,
                      details: [
                        for (final k in _historyChangedKeys(h))
                          BilingualText(
                            L10n.labelValuesbeea2b.withValues([
                              _historyFieldLabel(k),
                              ownedMessage(LifecycleStrings.before),
                              _historyFieldValue(k, (h['before'] as Map)[k]),
                              ownedMessage(LifecycleStrings.after),
                              _historyFieldValue(k, (h['after'] as Map)[k]),
                            ]),
                          ),
                      ],
                    ),
                ],
              ),
            // Wrap: bilingual buttons overflow a fixed Row at 200%.
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: offset == 0 ? null : () => reload(offset - 50),
                  child: const BilingualCaption(L10n.previous),
                ),
                TextButton(
                  onPressed: history.length < 50
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
  );
}
