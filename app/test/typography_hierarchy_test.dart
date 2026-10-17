import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_typography.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:flutter/material.dart';
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
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
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
