import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_typography.dart';
import 'package:carrier_records/features/backup/backup_workspace.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:carrier_records/features/finance/correction_workspace.dart';
import 'package:carrier_records/features/masters/master_workspace.dart';
import 'package:carrier_records/features/reports/document_workspace.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_workspace_test.dart' show FakeBackup;
import 'correction_workspace_test.dart' show CorrectionsFake;
import 'document_workspace_test.dart' show DocumentFake;
import 'expense_workspace_test.dart'
    show ExpensesFake, ExpenseMasters, PickerFake;
import 'output_workspace_test.dart' show OutputsFake;
import 'payment_workspace_test.dart' show PaymentsFake;
import 'text_layout_qa_test.dart' show TextQaSession, captureTextQa;
import 'trip_workspace_test.dart' show FakeTrips, FakeMasters;

void main() {
  final screens = <String, Widget Function()>{
    'authentication': () => StaffHome(session: TextQaSession()),
    'trips-list': () => TripWorkspace(
      repository: FakeTrips(),
      masters: FakeMasters(),
      offices: const [],
    ),
    'expense-entry': () => ExpenseEntry(
      expenses: ExpensesFake(),
      finance: PaymentsFake(),
      trips: FakeTrips(),
      masters: ExpenseMasters(),
      offices: const [
        {'id': 'office', 'name': 'Synthetic office'},
      ],
      guard: (w) => w,
      picker: PickerFake(),
    ),
    'expense-list': () => ExpenseWorkspace(
      expenses: ExpensesFake(),
      finance: PaymentsFake(),
      trips: FakeTrips(),
      masters: ExpenseMasters(),
      offices: const [],
      guard: (w) => w,
    ),
    'masters': () => MasterWorkspace(repository: FakeMasters()),
    'backups': () => BackupWorkspace(commands: FakeBackup()),
    'documents': () => DocumentWorkspace(
      commands: DocumentFake(),
      onSupersede: (_, _) {},
      guard: (w) => w,
    ),
    'output-configuration': () => OutputWorkspace(
      commands: OutputsFake(),
      masters: FakeMasters(),
      trips: FakeTrips(),
      offices: const [],
      administrator: false,
    ),
    'correction-history': () => CorrectionWorkspace(
      commands: CorrectionsFake(),
      trips: FakeTrips(),
      guard: (w) => w,
    ),
  };
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in screens.entries) {
        testWidgets('paired typography ${entry.key} $width/$scale', (t) async {
          t.view.physicalSize = Size(width, 1100);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final capture = GlobalKey();
          await t.pumpWidget(
            MaterialApp(
              theme: KarvaanDesign.theme(),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: capture, child: entry.value()),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          expect(
            t
                .widgetList<BilingualText>(find.byType(BilingualText))
                .any((w) => w.text.ur.isNotEmpty),
            isTrue,
            reason: 'Actual paired screen, not a catalogue-only assertion',
          );
          if (entry.key == 'expense-entry') {
            final field = find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.style?.fontSize == KarvaanTypography.display,
            );
            await t.scrollUntilVisible(
              field,
              250,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 40,
            );
            await t.enterText(field, '10000.00');
            await t.pumpAndSettle();
            expect(t.widget<TextField>(field).controller!.text, '10000.00');
            expect(t.widget<TextField>(field).textDirection, TextDirection.ltr);
          }
          await t.runAsync(
            () => captureTextQa(
              t,
              capture,
              'before-metrics-${entry.key}-$width-$scale',
            ),
          );
          // Every rendered catalogue Urdu run keeps the readable minimum and
          // the bundled font's natural ascent/descent at the actual width/scale.
          for (final element in find.byType(Text).evaluate()) {
            final text = element.widget as Text;
            if (text.textDirection != TextDirection.rtl ||
                text.data == null ||
                text.style?.fontFamily != 'NotoSansArabic') {
              continue;
            }
            expect(
              text.style!.fontSize,
              greaterThanOrEqualTo(KarvaanTypography.urduMinimum),
            );
            final box = element.renderObject as RenderParagraph;
            // A field's single label line may shorten a run that does not
            // fit (the tooltip carries the full pair); the line it does
            // render still has to keep the font's natural height.
            final natural = TextPainter(
              text: box.text,
              maxLines: box.maxLines,
              ellipsis: box.overflow == TextOverflow.ellipsis ? '\u2026' : null,
              textDirection: box.textDirection,
              textScaler: box.textScaler,
              locale: box.locale,
              strutStyle: box.strutStyle,
              textWidthBasis: box.textWidthBasis,
              textHeightBehavior: box.textHeightBehavior,
            )..layout(maxWidth: box.constraints.maxWidth);
            expect(
              box.size.height,
              greaterThanOrEqualTo(natural.height - .1),
              reason:
                  '${entry.key}: ${text.data}; maxLines=${box.maxLines}, softWrap=${box.softWrap}, constraints=${box.constraints}, scale=${box.textScaler.scale(1)}',
            );
            natural.dispose();
          }
          await t.runAsync(
            () => captureTextQa(t, capture, 'form-${entry.key}-$width-$scale'),
          );
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
