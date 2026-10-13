import '../test/bilingual_finders.dart';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Windows scoped report with January server earnings', (
    tester,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate();
    final storage = SecureSessionStorage(
      namespace: 'native-reports.${DateTime.now().microsecondsSinceEpoch}',
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
      await tester.pumpWidget(
        MaterialApp(
          home: ReportWorkspace(
            reports: ReportRepository(client),
            trips: SupabaseTripRepository(client),
            masters: SupabaseMasterRepository(client),
            offices: (session.profile!['offices'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        ('From (YYYY-MM-DD)', '2026-01-01'),
        ('To (YYYY-MM-DD)', '2026-01-31'),
        ('Trip / vehicle search', 'T11-SYNTHETIC'),
      ]) {
        final f = find.byWidgetPredicate(
          (w) => w is TextField && hasEnglishLabel(w.decoration, entry.$1),
        );
        await tester.ensureVisible(f);
        await tester.enterText(f, entry.$2);
      }
      await tester.ensureVisible(find.text('Run report'));
      await tester.tap(find.text('Run report'));
      await tester.pumpAndSettle();
      expect(
        englishTextContaining('not a complete business balance'),
        findsOneWidget,
      );
      expect(
        englishTextContaining(
          'Owner earnings — dispatch / adjustment date: PKR 95000.00',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ExpansionTile, 'T11-SYNTHETIC'),
        findsOneWidget,
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
