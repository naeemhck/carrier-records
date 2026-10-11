import 'package:carrier_records/features/finance/payment_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cash and identified credit exactly equal payment', () {
    final t = AllocationTotals(['0.01', '100.00'], [], ['20.00']);
    t.validate('120.01', false);
    expect(AllocationTotals.decimal(t.cash), '100.01');
    expect(() => t.validate('120.02', false), throwsFormatException);
  });
  test('credit application is a separately reviewed non-cash component', () {
    final t = AllocationTotals([], ['20000.00'], []);
    t.validate('20000.00', true);
    expect(t.cash, BigInt.zero);
    expect(() => t.validate('20000.00', false), throwsFormatException);
  });
  test('wide allocation review sums remain exact', () {
    final t = AllocationTotals(['9999999999999999.99', '0.01'], [], []);
    expect(AllocationTotals.decimal(t.cash), '10000000000000000.00');
    expect(
      () => t.validate('9999999999999999.99', false),
      throwsFormatException,
    );
  });
  test('extra decimals and nonpositive allocations rejected', () {
    for (final input in ['0.00', '-1.00', '1.001']) {
      expect(() => AllocationTotals([input], [], []), throwsFormatException);
    }
  });
}
