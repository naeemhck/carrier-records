import '../../core/domain/money.dart';
import '../../core/domain/business_date.dart';
import '../finance/payment_model.dart';

enum ExpenseFunding {
  personal('PERSONAL_FUNDS', 'Personal funds advanced'),
  self('SELF_FUNDED_COST', 'Payer personally bears this cost'),
  held('HELD_TRIP_FUNDS', 'Held trip funds');

  const ExpenseFunding(this.key, this.label);
  final String key, label;
}

/// Every offset/source is explicit; an allocation is not another expense.
Map<String, dynamic> expensePayload({
  required String vehicle,
  String? trip,
  required String office,
  required String category,
  required String date,
  required String amount,
  required String payer,
  required String bearer,
  required String owner,
  required ExpenseFunding funding,
  required String reason,
  required bool agreed,
  required List<Map<String, dynamic>> allocations,
  bool earningsRecognized = true,
  String? availableOwner,
}) {
  BusinessDate.parse(date);
  final cost = Money.parse(amount);
  if (cost.paisa <= 0 || reason.trim().isEmpty) {
    throw const FormatException('Enter a positive amount and notes.');
  }
  if (funding == ExpenseFunding.self && payer != bearer ||
      funding == ExpenseFunding.personal && payer == bearer ||
      funding == ExpenseFunding.held && trip == null) {
    throw const FormatException(
      'Review payer, cost bearer and funding source.',
    );
  }
  final offset =
      trip != null &&
      earningsRecognized &&
      bearer == owner &&
      funding != ExpenseFunding.self;
  if (offset && !agreed) {
    throw const FormatException('Confirm the agreed owner settlement offset.');
  }
  final offsets = AllocationTotals.sum(
    allocations
        .where((a) => a['component'] == 'OFFSET')
        .map((a) => a['amount'] as String)
        .toList(),
  );
  final cash = AllocationTotals.sum(
    allocations
        .where((a) => a['component'] == 'CASH')
        .map((a) => a['amount'] as String)
        .toList(),
  );
  if (offsets !=
          (offset
              ? (availableOwner == null
                    ? BigInt.from(cost.paisa)
                    : BigInt.from(cost.paisa) < BigInt.parse(availableOwner)
                    ? BigInt.from(cost.paisa)
                    : BigInt.parse(availableOwner))
              : BigInt.zero) ||
      cash !=
          (funding == ExpenseFunding.held
              ? BigInt.from(cost.paisa)
              : BigInt.zero)) {
    throw const FormatException(
      'Allocate the exact offset and held-funds spending separately.',
    );
  }
  return {
    'vehicle_id': vehicle,
    'trip_id': trip,
    'office_id': office,
    'category_id': category,
    'effective_date': date,
    'amount': cost.toString(),
    'payer_id': payer,
    'cost_bearer_id': bearer,
    'funding_source': funding.key,
    'reason': reason.trim(),
    'allocations': allocations,
    'offset_confirmed': agreed,
  };
}
