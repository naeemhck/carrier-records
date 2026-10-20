import 'dart:async';

import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:carrier_records/features/trips/trip_lifecycle.dart';
import 'package:carrier_records/features/trips/trip_operation_dialog.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_lifecycle_test.dart' show LifecycleFake, journey;
import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;

class OfficeChoices extends FakeMasters {
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async => [
    MasterRecord({
      'id': 'destination',
      'version': 1,
      'code': 'dst',
      'name': 'Authorized destination',
    }),
  ];
}

class PendingReview extends LifecycleFake {
  final review = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> overlap(TripDraft draft) => review.future;
}

Future<void> openDispatch(WidgetTester tester, LifecycleFake repo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => TripOperationDialog(
              repository: repo,
              trip: journey(),
              action: TripAction.dispatch,
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('operation-reason')),
    'QA review',
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'destination picker retains authorized label outside origin assignments',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripEditor(
            repository: FakeTrips(),
            masters: OfficeChoices(),
            offices: const [
              {'id': 'origin', 'name': 'Assigned origin'},
            ],
            draft: TripDraft()
              ..origin = 'origin'
              ..kind = 'EMPTY',
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('trip-picker-destination-choose')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('trip-picker-destination-choose')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Authorized destination'));
      await tester.pumpAndSettle();
      // Density pass picker: label and value are separate widgets; the
      // value shows the authorized office's name, never its raw id.
      expect(find.text('Authorized destination'), findsOneWidget);
      expect(find.text('destination'), findsNothing);
    },
  );

  testWidgets('Escape dismisses an idle operation without backend mutation', (
    tester,
  ) async {
    final repo = LifecycleFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TripOperationDialog(
                repository: repo,
                trip: journey(),
                action: TripAction.dispatch,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TripOperationDialog), findsNothing);
    expect(repo.operationRequests, isEmpty);
  });

  for (final escape in [true, false]) {
    testWidgets(
      'pending review may be dismissed without posting: Escape=$escape',
      (tester) async {
        final repo = PendingReview();
        await openDispatch(tester, repo);
        await tester.ensureVisible(find.text(LifecycleStrings.dispatchReview));
        await tester.tap(find.text(LifecycleStrings.dispatchReview));
        await tester.pump();
        if (escape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(find.text(TripStrings.cancel));
        }
        await tester.pumpAndSettle();
        expect(find.byType(TripOperationDialog), findsNothing);
        expect(repo.operationRequests, isEmpty);
        repo.review.complete({
          'requires_confirmation': false,
          'review_token': 'unused',
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'dispatch needs review, acknowledgement and current valid inputs',
    (tester) async {
      await openDispatch(tester, LifecycleFake());
      FilledButton confirm() => tester.widget(
        find.widgetWithText(FilledButton, LifecycleStrings.confirm),
      );
      expect(confirm().onPressed, isNull);
      await tester.ensureVisible(find.text(LifecycleStrings.dispatchReview));
      await tester.tap(find.text(LifecycleStrings.dispatchReview));
      await tester.pumpAndSettle();
      expect(confirm().onPressed, isNull);
      await tester.ensureVisible(find.text(LifecycleStrings.reviewed));
      await tester.tap(find.text(LifecycleStrings.reviewed));
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(const Key('operation-reason')));
      await tester.enterText(find.byKey(const Key('operation-reason')), ' ');
      await tester.pump();
      expect(confirm().onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('operation-reason')),
        'Valid reason',
      );
      await tester.pump();
      expect(confirm().onPressed, isNotNull);
      await tester.enterText(
        find.byKey(const Key('operation-date')),
        '2026-02-30',
      );
      await tester.pump();
      expect(confirm().onPressed, isNull);
    },
  );
}
