import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'authorized_output.dart';
import 'bilingual_output.dart';

String _xml(String value) =>
    cleanText(value)
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
String _column(int number) {
  var n = number + 1, text = '';
  while (n > 0) {
    n--;
    text = String.fromCharCode(65 + n % 26) + text;
    n ~/= 26;
  }
  return text;
}

bool _preciseInExcel(String money) =>
    money
        .replaceAll(RegExp(r'[-.]'), '')
        .replaceFirst(RegExp(r'^0+'), '')
        .length <=
    15;

/// Cell style indexes into the styles.xml cellXfs table below:
/// 0 normal, 1 workbook title, 2 column header (bold, no fill),
/// 3 money (PKR number format, right aligned), 4 date,
/// 5 totals label (bold), 6 totals integer (bold),
/// 7 totals money (bold, PKR format), 8 outstanding integer (bold, #EAF4ED),
/// 9 outstanding money (bold, PKR format, #EAF4ED).
int _dataStyle(String type) => switch (type) {
  'MONEY' => 3,
  'DATE' => 4,
  _ => 0,
};

int _totalValueStyle(String key, String type) {
  final due = isBalanceDueKey(key);
  return switch (type) {
    'MONEY' => due ? 9 : 7,
    'INTEGER' => due ? 8 : 6,
    _ => 5,
  };
}

