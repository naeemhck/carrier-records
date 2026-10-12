import 'dart:convert';
import 'dart:io';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:carrier_records/features/reports/output_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Windows authorized PDF Excel and issued snapshot exports', (
    t,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate(),
        storage = SecureSessionStorage(
          namespace: 'native-exports.${DateTime.now().microsecondsSinceEpoch}',
        );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(localStorage: storage),
    );
    final client = Supabase.instance.client,
        session = StaffSession(client, config, storage),
        service = OutputExportService(
          ExportRepository(client),
          DocumentRepository(client),
        );
    final directory = Directory(
      const String.fromEnvironment('TEST_EXPORT_DIR'),
    );
    try {
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Local export verification')),
        ),
      );
      await t.runAsync(() async {
        final outputs = <String, Map<String, dynamic>>{};
        for (final c in [
          (
            'owner_full',
            'OWNER_STATEMENT',
            'OWNER',
            const String.fromEnvironment('TEST_OWNER_ID'),
          ),
          (
            'owner_hidden',
            'OWNER_STATEMENT',
            'OWNER',
            const String.fromEnvironment('TEST_OWNER_ID'),
          ),
          (
            'customer',
            'CUSTOMER_STATEMENT',
            'CUSTOMER',
            const String.fromEnvironment('TEST_CUSTOMER_ID'),
          ),
          (
            'broker',
            'BROKER_MONTHLY',
            'BROKER',
            const String.fromEnvironment('TEST_BROKER_ID'),
          ),
          ('wide_internal', 'OWNER_STATEMENT', 'INTERNAL', ''),
        ]) {
          final catalogue = Map<String, dynamic>.from(
            await client.rpc(
              'get_output_catalogue',
              params: {'report_kind': c.$2, 'recipient_kind': c.$3},
            ) as Map,
          );
          outputs[c.$1] = await service.live({
            'report_kind': c.$2,
            'recipient_kind': c.$3,
            'recipient_id': c.$4.isEmpty ? null : c.$4,
            'filters': const {
              'from': '2026-01-01',
              'to': '2026-12-31',
              'vehicle_id': String.fromEnvironment('TEST_VEHICLE_ID'),
            },
            'field_order': [
              for (final f in catalogue['fields'] as List)
                if (c.$1 != 'owner_hidden' || f['field_key'] != 'owner_cost')
                  f['field_key'],
            ],
            'format_options': {'orientation': 'AUTO', 'sheet_name': 'Records'},
            'preset_id': null,
            'event_id': null,
          });
        }
        for (final c in [
          ('issued_original', const String.fromEnvironment('TEST_ORIGINAL_ID')),
          (
            'issued_replacement',
            const String.fromEnvironment('TEST_REPLACEMENT_ID'),
          ),
          ('issued_receipt', const String.fromEnvironment('TEST_RECEIPT_ID')),
        ]) {
          outputs[c.$1] = await service.issued(c.$2);
        }
        expect(
          outputs['owner_full']!['totals'],
          outputs['owner_hidden']!['totals'],
        );
        expect(
          outputs['issued_original']!['totals']['invoice_total'],
          '100000.00',
        );
        expect(
          outputs['issued_replacement']!['totals']['invoice_total'],
          '20000.00',
        );
        for (final e in outputs.entries) {
          await File('${directory.path}/${e.key}.json')
              .writeAsString(jsonEncode(e.value));
          for (final format in ['pdf', 'xlsx']) {
            await File('${directory.path}/${e.key}.$format')
                .writeAsBytes(await service.generate(e.value, format));
          }
        }
        final info = await Printing.info(),
            printers = await Printing.listPrinters();
        expect(info.canPrint, isTrue);
        expect(info.canRaster, isTrue);
        final pdf = await File('${directory.path}/wide_internal.pdf')
            .readAsBytes();
        final first = await Printing.raster(pdf, pages: [0], dpi: 100).first;
        await File('${directory.path}/native-raster-first.png')
            .writeAsBytes(await first.toPng());
        await File('${directory.path}/printing-info.json').writeAsString(
          jsonEncode({
            'can_print': info.canPrint,
            'can_raster': info.canRaster,
            'printers': [for (final p in printers) p.name],
            'physical_print_completed': false,
            'android_device_checked': false,
          }),
        );
      });
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
