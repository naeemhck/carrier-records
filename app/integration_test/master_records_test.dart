import '../test/bilingual_finders.dart';

import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native administrator creates, edits and archives a master record',
    (tester) async {
      final config = PublicConfig.fromEnvironment();
      config.validate();
      final storage = SecureSessionStorage(
        namespace: 'native-masters.${DateTime.now().microsecondsSinceEpoch}',
      );
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        authOptions: FlutterAuthClientOptions(localStorage: storage),
      );
      final session = StaffSession(Supabase.instance.client, config, storage);
      try {
        await session.signIn(
          const String.fromEnvironment('TEST_USERNAME'),
          const String.fromEnvironment('TEST_PASSWORD'),
        );
        expect(session.profile?['role'], 'ADMIN');
        await tester.pumpWidget(CarrierRecordsApp(session: session));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await tester.tap(find.text(MasterStrings.title));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await tester.tap(find.text(MasterKind.category.label));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        // Keep the native fixture searchable even with pagination test rows.
        await tester.enterText(
          find.byType(TextField).first,
          'Native UI synthetic',
        );
        await tester.tap(find.text(MasterStrings.refresh));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await tester.tap(find.text(MasterStrings.newRecord));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Native UI synthetic',
        );
        await tester.tap(find.text(MasterStrings.save));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Native UI synthetic'), findsNWidgets(2));
        await tester.tap(find.text(MasterStrings.edit));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'Native UI synthetic renamed',
        );
        await tester.tap(find.text(MasterStrings.save));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Native UI synthetic renamed'), findsOneWidget);
        await tester.tap(find.text(MasterStrings.edit));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.tap(find.text(MasterStrings.save));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Native UI synthetic renamed'), findsNothing);
        await tester.tap(find.text(MasterStrings.includeArchived));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Native UI synthetic renamed'), findsOneWidget);
        expect(englishTextContaining(MasterStrings.archived), findsWidgets);
      } finally {
        await session.signOut();
        session.dispose();
        await Supabase.instance.dispose();
        await storage.removePersistedSession();
      }
    },
  );
}
