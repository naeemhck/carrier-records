import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:carrier_records/features/finance/payment_workspace.dart';

import 'gui_trip_detail_test.dart' show DetailFixture;
import 'payment_workspace_test.dart'
    show PaymentTrips, PaymentMasters, PaymentsFake, tripId;

import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_typography.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_workspace_test.dart' show ReportsFake;
import 'trip_workspace_test.dart' show FakeTrips, FakeMasters;
import 'text_layout_qa_test.dart' show captureTextQa;

void main() {
  test('one shared scale including tabular numeric roles', () {
    final theme = KarvaanDesign.theme().textTheme;
    expect(theme.displaySmall!.fontSize, 30);
    expect(theme.titleLarge!.fontSize, 22);
    expect(theme.titleMedium!.fontSize, 16);
    expect(theme.bodyMedium!.fontSize, 13);
    expect(theme.bodySmall!.fontSize, 12);
    expect(theme.labelSmall!.fontSize, 11);
    for (final style in [
      theme.displaySmall,
      theme.headlineSmall,
      theme.bodyMedium,
    ]) {
      expect(style!.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });
  testWidgets('bilingual labels do not inherit toolbar no-wrap clipping', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: Scaffold(
          body: DefaultTextStyle(
            style: KarvaanTypography.screenTitle,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            child: const SizedBox(
              width: 180,
              child: BilingualText(L10n.outputsAndPresets),
            ),
          ),
        ),
      ),
    );
    for (final phrase in [
      L10n.outputsAndPresets.en,
      L10n.outputsAndPresets.ur,
    ]) {
      final text = t.widget<Text>(find.text(phrase));
      expect(text.softWrap, isTrue);
      expect(text.overflow, TextOverflow.clip);
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('quiet action captions retain the action foreground contrast', (
    t,
  ) async {
    final theme = KarvaanDesign.theme();
    await t.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: FilledButton(
            onPressed: () {},
            child: const BilingualCaption(L10n.signIn),
          ),
        ),
      ),
    );
    for (final phrase in [L10n.signIn.en, L10n.signIn.ur]) {
      final paragraph = t.renderObject<RenderParagraph>(find.text(phrase));
      expect(paragraph.text.style!.color, theme.colorScheme.onPrimary);
    }
  });
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('trip hero preserves separate quote amounts $width/$scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final repo = DetailFixture();
        await t.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: capture,
                child: TripDetail(
                  repository: repo,
                  id: 'synthetic-trip',
                  canReturn: (_) => false,
                  onEdit: (_) async {},
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final metrics = t
            .widgetList<KarvaanMetric>(find.byType(KarvaanMetric))
            .toList();
        expect(metrics.where((m) => m.hero).length, 1);
        final hero = metrics.singleWhere((m) => m.hero);
        expect(hero.formattedValue, 'PKR 100,000.00');
        expect(
          metrics.any((m) => m.formattedValue == 'PKR 95,000.00' && !m.hero),
          isTrue,
        );
        expect(
          metrics.any((m) => m.formattedValue == 'PKR 5,000.00' && !m.hero),
          isTrue,
        );
        final target = find.byKey(const ValueKey('trip-total-customer_charge'));
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        expect(find.text(hero.label.en), findsOneWidget);
        expect(find.text(hero.label.ur), findsOneWidget);
        final number = find.descendant(
          of: target,
          matching: find.text(hero.formattedValue),
        );
        expect(
          t.widget<Text>(number).softWrap,
          isFalse,
          reason: 'A decimal amount must never wrap individual digits',
        );
        final horizontal = find.descendant(
          of: target,
          matching: find.byType(SingleChildScrollView),
        );
        final strip = t.widget<SingleChildScrollView>(horizontal);
        if (width == 360 && scale == 2) {
          expect(strip.controller!.position.maxScrollExtent, greaterThan(0));
          await t.drag(horizontal, const Offset(-300, 0));
          await t.pumpAndSettle();
          expect(
            strip.controller!.offset,
            greaterThan(0),
            reason: 'Full unshrunk amount remains reachable at 200%',
          );
        }
        await t.runAsync(
          () => captureTextQa(t, capture, 'trip-hierarchy-$width-$scale'),
        );
        expect(repo.details, 1);
        expect(repo.requests, isEmpty);
        expect(t.takeException(), isNull);
      });
      testWidgets('Money explicit total alone is display sized $width/$scale', (
        t,
      ) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final finance = PaymentsFake();
        await t.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: capture,
                child: PaymentWorkspace(
                  finance: finance,
                  trips: PaymentTrips(),
                  masters: PaymentMasters(),
                  offices: const [
                    {'id': 'office', 'name': 'Synthetic Karachi'},
                  ],
                  initialTrip: tripId,
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final target = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.style?.fontSize == KarvaanTypography.display,
        );
        // ListView builds lazily: at narrow 200% the total is below the fold.
        await t.scrollUntilVisible(
          target,
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
        final hero = t.widget<TextField>(target);
        final fields = t.widgetList<TextField>(find.byType(TextField));
        await t.ensureVisible(target);
        await t.enterText(target, '12345.67');
        await t.pumpAndSettle();
        expect(hero.controller!.text, '12345.67');
        expect(hero.textDirection, TextDirection.ltr);
        expect(
          fields
              .where((f) => f.style?.fontSize == KarvaanTypography.display)
              .length,
          1,
        );
        expect(
          t
              .widgetList<KarvaanMetric>(find.byType(KarvaanMetric))
              .where((m) => m.hero),
          isEmpty,
        );
        await t.runAsync(
          () => captureTextQa(t, capture, 'money-hierarchy-$width-$scale'),
        );
        expect(finance.requests, isEmpty);
        expect(t.takeException(), isNull);
      });
      testWidgets('monthly hierarchy paired labels $width/$scale', (t) async {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final capture = GlobalKey();
        final fake = ReportsFake();
        await t.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: capture,
                child: ReportWorkspace(
                  reports: fake,
                  trips: FakeTrips(),
                  masters: FakeMasters(),
                  offices: const [],
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final metrics = t.widgetList<KarvaanMetric>(find.byType(KarvaanMetric));
        expect(metrics.where((m) => m.hero).length, 1);
        final hero = metrics.singleWhere((m) => m.hero);
        expect(hero.label.en, contains('Vehicle operating profit'));
        expect(hero.formattedValue, 'PKR 0.00');
        expect(
          metrics
              .singleWhere((m) => m.label.en.startsWith('Owner profit'))
              .formattedValue,
          'PKR 85,000.00',
        );
        expect(
          metrics
              .singleWhere((m) => m.label.en.startsWith('Owner settlement due'))
              .formattedValue,
          'PKR 95,000.00',
        );
        expect(fake.offsets, [0]);
        final target = find.byKey(
          const ValueKey('report-hero-operating_profit'),
        );
        await t.ensureVisible(target);
        await t.pumpAndSettle();
        final value = find.descendant(
          of: target,
          matching: find.text(hero.formattedValue),
        );
        final label = find.descendant(
          of: target,
          matching: find.text(hero.label.en),
        );
        expect(
          t.widget<Text>(value).style!.fontSize,
          KarvaanTypography.display,
        );
        expect(t.getTopLeft(value).dy, lessThan(t.getTopLeft(label).dy));
        final urdu = find.descendant(
          of: target,
          matching: find.text(hero.label.ur),
        );
        final text = t.widget<Text>(urdu);
        expect(text.textDirection, TextDirection.rtl);
        expect(
          text.style!.fontSize,
          greaterThanOrEqualTo(KarvaanTypography.urduMinimum),
        );
        final box = t.getSize(urdu);
        final natural = TextPainter(
          text: TextSpan(text: text.data, style: text.style),
          textDirection: TextDirection.rtl,
          textScaler: TextScaler.linear(scale),
        )..layout(maxWidth: box.width);
        expect(box.height, greaterThanOrEqualTo(natural.height - .1));
        natural.dispose();
        await t.runAsync(
          () => captureTextQa(t, capture, 'monthly-hierarchy-$width-$scale'),
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
