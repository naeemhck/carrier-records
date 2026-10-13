import '../test/bilingual_finders.dart';

import 'dart:convert';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:carrier_records/features/expenses/expense_repository.dart';
import 'package:carrier_records/features/finance/financial_repository.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyntheticReceipt implements ReceiptPicker {
  @override
  Future<ReceiptSelection?> pick() async => ReceiptSelection(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aVuoAAAAASUVORK5CYII=',
    ),
    'image/png',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Windows expense confirmation and separate private receipt',
    (tester) async {
      final config = PublicConfig.fromEnvironment()..validate();
      final storage = SecureSessionStorage(
        namespace: 'native-expenses.${DateTime.now().microsecondsSinceEpoch}',
      );
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        authOptions: FlutterAuthClientOptions(localStorage: storage),
      );
      final client = Supabase.instance.client;
      final session = StaffSession(client, config, storage);
      Future<void> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );
      Future<void> tap(String text, {double direction = 250}) async {
        final f = find.text(text);
        await tester.scrollUntilVisible(
          f,
          direction,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await settle();
        await tester.tap(f);
        await settle();
      }

      Future<void> field(String label, String text) async {
        final f = find.byWidgetPredicate(
          (w) => w is TextField && hasEnglishLabel(w.decoration, label),
        );
        await tester.scrollUntilVisible(
          f,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await settle();
        await tester.enterText(f, text);
        await tester.pump();
      }

      Future<void> pick(String button, String name) async {
        await tap(button, direction: -250);
        final search = find.byWidgetPredicate(
          (w) =>
              w is TextField && hasEnglishLabel(w.decoration, 'Search records'),
        );
        await tester.enterText(search, 'T09');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle();
        await tester.tap(find.widgetWithText(ListTile, name));
        await settle();
      }

      try {
        await session.signIn(
          const String.fromEnvironment('TEST_USERNAME'),
          const String.fromEnvironment('TEST_PASSWORD'),
        );
        expect(session.profile?['must_change_password'], false);
        await tester.pumpWidget(
          MaterialApp(
            home: ExpenseEntry(
              expenses: ExpenseRepository(client),
              finance: FinancialRepository(client),
              trips: SupabaseTripRepository(client),
              masters: SupabaseMasterRepository(client),
              offices: [
                {
                  'id': const String.fromEnvironment('TEST_OFFICE_ID'),
                  'name': 'Synthetic office',
                },
              ],
              guard: (w) => w,
              picker: SyntheticReceipt(),
            ),
          ),
        );
        await settle();
        await pick('Choose vehicle', 'T09-SYNTHETIC');
        await pick('Choose category', 'T09 Diesel and maintenance');
        await pick('Choose payer', 'Synthetic owner');
        await pick('Choose cost bearer', 'Synthetic owner');
        await field('Expense date (YYYY-MM-DD)', '2026-03-05');
        await field('Expense amount (PKR)', '1234.56');
        await field('Notes / reason', 'Synthetic native T09 expense');
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
        await tester.ensureVisible(funding);
        await settle();
        await tester.tap(funding);
        await settle();
        await tester.tap(find.text('Payer personally bears this cost').last);
        await settle();
        await tap('Optional private receipt (PNG / JPEG / PDF, 5 MB)');
        await tap('Review expense');
        await tap('Confirm expense');
        expect(
          englishTextContaining('Expense confirmed: PKR 1234.56'),
          findsOneWidget,
        );
        expect(find.text('Receipt attached.'), findsOneWidget);
        final data = await client
            .from('expenses')
            .select('id,amount,funding_source')
            .eq('notes', 'Synthetic native T09 expense')
            .single();
        expect(data['funding_source'], 'SELF_FUNDED_COST');
        final bytes = await ExpenseRepository(client)
            .download(data['id'] as String);
        expect(bytes, await SyntheticReceipt().pick().then((r) => r!.bytes));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await session.signOut();
        session.dispose();
        await Supabase.instance.dispose();
        await storage.removePersistedSession();
      }
    },
  );
}
