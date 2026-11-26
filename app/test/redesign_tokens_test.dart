import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the redesign tokens (plan §2) and the testable bilingual rules
/// (plan §3) so later phases cannot silently drift from the spec. The
/// 2026-11-26 GUI refresh (owner directive) superseded the neutrals, the
/// stacked bilingual pair and the Urdu display face; those pins follow it.
void main() {
  test('color tokens match plan section 2.1 and the GUI refresh neutrals', () {
    expect(KarvaanDesign.primary, const Color(0xFF1E40AF));
    expect(KarvaanDesign.primaryBright, const Color(0xFF3B82F6));
    expect(KarvaanDesign.money, const Color(0xFF15803D));
    expect(KarvaanDesign.accent, KarvaanDesign.money);
    expect(KarvaanDesign.moneySurface, const Color(0xFFF0FDF4));
    expect(KarvaanDesign.attention, const Color(0xFFD97706));
    expect(KarvaanDesign.destructive, const Color(0xFFDC2626));
    expect(KarvaanDesign.background, const Color(0xFFF5F6F8));
    expect(KarvaanDesign.surface, const Color(0xFFFFFFFF));
    expect(KarvaanDesign.headingInk, const Color(0xFF0F172A));
    expect(KarvaanDesign.ink, const Color(0xFF1F2937));
    expect(KarvaanDesign.muted, const Color(0xFFEEF1F5));
    expect(KarvaanDesign.secondary, const Color(0xFF475569));
    expect(KarvaanDesign.borderColor, const Color(0xFFE3E7ED));
  });

  test('theme carries the tokens, families and radius system', () {
    final theme = KarvaanDesign.theme();
    expect(theme.scaffoldBackgroundColor, KarvaanDesign.background);
    expect(theme.colorScheme.primary, KarvaanDesign.primary);
    expect(theme.colorScheme.error, KarvaanDesign.destructive);
    expect(
      theme.textTheme.bodyMedium!.fontFamily,
      KarvaanTypography.latinFamily,
    );
    final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(10));
  });

  test('type scale matches plan section 2.2 with the KPI cap', () {
    final theme = KarvaanDesign.theme().textTheme;
    expect(theme.displaySmall!.fontSize, 28);
    expect(theme.displaySmall!.height, 36 / 28);
    // The KPI figure step: the largest a routine number ever gets.
    expect(theme.headlineSmall!.fontSize, 20);
    expect(theme.headlineSmall!.height, 26 / 20);
    expect(theme.titleMedium!.fontSize, 18);
    expect(theme.bodyMedium!.fontSize, 14);
    expect(theme.bodySmall!.fontSize, 12);
  });

  test('rule 3: one short date-time format, never raw ISO', () {
    expect(
      displayTimestamp('2026-10-15T23:27:26.539984+00:00'),
      '2026-10-15 23:27',
    );
    expect(displayTimestamp('2026-10-15'), '2026-10-15');
  });

  test('rule 6: numerals stay Latin in counts and money', () {
    expect(displayCount('100000'), '100000');
    final money = displayMoney('100000.00');
    expect(money, contains('100,000.00'));
    expect(RegExp(r'[٠-٩]').hasMatch(money), isFalse);
    expect(RegExp(r'[۰-۹]').hasMatch(money), isFalse);
  });

  test('rule 7: known mistranslations stay corrected', () {
    expect(L10n.selectHistoricalOwner.ur, 'سابقہ مالک منتخب کریں');
    expect(ownedMessage('ڈیبٹ کی رند رقم').ur, 'گول ڈیبٹ رقم');
  });

  testWidgets('rule 1: English leads and its Urdu companion follows on the '
      'same line, dropping beneath it only when the pair does not fit', (
    t,
  ) async {
    Future<(Rect, Rect)> pairAt(double width) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const BilingualText(L10n.customerOutstanding),
              ),
            ),
          ),
        ),
      );
      return (
        t.getRect(find.text(L10n.customerOutstanding.en)),
        t.getRect(find.text(L10n.customerOutstanding.ur)),
      );
    }

    final (en, ur) = await pairAt(600);
    expect(ur.left, greaterThanOrEqualTo(en.right));
    expect(ur.top, lessThan(en.bottom));
    final (narrowEn, narrowUr) = await pairAt(150);
    expect(narrowUr.top, greaterThanOrEqualTo(narrowEn.bottom));
  });

  testWidgets('Urdu headings and body share one face at its natural leading', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: Scaffold(
          body: Column(
            children: [
              BilingualText(
                L10n.dashboard,
                style: KarvaanTypography.textTheme.titleMedium,
              ),
              const BilingualText(L10n.customerOutstanding),
            ],
          ),
        ),
      ),
    );
    final headingUrdu = t.widget<Text>(find.text(L10n.dashboard.ur));
    expect(headingUrdu.style!.fontFamily, KarvaanTypography.urduDisplayFamily);
    final bodyUrdu = t.widget<Text>(find.text(L10n.customerOutstanding.ur));
    expect(bodyUrdu.style!.fontFamily, KarvaanTypography.urduBodyFamily);
    expect(
      KarvaanTypography.urduDisplayFamily,
      KarvaanTypography.urduBodyFamily,
    );
    // No forced leading: a line box shorter than the script's natural
    // ascent and descent lets its marks be cut off at a panel edge.
    expect(headingUrdu.style!.height, isNull);
    expect(bodyUrdu.style!.height, isNull);
  });

  testWidgets('rules 2 and 5: inline line keeps the value once, LTR, '
      'with punctuation attached to the label', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BilingualInlineLine(
            L10n.brokerLine,
            value: Bilingual.data('Synthetic broker'),
          ),
        ),
      ),
    );
    final rich = t.widget<Text>(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );
    expect(rich.textDirection, TextDirection.ltr);
    final plain = rich.textSpan!.toPlainText();
    expect('Synthetic broker'.allMatches(plain).length, 1);
    expect(
      plain,
      '${L10n.brokerLine.en} / ${L10n.brokerLine.ur}\u200E: Synthetic broker',
    );
  });

  testWidgets('figures render in the tabular figure face', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KarvaanFigure('PKR 100,000.00', style: TextStyle(fontSize: 20)),
        ),
      ),
    );
    final text = t.widget<Text>(find.text('PKR 100,000.00'));
    expect(text.style!.fontFamily, KarvaanTypography.figureFamily);
    expect(
      text.style!.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('status chip colors follow the plan for every state', (t) async {
    Color bgOf(String state) {
      final box = t.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text(tripStateLabel(state).en),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (box.decoration as BoxDecoration).color!;
    }

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (final state in [
                'DRAFT',
                'DISPATCHED',
                'ARRIVED',
                'CANCELLED',
              ])
                TripStatusBadge(state),
            ],
          ),
        ),
      ),
    );
    expect(bgOf('DRAFT'), KarvaanDesign.muted);
    expect(bgOf('DISPATCHED'), KarvaanDesign.primarySurface);
    expect(bgOf('ARRIVED'), KarvaanDesign.moneySurface);
    expect(bgOf('CANCELLED'), KarvaanDesign.surface);
  });
}
