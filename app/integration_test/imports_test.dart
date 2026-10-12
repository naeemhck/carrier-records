import 'dart:io';
import 'dart:typed_data';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/imports/import_workbook.dart';
import 'package:carrier_records/features/imports/import_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FixtureFiles implements ImportFiles {
  FixtureFiles(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> pick() async => bytes;
  @override
  Future<bool> save(Uint8List bytes) async {
    await File(
      '${const String.fromEnvironment('TEST_IMPORT_DIR')}/template.xlsx',
    ).writeAsBytes(bytes);
    return true;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real Windows XLSX import preview and explicit atomic confirmation',
    (t) async {
      final config = PublicConfig.fromEnvironment()..validate();
      final storage = SecureSessionStorage(
        namespace: 'native-imports.${DateTime.now().microsecondsSinceEpoch}',
      );
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.key,
        authOptions: FlutterAuthClientOptions(localStorage: storage),
      );
      final client = Supabase.instance.client,
          session = StaffSession(client, config, storage);
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      try {
        final cat = await client.rpc('get_import_templates') as Map;
        final fields = {
          for (final e in (cat['fields'] as Map).entries)
            '${e.key}': (e.value as List).cast<String>(),
        };
        final bytes = importTemplate(
          fields,
          rows: [
            {
              'kind': 'TRIP_DRAFT',
              'row_key': 'native-trip',
              'data': {
                'vehicle_code': 'T15-VEHICLE',
                'origin_code': 'O0',
                'destination_code': 'O1',
                'load_kind': 'EMPTY',
                'planned_dispatch_date': '2026-10-15',
                'notes': 'Synthetic native XLSX import',
              },
            },
          ],
        );
        await File(
          '${const String.fromEnvironment('TEST_IMPORT_DIR')}/input.xlsx',
        ).writeAsBytes(bytes);
        await t.pumpWidget(
          MaterialApp(
            home: ImportWorkspace(
              client: client,
              offices: (session.profile!['offices'] as List)
                  .map((x) => Map<String, dynamic>.from(x as Map))
                  .toList(),
              guard: (w) => w,
              files: FixtureFiles(bytes),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Download template'));
        await t.pumpAndSettle();
        await t.tap(find.text('Choose XLSX'));
        await t.pumpAndSettle();
        expect(find.text('Read 1 rows.'), findsOneWidget);
        await t.tap(find.text('Validate and preview'));
        await t.pumpAndSettle();
        expect(find.text('TRIP_DRAFT native-trip'), findsOneWidget);
        expect(
          find.text(
            'Import committed. Use Trips to review/dispatch trip drafts. Review expense drafts below before financial confirmation.',
          ),
          findsNothing,
        );
        await t.tap(find.text('Confirm reviewed import'));
        await t.pumpAndSettle();
        expect(find.text('Confirm reviewed import'), findsNWidgets(2));
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        await t.tap(find.text('Confirm reviewed import'));
        await t.pumpAndSettle();
        await t.tap(find.text('Confirm import'));
        await t.pumpAndSettle();
        expect(
          find.text(
            'Import committed. Use Trips to review/dispatch trip drafts. Review expense drafts below before financial confirmation.',
          ),
          findsOneWidget,
        );
      } finally {
        await session.signOut();
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
  );
}
