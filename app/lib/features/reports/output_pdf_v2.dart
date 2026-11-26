import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/bilingual_message.dart';
import '../../app/ui_catalogue.dart';
import 'authorized_output.dart';
import 'bilingual_output.dart';

/// Financial sections for the document totals, mirroring the on-screen
/// preview grouping (_previewTotalSections in output_workspace.dart).
/// Sections are presented as separate labelled blocks and are never
/// summed together.
const _pdfTotalSections = <(String, List<String>)>[
  ('earnings', ['customer_fare', 'owner_earnings', 'brokerage']),
  (
    'expensesProfit',
    ['vehicle_cost', 'owner_cost', 'operating_profit', 'owner_profit'],
  ),
  (
    'payments',
    [
      'receipts',
      'refunds',
      'owner_settled',
      'commission_settled',
      'credit_created',
      'credit_applied',
    ],
  ),
  ('customerOutstanding', ['customer_outstanding']),
  ('moneyHeld', ['customer_credit', 'custody']),
  (
    'ownerSettlement',
    [
      'owner_due',
      'owner_recovery',
      'brokerage_due',
      'brokerage_recovery',
      'funding_due',
      'reimbursement_due',
      'cost_recovery',
    ],
  ),
  ('activity', ['dispatched', 'arrived']),
];

/// Section headings are owned UI text (the same catalogue entries the
/// preview uses), never payload data.
Bilingual _pdfSectionLabel(String group) => switch (group) {
  'earnings' => L10n.earningsGroup,
  'expensesProfit' => L10n.expensesProfitGroup,
  'payments' => L10n.payments,
  'customerOutstanding' => L10n.customerOutstanding,
  'moneyHeld' => L10n.moneyHeldGroup,
  'ownerSettlement' => L10n.ownerSettlementGroup,
  'activity' => L10n.activityGroup,
  _ => L10n.otherTotalsGroup,
};

