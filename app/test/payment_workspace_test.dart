import 'dart:async';

import 'package:carrier_records/core/domain/record_context.dart';
import 'package:carrier_records/features/finance/financial_repository.dart';
import 'package:carrier_records/features/finance/payment_workspace.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_workspace_test.dart' show FakeTrips, FakeMasters;

const tripId = '11111111-1111-4111-8111-111111111111';

class PaymentTrips extends FakeTrips {
  @override
  Future<Map<String, dynamic>> detail(String id) async => {
    'trip_number': 'TRP-001',
    'consignments': [
      {
        'id': 'consignment',
        'customer_id': 'customer',
        'customer_name': 'Customer',
        'broker_id': 'broker',
        'broker_name': 'Broker',
        'car_count': 1,
      },
    ],
  };
}

class PaymentMasters extends FakeMasters {
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async => [
    MasterRecord({
      'id': 'customer',
      'display_name': 'Customer',
      'roles': ['CUSTOMER'],
    }),
    MasterRecord({
      'id': 'broker',
      'display_name': 'Broker',
      'roles': ['BROKER'],
    }),
  ];
}

class PaymentsFake implements FinancialCommands {
  final requests = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<Map<String, dynamic>> trip(RecordId id) async => {
    'balances': [],
    'claims': [
      {
        'line_id': 'claim',
        'party_id': 'customer',
        'account_purpose': 'CUSTOMER_RECEIVABLE',
        'consignment_id': 'consignment',
        'effective_date': '2026-01-30',
        'remaining': '10.00',
        'version': 1,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> post(
    String kind,
    String request,
    Map<String, dynamic> payload,
  ) {
    requests.add(request);
    bodies.add(payload);
    return pending.future;
  }
}

void main() {
  testWidgets('revoked scope hides payment form and its open party picker', (
    tester,
  ) async {
    final access = ValueNotifier(true);
    Widget guard(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: access,
      builder: (_, allowed, _) =>
          allowed ? child : const Scaffold(body: Text('Access changed')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: guard(
          PaymentWorkspace(
            finance: PaymentsFake(),
            trips: PaymentTrips(),
            masters: PaymentMasters(),
            offices: const [
              {'id': 'office', 'name': 'Origin'},
            ],
            initialTrip: tripId,
            guard: guard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Payer: Choose'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Customer'), findsOneWidget);
    access.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(PaymentWorkspace), findsNothing);
    expect(find.widgetWithText(ListTile, 'Customer'), findsNothing);
    expect(find.text('Access changed'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    access.dispose();
  });
  testWidgets(
    'await commit, preserve ambiguous request and require conflict review',
    (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fake = PaymentsFake();
      await tester.pumpWidget(
        MaterialApp(
          home: PaymentWorkspace(
            finance: fake,
            trips: PaymentTrips(),
            masters: PaymentMasters(),
            offices: const [
              {'id': 'office', 'name': 'Origin'},
            ],
            initialTrip: tripId,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      await tap(find.widgetWithText(TextButton, 'Payer: Choose'));
      await tap(find.widgetWithText(ListTile, 'Customer'));
      await tap(find.widgetWithText(TextButton, 'Recipient: Choose'));
      await tap(find.widgetWithText(ListTile, 'Broker'));
      Future<void> enter(String label, String text) async {
        final f = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.ensureVisible(f);
        await tester.enterText(f, text);
        await tester.pump();
      }

      Future<void> prepare() async {
        await enter('Payment date (YYYY-MM-DD)', '2026-03-05');
        await enter('Total amount (PKR)', '5.00');
        await enter('Reason / reference', 'Synthetic review');
        await tap(
          find.byWidgetPredicate(
            (w) =>
                w is InputDecorator &&
                w.decoration.labelText == 'Outstanding claim',
          ),
        );
        await tap(find.textContaining('Customer outstanding').last);
        await enter('Allocated amount (PKR)', '5.00');
        await tap(find.widgetWithText(FilledButton, 'Review payment'));
      }

      await prepare();
      final confirm = find.widgetWithText(FilledButton, 'Confirm payment');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      expect(find.text('Payment confirmed. Balances reloaded.'), findsNothing);
      expect(fake.requests.length, 1);
      fake.pending.completeError(Exception('Lost response'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic review'), findsOneWidget);
      fake.pending = Completer();
      await tester.tap(confirm);
      await tester.pump();
      expect(fake.requests.length, 2);
      expect(fake.requests[1], fake.requests[0]);
      expect(fake.bodies[1], fake.bodies[0]);
      fake.pending.complete({'record_id': 'confirmed'});
      await tester.pumpAndSettle();
      expect(
        find.text('Payment confirmed. Balances reloaded.'),
        findsOneWidget,
      );
      await prepare();
      fake.pending = Completer();
      await tester.tap(confirm);
      await tester.pump();
      fake.pending.completeError(
        const PostgrestException(
          message: 'CLAIM_VERSION_CONFLICT',
          code: 'PT409',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tap(find.byTooltip('Reload balances'));
      expect(find.text('Confirm payment'), findsNothing);
      expect(find.text('Synthetic review'), findsOneWidget);
    },
  );
}
