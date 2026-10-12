import 'package:carrier_records/core/domain/money.dart';
import 'package:carrier_records/features/finance/payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AT-17 web preserves adjacent paisa above JavaScript safe integers', () {
    final value = Money.parse('90071992547409.93');
    expect(value.paisa, BigInt.parse('9007199254740993'));
    expect(value.toJson(), '90071992547409.93');
    expect((value + Money.parse('0.01')).toJson(), '90071992547409.94');
    expect((value - Money.parse('0.01')).toJson(), '90071992547409.92');
    expect((-value).toJson(), '-90071992547409.93');
    expect(value, isNot(Money.parse('90071992547409.92')));
  });

  test('AT-17 full numeric range keeps exact sums and rejects overflow', () {
    final maximum = Money.parse('9999999999999999.99');
    expect(maximum.toJson(), '9999999999999999.99');
    expect(Percentage.parse('100').applyTo(maximum), maximum);
    expect(() => maximum + Money.parse('0.01'), throwsRangeError);
    expect(() => -maximum - Money.parse('0.01'), throwsRangeError);
    final totals = AllocationTotals(['90071992547409.93', '0.01'], [], []);
    totals.validate('90071992547409.94', false);
    expect(
      () => totals.validate('90071992547409.93', false),
      throwsFormatException,
    );
  });
}
