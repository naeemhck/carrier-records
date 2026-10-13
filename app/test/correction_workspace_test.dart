import 'bilingual_finders.dart';

import 'dart:async';

import 'package:carrier_records/features/finance/correction_repository.dart';
import 'package:carrier_records/features/finance/correction_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CorrectionsFake implements CorrectionCommands {
  final requests = <String>[], payloads = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<List<Map<String, dynamic>>> history(String? trip, int offset) async =>
      [];
  @override
  Future<Map<String, dynamic>> review(
    String id, {
    bool cancellation = false,
  }) async => {};
  @override
  Future<Map<String, dynamic>> confirm(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload, {
    bool cancellation = false,
  }) {
    requests.add(request);
    payloads.add(payload);
    return pending.future;
  }
}

final review = {
  'review_token': 'synthetic',
  'events': <dynamic>[],
  'claims': <dynamic>[],
};
final event = {
  'id': '00000000-0000-4000-8000-000000000001',
  'kind': 'EXPENSE',
  'amount': '2500.00',
  'effective_date': '2026-02-01',
  'payload': {
    'amount': '2500.00',
    'effective_date': '2026-02-01',
    'reason': 'Original synthetic cost',
    'allocations': <dynamic>[],
  },
};
Future<void> field(WidgetTester t, String label, String value) async {
  final finder = find.byWidgetPredicate(
    (w) => w is TextField && hasEnglishLabel(w.decoration, label),
  );
  await t.ensureVisible(finder);
  await t.enterText(finder, value);
  await t.pump();
}

Future<void> tap(WidgetTester t, String label) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

void main() {
  testWidgets(
    'Correction commits before success and preserves UUID after lost response',
    (t) async {
      final fake = CorrectionsFake();
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CorrectionForm(
                      commands: fake,
                      id: event['id'] as String,
                      review: review,
                      event: event,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tap(t, 'Open');
      await t.pumpAndSettle();
      await field(t, 'Reason', 'Correct entered maintenance amount');
      await field(t, 'Corrected amount', '3500.01');
      await tap(t, 'Review correction');
      await tap(t, 'Confirm reviewed correction');
      expect(fake.requests.length, 1);
      expect(englishTextContaining('Correction committed.'), findsNothing);
      fake.pending.completeError(TimeoutException('Lost response'));
      await t.pumpAndSettle();
      final amount = t.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              hasEnglishLabel(w.decoration, 'Corrected amount'),
        ),
      );
      expect(amount.enabled, false);
      fake.pending = Completer();
      await tap(t, 'Retry reviewed correction');
      expect(fake.requests[0], fake.requests[1]);
      expect(fake.payloads[0], fake.payloads[1]);
      fake.pending.complete({'record_id': event['id']});
      await t.pumpAndSettle();
      expect(englishTextContaining('Correction committed.'), findsOneWidget);
    },
  );
  testWidgets(
    'Cancellation reviews exact fee split; conflict prevents automatic repost',
    (t) async {
      final fake = CorrectionsFake();
      final trip = {
        'version': 3,
        'consignments': [
          {
            'id': 'synthetic-consignment',
            'customer_name': 'Synthetic customer',
            'customer_charge': '100000.00',
            'broker_id': 'synthetic-broker',
            'state': 'ACTIVE',
          },
        ],
      };
      await t.pumpWidget(
        MaterialApp(
          home: CorrectionForm(
            commands: fake,
            id: 'synthetic-trip',
            review: review,
            trip: trip,
          ),
        ),
      );
      await field(t, 'Reason', 'Agreed cancellation terms');
      await field(t, 'Cancellation effective date (YYYY-MM-DD)', '2026-04-01');
      await field(t, 'Agreed cancellation charge', '10000.01');
      await field(t, 'Broker share within cancellation charge', '1000.00');
      await tap(t, 'Review correction');
      await t.scrollUntilVisible(
        englishTextContaining('owner PKR 9000.01'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(englishTextContaining('owner PKR 9000.01'), findsOneWidget);
      await tap(t, 'Confirm reviewed correction');
      fake.pending.completeError(
        const PostgrestException(message: 'VERSION_CONFLICT', code: 'PT409'),
      );
      await t.pumpAndSettle();
      expect(englishTextContaining('Records changed.'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retry reviewed correction'),
            )
            .onPressed,
        isNull,
      );
      expect(fake.requests.length, 1);
    },
  );
}
