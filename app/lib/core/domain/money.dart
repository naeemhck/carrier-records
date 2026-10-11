/// Exact PKR value, bounded by PostgreSQL NUMERIC(18,2).
final class Money implements Comparable<Money> {
  static const maxPaisa = 999999999999999999;
  static final zero = Money.fromPaisa(0);
  final int paisa;

  Money.fromPaisa(this.paisa) {
    if (paisa < -maxPaisa || paisa > maxPaisa) {
      throw RangeError('Money exceeds NUMERIC(18,2)');
    }
  }

  factory Money.parse(String value) {
    if (!RegExp(r'^-?[0-9]+(?:\.[0-9]{1,2})?$').hasMatch(value)) {
      throw FormatException(
        'Expected a decimal string with at most two places',
      );
    }
    final negative = value.startsWith('-');
    final parts = (negative ? value.substring(1) : value).split('.');
    var amount = BigInt.parse(parts[0]) * BigInt.from(100);
    if (parts.length == 2) {
      amount += BigInt.parse(parts[1].padRight(2, '0'));
    }
    if (negative) amount = -amount;
    if (amount.abs() > BigInt.from(maxPaisa)) {
      throw RangeError('Money exceeds NUMERIC(18,2)');
    }
    return Money.fromPaisa(amount.toInt());
  }

  factory Money.fromJson(Object? value) {
    if (value is! String) {
      throw FormatException('Money must be a decimal string');
    }
    return Money.parse(value);
  }

  Money operator +(Money other) => Money.fromPaisa(paisa + other.paisa);
  Money operator -(Money other) => Money.fromPaisa(paisa - other.paisa);
  Money operator -() => Money.fromPaisa(-paisa);
  bool get isNegative => paisa < 0;
  String toJson() => toString();

  @override
  String toString() {
    final absolute = paisa.abs();
    return '${paisa < 0 ? '-' : ''}${absolute ~/ 100}.${(absolute % 100).toString().padLeft(2, '0')}';
  }

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);
  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;
  @override
  int get hashCode => paisa.hashCode;
}

/// Two-decimal percentage, 0.00 through 100.00.
final class Percentage {
  final int basisPoints;
  Percentage._(this.basisPoints);

  factory Percentage.parse(String value) {
    final parsed = Money.parse(value);
    if (parsed.paisa < 0 || parsed.paisa > 10000) {
      throw RangeError('Percentage must be between 0 and 100');
    }
    return Percentage._(parsed.paisa);
  }

  Money applyTo(Money quote) {
    if (quote.isNegative) throw ArgumentError('Quote cannot be negative');
    // BigInt avoids overflow before the division, including maximum quotes.
    final numerator = BigInt.from(quote.paisa) * BigInt.from(basisPoints);
    return Money.fromPaisa(
      ((numerator + BigInt.from(5000)) ~/ BigInt.from(10000)).toInt(),
    );
  }

  String toJson() => Money.fromPaisa(basisPoints).toJson();
}