/// Report-format restyle of template 2 (newly issued documents only).
///
/// Page header: Karvaan/کاروان wordmark in brand green, the stacked report
/// title, a scope line (offices, period) and the generated-on timestamp in
/// Latin digits. Tables use hairlines only — no zebra striping, no colored
/// fills; amounts are right-aligned Latin digits. Every financial report ends
/// with a totals strip: key totals in bold green, outstanding / balance-due
/// rows highlighted #EAF4ED. Footer: page numbers, a bilingual "internal use"
/// note, and generation metadata (issuer, timestamp). Green appears only on
/// totals, status accents and the wordmark.
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
  const green = PdfColor.fromInt(0xFF0E7A3D);
  const dueHighlight = PdfColor.fromInt(0xFFEAF4ED);
  const hairline = PdfColors.grey400;
  pw.Widget latin(String value, {bool heading = false, PdfColor? color}) =>
      pw.Text(
        value,
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: heading ? bold : regular,
          fontFallback: [arabic, math],
          fontSize: heading ? 10 : 9,
          color: color,
        ),
        softWrap: true,
      );
  final urduRuns = RegExp(
    r'[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+(?:\s+[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]+)*',
  );
  pw.Widget data(String value, {bool heading = false, PdfColor? color}) {
    final matches = urduRuns.allMatches(value).toList();
    if (matches.isEmpty) return latin(value, heading: heading, color: color);
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
            color: color,
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

  pw.Widget label(FrozenLabel value, {bool heading = false, PdfColor? color}) =>
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            data(value.en, heading: heading, color: color),
            pw.Text(
              value.ur,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(
                font: heading ? arabicBold : arabic,
                fontFallback: [regular, math],
                fontSize: heading ? 10 : 9,
                height: 1.4,
                color: color,
              ),
              softWrap: true,
            ),
          ],
        ),
      );

  /// One-line bilingual pair ("English · اردو") for compact rows: the
  /// label's two languages share one line instead of stacking, halving
  /// the row height versus [label].
  pw.Widget inlineLabel(FrozenLabel value, {bool heading = false}) => pw.Wrap(
    crossAxisAlignment: pw.WrapCrossAlignment.center,
    children: [
      data(value.en, heading: heading),
      pw.Text(' · ', style: pw.TextStyle(font: regular, fontSize: 9)),
      pw.Text(
        value.ur,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          font: heading ? arabicBold : arabic,
          fontFallback: [regular, math],
          fontSize: 9,
          height: 1.4,
        ),
      ),
    ],
  );

  pw.Widget metadata(FrozenLabel name, String value) => pw.Inseparable(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 190, child: inlineLabel(name)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: data(value)),
        ],
      ),
    ),
  );

  /// Display text of a header field, or null when absent/empty.
  String? headerText(String key) {
    final field = base.fields
        .where((f) => f.header && f.key == key)
        .firstOrNull;
    if (field == null) return null;
    final text = displayValue(field.type, base.metadata[field.key]);
    return text.isEmpty ? null : text;
  }

  final scopeParts = [
    if (base.offices.join(', ').isNotEmpty) base.offices.join(', '),
    if (headerText('period') != null) headerText('period')!,
  ];
  // Human date-time on the document ("20 Oct 2026, 13:16") — the raw ISO
  // stamp with microseconds never prints.
  final generatedRaw = headerText('generated_at');
  final generatedAt = generatedRaw == null
      ? null
      : humanTimestampText(generatedRaw);
  final generatedLabel = output.labels['generated_at'];

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
  final columns = base.columns, rows = base.layoutRows;
  // Statement layout (GUI handoff group 1): record columns print as ONE
  // table in a single document flow — the page header identifies the
  // document on every page and the table header row repeats on
  // continuation pages. The single table is used only while every text
  // column keeps a readable minimum width beside the fixed money
  // columns; otherwise the sequential attribute bands remain the
  // fallback. (A squeezed text column can make a wrapped row taller
  // than the page, which cannot split — the wide bilingual fixture at
  // 12 columns / 5 money columns is exactly that case.)
  final moneyColumns = columns.where((c) => c.type == 'MONEY').length;
  final textColumns = columns.length - moneyColumns;
  final contentWidth =
      (base.landscape ? PdfPageFormat.a4.height : PdfPageFormat.a4.width) - 56;
  final singleTable =
      columns.length <= 12 &&
      contentWidth - 35 - moneyColumns * 76 >= textColumns * 64;
  final bandSize = singleTable
      ? (columns.isEmpty ? 1 : columns.length)
      : base.landscape
      ? 4
      : 3;
  final bands = [
    for (var i = 0; i < columns.length; i += bandSize)
      columns.sublist(i, (i + bandSize).clamp(0, columns.length)),
  ];

  /// Totals in their separate financial sections (never summed
  /// together): compact label/value rows, key totals in bold green,
  /// outstanding / balance-due rows highlighted #EAF4ED. With more than
  /// six entries the sections balance across two columns so the strip
  /// no longer dominates the document (GUI handoff group 1). Rendered
  /// once, at the end of the records table.
  pw.Widget totalsStrip() {
    final entries = base.totals.entries
        .where((e) => !base.fields.any((f) => f.header && f.key == e.key))
        .toList();
    final sections = <(String, List<MapEntry<String, dynamic>>)>[];
    final grouped = <String>{};
    for (final section in _pdfTotalSections) {
      final keys = section.$2
          .where((k) => entries.any((e) => e.key == k))
          .toList();
      if (keys.isNotEmpty) {
        sections.add((
          section.$1,
          [for (final k in keys) entries.firstWhere((e) => e.key == k)],
        ));
        grouped.addAll(keys);
      }
    }
    final rest = entries.where((e) => !grouped.contains(e.key)).toList();
    if (rest.isNotEmpty) sections.add(('other', rest));
    pw.Widget entryCell(MapEntry<String, dynamic> e) => pw.Container(
      decoration: isBalanceDueKey(e.key)
          ? const pw.BoxDecoration(color: dueHighlight)
          : null,
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 4),
      child: pw.Row(
        children: [
          pw.Expanded(child: inlineLabel(output.summaries[e.key]!)),
          pw.SizedBox(width: 8),
          data(
            displayValue(
              integerKeys.contains(e.key) ? 'INTEGER' : 'MONEY',
              e.value,
            ),
            heading: true,
            color: green,
          ),
        ],
      ),
    );
    pw.Widget sectionHeading((String, List<MapEntry<String, dynamic>>) s) {
      final heading = _pdfSectionLabel(s.$1);
      return pw.Padding(
        padding: const pw.EdgeInsets.only(top: 3, bottom: 1),
        child: inlineLabel(FrozenLabel(heading.en, heading.ur), heading: true),
      );
    }

    // Flat, page-splittable flow: section headings followed by entry
    // rows; with more than six entries the rows pack two per row. A
    // two-column pw.Row of section columns would be one unsplittable
    // widget taller than a page, so the pairing lives in the rows.
    final twoUp = entries.length > 6;
    final body = <pw.Widget>[];
    for (final s in sections) {
      final rows = <pw.Widget>[];
      if (!twoUp) {
        rows.addAll([for (final e in s.$2) entryCell(e)]);
      } else {
        for (var i = 0; i < s.$2.length; i += 2) {
          rows.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: entryCell(s.$2[i])),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: i + 1 < s.$2.length
                      ? entryCell(s.$2[i + 1])
                      : pw.SizedBox(),
                ),
              ],
            ),
          );
        }
      }
      if (rows.isEmpty) continue;
      // Keep the heading with at least its first row.
      body.add(
        pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [sectionHeading(s), rows.first],
          ),
        ),
      );
      body.addAll(rows.skip(1));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: hairline, width: .8)),
          ),
          padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
          child: inlineLabel(output.frames['summary']!, heading: true),
        ),
        ...body,
        pw.SizedBox(height: 4),
        inlineLabel(output.frames['totals']!.values([base.recordCount])),
        inlineLabel(output.frames['continuation']!),
      ],
    );
  }

  pw.Widget cell(pw.Widget child, {bool money = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(4),
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
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        maxPages: 10000,
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              label(output.brand, heading: true, color: green),
              label(output.titlePair, heading: true),
              if (base.metadata['document_number'] != null)
                data(base.metadata['document_number'] as String),
              if (scopeParts.isNotEmpty) data(scopeParts.join(' · ')),
              if (generatedAt != null && generatedLabel != null)
                inlineLabel(
                  FrozenLabel(
                    '${generatedLabel.en}: $generatedAt',
                    '${generatedLabel.ur}: $generatedAt',
                  ),
                ),
              if (bands.length > 1)
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
        footer: (context) {
          final issuer =
              base.metadata['issuer_name'] as String? ?? output.brand.en;
          final whenRaw =
              base.metadata['issued_at'] as String? ??
              base.metadata['generated_at'] as String? ??
              '';
          final when = humanTimestampText(whenRaw);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    inlineLabel(
                      output.frames['page']!.values([
                        context.pageNumber,
                        context.pagesCount,
                      ]),
                    ),
                    inlineLabel(output.internalUse),
                    if (when.isNotEmpty) data('$issuer · $when'),
                  ],
                ),
                // The issued-snapshot frame stays in the footer of issued
                // documents; on live previews the title already says
                // "not issued", so the live frame line is omitted.
                if (base.issued) ...[
                  pw.SizedBox(height: 4),
                  inlineLabel(output.frames['issued']!),
                ],
              ],
            ),
          );
        },
        build: (context) => [
          if (band == 0) ...[
            for (final field in base.fields.where((f) => f.header))
              if (displayValue(field.type, base.metadata[field.key]).isNotEmpty)
                for (final chunk in textChunks(
                  // The generated-at metadata value prints human with its
                  // declared zone — never the raw ISO stamp (handoff
                  // group 1); the page header already humanized it.
                  field.key == 'generated_at'
                      ? humanTimestampText(
                          displayValue(field.type, base.metadata[field.key]),
                        )
                      : displayValue(field.type, base.metadata[field.key]),
                  500,
                ))
                  metadata(output.labels[field.key]!, chunk),
            metadata(output.frames['offices']!, base.offices.join(', ')),
            // No date-bases block in the document body (owner directive,
            // reports pass): basis descriptors are internal metadata.
            // Currency and record-count frame rows are also omitted here:
            // every amount already prints "PKR …" and the totals frame
            // states the authorized record count (handoff group 1).
            if (base.metadata['supersedes_number'] != null) ...[
              metadata(
                output.frames['supersedes']!,
                base.metadata['supersedes_number'] as String,
              ),
            ],
            pw.SizedBox(height: 4),
          ],
          if (rows.isEmpty) label(output.frames['no_records']!),
          pw.Table(
            border: const pw.TableBorder(
              top: pw.BorderSide(color: hairline, width: .5),
              bottom: pw.BorderSide(color: hairline, width: .5),
              horizontalInside: pw.BorderSide(color: hairline, width: .4),
            ),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              for (var i = 0; i < selected.length; i++)
                i + 1: singleTable && selected[i].type == 'MONEY'
                    ? const pw.FixedColumnWidth(76)
                    : const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                repeat: true,
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
              padding: const pw.EdgeInsets.only(top: 6),
              child: totalsStrip(),
            ),
        ],
      ),
    );
  }
  return document.save();
}