/// Template 2 uses frozen bilingual labels; v1 is unchanged.
/// OOXML writes decimal tokens directly. No binary floating-point money conversion.
///
/// Layout mirrors the PDF: title and scope metadata on top, the frozen
/// bilingual header row, data rows, then a totals strip at the end — key
/// totals bold, outstanding / balance-due rows highlighted #EAF4ED. Amounts
/// are stored as real numbers (never text) so they sum. Green appears only
/// on the totals strip.
Uint8List renderOutputXlsxV2(Map<String, dynamic> payload) {
  final output = BilingualOutput(payload), archive = Archive();
  void file(String name, String value) {
    final bytes = utf8.encode(value);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  final width = math.max(2, output.columns.length), last = _column(width - 1);
  final rows = <String>[], merges = <String>[];
  int rowNumber = 0;
  bool wideMoney = false;
  String cell(
    int column,
    dynamic value, {
    String type = 'TEXT',
    int style = 0,
  }) {
    final ref = '${_column(column)}$rowNumber';
    if (value == null) {
      return '<c r="$ref" s="$style"/>';
    }
    if (type == 'MONEY') {
      validatedValue(type, value);
      if (_preciseInExcel(value as String)) {
        return '<c r="$ref" s="$style"><v>$value</v></c>';
      }
      wideMoney =
          true; // Excel has a 15-digit limit; preserve larger values as text.
    }
    if (type == 'INTEGER') {
      return '<c r="$ref" s="$style"><v>${value as int}</v></c>';
    }
    if (type == 'DATE') {
      final d = DateTime.parse(value as String);
      final serial = DateTime.utc(
        d.year,
        d.month,
        d.day,
      ).difference(DateTime.utc(1899, 12, 30)).inDays;
      return '<c r="$ref" s="$style"><v>$serial</v></c>';
    }
    // Explicit inline strings never become formulas, links or external references.
    return '<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${_xml(value.toString())}</t></is></c>';
  }

  void add(
    List<(dynamic, String, int)> values, {
    double height = 22,
    bool merged = false,
  }) {
    final explicitLines = values
        .map((v) => (v.$1?.toString() ?? '').split('\n').length)
        .fold<int>(1, math.max);
    height = math.max(height, explicitLines * 18 + 10);
    rowNumber++;
    rows.add(
      '<row r="$rowNumber" ht="$height" customHeight="1">${[for (var i = 0; i < values.length; i++) cell(i, values[i].$1, type: values[i].$2, style: values[i].$3)].join()}</row>',
    );
    if (merged) {
      merges.add('<mergeCell ref="A$rowNumber:$last$rowNumber"/>');
    }
  }

  add([(output.title, 'TEXT', 1)], height: 100, merged: true);
  for (final h in output.headers.where((h) => h.$3.isNotEmpty)) {
    for (final chunk in textChunks('${h.$1}: ${h.$3}', 450)) {
      add(
        [(chunk, 'TEXT', 0)],
        height: math.max(26, (chunk.length / (width * 22)).ceil() * 15 + 10),
        merged: true,
      );
    }
  }
  add([for (final f in output.columns) (f.label, 'TEXT', 2)], height: 80);
  final heading = rowNumber;
  for (final values in output.displayRows) {
    final lines = [
      for (var i = 0; i < values.length; i++)
        (displayValue(output.columns[i].type, values[i]).length / 24).ceil(),
    ].fold<int>(1, math.max);
    add([
      for (var i = 0; i < values.length; i++)
        (values[i], output.columns[i].type, _dataStyle(output.columns[i].type)),
    ], height: math.min(390, math.max(24, lines * 15 + 10)));
  }
  if (output.rows.isEmpty) {
    add([(output.frames['no_records']!.combined, 'TEXT', 0)], merged: true);
  }
  // Totals strip at the end, mirroring the PDF: bold totals, outstanding /
  // balance-due highlighted. Amounts stay real numbers so they sum.
  final totals = [
    for (final e in output.totals.entries.where(
      (e) => !output.fields.any((f) => f.header && f.key == e.key),
    ))
      e,
  ];
  if (totals.isNotEmpty) {
    add(
      [(output.frames['totals']!.values([output.recordCount]).combined, 'TEXT', 2)],
      merged: true,
    );
    for (final e in totals) {
      final type = integerKeys.contains(e.key) ? 'INTEGER' : 'MONEY';
      add([
        (output.summaries[e.key]!.combined, 'TEXT', 5),
        (e.value, type, _totalValueStyle(e.key, type)),
      ], height: 60);
    }
  }
  add(
    [(output.frames['continuation']!.combined, 'TEXT', 0)],
    height: 60,
    merged: true,
  );
  if (wideMoney) {
    add(
      [(output.frames['precision']!.combined, 'TEXT', 0)],
      height: 70,
      merged: true,
    );
  }
  file(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>''',
  );
  file(
    '_rels/.rels',
    '''<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>''',
  );
  file(
    'docProps/core.xml',
    '''<?xml version="1.0"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>${_xml(output.title)}</dc:title><dc:creator>${_xml(output.metadata['issuer_name'] as String? ?? output.brand.en)}</dc:creator><dc:description>${_xml(output.metadata['scope'] as String? ?? '')}</dc:description></cp:coreProperties>''',
  );
  file(
    'docProps/app.xml',
    '''<?xml version="1.0"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Karvaan</Application></Properties>''',
  );
  file(
    'xl/workbook.xml',
    '''<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets><sheet name="${_xml(output.sheetName)}" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm.Print_Titles" localSheetId="0">'${_xml(output.sheetName.replaceAll("'", "''"))}'!\$$heading:\$$heading</definedName></definedNames><calcPr calcId="191029"/></workbook>''',
  );
  file(
    'xl/_rels/workbook.xml.rels',
    '''<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>''',
  );
  file(
    'xl/styles.xml',
    '''<?xml version="1.0"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="&quot;PKR&quot; #,##0.00;[Red]&quot;PKR&quot; -#,##0.00"/><numFmt numFmtId="165" formatCode="dd mmm yyyy"/></numFmts><fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="16"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEAF4ED"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="10"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="top" wrapText="1" readingOrder="1"/></xf><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1" readingOrder="1"/></xf><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" vertical="top" wrapText="1" readingOrder="1"/></xf><xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"><alignment vertical="top"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment vertical="center" wrapText="1" readingOrder="1"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center" wrapText="1" readingOrder="1"/></xf><xf numFmtId="164" fontId="2" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" vertical="center" wrapText="1" readingOrder="1"/></xf><xf numFmtId="0" fontId="2" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="right" vertical="center" wrapText="1" readingOrder="1"/></xf><xf numFmtId="164" fontId="2" fillId="2" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="right" vertical="center" wrapText="1" readingOrder="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>''',
  );
  file(
    'xl/worksheets/sheet1.xml',
    '''<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:$last$rowNumber"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="$heading" topLeftCell="A${heading + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="22"/><cols>${[for (var i = 0; i < width; i++) '<col min="${i + 1}" max="${i + 1}" width="${i < output.columns.length && output.columns[i].type == 'MONEY' ? 23 : 32}" customWidth="1"/>'].join()}</cols><sheetData>${rows.join()}</sheetData><autoFilter ref="A$heading:${_column(output.columns.length - 1)}$rowNumber"/><mergeCells count="${merges.length}">${merges.join()}</mergeCells><pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.2" footer="0.2"/><pageSetup paperSize="9" orientation="${output.landscape ? 'landscape' : 'portrait'}" scale="100" fitToWidth="0" fitToHeight="0"/></worksheet>''',
  );
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
