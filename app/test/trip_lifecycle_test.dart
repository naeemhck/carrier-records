import 'dart:async';

import 'package:carrier_records/features/trips/trip_lifecycle.dart';
import 'package:carrier_records/features/trips/trip_operation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_workspace_test.dart' show FakeTrips;

Map<String, dynamic> journey() => {
  'id': 'trip',
  'version': 3,
  'trip_number': 'TRP-000001',
  'notes': '',
  'state': 'DISPATCHED',
  'dispatch_date': '2026-01-30',
  'arrival_date': null,
  'load_kind': 'EMPTY',
  'owner_snapshot': {},
  'route_snapshot': {},
  'stops': [],
  'consignments': [],
  'totals': {
    'customer_charge': '0.00',
    'commission': '0.00',
    'owner_entitlement': '0.00',
  },
};

class LifecycleFake extends FakeTrips {
  final operationRequests = <String>[];
  final operationBodies = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? commit;
  bool stale = false;
  @override
  Future<Map<String, dynamic>> operate(
    String action,
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) async {
    operationRequests.add(request);
    operationBodies.add(Map.from(payload));
    if (stale) {
      throw const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'PT409',
      );
    }
    if (commit != null) return commit!.future;
    throw Exception('Response lost');
  }
}

Future<void> open(
  WidgetTester tester,
  LifecycleFake repo,
  TripAction action,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                barrierDismissible: false,
                builder: (_) => TripOperationDialog(
                  repository: repo,
                  trip: journey(),
                  action: action,
                ),
              );
              if (context.mounted && result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Committed result')),
                );
              }
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('operation-date')), '2026-02-02');
  await tester.enterText(
    find.byKey(const Key('operation-reason')),
    'Recorded delivery',
  );
}

void main() {
  test('actual dates and corrections enforce chronological business dates', () {
    final t = journey();
    expect(
      () => lifecyclePayload(
        TripAction.arrive,
        t,
        reason: 'Recorded',
        date: '2026-01-29',
      ),
      throwsFormatException,
    );
    expect(
      () => lifecyclePayload(
        TripAction.arrive,
        t,
        reason: 'Recorded',
        date: '2026-02-30',
      ),
      throwsFormatException,
    );
    expect(
      () => lifecyclePayload(
        TripAction.dispatch,
        t,
        reason: ' ',
        date: '2026-01-30',
      ),
      throwsFormatException,
    );
    expect(
      () => lifecyclePayload(
        TripAction.correctDispatch,
        t,
        reason: 'Correction',
        date: '2026-01-30',
      ),
      throwsFormatException,
    );
    t['arrival_date'] = '2026-02-02';
    expect(
      () => lifecyclePayload(
        TripAction.correctDispatch,
        t,
        reason: 'Correction',
        date: '2026-02-03',
      ),
      throwsFormatException,
    );
    expect(
      lifecyclePayload(
        TripAction.arrive,
        t,
        reason: ' Recorded ',
        date: '2026-02-02',
      ),
      {'arrival_date': '2026-02-02', 'reason': 'Recorded'},
    );
  });
  test(
    'operational payload contains no financial commands or editable prices',
    () {
      expect(
        lifecyclePayload(
          TripAction.correctOperation,
          journey(),
          reason: 'Own correction',
          notes: 'Driver contacted',
        ),
        {'reason': 'Own correction', 'notes': 'Driver contacted'},
      );
      expect(
        lifecyclePayload(
          TripAction.cancelConsignment,
          journey(),
          reason: 'Withdrawn',
          consignment: 'child',
        ),
        {'reason': 'Withdrawn', 'consignment_id': 'child'},
      );
    },
  );
  testWidgets(
    'pending transaction does not show success or accept duplicate clicks',
    (tester) async {
      final repo = LifecycleFake()..commit = Completer();
      await open(tester, repo, TripAction.arrive);
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pump();
      expect(find.text(LifecycleStrings.pending), findsOneWidget);
      expect(find.text('Committed result'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.operationRequests.length, 1);
      repo.commit!.complete({'state': 'ARRIVED'});
      await tester.pumpAndSettle();
      expect(find.text('Committed result'), findsOneWidget);
      expect(find.byType(TripOperationDialog), findsNothing);
    },
  );
  testWidgets(
    'lost response retry preserves UUID and payload; changed input gets new UUID',
    (tester) async {
      final repo = LifecycleFake();
      await open(tester, repo, TripAction.arrive);
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.operationRequests[0], repo.operationRequests[1]);
      expect(repo.operationBodies[0], repo.operationBodies[1]);
      expect(find.text('Committed result'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('operation-reason')),
        'Changed reason',
      );
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.operationRequests[2], isNot(repo.operationRequests[0]));
    },
  );
  testWidgets(
    'concurrent-edit conflict preserves input and requires closing to reload',
    (tester) async {
      final repo = LifecycleFake()..stale = true;
      await open(tester, repo, TripAction.arrive);
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('operation-reason')))
            .controller!
            .text,
        'Recorded delivery',
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Committed result'), findsNothing);
    },
  );
  testWidgets(
    'explicit fresh dispatch review replaces a failed request ticket',
    (tester) async {
      final repo = LifecycleFake();
      await open(tester, repo, TripAction.dispatch);
      Future<void> review() async {
        await tester.ensureVisible(find.text(LifecycleStrings.dispatchReview));
        await tester.tap(find.text(LifecycleStrings.dispatchReview));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(LifecycleStrings.reviewed));
        await tester.tap(find.text(LifecycleStrings.reviewed));
        await tester.pump();
      }

      await review();
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      await review();
      await tester.tap(find.text(LifecycleStrings.confirm));
      await tester.pumpAndSettle();
      expect(repo.operationBodies[0]['review_token'], 'ticket-1');
      expect(repo.operationBodies[1]['review_token'], 'ticket-2');
      expect(repo.operationRequests[0], isNot(repo.operationRequests[1]));
    },
  );
}
