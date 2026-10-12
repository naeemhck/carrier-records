import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'authorized_output.dart';
import 'document_repository.dart';
import 'output_pdf.dart';
import 'output_xlsx.dart';

abstract interface class ExportCommands {
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command);
}

class ExportRepository implements ExportCommands {
  ExportRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) async =>
      Map<String, dynamic>.from(
        await client.rpc('prepare_output_export', params: {'command': command})
            as Map,
      );
}

bool _same(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _same(a[i], b[i]));
  }
  return a == b;
}

class OutputExportService {
  OutputExportService(this.commands, this.documents);
  final ExportCommands commands;
  final DocumentCommands documents;
  Future<Map<String, dynamic>> live(Map<String, dynamic> command) async {
    final payload = await commands.prepare(command);
    AuthorizedOutput.fromPayload(payload);
    return payload;
  }

  Future<Map<String, dynamic>> issued(String id) async {
    // Reauthorize every print/export, including old snapshots and cached UI views.
    final doc = await documents.get(id),
        canonical = doc['canonical_content'] as String;
    if (sha256.convert(utf8.encode(canonical)).toString() !=
            doc['content_digest'] ||
        !_same(jsonDecode(canonical), doc['snapshot'])) {
      throw const FormatException('Issued content verification failed.');
    }
    final snapshot = Map<String, dynamic>.from(doc['snapshot'] as Map);
    AuthorizedOutput.fromPayload(snapshot);
    return snapshot;
  }

  Future<Uint8List> generate(
    Map<String, dynamic> payload,
    String format,
  ) async {
    AuthorizedOutput.fromPayload(payload);
    if (format == 'xlsx') {
      return compute(renderOutputXlsx, payload);
    }
    if (format != 'pdf') {
      throw const FormatException('Unsupported file type.');
    }
    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
        bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    return compute(renderOutputPdf, {
      'payload': payload,
      'regular': regular.buffer.asUint8List(
        regular.offsetInBytes,
        regular.lengthInBytes,
      ),
      'bold': bold.buffer.asUint8List(bold.offsetInBytes, bold.lengthInBytes),
    });
  }
}
