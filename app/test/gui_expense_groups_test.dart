import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_workspace_test.dart'
    show ExpensesFake, ExpenseMasters, PickerFake;
import 'payment_workspace_test.dart' show PaymentsFake;
import 'trip_workspace_test.dart' show FakeTrips;

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('expense groups retain complete labels at200% width$width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final commands = ExpensesFake();
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ExpenseEntry(
              expenses: commands,
              finance: PaymentsFake(),
              trips: FakeTrips(),
              masters: ExpenseMasters(),
              offices: const [
                {'id': 'office', 'name': 'Synthetic office'},
              ],
              guard: (w) => w,
              picker: PickerFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final group in [
        L10n.whatSection,
        L10n.whoseMoneySection,
        L10n.whereSection,
        L10n.proofSection,
      ]) {
        await tester.scrollUntilVisible(
          find.text(group.en),
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 60,
        );
        expect(find.text(group.ur), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(commands.requests, isEmpty);
      expect(commands.attachments, isEmpty);
    });
  }
}
