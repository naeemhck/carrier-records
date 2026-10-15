import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:carrier_records/features/trips/trip_lifecycle.dart';
import 'package:carrier_records/features/trips/trip_operation_dialog.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bilingual_finders.dart';
import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;
import 'trip_lifecycle_test.dart' show LifecycleFake, journey;

ThemeData candidateTheme() => KarvaanDesign.theme();

void karvaanScreenTests({bool native = false}) {
  void strictHits() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  }

  test('owned templates preserve raw data and unknown labels are explicit', () {
    final phrase = ownedMessage(
      'Selected evidence (1250 bytes); not uploaded.',
    );
    expect(phrase.key, isNot('unresolved.presentation'));
    expect(phrase.en, 'Selected evidence (1250 bytes); not uploaded.');
    expect(phrase.ur, contains('1250'));
    expect(
      ownedMessage('unknown-provider-label').key,
      'unresolved.presentation',
    );
    final data = L10n.trip3c1efc.withValues([Bilingual.data('TRP-000123')]);
    expect(data.ur, contains('TRP-000123'));
    final bases = {
      'earnings': 'Dispatch / explicit adjustment date',
      'expenses': 'Expense date',
    };
    expect(ownedDateBases(bases).en, bases.toString());
    expect(ownedDateBases(bases).ur, contains('آمدن'));
    expect(ownedDateBases(bases).ur, contains('اخراجات'));
    for (final label in reportLabels.values) {
      final lifetime = label
          .replaceAll('period end', 'current lifetime')
          .replaceAll('period costs', 'all linked costs')
          .replaceAll('expense date', 'all linked expense dates');
      expect(ownedMessage(label).key, isNot('unresolved.presentation'));
      expect(ownedMessage(lifetime).key, isNot('unresolved.presentation'));
    }
  });
  for (final width in native ? [900.0] : [320.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'draft form, dropdown, bilingual validation $width scale $scale',
        (tester) async {
          strictHits();
          if (!native) {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
          }
          final repo = FakeTrips();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: candidateTheme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: TripEditor(
                  repository: repo,
                  masters: FakeMasters(),
                  offices: const [
                    {'id': 'origin', 'name': 'Save / محفوظ'},
                  ],
                  draft: TripDraft()
                    ..origin = 'origin'
                    ..kind = 'EMPTY',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            Directionality.of(tester.element(find.byType(TripEditor))),
            TextDirection.ltr,
          );
          final origin = find.byWidgetPredicate(
            (widget) =>
                widget is InputDecorator &&
                hasEnglishLabel(
                  widget.decoration,
                  TripStrings.labels['origin']!,
                ),
          );
          await tester.scrollUntilVisible(
            origin,
            200,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await tester.pumpAndSettle();
          expect(find.text('Save / محفوظ'), findsOneWidget);
          expect(find.byType(BilingualFloatingLabel), findsWidgets);
          final urduFields = tester.widgetList<BilingualFloatingLabel>(
            find.byType(BilingualFloatingLabel),
          );
          expect(
            urduFields.any((field) => field.message.ur.contains('روانگی')),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          final kind = find.byWidgetPredicate(
            (widget) =>
                widget is InputDecorator &&
                hasEnglishLabel(widget.decoration, TripStrings.labels['load']!),
          );
          await tester.scrollUntilVisible(
            kind,
            200,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await tester.pumpAndSettle();
          await tester.tap(kind);
          await tester.pumpAndSettle();
          expect(find.text(ownedMessage('LOADED').ur), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.text(ownedMessage('LOADED').ur), findsNothing);
          await tester.tap(find.byKey(const ValueKey('trip-step-2')));
          await tester.pumpAndSettle();
          final review = find.text(TripStrings.save);
          await tester.scrollUntilVisible(
            review,
            250,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 40,
          );
          await tester.tap(review);
          await tester.pumpAndSettle();
          expect(repo.requests, isEmpty);
          expect(find.text(TripStrings.requiredJourney), findsOneWidget);
          expect(
            find.text(ownedMessage(TripStrings.requiredJourney).ur),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          if (!native && scale == 1) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1.5);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('../tools/.local/karvaan-form-${width.toInt()}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
    testWidgets('dispatch dialog Urdu review/invalid date/Escape $width', (
      tester,
    ) async {
      strictHits();
      if (!native) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final repo = LifecycleFake();
      await tester.pumpWidget(
        MaterialApp(
          theme: candidateTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TripOperationDialog(
                    repository: repo,
                    trip: {...journey(), 'state': 'DRAFT'},
                    action: TripAction.dispatch,
                  ),
                ),
                child: const Text('Open synthetic dispatch'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open synthetic dispatch'));
      await tester.pumpAndSettle();
      expect(
        find.text(ownedMessage(TripAction.dispatch.label).ur),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('operation-date')),
        '2026-02-30',
      );
      await tester.enterText(
        find.byKey(const Key('operation-reason')),
        'QA synthetic 125,000.00',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final review = find.text(LifecycleStrings.dispatchReview);
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, LifecycleStrings.dispatchReview),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, LifecycleStrings.confirm),
            )
            .onPressed,
        isNull,
      );
      expect(repo.reviews, 0);
      expect(repo.operationRequests, isEmpty);
      await tester.enterText(
        find.byKey(const Key('operation-date')),
        '2026-03-01',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(
        find.text(ownedMessage(LifecycleStrings.reviewed).ur),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, LifecycleStrings.confirm),
            )
            .onPressed,
        isNull,
      );
      final acknowledgement = find.widgetWithText(
        CheckboxListTile,
        LifecycleStrings.reviewed,
      );
      await tester.ensureVisible(acknowledgement);
      await tester.pumpAndSettle();
      await tester.tap(acknowledgement);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, LifecycleStrings.confirm),
            )
            .onPressed,
        isNotNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TripOperationDialog), findsNothing);
      expect(repo.operationRequests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}

void main() => karvaanScreenTests();
