import 'bilingual_finders.dart';

import 'dart:async';
import 'dart:convert';

import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:carrier_records/features/reports/output_export_service.dart';
import 'package:carrier_records/features/reports/output_file_actions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'output_export_test.dart' show exportFixture;

class Commands implements ExportCommands, DocumentCommands {
  Map<String, dynamic> document = {};
  int reads = 0;
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) async =>
      exportFixture();
  @override
  Future<Map<String, dynamic>> get(String id) async {
    reads++;
    return document;
  }

  @override
  Future<Map<String, dynamic>> issue(
    String request,
    Map<String, dynamic> payload,
  ) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> list(Map<String, dynamic> filters, int offset) =>
      throw UnimplementedError();
}

class Destination implements OutputDestination {
  int calls = 0;
  final completion = Completer<bool>();
  @override
  Future<bool> save(Uint8List bytes, String format, String name) {
    calls++;
    expect(bytes, isNotEmpty);
    expect(format, 'xlsx');
    return completion.future;
  }

  @override
  Future<bool> print(Uint8List bytes, String name) =>
      throw UnimplementedError();
}

void main() {
  test(
    'Issued exports re-read authority and reject changed snapshots or digests',
    () async {
      final commands = Commands(), payload = exportFixture();
      final canonical = jsonEncode(payload);
      commands.document = {
        'canonical_content': canonical,
        'snapshot': payload,
        'content_digest': sha256.convert(utf8.encode(canonical)).toString(),
      };
      final service = OutputExportService(commands, commands);
      expect(await service.issued('original'), payload);
      expect(await service.issued('original'), payload);
      expect(commands.reads, 2);
      commands.document['snapshot'] = {
        ...payload,
        'totals': {'owner_profit': '999999.00'},
      };
      await expectLater(service.issued('original'), throwsFormatException);
      commands.document['snapshot'] = payload;
      commands.document['content_digest'] = '0' * 64;
      await expectLater(service.issued('original'), throwsFormatException);
    },
  );

  testWidgets('Revoked access never reaches a file destination', (
    tester,
  ) async {
    final commands = Commands(), destination = Destination();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OutputFileActions(
            service: OutputExportService(commands, commands),
            destination: destination,
            load: () async => throw StateError('403'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save / share Excel'));
    await tester.pumpAndSettle();
    expect(destination.calls, 0);
    expect(englishTextContaining('Unable to export'), findsOneWidget);
    expect(
      find.text(
        defaultTargetPlatform == TargetPlatform.android
            ? 'Share completed.'
            : 'File saved.',
      ),
      findsNothing,
    );
  });

  for (final confirmed in [true, false]) {
    testWidgets('File success waits for destination confirmation: $confirmed', (
      tester,
    ) async {
      final commands = Commands(), destination = Destination();
      int loads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutputFileActions(
              service: OutputExportService(commands, commands),
              destination: destination,
              load: () async {
                loads++;
                return exportFixture();
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save / share Excel'));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && destination.calls == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      expect(loads, 1);
      expect(destination.calls, 1);
      expect(
        find.text(
          defaultTargetPlatform == TargetPlatform.android
              ? 'Share completed.'
              : 'File saved.',
        ),
        findsNothing,
      );
      destination.completion.complete(confirmed);
      await tester.pumpAndSettle();
      expect(
        find.text(
          defaultTargetPlatform == TargetPlatform.android
              ? 'Share completed.'
              : 'File saved.',
        ),
        confirmed ? findsOneWidget : findsNothing,
      );
      if (!confirmed) {
        expect(
          englishTextContaining('cancelled or not confirmed'),
          findsOneWidget,
        );
      }
    });
  }
}
