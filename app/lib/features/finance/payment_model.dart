import '../../core/domain/money.dart';

enum PaymentAction {
  refundFunding(
    'REFUND_FUNDING',
    'Personally fund a customer refund',
    'CUSTOMER_ADVANCE_CREDIT',
    null,
  ),
  cancellationRecovery(
    'RECOVERY_RECEIPT',
    'Receive owner / broker recovery',
    'RECOVERY',
    null,
  ),
  receipt('CUSTOMER_RECEIPT', 'Customer receipt', 'CUSTOMER_RECEIVABLE', null),
  owner(
    'OWNER_SETTLEMENT',
    'Owner settlement',
    'OWNER_PAYABLE',
    'CUSTODY_RECEIVABLE',
  ),
  commission(
    'COMMISSION_SETTLEMENT',
    'Commission retained / paid',
    'BROKER_COMMISSION_PAYABLE',
    'CUSTODY_RECEIVABLE',
  ),
  transfer(
    'CUSTODY_TRANSFER',
    'Held-funds transfer',
    null,
    'CUSTODY_RECEIVABLE',
  ),
  funding(
    'PERSONAL_FUNDING',
    'Personally funded owner payment',
    'OWNER_PAYABLE',
    null,
  ),
  recovery(
    'FUNDING_RECOVERY',
    'Recover personal funding',
    'TRIP_FUNDING_PAYABLE',
    'CUSTODY_RECEIVABLE',
  ),
  advance('ADVANCE', 'Customer advance', null, null),
  application(
    'ADVANCE_APPLICATION',
    'Apply customer credit',
    'CUSTOMER_RECEIVABLE',
    'CUSTOMER_ADVANCE_CREDIT',
  ),
  refund(
    'REFUND',
    'Refund unused customer credit',
    'CUSTOMER_ADVANCE_CREDIT',
    'CUSTODY_RECEIVABLE',
  );

  const PaymentAction(this.key, this.label, this.target, this.source);
  final String key, label;
  final String? target, source;
  bool get offset => this == application;
}

/// Exact review totals, deliberately independent of visual table columns.
final class AllocationTotals {
  AllocationTotals(
    List<String> cash,
    List<String> offsets,
    List<String> credits,
  ) : cash = sum(cash),
      offsets = sum(offsets),
      credits = sum(credits);
  final BigInt cash, offsets, credits;
  static BigInt sum(List<String> values) => values.fold(BigInt.zero, (n, v) {
    final amount = Money.parse(v);
    if (amount.paisa <= BigInt.zero) {
      throw const FormatException('Allocation must be positive.');
    }
    return n + amount.paisa;
  });
  void validate(String amount, bool offset) {
    final entered = Money.parse(amount);
    if (entered.paisa <= BigInt.zero ||
        entered.paisa != cash + offsets + credits ||
        (offset
            ? cash != BigInt.zero || credits != BigInt.zero
            : offsets != BigInt.zero)) {
      throw const FormatException(
        'Total must equal explicit allocations and credit remainder.',
      );
    }
  }

  static String decimal(BigInt value) =>
      '${value.isNegative ? '-' : ''}${value.abs() ~/ BigInt.from(100)}.${(value.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';
}
