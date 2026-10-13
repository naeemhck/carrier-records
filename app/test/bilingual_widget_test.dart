import 'package:carrier_records/app/bilingual.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('original 554 semantic keys and English wording remain stable', () {
    final baseline = L10n.values.take(554)
        .map((entry) => '${entry.key}\u0000${entry.en}').join('\n');
    expect(sha256.convert(utf8.encode(baseline)).toString(),
        '1097229ad60e19dea0873f36dc35f8dc5ff74e73846c54be6a20776c7bc7cb33');
  });
  test('owned catalogue preserves placeholders and Latin digits', () {
    expect(L10n.values.length, greaterThanOrEqualTo(554));
    expect(
      L10n.values.map((value) => value.key).toSet().length,
      L10n.values.length,
    );
    final placeholders = RegExp(r'\{[0-9]+\}');
    for (final value in L10n.values) {
      expect(value.en, isNotEmpty, reason: value.key);
      expect(value.ur, isNotEmpty, reason: value.key);
      final english =
          placeholders
              .allMatches(value.en)
              .map((match) => match.group(0))
              .toList()
            ..sort();
      final urdu =
          placeholders
              .allMatches(value.ur)
              .map((match) => match.group(0))
              .toList()
            ..sort();
      expect(urdu, english, reason: value.key);
      expect(RegExp('[۰-۹٠-٩]').hasMatch(value.ur), isFalse, reason: value.key);
    }
  });
  test('typed interpolation preserves opaque data and Latin digits', () {
    const phrase = Bilingual('probe', 'Trip {0}: {1}', 'ٹرپ {0}: {1}');
    final value = phrase.withValues(['TRP-000001', 'PKR 125,000.00']);
    expect(value.en, 'Trip TRP-000001: PKR 125,000.00');
    expect(value.ur, contains('TRP-000001'));
    expect(value.ur, contains('PKR 125,000.00'));
    expect(RegExp('[۰-۹٠-٩]').hasMatch(value.ur), isFalse);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('bilingual labels wrap at width $width without global RTL', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const BilingualText(L10n.accountInstruction),
                  FilledButton(
                    onPressed: () {},
                    child: const BilingualText(L10n.save),
                  ),
                  const Row(children: [BilingualCaption(L10n.vehicle)]),
                  const TextField(
                    decoration: InputDecoration(
                      label: BilingualCaption(L10n.username),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(L10n.save.en), findsOneWidget);
      expect(find.text(L10n.save.ur), findsOneWidget);
      final english = tester.widget<Text>(
        find.text(L10n.accountInstruction.en),
      );
      final urdu = tester.widget<Text>(find.text(L10n.accountInstruction.ur));
      expect(english.textDirection, TextDirection.ltr);
      expect(urdu.textDirection, TextDirection.rtl);
      expect(
        Directionality.of(tester.element(find.byType(Scaffold))),
        TextDirection.ltr,
      );
    });
  }
}
