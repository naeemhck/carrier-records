import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/reports/output_repository.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Windows authorized output and committed personal preset', (
    t,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate();
    final storage = SecureSessionStorage(
      namespace: 'native-outputs.${DateTime.now().microsecondsSinceEpoch}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(localStorage: storage),
    );
    final client = Supabase.instance.client,
        session = StaffSession(Supabase.instance.client, config, storage);
    try {
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      await t.pumpWidget(
        MaterialApp(
          home: OutputWorkspace(
            commands: OutputRepository(client),
            masters: SupabaseMasterRepository(client),
            trips: SupabaseTripRepository(client),
            offices: (session.profile!['offices'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList(),
            administrator: false,
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final entry in [
        ('From (YYYY-MM-DD)', '2026-01-01'),
        ('To (YYYY-MM-DD)', '2026-04-30'),
        ('Trip / vehicle search', 'T12-SYNTHETIC'),
      ]) {
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == entry.$1,
        );
        await t.ensureVisible(field);
        await t.enterText(field, entry.$2);
      }
      Future<void> tap(Finder f) async {
        await t.ensureVisible(f);
        await t.tap(f);
        await t.pumpAndSettle();
      }

      await tap(find.text('Select all permitted'));
      await tap(find.text('Preview'));
      expect(find.text('Vehicle operating profit: 85000.00'), findsOneWidget);
      expect(
        find.textContaining('not a complete business balance'),
        findsOneWidget,
      );
      if (find.text('Edit configuration').evaluate().isNotEmpty) {
        await tap(find.text('Edit configuration'));
      }
      await tap(find.byKey(const ValueKey('field-vehicle_cost')));
      await tap(find.text('Preview'));
      expect(find.text('Vehicle operating profit: 85000.00'), findsOneWidget);
      final table = t.widget<DataTable>(find.byType(DataTable));
      expect(
        table.columns.where(
          (c) => (c.label as Text).data == 'All vehicle costs',
        ),
        isEmpty,
      );
      if (find.text('Edit configuration').evaluate().isNotEmpty) {
        await tap(find.text('Edit configuration'));
      }
      await tap(find.text('Save named preset'));
      await t.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Preset name',
        ),
        'Synthetic native T12',
      );
      await tap(find.text('Save preset'));
      expect(find.byType(AlertDialog), findsNothing);
      await tap(find.text('Reload catalogue and presets'));
      await tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Saved preset'),
      );
      await tap(find.text('Personal: Synthetic native T12').last);
      expect(find.text('Vehicle operating profit: 85000.00'), findsOneWidget);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
