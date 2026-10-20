import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('original 554 semantic keys and English wording remain stable', () {
    const corrected = 'Preview only — not an issued document.';
    expect(
      L10n.previewOnlyNotAnIssuedDocumentFiltersDetermineRecords.en,
      corrected,
    );
    // QA text fixes authorized 2026-10-20 (branch fix/karvaan-qa-text-fixes):
    // plain-words relabeling across the original catalogue. Every original key
    // remains; the digest below pins the newly authorized English wording.
    final baseline = L10n.values
        .take(554)
        .map((entry) {
          final english =
              entry.key ==
                  L10n.previewOnlyNotAnIssuedDocumentFiltersDetermineRecords.key
              ? entry.en.replaceFirst('Preview only —', 'Preview only ?')
              : entry.en;
          return '${entry.key}\u0000$english';
        })
        .join('\n');
    expect(
      sha256.convert(utf8.encode(baseline)).toString(),
      'a560ea975ef0a3f134bef634ce5b109e5262ae8d880ca247d7d3677995d70b5c',
    );
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
