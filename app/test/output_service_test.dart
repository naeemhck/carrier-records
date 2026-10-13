import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:carrier_records/features/reports/output_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bilingual_output_test.dart' show bilingualFixture;

class SnapshotDocuments implements DocumentCommands {
  SnapshotDocuments(this.payload);
  Map<String, dynamic> payload;
  bool denied = false;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> get(String id) async {
    reads++;
    if (denied) throw StateError('Current access denied');
    return payload;
  }

  @override
  Future<Map<String, dynamic>> issue(
    String request,
    Map<String, dynamic> command,
  ) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> list(Map<String, dynamic> filters, int offset) =>
      throw UnimplementedError();
}

class UnusedExports implements ExportCommands {
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) =>
      throw UnimplementedError();
}

void main() {
  test(
    'issued v2 reauthorizes every use and verifies frozen labels in digest',
    () async {
      final snapshot = bilingualFixture(), canonical = jsonEncode(snapshot);
      final documents = SnapshotDocuments({
        'snapshot': snapshot,
        'canonical_content': canonical,
        'content_digest': sha256.convert(utf8.encode(canonical)).toString(),
      });
      final service = OutputExportService(UnusedExports(), documents);
      expect(await service.issued('synthetic-document'), snapshot);
      expect(await service.issued('synthetic-document'), snapshot);
      expect(documents.reads, 2);
      snapshot['presentation']['fields']['owner_profit']['ur'] = 'بدلا ہوا لفظ';
      await expectLater(
        service.issued('synthetic-document'),
        throwsFormatException,
      );
      documents.denied = true;
      await expectLater(service.issued('synthetic-document'), throwsStateError);
      expect(documents.reads, 4);
    },
  );
}
