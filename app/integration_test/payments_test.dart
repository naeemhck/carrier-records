import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/finance/financial_repository.dart';
import 'package:carrier_records/features/finance/payment_model.dart';
import 'package:carrier_records/features/finance/payment_workspace.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/core/domain/record_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Windows receipt, commission retention and owner remittance',
    (tester) async {
      final config = PublicConfig.fromEnvironment()..validate();
      final storage = SecureSessionStorage(
        namespace: 'native-payments.${DateTime.now().microsecondsSinceEpoch}',
      );
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        authOptions: FlutterAuthClientOptions(localStorage: storage),
      );
      final client = Supabase.instance.client;
      final session = StaffSession(client, config, storage);
      final finance = FinancialRepository(client);
      const trip = String.fromEnvironment('TEST_TRIP_ID');
      Future<void> settle() => tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      Future<void> tap(Finder f) async {
        await tester.ensureVisible(f);
        await settle();
        await tester.tap(f);
        await settle();
      }

      Future<void> field(String label, String value) async {
        final f = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await tester.scrollUntilVisible(
          f,
          label == 'Allocated amount (PKR)' ? 250 : -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(f);
        await settle();
        await tester.enterText(f, value);
        await tester.pump();
      }

      Future<void> party(bool payer, String name) async {
        final f = find.byWidgetPredicate(
          (w) =>
              w is TextButton &&
              w.child is Text &&
              ((w.child as Text).data ?? '').startsWith(
                payer ? 'Payer:' : 'Recipient:',
              ),
        );
        await tester.scrollUntilVisible(
          f,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(f);
        final search = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Search parties',
        );
        await tester.enterText(search, 'T08');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await settle();
        await tester.tap(find.widgetWithText(ListTile, name));
        await settle();
      }

      Future<void> select(String label, String option) async {
        final f = find.byWidgetPredicate(
          (w) => w is InputDecorator && w.decoration.labelText == label,
        );
        await tester.scrollUntilVisible(
          f,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(f);
        await tester.tap(find.textContaining(option).last);
        await settle();
      }

      Future<void> post(String total) async {
        await field('Payment date (YYYY-MM-DD)', '2026-03-05');
        await field('Total amount (PKR)', total);
        await field('Reason / reference', 'Native synthetic payment');
        await field('Allocated amount (PKR)', total);
        final review = find.widgetWithText(FilledButton, 'Review payment');
        await tester.scrollUntilVisible(
          review,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(review);
        await tap(find.widgetWithText(FilledButton, 'Confirm payment'));
        expect(
          find.text('Payment confirmed. Balances reloaded.'),
          findsOneWidget,
        );
      }

      Future<void> action(PaymentAction a) async {
        final f = find.byType(DropdownButtonFormField<PaymentAction>);
        await tester.scrollUntilVisible(
          f,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await tap(f);
        await tester.tap(find.text(a.label).last);
        await settle();
      }

      try {
        await session.signIn(
          const String.fromEnvironment('TEST_USERNAME'),
          const String.fromEnvironment('TEST_PASSWORD'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PaymentWorkspace(
              finance: finance,
              trips: SupabaseTripRepository(client),
              masters: SupabaseMasterRepository(client),
              offices: [
                {
                  'id': const String.fromEnvironment('TEST_OFFICE_ID'),
                  'name': 'Synthetic origin',
                },
              ],
              initialTrip: trip,
            ),
          ),
        );
        await settle();
        await party(true, 'Synthetic customer');
        await party(false, 'Synthetic broker');
        await select('Outstanding claim', 'Customer outstanding');
        await post('60000.00');
        var ledger = await finance.trip(RecordId(trip));
        expect(
          (ledger['balances'] as List).firstWhere(
            (b) => b['account_purpose'] == 'OWNER_PAYABLE',
          )['balance'],
          '-95000.00',
        );
        await action(PaymentAction.commission);
        await party(true, 'Synthetic broker');
        await party(false, 'Synthetic broker');
        await select('Outstanding claim', 'Commission due');
        await select('Available source', 'Money held');
        await post('5000.00');
        await action(PaymentAction.owner);
        await party(false, 'Synthetic owner');
        await select('Outstanding claim', 'Owner settlement');
        await select('Available source', 'Money held');
        await post('55000.00');
        ledger = await finance.trip(RecordId(trip));
        final values = {
          for (final b in ledger['balances'] as List)
            b['account_purpose']: b['balance'],
        };
        expect(values, {
          'CUSTOMER_RECEIVABLE': '40000.00',
          'OWNER_PAYABLE': '-40000.00',
          'BROKER_COMMISSION_PAYABLE': '0.00',
          'CUSTODY_RECEIVABLE': '0.00',
        });
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
