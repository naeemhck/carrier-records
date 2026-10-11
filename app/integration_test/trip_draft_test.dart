import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native scoped draft list, multi-customer detail and editor', (
    tester,
  ) async {
    final config = PublicConfig.fromEnvironment();
    config.validate();
    final storage = SecureSessionStorage(
      namespace: 'native-trips.${DateTime.now().microsecondsSinceEpoch}',
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
      await tester.pumpWidget(CarrierRecordsApp(session: session));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.tap(find.text(TripStrings.trips));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      debugPrint('T05 native workspace loaded');
      expect(find.byType(TripWorkspace), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'TRP-000001');
      await tester.tap(find.text(TripStrings.refresh));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      final row = find.byKey(
        const ValueKey('trip:${String.fromEnvironment('TEST_TRIP_ID')}'),
      );
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      debugPrint('T05 native detail loaded');
      expect(find.byType(TripDetail), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Customer charge: PKR 101244.57'),
        300,
      );
      expect(
        find.textContaining('Customer charge: PKR 101244.57'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text(TripStrings.edit), 300);
      await tester.tap(find.text(TripStrings.edit));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      debugPrint('T05 native editor loaded');
      expect(find.byType(TripEditor), findsOneWidget);
      // Native form must preserve recorded fare, optional identifiers and counts.
      await tester.scrollUntilVisible(
        find.text('Consignment 1'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Consignment 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notes:')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('notes:')),
        'Native draft correction',
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('reason:')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('reason:')),
        'Native synthetic correction',
      );
      await tester.scrollUntilVisible(
        find.text(TripStrings.save),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(TripStrings.save));
      await tester.pump(const Duration(seconds: 2));
      debugPrint('T05 native overlap dialog loaded');
      expect(find.text(TripStrings.overlap), findsOneWidget);
      expect(find.text(TripStrings.restricted), findsOneWidget);
      await tester.tap(find.text(TripStrings.confirmOverlap));
      await tester.enterText(
        find.byType(TextField).last,
        'Native reviewed synthetic warning',
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, TripStrings.confirm),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text(TripStrings.confirm));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.text(TripStrings.saved), findsOneWidget);
    } finally {
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
