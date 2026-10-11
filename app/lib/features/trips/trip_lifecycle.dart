import '../../core/domain/business_date.dart';

enum TripAction {
  dispatch('DISPATCH', 'Dispatch', 'can_dispatch', 'dispatch_date'),
  arrive('ARRIVE', 'Record arrival', 'can_arrive', 'arrival_date'),
  correctOperation(
    'CORRECT_OPERATION',
    'Correct operational notes',
    'can_correct_operation',
    null,
  ),
  correctDispatch(
    'CORRECT_DISPATCH_DATE',
    'Correct dispatch date',
    'can_correct_dispatch_date',
    'dispatch_date',
  ),
  correctArrival(
    'CORRECT_ARRIVAL_DATE',
    'Correct arrival date',
    'can_correct_arrival_date',
    'arrival_date',
  ),
  cancelDraft(
    'CANCEL_DRAFT',
    'Cancel unposted draft',
    'can_cancel_draft',
    null,
  ),
  cancelConsignment(
    'CANCEL_CONSIGNMENT',
    'Cancel draft consignment',
    'can_cancel_consignment',
    null,
  );

  const TripAction(this.key, this.label, this.permission, this.dateField);
  final String key, label, permission;
  final String? dateField;
}

class LifecycleStrings {
  static const reason = 'Reason for recording or correcting this operation';
  static const date = 'Actual business date (YYYY-MM-DD)';
  static const dateRequired = 'Enter a valid actual business date.';
  static const reasonRequired = 'Enter a reason of 1 to 500 characters.';
  static const arrivalOrder = 'Arrival cannot precede dispatch.';
  static const invalidCorrection =
      'The corrected date must change the existing value and preserve dispatch/arrival order.';
  static const dispatchReview = 'Review dispatch earnings';
  static const reviewed =
      'I reviewed the actual date and the fare/brokerage amounts';
  static const recognition =
      'Dispatch recognizes customer debt, owner fare share and brokerage together. It records no receipt or owner settlement.';
  static const independent =
      'Operational completion and financial settlement are independent. Arrival creates no receipt or owner payment.';
  static const correction =
      'Confirmed fare changes and dependent financial corrections need the later financial adjustment workflow. Date corrections retain linked reversal/replacement history.';
  static const cancelled =
      'Cancelled consignments stay on the trip and are not delivered or recognized at dispatch.';
  static const pending = 'Waiting for the server transaction to commit...';
  static const success = 'Operation committed. Current server record shown.';
  static const history = 'History';
  static const emptyHistory = 'No recorded history in this scope.';
  static const before = 'Before';
  static const after = 'After';
  static const confirm = 'Confirm operation';
  static const errorMessages = {
    'INVALID_TRANSITION': 'The current trip state does not allow this transition. Close and refresh the trip.',
    'INVALID_ARRIVAL_DATE': arrivalOrder,
    'INVALID_DISPATCH_DATE': invalidCorrection,
    'REASON_REQUIRED': reasonRequired,
    'ACTUAL_DATE_REQUIRED': dateRequired,
    'DISPATCH_NOT_READY':
        'Review the active vehicle, offices and consignments before dispatch.',
    'FINANCIAL_ADJUSTMENT_REQUIRED': 'A dispatched or arrived trip requires an explicit financial adjustment/cancellation plan in the later workflow.',
    'DEPENDENT_SETTLEMENTS': 'Financial or issued-document dependencies require an explicit correction plan. This operation was not committed.',
    'EARNINGS_HISTORY_UNAVAILABLE': 'This record lacks recognized earnings history. Administrator review is required.',
  };
}

Map<String, dynamic> lifecyclePayload(
  TripAction action,
  Map<String, dynamic> trip, {
  required String reason,
  String date = '',
  String notes = '',
  String? consignment,
}) {
  reason = reason.trim();
  date = date.trim();
  if (reason.isEmpty || reason.length > 500) {
    throw const FormatException(LifecycleStrings.reasonRequired);
  }
  if (action.dateField != null) {
    if (date.isEmpty) {
      throw const FormatException(LifecycleStrings.dateRequired);
    }
    BusinessDate.parse(date);
    if (action.dateField == 'arrival_date' &&
        date.compareTo(trip['dispatch_date'] as String) < 0) {
      throw const FormatException(LifecycleStrings.arrivalOrder);
    }
    if ((action == TripAction.correctDispatch ||
            action == TripAction.correctArrival) &&
        date == trip[action.dateField]) {
      throw const FormatException(LifecycleStrings.invalidCorrection);
    }
    if (action == TripAction.correctDispatch &&
        trip['arrival_date'] != null &&
        date.compareTo(trip['arrival_date'] as String) > 0) {
      throw const FormatException(LifecycleStrings.invalidCorrection);
    }
  }
  return {
    'reason': reason,
    if (action.dateField != null) action.dateField!: date,
    if (action == TripAction.correctOperation) 'notes': notes,
    if (action == TripAction.cancelConsignment) 'consignment_id': consignment,
  };
}
