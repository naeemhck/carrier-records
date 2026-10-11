import 'money.dart';

enum QuoteMode {
  deducted('DEDUCTED'),
  added('ADDED');

  const QuoteMode(this.key);
  final String key;
}

sealed class Commission {
  const Commission();
  Money calculate(Money quote);
  bool get isZero;
}

final class FixedCommission extends Commission {
  final Money amount;
  FixedCommission(this.amount) {
    if (amount.isNegative) throw ArgumentError('Commission cannot be negative');
  }
  @override
  Money calculate(Money quote) => amount;
  @override
  bool get isZero => amount == Money.zero;
}

final class PercentageCommission extends Commission {
  final Percentage rate;
  const PercentageCommission(this.rate);
  @override
  Money calculate(Money quote) => rate.applyTo(quote);
  @override
  bool get isZero => rate.basisPoints == 0;
}

/// Client preview only. Persisted values are recomputed by PostgreSQL.
final class Quote {
  final Money quotedAmount;
  final QuoteMode mode;
  final Commission method;
  final bool hasBroker;
  final Money commission;
  final Money customerCharge;
  final Money ownerEntitlement;

  Quote._(
    this.quotedAmount,
    this.mode,
    this.method,
    this.hasBroker,
    this.commission,
    this.customerCharge,
    this.ownerEntitlement,
  );

  factory Quote.calculate({
    required Money amount,
    required QuoteMode mode,
    required Commission commission,
    required bool hasBroker,
  }) {
    if (amount.isNegative) throw ArgumentError('Quote cannot be negative');
    if (!hasBroker && !commission.isZero) {
      throw ArgumentError('Commission requires a broker');
    }
    final earned = commission.calculate(amount);
    if (mode == QuoteMode.deducted && earned.compareTo(amount) > 0) {
      throw ArgumentError('Deducted commission exceeds quote');
    }
    final customer = mode == QuoteMode.added ? amount + earned : amount;
    final owner = mode == QuoteMode.deducted ? amount - earned : amount;
    return Quote._(
      amount,
      mode,
      commission,
      hasBroker,
      earned,
      customer,
      owner,
    );
  }

  Map<String, Object?> toJson() => {
    'quoted_amount': quotedAmount.toJson(),
    'mode': mode.key,
    'method': method is FixedCommission ? 'FIXED' : 'PERCENTAGE',
    'commission_value': switch (method) {
      FixedCommission(:final amount) => amount.toJson(),
      PercentageCommission(:final rate) => rate.toJson(),
    },
    'has_broker': hasBroker,
    'commission': commission.toJson(),
    'customer_charge': customerCharge.toJson(),
    'owner_entitlement': ownerEntitlement.toJson(),
  };
}
