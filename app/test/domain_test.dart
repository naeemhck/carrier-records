import 'package:carrier_records/core/domain/business_date.dart';
import 'package:carrier_records/core/domain/money.dart';
import 'package:carrier_records/core/domain/quote.dart';
import 'package:carrier_records/core/domain/record_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AT-01/02 quote bases keep commission and owner share separate', () {
    for (final mode in QuoteMode.values) {
      final quote = Quote.calculate(
        amount: Money.parse('100000'),
        mode: mode,
        commission: FixedCommission(Money.parse('5000')),
        hasBroker: true,
      );
      expect(
        quote.customerCharge.toJson(),
        mode == QuoteMode.deducted ? '100000.00' : '105000.00',
      );
      expect(
        quote.ownerEntitlement.toJson(),
        mode == QuoteMode.deducted ? '95000.00' : '100000.00',
      );
      expect(quote.commission.toJson(), '5000.00');
      expect(quote.ownerEntitlement + quote.commission, quote.customerCharge);
    }
  });
  test('AT-03 percentages use quoted basis and half-up paisa rounding', () {
    for (final mode in QuoteMode.values) {
      final quote = Quote.calculate(
        amount: Money.parse('100000'),
        mode: mode,
        commission: PercentageCommission(Percentage.parse('5')),
        hasBroker: true,
      );
      expect(quote.commission, Money.parse('5000'));
    }
    expect(
      Percentage.parse('50').applyTo(Money.parse('0.01')),
      Money.parse('0.01'),
    );
    expect(Percentage.parse('49.99').applyTo(Money.parse('0.01')), Money.zero);
    expect(
      Percentage.parse('100').applyTo(Money.parse('9999999999999999.99')),
      Money.parse('9999999999999999.99'),
    );
    expect(() => Percentage.parse('100.01'), throwsRangeError);
    expect(() => Percentage.parse('-0.01'), throwsRangeError);
    expect(
      () => Quote.calculate(
        amount: Money.parse('1'),
        mode: QuoteMode.deducted,
        commission: FixedCommission(Money.parse('1.01')),
        hasBroker: true,
      ),
      throwsArgumentError,
    );
    expect(
      () => Quote.calculate(
        amount: Money.parse('0'),
        mode: QuoteMode.added,
        commission: PercentageCommission(Percentage.parse('1')),
        hasBroker: false,
      ),
      throwsArgumentError,
    );
  });
  test('AT-17 money interfaces reject lossy and ambiguous values', () {
    expect(Money.parse('0.10') + Money.parse('0.20'), Money.parse('0.30'));
    expect(Money.parse('-0.01').toJson(), '-0.01');
    expect(Money.parse('-0.00').toJson(), '0.00');
    expect(Money.parse('00012.3').toJson(), '12.30');
    for (final value in [
      '1.001',
      '1.000',
      '1e2',
      'NaN',
      ' 1',
      '+1',
      '1,000',
      '1.',
      '.1',
      '',
    ]) {
      expect(() => Money.parse(value), throwsFormatException, reason: value);
    }
    expect(() => Money.fromJson(0.1), throwsFormatException);
    expect(() => Money.fromJson(null), throwsFormatException);
    expect(() => Money.parse('10000000000000000'), throwsRangeError);
    expect(
      () => Money.parse('9999999999999999.99') + Money.parse('0.01'),
      throwsRangeError,
    );
    expect(
      () => Quote.calculate(
        amount: Money.parse('9999999999999999.99'),
        mode: QuoteMode.added,
        commission: FixedCommission(Money.parse('0.01')),
        hasBroker: true,
      ),
      throwsRangeError,
    );
  });
  test(
    'business dates validate actual calendar days without time conversion',
    () {
      expect(BusinessDate.parse('2024-02-29').toJson(), '2024-02-29');
      expect(BusinessDate.parse('0001-01-01').year, 1);
      for (final value in [
        '2025-02-29',
        '2026-04-31',
        '2026-13-01',
        '2026-00-01',
        '2026-01-00',
        '0000-01-01',
        '11/10/2026',
        '2026-1-01',
        '2026-01-01T00:00:00Z',
      ]) {
        expect(
          () => BusinessDate.parse(value),
          throwsFormatException,
          reason: value,
        );
      }
      expect(
        BusinessDate.parse('2026-01-01')
            .compareTo(BusinessDate.parse('2026-01-02')),
        lessThan(0),
      );
    },
  );
  test('command versions distinguish create, update and retry identity', () {
    final id = RecordId('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
    expect(
      CommandEnvelope(
        requestId: id,
        expectedVersion: 0,
        payload: {},
      ).toJson()['request_id'],
      id.value,
    );
    expect(() => RecordId('not-a-uuid'), throwsFormatException);
    expect(
      () => CommandEnvelope(requestId: id, expectedVersion: -1, payload: {}),
      throwsRangeError,
    );
    expect(
      () => RecordContext(id: id, businessId: id, version: 0),
      throwsRangeError,
    );
  });
}
