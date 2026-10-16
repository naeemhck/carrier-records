import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/core/domain/money.dart';
import 'package:carrier_records/features/reports/authorized_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money delegates to existing exact grouping and never changes canonical values', () {
    for (final value in [
      '0.00',
      '100000.00',
      '-1234567890123456789.09',
      '9007199254740993.01',
    ]) {
      expect(displayMoney(value), displayValue('MONEY', value));
    }
    final money = Money.parse('100000.00');
    expect(displayMoney(money), 'PKR 100,000.00');
    expect(money.toString(), '100000.00');
    expect(() => displayMoney(1.1), throwsFormatException);
    expect(() => displayMoney('1.001'), throwsFormatException);
  });
  test('count metadata allows only exact integers and reports fractional contracts', () {
    for (final pair in [
      ('1.00', '1'),
      ('100000.00', '100000'),
      ('-2.00', '-2'),
      ('9007199254740993.00', '9007199254740993'),
    ]) {
      expect(displayCount(pair.$1), pair.$2);
    }
    expect(displayField('MONEY', '1.00'), 'PKR 1.00');
    expect(displayField('TEXT', '1.00'), '1.00');
    expect(() => displayCount('1.01'), throwsFormatException);
    expect(() => displayCount(1.5), throwsFormatException);
    expect(displayField('INTEGER', '1.01'), contains('Invalid count: 1.01'));
  });
  testWidgets(
    'grouped amount and count remain distinct and raw inputs unchanged',
    (tester) async {
      final controller = TextEditingController(text: '100000.00');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: Scaffold(
            body: Column(
              children: [
                const KarvaanAmount(
                  label: L10n.moneyNavigation,
                  value: '100000.00',
                ),
                BilingualText(
                  L10n.carCount04a594.withValues([displayCount('1.00')]),
                ),
                TextField(controller: controller),
              ],
            ),
          ),
        ),
      );
      expect(find.text('PKR 100,000.00'), findsOneWidget);
      expect(controller.text, '100000.00');
      expect(find.textContaining('Car count: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
