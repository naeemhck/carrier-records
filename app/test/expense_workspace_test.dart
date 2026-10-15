import 'bilingual_finders.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:carrier_records/features/expenses/expense_repository.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'payment_workspace_test.dart' show PaymentsFake;
import 'trip_workspace_test.dart' show FakeTrips, FakeMasters;

class ExpenseMasters extends FakeMasters {
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async => [
    MasterRecord(switch (kind) {
      MasterKind.vehicle => {
        'id': 'vehicle',
        'registration': 'Vehicle',
        'current_owner_id': 'owner',
      },
      MasterKind.category => {'id': 'category', 'name': 'Diesel'},
      _ => {
        'id': 'owner',
        'display_name': 'Owner',
        'roles': ['OWNER'],
      },
    }),
  ];
}

class PickerFake implements ReceiptPicker {
  @override
  Future<ReceiptSelection?> pick() async => ReceiptSelection(
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    'image/png',
  );
}

class ExpensesFake implements ExpenseCommands {
  @override
  Future<int> cleanup() async => 0;
  final requests = <String>[], attachments = <String>[];
  final bodies = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<List<Map<String, dynamic>>> list({int offset = 0}) async => [];
  @override
  Future<List<Map<String, dynamic>>> claims(String expense) async => [];
  @override
  Future<Map<String, dynamic>> post(
    String request,
    Map<String, dynamic> payload,
  ) {
    requests.add(request);
    bodies.add(payload);
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> attach(
    String expense,
    String request,
    ReceiptSelection receipt,
  ) async {
    attachments.add(request);
    if (attachments.length == 1) throw Exception('Storage unavailable');
    return {'receipt_status': 'ATTACHED'};
  }

  @override
  Future<Uint8List?> download(String expense) async => null;
}

void main() {
  testWidgets(
    'Lost posting retry keeps UUID; upload failure retries only receipt',
    (tester) async {
      final commands = ExpensesFake();
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseEntry(
            expenses: commands,
            finance: PaymentsFake(),
            trips: FakeTrips(),
            masters: ExpenseMasters(),
            offices: const [
              {'id': 'office', 'name': 'Office'},
            ],
            guard: (w) => w,
            picker: PickerFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String text, {double direction = 250}) async {
        final f = find.text(text);
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          f,
          direction.abs(),
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      Future<void> pick(String button, String name) async {
        await tap(button, direction: -250);
        await tester.tap(find.widgetWithText(ListTile, name));
        await tester.pumpAndSettle();
      }

      await pick('Choose vehicle', 'Vehicle');
      await pick('Choose category', 'Diesel');
      await pick('Choose payer', 'Owner');
      await pick('Choose cost bearer', 'Owner');
      Future<void> field(String label, String value) async {
        final f = find.byWidgetPredicate(
          (w) => w is TextField && hasEnglishLabel(w.decoration, label),
        );
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          f,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(f, value);
        await tester.pump();
      }

      await field('Expense amount (PKR)', '10000.00');
      await field('Notes / reason', 'Diesel paid personally');
      final funding = find.byWidgetPredicate(
        (w) =>
            w is InputDecorator &&
            hasEnglishLabel(w.decoration, 'Funding source'),
      );
      await tester.scrollUntilVisible(
        funding,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(funding);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payer personally bears this cost').last);
      await tester.pumpAndSettle();
      await tap('Optional private receipt (PNG / JPEG / PDF, 5 MB)');
      await tap('Review expense');
      final confirm = find.text('Confirm expense');
      await tester.scrollUntilVisible(
        confirm,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      expect(englishTextContaining('Expense confirmed:'), findsNothing);
      expect(commands.requests, hasLength(1));
      commands.pending.completeError(Exception('Lost response'));
      await tester.pumpAndSettle();
      commands.pending = Completer();
      final retry = find.text('Retry same expense request');
      await tester.scrollUntilVisible(
        retry,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump();
      expect(commands.requests[0], commands.requests[1]);
      expect(commands.bodies[0], commands.bodies[1]);
      commands.pending.complete({'record_id': 'expense', 'amount': '10000.00'});
      await tester.pumpAndSettle();
      expect(englishTextContaining('Expense confirmed:'), findsOneWidget);
      expect(englishTextContaining('Receipt upload failed.'), findsOneWidget);
      expect(commands.attachments, hasLength(1));
      await tap('Retry receipt only', direction: -250);
      expect(commands.requests, hasLength(2));
      expect(commands.attachments[0], commands.attachments[1]);
      expect(find.text('Receipt attached.'), findsOneWidget);
    },
  );
  testWidgets(
    'Revoked office hides expense editor and an already open selector',
    (tester) async {
      final access = ValueNotifier(true);
      Widget guard(Widget child) => ValueListenableBuilder<bool>(
        valueListenable: access,
        builder: (_, v, _) =>
            v ? child : const Scaffold(body: Text('Access revoked')),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: guard(
            ExpenseEntry(
              expenses: ExpensesFake(),
              finance: PaymentsFake(),
              trips: FakeTrips(),
              masters: ExpenseMasters(),
              offices: const [
                {'id': 'office', 'name': 'Office'},
              ],
              guard: guard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Choose vehicle'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose vehicle'));
      await tester.pumpAndSettle();
      expect(find.text('Vehicle'), findsOneWidget);
      access.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Vehicle'), findsNothing);
      expect(find.text('Choose vehicle'), findsNothing);
      access.dispose();
    },
  );
}
