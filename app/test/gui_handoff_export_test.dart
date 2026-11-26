import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:carrier_records/features/reports/output_pdf_v2.dart';
import 'package:carrier_records/features/reports/output_xlsx_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gui_handoff_fixture.dart';

/// Renders the one-record monthly-vehicle fixture through the app's own
/// template-2 exporters so the files can be inspected externally
/// (pdfinfo / pdftotext / sheet XML). Output directory is selected with
/// --dart-define=gui_out=before|after (default: before).
///
/// Regression assertions (GUI handoff groups 1 + 5): the statement PDF
/// is 2 pages for this one-record report (baseline: 8), and the XLSX
/// AutoFilter covers the record table only (A9:J10 — baseline A9:J37)
/// with a coherent Print_Area.
void main() {
  test('render monthly vehicle fixture exports', () async {
    const out = String.fromEnvironment('gui_out', defaultValue: 'before');
    final dir = Directory('../tools/.local/gui-verify/$out')
      ..createSync(recursive: true);
    final payload = monthlyVehicleFixture();
    Uint8List font(String name) =>
        Uint8List.fromList(File('assets/fonts/$name').readAsBytesSync());
    final pdf = await renderOutputPdfV2({
      'payload': payload,
      'regular': font('NotoSans-Regular.ttf'),
      'bold': font('NotoSans-Bold.ttf'),
      'arabic': font('NotoSansArabic-Regular.ttf'),
      'arabic_bold': font('NotoSansArabic-Bold.ttf'),
      'math': font('NotoSansMath-Regular.ttf'),
    });
    await File('${dir.path}/monthly-vehicle.pdf').writeAsBytes(pdf);
    final xlsx = renderOutputXlsxV2(payload);
    await File('${dir.path}/monthly-vehicle.xlsx').writeAsBytes(xlsx);
    expect(pdf.length, greaterThan(1000));

    // PDF: page objects are uncompressed even when content streams are
    // not; count '/Type /Page' entries excluding the '/Type /Pages' root.
    final pdfText = String.fromCharCodes(pdf.map((b) => b & 0xff));
    final pageCount = RegExp(r'/Type\s*/Page[^s]').allMatches(pdfText).length;
    expect(pageCount, 2, reason: 'one-record statement PDF must be 2 pages');

    // XLSX: filter boundary, print area/titles, numeric money values.
    final zip = ZipDecoder().decodeBytes(xlsx);
    String part(String name) => utf8.decode(
      zip.files.singleWhere((f) => f.name == name).content as List<int>,
    );
    final sheet = part('xl/worksheets/sheet1.xml');
    final workbook = part('xl/workbook.xml');
    expect(sheet, contains('<autoFilter ref="A9:J10"/>'));
    expect(workbook, contains('_xlnm.Print_Area'));
    expect(workbook, contains('_xlnm.Print_Titles'));
    expect(sheet, contains('<v>100000.00</v>'));
    expect(sheet, contains('<v>95000.00</v>'));
    expect(sheet, contains('<v>5000.00</v>'));
  });
}
