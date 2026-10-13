import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'authorized_output.dart';
import 'document_repository.dart';
import 'output_pdf.dart';
import 'output_xlsx.dart';
import 'bilingual_output.dart';
import 'output_pdf_v2.dart';
import 'output_xlsx_v2.dart';

void validateOutputVersion(Map<String, dynamic> payload) {
  if (payload['template_version'] == 2) {
    BilingualOutput(payload);
  } else {
    AuthorizedOutput.fromPayload(payload);
  }
}

abstract interface class ExportCommands {
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command);
}

class ExportRepository implements ExportCommands {
  ExportRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'prepare_output_export',
          params: {
            'command': {...command, 'presentation_version': 2},
          },
        ) as Map,
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
    validateOutputVersion(payload);
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
    validateOutputVersion(snapshot);
    return snapshot;
  }

  Future<Uint8List> generate(
    Map<String, dynamic> payload,
    String format,
  ) async {
    validateOutputVersion(payload);
    if (format == 'xlsx') {
      return compute(
        payload['template_version'] == 2
            ? renderOutputXlsxV2
            : renderOutputXlsx,
        payload,
      );
    }
    if (format != 'pdf') {
      throw const FormatException('Unsupported file type.');
    }
    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
        bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final args = <String, dynamic>{
      'payload': payload,
      'regular': regular.buffer.asUint8List(
        regular.offsetInBytes,
        regular.lengthInBytes,
      ),
      'bold': bold.buffer.asUint8List(bold.offsetInBytes, bold.lengthInBytes),
    };
    if (payload['template_version'] == 2) {
      for (final entry in {
        'arabic': 'NotoSansArabic-Regular.ttf',
        'arabic_bold': 'NotoSansArabic-Bold.ttf',
        'math': 'NotoSansMath-Regular.ttf',
      }.entries) {
        final data = await rootBundle.load('assets/fonts/${entry.value}');
        args[entry.key] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }
      return compute(renderOutputPdfV2, args);
    }
    return compute(renderOutputPdf, args);
  }
}
