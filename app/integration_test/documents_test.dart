import '../test/bilingual_finders.dart';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/reports/output_repository.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Windows permanent issuance from current server source', (
    t,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate();
    final storage = SecureSessionStorage(
      namespace: 'native-documents.${DateTime.now().microsecondsSinceEpoch}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(localStorage: storage),
    );
    final client = Supabase.instance.client,
        session = StaffSession(client, config, storage);
    try {
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      await t.pumpWidget(
        MaterialApp(
          home: OutputWorkspace(
            commands: OutputRepository(client),
            documents: DocumentRepository(client),
            masters: SupabaseMasterRepository(client),
            trips: SupabaseTripRepository(client),
            offices: (session.profile!['offices'] as List)
                .map((r) => Map<String, dynamic>.from(r as Map))
                .toList(),
            administrator: false,
            initialCommand: const {
              'report_kind': 'CUSTOMER_INVOICE',
              'recipient_kind': 'CUSTOMER',
              'recipient_id': String.fromEnvironment('TEST_CUSTOMER_ID'),
              'filters': {
                'from': '2026-01-01',
                'to': '2026-12-31',
                'trip_id': String.fromEnvironment('TEST_TRIP_ID'),
              },
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      Future<void> tap(String text) async {
        final f = find.text(text);
        await t.ensureVisible(f);
        await t.tap(f);
        await t.pumpAndSettle();
      }

      await tap('Preview');
      await tap('Issue document');
      await tap('Confirm issuance');
      expect(
        find.text('Changed T13 Company'),
        findsNothing,
      ); // Header includes its descriptive label.
      expect(find.text('Company: Changed T13 Company'), findsOneWidget);
      expect(englishTextContaining('INV-'), findsWidgets);
      expect(find.text('Authoritative invoice total: 20000.00'), findsWidgets);
      expect(englishTextContaining('Issued snapshot.'), findsOneWidget);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
