// Phase 5 widget tests: expense entry amount figure caption, most-used-first
// pickers, and the expense list summary-first layout (status chips, page
// totals strip, empty state). Presentation only; synthetic fakes.
import 'bilingual_finders.dart';

import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_workspace_test.dart'
    show ExpensesFake, ExpenseMasters, PickerFake;
import 'payment_workspace_test.dart' show PaymentsFake;
import 'trip_workspace_test.dart' show FakeTrips;

class ListedExpenses extends ExpensesFake {
  @override
  Future<List<Map<String, dynamic>>> list({int offset = 0}) async => [
    {
      'id': 'e1',
      'expense_date': '2026-10-19',
      'trip_id': null,
      'amount': '10000.00',
      'notes': 'Diesel',
      'funding_source': 'PERSONAL_FUNDS',
      'effective': true,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
    {
      'id': 'e2',
      'expense_date': '2026-10-18',
      'trip_id': 't1',
      'amount': '5000.00',
      'notes': '',
      'funding_source': 'HELD_TRIP_FUNDS',
      'effective': false,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
  ];
}

class MultiPartyMasters extends ExpenseMasters {
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async {
    if (kind == MasterKind.party) {
      return [
        MasterRecord({'id': 'p5-1', 'display_name': 'Party one'}),
        MasterRecord({'id': 'p5-2', 'display_name': 'Party two'}),
      ];
    }
    return super.list(kind, search: search, offset: offset, archived: archived);
  }
}

Widget entryHarness({MasterRepository? masters}) => MaterialApp(
  theme: KarvaanDesign.theme(),
  home: ExpenseEntry(
    expenses: ExpensesFake(),
    finance: PaymentsFake(),
    trips: FakeTrips(),
    masters: masters ?? ExpenseMasters(),
    offices: const [
      {'id': 'office', 'name': 'Office'},
    ],
    guard: (w) => w,
    picker: PickerFake(),
  ),
);

Widget workspaceHarness({ExpensesFake? expenses}) => MaterialApp(
  theme: KarvaanDesign.theme(),
  home: ExpenseWorkspace(
    expenses: expenses ?? ExpensesFake(),
    finance: PaymentsFake(),
    trips: FakeTrips(),
    masters: ExpenseMasters(),
    offices: const [
      {'id': 'office', 'name': 'Office'},
    ],
    guard: (w) => w,
    picker: PickerFake(),
  ),
);

void main() {
  testWidgets('amount input shows a formatted figure caption beneath it', (
    tester,
  ) async {
    await tester.pumpWidget(entryHarness());
    await tester.pumpAndSettle();
    final amount = find.byWidgetPredicate(
      (w) => w is TextField && hasEnglishLabel(w.decoration, 'Expense amount (PKR)'),
    );
    await tester.scrollUntilVisible(
      amount,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(amount, '10000');
    await tester.pump();
    expect(find.text('PKR 10,000.00'), findsOneWidget);
    await tester.enterText(amount, 'not-a-number');
    await tester.pump();
    expect(find.text('PKR 10,000.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('master picker promotes the most-used record first', () {
    final rows = [
      MasterRecord({'id': 'pm-1', 'display_name': 'One'}),
      MasterRecord({'id': 'pm-2', 'display_name': 'Two'}),
    ];
    PickerUsage.pickedMaster(MasterKind.party, 'pm-2');
    PickerUsage.pickedMaster(MasterKind.party, 'pm-2');
    PickerUsage.pickedMaster(MasterKind.party, 'pm-1');
    final promoted = PickerUsage.promoteMasters(MasterKind.party, rows);
    expect(promoted.promoted, 2);
    expect(promoted.rows.map((r) => r.id).toList(), ['pm-2', 'pm-1']);
  });

  test('trip picker promotes the most-used trip first, capped at five', () {
    final rows = [
      for (var i = 0; i < 8; i++)
        {'id': 'cap-$i', 'trip_number': 'T-$i'},
    ];
    for (var i = 0; i < 8; i++) {
      for (var k = 0; k <= i; k++) {
        PickerUsage.pickedTrip('cap-$i');
      }
    }
    final promoted = PickerUsage.promoteTrips(rows);
    expect(promoted.promoted, 5);
    expect(promoted.rows.first['id'], 'cap-7');
    expect(promoted.rows[4]['id'], 'cap-3');
    expect(promoted.rows.last['id'], 'cap-2');
  });

  testWidgets('master picker leads with the most-used section in the dialog', (
    tester,
  ) async {
    final masters = MultiPartyMasters();
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final r = await chooseExpenseMaster(
                  context,
                  masters,
                  MasterKind.party,
                  (w) => w,
                );
                picked = r?.id;
              },
              child: const Text('open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Most used'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Party two'));
    await tester.pumpAndSettle();
    expect(picked, 'p5-2');
    await tester.tap(find.text('open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Most used'), findsOneWidget);
    final two = tester.getTopLeft(find.text('Party two')).dy;
    final one = tester.getTopLeft(find.text('Party one')).dy;
    expect(two, lessThan(one));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense list shows page total, status chips and page count', (
    tester,
  ) async {
    await tester.pumpWidget(workspaceHarness(expenses: ListedExpenses()));
    await tester.pumpAndSettle();
    expect(find.text('PKR 15,000.00'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Historical', skipOffstage: false), findsOneWidget);
    expect(find.text('2 records · Page 1'), findsOneWidget);
    expect(find.text('No records found.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty expense list shows guidance and the record action', (
    tester,
  ) async {
    await tester.pumpWidget(workspaceHarness());
    await tester.pumpAndSettle();
    expect(find.text('No records found.'), findsOneWidget);
    expect(find.text('Record expense'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
