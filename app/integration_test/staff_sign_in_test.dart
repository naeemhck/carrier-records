import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native staff username sign-in, verified office home and protected logout',
    (tester) async {
      final config = PublicConfig.fromEnvironment();
      config.validate();
      const username = String.fromEnvironment('TEST_USERNAME');
      const password = String.fromEnvironment('TEST_PASSWORD');
      expect(username.isNotEmpty && password.isNotEmpty, true);
      final storage = SecureSessionStorage(
        namespace: 'native-auth-test.${DateTime.now().microsecondsSinceEpoch}',
      );
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        authOptions: FlutterAuthClientOptions(localStorage: storage),
      );
      final session = StaffSession(Supabase.instance.client, config, storage);
      try {
        await tester.pumpWidget(CarrierRecordsApp(session: session));
        await tester.enterText(find.byType(TextField).at(0), username);
        await tester.enterText(find.byType(TextField).at(1), password);
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(session.profile?['role'] == 'STAFF', true);
        expect(find.textContaining('Assigned offices:'), findsOneWidget);
        expect(await storage.hasAccessToken(), true);
        await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(session.profile == null, true);
        expect(await storage.hasAccessToken(), false);
        expect(find.text('Staff sign-in'), findsOneWidget);
      } finally {
        await session.signOut();
        session.dispose();
        await Supabase.instance.dispose();
        await storage.removePersistedSession();
      }
    },
  );
}
