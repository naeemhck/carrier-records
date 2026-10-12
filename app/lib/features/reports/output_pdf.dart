import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'authorized_output.dart';

/// Template v1 remains reproducible for issued snapshots.
Future<Uint8List> renderOutputPdf(Map<String, dynamic> args) async {
  final output = AuthorizedOutput.fromPayload(
    Map<String, dynamic>.from(args['payload'] as Map),
  );
  final regular = pw.Font.ttf(
    ByteData.sublistView(args['regular'] as Uint8List),
  );
  final bold = pw.Font.ttf(ByteData.sublistView(args['bold'] as Uint8List));
  final document = pw.Document(
    title: output.title,
    author: output.metadata['issuer_name'] as String? ?? 'Carrier Records',
    creator: 'Carrier Records',
    subject: output.metadata['scope'] as String? ?? '',
    keywords: 'PKR; authorized output',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final rows = output.layoutRows, columns = output.columns;
  final bandSize = output.landscape ? 4 : 3;
  final bands = [
    for (var i = 0; i < columns.length; i += bandSize)
      columns.sublist(i, (i + bandSize).clamp(0, columns.length)),
  ];
  for (var band = 0; band < bands.length; band++) {
    final selected = bands[band];
    pw.Widget text(String value, {bool heading = false}) => pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: heading ? 10 : 9,
        fontWeight: heading ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      softWrap: true,
    );
    pw.Widget cell(String value, {bool heading = false, bool money = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Align(
            alignment: money
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft,
            child: text(value, heading: heading),
          ),
        );
    document.addPage(
      pw.MultiPage(
        pageFormat: output.landscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 10000,
        header: (c) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                output.title,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (output.metadata['document_number'] != null)
                text(output.metadata['document_number'] as String),
              text(
                'Selected attributes ${band * bandSize + 1}-${band * bandSize + selected.length} of ${columns.length}',
              ),
            ],
          ),
        ),
        footer: (c) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              text('Page ${c.pageNumber} of ${c.pagesCount}'),
              text(
                output.metadata['supersedes_number'] == null
                    ? 'PKR | ${output.issued ? 'Issued snapshot' : 'Current authorized records'}'
                    : 'Supersedes ${output.metadata['supersedes_number']}',
              ),
            ],
          ),
        ),
        build: (c) => [
          if (band == 0) ...[
            for (final h in output.headers.where((h) => h.$3.isNotEmpty))
              for (final chunk in textChunks(h.$3, 500))
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: text('${h.$1}: $chunk'),
                ),
            pw.SizedBox(height: 8),
            text('Authoritative summary', heading: true),
            for (final e in output.totals.entries.where(
              (e) => !output.fields.any((f) => f.header && f.key == e.key),
            ))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: text(
                  '${output.summaries[e.key]}: ${displayValue(integerKeys.contains(e.key) ? 'INTEGER' : 'MONEY', e.value)}',
                ),
              ),
            pw.SizedBox(height: 12),
          ],
          if (rows.isEmpty) text('No records in this period/scope.'),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              for (var i = 0; i < selected.length; i++)
                i + 1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                repeat: true,
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  cell('Row', heading: true),
                  for (final f in selected) cell(f.label, heading: true),
                ],
              ),
              for (var row = 0; row < rows.length; row++)
                if (rows[row].part == 1 ||
                    selected.any(
                      (f) =>
                          f.key != 'record_name' &&
                          rows[row].values[columns.indexOf(f)] != null &&
                          rows[row].values[columns.indexOf(f)] != '',
                    ))
                  pw.TableRow(
                    children: [
                      cell(rows[row].label),
                      for (final f in selected)
                        cell(
                          displayValue(
                            f.type,
                            rows[row].values[columns.indexOf(f)],
                          ),
                          money: f.type == 'MONEY',
                        ),
                    ],
                  ),
            ],
          ),
          if (band == bands.length - 1)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 10),
              child: text(
                'Totals are server-calculated for all ${output.recordCount} authorized records. Long text uses continuation rows; amounts occur once per source record.',
              ),
            ),
        ],
      ),
    );
  }
  return document.save();
}
