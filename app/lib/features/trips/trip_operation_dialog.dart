import 'package:carrier_records/app/bilingual.dart';

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
            for (final h in history)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BilingualText(
                        L10n.auditEventIdentity.withValues([
                          ownedMessage(h['action']),
                          h['actor_name'],
                          h['recorded_at'],
                        ]),
                      ),
                      Text((h['reason'] ?? '').toString()),
                      for (final k in (h['after'] as Map).keys)
                        if ((h['before'] as Map)[k] != (h['after'] as Map)[k])
                          BilingualText(
                            L10n.labelValuesbeea2b.withValues([
                              k,
                              ownedMessage(LifecycleStrings.before),
                              (h['before'] as Map)[k] ?? '',
                              ownedMessage(LifecycleStrings.after),
                              (h['after'] as Map)[k],
                            ]),
                          ),
                    ],
                  ),
                ),
              ),
            Row(
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
