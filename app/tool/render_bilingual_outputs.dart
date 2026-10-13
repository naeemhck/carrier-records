// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carrier_records/features/reports/output_pdf_v2.dart';
import 'package:carrier_records/features/reports/output_xlsx_v2.dart';

Future<void> main() async {
  final dir = Directory('../tools/.local/karvaan-documents');
  for (final file in dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('_v2.json'),
  )) {
    final payload = Map<String, dynamic>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
    final args = <String, dynamic>{
      'payload': payload,
      for (final e in {
        'regular': 'NotoSans-Regular.ttf',
        'bold': 'NotoSans-Bold.ttf',
        'arabic': 'NotoSansArabic-Regular.ttf',
        'arabic_bold': 'NotoSansArabic-Bold.ttf',
        'math': 'NotoSansMath-Regular.ttf',
      }.entries)
        e.key: Uint8List.fromList(
          File('assets/fonts/${e.value}').readAsBytesSync(),
        ),
    };
    final name = file.path.substring(0, file.path.length - 5);
    await File('$name.pdf').writeAsBytes(await renderOutputPdfV2(args));
    await File('$name.xlsx').writeAsBytes(renderOutputXlsxV2(payload));
    print(
      'Rendered authorized synthetic snapshot: ${file.uri.pathSegments.last}',
    );
  }
}
