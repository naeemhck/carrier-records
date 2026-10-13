import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'authorized_output.dart';
import 'bilingual_output.dart';

/// New issued documents use only their frozen v2 labels and pinned font set.
Future<Uint8List> renderOutputPdfV2(Map<String, dynamic> args) async {
  if (!const bool.fromEnvironment('use_arabic')) {
    throw const FormatException(
      'Arabic shaping must be enabled for template 2.',
    );
  }
  final output = BilingualOutput(
        Map<String, dynamic>.from(args['payload'] as Map),
      ),
      base = output.base;
  pw.Font font(String key) =>
      pw.Font.ttf(ByteData.sublistView(args[key] as Uint8List));
  for (final entry in {
    'regular':
        'b85c38ecea8a7cfb39c24e395a4007474fa5a4fc864f6ee33309eb4948d232d5',
    'bold': 'c976e4b1b99edc88775377fcc21692ca4bfa46b6d6ca6522bfda505b28ff9d6a',
    'arabic':
        '7d8bfab8154058b0b4fdaa12a23279c5392ec100c4529b82456cf68f37a43263',
    'arabic_bold':
        'ef1b7d85325ccae80717ba618166583c14d880bc3a2fdcd0de58c990cb5c1abf',
    'math': '3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d',
  }.entries) {
    if (sha256.convert(args[entry.key] as Uint8List).toString() !=
        entry.value) {
      throw const FormatException('Frozen font set mismatch.');
    }
  }
  final regular = font('regular'),
      bold = font('bold'),
      arabic = font('arabic'),
      arabicBold = font('arabic_bold'),
      math = font('math');
  pw.Widget latin(String value, {bool heading = false}) => pw.Text(
    value,
    textDirection: pw.TextDirection.ltr,
    style: pw.TextStyle(
      font: heading ? bold : regular,
      fontFallback: [arabic, math],
      fontSize: heading ? 10 : 9,
    ),
    softWrap: true,
  );
  final urduRuns = RegExp(
    r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+(?:\s+[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+)*',
  );
  pw.Widget data(String value, {bool heading = false}) {
    final matches = urduRuns.allMatches(value).toList();
    if (matches.isEmpty) return latin(value, heading: heading);
    final children = <pw.Widget>[];
    var end = 0;
    for (final match in matches) {
      if (match.start > end) {
        children.add(
          latin(value.substring(end, match.start), heading: heading),
        );
      }
      children.add(
        pw.Text(
          match.group(0)!,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: heading ? arabicBold : arabic,
            fontFallback: [regular, math],
            fontSize: heading ? 10 : 9,
            height: 1.4,
          ),
        ),
      );
      end = match.end;
    }
    if (end < value.length) {
      children.add(latin(value.substring(end), heading: heading));
    }
    return pw.Wrap(children: children, runSpacing: 2);
  }

  pw.Widget label(FrozenLabel value, {bool heading = false}) => pw.Inseparable(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        data(value.en, heading: heading),
        pw.Text(
          value.ur,
          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(
            font: heading ? arabicBold : arabic,
            fontFallback: [regular, math],
            fontSize: heading ? 10 : 9,
            height: 1.4,
          ),
          softWrap: true,
        ),
      ],
    ),
  );
  pw.Widget metadata(FrozenLabel name, String value) => pw.Inseparable(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 150, child: label(name)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: data(value)),
        ],
      ),
    ),
  );
  final document = pw.Document(
    title: output.titlePair.en,
    creator: output.brand.en,
    author: base.metadata['issuer_name'] as String? ?? output.brand.en,
    subject: base.metadata['scope'] as String? ?? '',
    keywords: 'PKR; authorized output; template 2',
    theme: pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [arabic, math],
    ),
  );
  final columns = base.columns,
      rows = base.layoutRows,
      bandSize = base.landscape ? 4 : 3;
  final bands = [
    for (var i = 0; i < columns.length; i += bandSize)
      columns.sublist(i, (i + bandSize).clamp(0, columns.length)),
  ];
  pw.Widget cell(pw.Widget child, {bool money = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(5),
    child: pw.Align(
      alignment: money ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: child,
    ),
  );
  for (var band = 0; band < bands.length; band++) {
    final selected = bands[band];
    document.addPage(
      pw.MultiPage(
        pageFormat: base.landscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 10000,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              label(output.brand, heading: true),
              label(output.titlePair, heading: true),
              if (base.metadata['document_number'] != null)
                data(base.metadata['document_number'] as String),
              label(
                output.frames['selected']!.values([
                  band * bandSize + 1,
                  band * bandSize + selected.length,
                  columns.length,
                ]),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              label(
                output.frames['page']!.values([
                  context.pageNumber,
                  context.pagesCount,
                ]),
              ),
              label(output.frames[base.issued ? 'issued' : 'live']!),
            ],
          ),
        ),
        build: (context) => [
          if (band == 0) ...[
            for (final field in base.fields.where((f) => f.header))
              if (displayValue(field.type, base.metadata[field.key]).isNotEmpty)
                for (final chunk in textChunks(
                  displayValue(field.type, base.metadata[field.key]),
                  500,
                ))
                  metadata(output.labels[field.key]!, chunk),
            metadata(output.frames['offices']!, base.offices.join(', ')),
            label(output.frames['date_bases']!),
            for (final basis in output.dates.values) label(basis),
            if (base.metadata['supersedes_number'] != null) ...[
              metadata(
                output.frames['supersedes']!,
                base.metadata['supersedes_number'] as String,
              ),
            ],
            metadata(output.frames['currency']!, 'PKR'),
            metadata(output.frames['records']!, base.recordCount.toString()),
            pw.SizedBox(height: 8),
            label(output.frames['summary']!, heading: true),
            for (final e in base.totals.entries.where(
              (e) => !base.fields.any((f) => f.header && f.key == e.key),
            ))
              metadata(
                output.summaries[e.key]!,
                displayValue(
                  integerKeys.contains(e.key) ? 'INTEGER' : 'MONEY',
                  e.value,
                ),
              ),
            pw.SizedBox(height: 12),
          ],
          if (rows.isEmpty) label(output.frames['no_records']!),
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
                  cell(label(output.frames['row']!, heading: true)),
                  for (final f in selected)
                    cell(label(output.labels[f.key]!, heading: true)),
                ],
              ),
              for (final row in rows)
                if (row.part == 1 ||
                    selected.any(
                      (f) =>
                          f.key != 'record_name' &&
                          row.values[columns.indexOf(f)] != null &&
                          row.values[columns.indexOf(f)] != '',
                    ))
                  pw.TableRow(
                    children: [
                      cell(data(row.label)),
                      for (final f in selected)
                        cell(
                          data(
                            displayValue(
                              f.type,
                              row.values[columns.indexOf(f)],
                            ),
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
              child: pw.Column(
                children: [
                  label(output.frames['totals']!.values([base.recordCount])),
                  label(output.frames['continuation']!),
                ],
              ),
            ),
        ],
      ),
    );
  }
  return document.save();
}
