import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
String _col(int n) {
  var s = '';
  do {
    s = String.fromCharCode(65 + n % 26) + s;
    n = n ~/ 26 - 1;
  } while (n >= 0);
  return s;
}

/// All editable cells are text: Excel must not round amounts or infer dates.
Uint8List importTemplate(
  Map<String, List<String>> fields, {
  List<Map<String, dynamic>> rows = const [],
}) {
  final a = Archive();
  void put(String name, String text) {
    final b = utf8.encode(text);
    a.addFile(ArchiveFile(name, b.length, b));
  }

  final sheets = fields.keys.toList();
  String cell(String ref, String text) =>
      '<c r="$ref" s="1" t="inlineStr"><is><t xml:space="preserve">${_escape(text)}</t></is></c>';
  for (var i = 0; i < sheets.length; i++) {
    final kind = sheets[i], keys = fields[kind]!;
    final rs = rows.where((r) => r['kind'] == kind).toList();
    final body = StringBuffer(
      '<row r="1">${cell('A1', 'Carrier Records import v1')}</row><row r="2">',
    );
    for (var j = 0; j < keys.length; j++) {
      body.write(cell('${_col(j)}2', keys[j]));
    }
    body.write('</row>');
    for (var n = 0; n < (rs.isEmpty ? 1 : rs.length); n++) {
      final r = rs.isEmpty ? <String, dynamic>{} : rs[n],
          d = (r['data'] as Map?) ?? {};
      body.write('<row r="${n + 3}">');
      for (var j = 0; j < keys.length; j++) {
        body.write(
          cell(
            '${_col(j)}${n + 3}',
            '${keys[j] == 'row_key' ? r['row_key'] ?? '' : d[keys[j]] ?? ''}',
          ),
        );
      }
      body.write('</row>');
    }
    put(
      'xl/worksheets/sheet${i + 1}.xml',
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="2" topLeftCell="A3" state="frozen"/></sheetView></sheetViews><cols><col min="1" max="${keys.length}" width="26" customWidth="1" style="1"/></cols><sheetData>$body</sheetData></worksheet>',
    );
  }
  put(
    'xl/workbook.xml',
    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${[for (var i = 0; i < sheets.length; i++) '<sheet name="${sheets[i]}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>',
  );
  put(
    'xl/_rels/workbook.xml.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}<Relationship Id="styles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
  );
  put(
    '_rels/.rels',
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="book" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
  );
  put(
    'xl/styles.xml',
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="2"><xf/><xf numFmtId="49" applyNumberFormat="1"><alignment wrapText="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>',
  );
  put(
    '[Content_Types].xml',
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>',
  );
  return Uint8List.fromList(ZipEncoder().encode(a));
}

class ImportWorkbook {
  ImportWorkbook(this.rows, this.errors);
  final List<Map<String, dynamic>> rows, errors;
  static ImportWorkbook parse(
    Uint8List bytes,
    Map<String, List<String>> fields,
  ) {
    if (bytes.length > 5242880) {
      throw const FormatException('XLSX must be at most 5 MB.');
    }
    final zip = ZipDecoder().decodeBytes(bytes, verify: true),
        files = <String, String>{};
    var size = 0;
    final names = <String>{};
    if (zip.files.length > 200) {
      throw const FormatException('Too many XLSX parts.');
    }
    for (final f in zip.files.where((f) => f.isFile)) {
      if (!names.add(f.name)) {
        throw const FormatException('Duplicate workbook part.');
      }
      size += f.size;
      if (size > 20971520 ||
          f.name.contains('..') ||
          f.name.contains('vba') ||
          f.name.contains('externalLinks') ||
          f.name.contains('embeddings')) {
        throw const FormatException('Unsupported or oversized workbook.');
      }
      if (f.name.endsWith('.xml') || f.name.endsWith('.rels')) {
        final text = utf8.decode(f.content);
        if (text.contains('<!DOCTYPE') || text.contains('<!ENTITY')) {
          throw const FormatException('XML entities are not supported.');
        }
        files[f.name] = text;
      }
    }
    XmlDocument doc(String path) => XmlDocument.parse(
      files[path] ?? (throw FormatException('Missing XLSX part: $path')),
    );
    final shared = files.containsKey('xl/sharedStrings.xml')
        ? doc('xl/sharedStrings.xml')
              .findAllElements('si')
              .map((s) => s.findAllElements('t').map((t) => t.innerText).join())
              .toList()
        : <String>[];
    final rels = {
      for (final r in doc(
        'xl/_rels/workbook.xml.rels',
      ).findAllElements('Relationship'))
        r.getAttribute('Id'): r.getAttribute('Target'),
    };
    if (doc('xl/_rels/workbook.xml.rels')
        .findAllElements('Relationship')
        .any((r) => r.getAttribute('TargetMode') == 'External')) {
      throw const FormatException('External workbook links are not supported.');
    }
    final rows = <Map<String, dynamic>>[], errors = <Map<String, dynamic>>[];
    final seenSheets = <String>{}, seenKeys = <String>{};
    for (final s in doc('xl/workbook.xml').findAllElements('sheet')) {
      final kind = s.getAttribute('name')!;
      if (!fields.containsKey(kind) ||
          !seenSheets.add(kind) ||
          (s.getAttribute('state') ?? 'visible') != 'visible') {
        throw const FormatException(
          'Unsupported, duplicate or hidden worksheet.',
        );
      }
      final id = s.attributes.firstWhere((a) => a.name.local == 'id').value;
      final target = rels[id]!;
      if (target.contains('..') || target.contains(':')) {
        throw const FormatException('Invalid worksheet path.');
      }
      final sheet = doc(
        target.startsWith('/') ? target.substring(1) : 'xl/$target',
      );
      if (sheet
          .findAllElements('col')
          .any((c) => ['1', 'true'].contains(c.getAttribute('hidden')))) {
        throw const FormatException('Hidden columns are not supported.');
      }
      final grid = <int, Map<int, (String, String)>>{};
      for (final r in sheet.findAllElements('row')) {
        final n = int.parse(r.getAttribute('r')!);
        if (n > 1002 || ['1', 'true'].contains(r.getAttribute('hidden'))) {
          throw const FormatException('Too many or hidden rows.');
        }
        final cells = <int, (String, String)>{};
        for (final c in r.findElements('c')) {
          final ref = c.getAttribute('r')!,
              letters = RegExp(r'^[A-Z]+').stringMatch(ref)!;
          var col = 0;
          for (final code in letters.codeUnits) {
            col = col * 26 + code - 64;
          }
          if (col > fields[kind]!.length || cells.containsKey(col - 1)) {
            throw const FormatException('Extra or duplicate columns.');
          }
          final type = c.getAttribute('t') ?? 'n';
          var value = c.findElements('v').firstOrNull?.innerText ?? '';
          if (type == 'inlineStr') {
            value = c.findAllElements('t').map((t) => t.innerText).join();
          }
          if (type == 's') {
            value = shared[int.parse(value)];
          }
          if (c.findElements('f').isNotEmpty) {
            errors.add({'kind': kind, 'row': n, 'code': 'FORMULA_NOT_ALLOWED'});
          }
          cells[col - 1] = (value, type);
        }
        grid[n] = cells;
      }
      if (grid[1]?[0]?.$1 != 'Carrier Records import v1') {
        throw const FormatException('Unsupported template version.');
      }
      final headers = fields[kind]!;
      for (var i = 0; i < headers.length; i++) {
        if (grid[2]?[i]?.$1 != headers[i]) {
          throw const FormatException(
            'Template headers changed. Download the current template.',
          );
        }
      }
      for (final entry in grid.entries.where((e) => e.key >= 3)) {
        if (entry.value.values.every((v) => v.$1.isEmpty)) {
          continue;
        }
        final data = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          final value = entry.value[i] ?? ('', 'inlineStr'), key = headers[i];
          data[key] = value.$1.trim();
          if (value.$1.isNotEmpty &&
              [
                'amount',
                'quoted_amount',
                'commission_value',
                'suggested_fare',
                'expense_date',
                'planned_dispatch_date',
              ].contains(key) &&
              !['s', 'inlineStr'].contains(value.$2)) {
            errors.add({
              'kind': kind,
              'row': entry.key,
              'code': 'AMOUNTS_AND_DATES_MUST_BE_TEXT',
            });
          }
          if (RegExp(r'^\s*[=+@]').hasMatch(value.$1)) {
            errors.add({
              'kind': kind,
              'row': entry.key,
              'code': 'FORMULA_NOT_ALLOWED',
            });
          }
        }
        final key = data.remove('row_key')!;
        if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(key) ||
            !seenKeys.add(key)) {
          errors.add({
            'kind': kind,
            'row': entry.key,
            'code': 'INVALID_OR_DUPLICATE_ROW_KEY',
          });
        }
        rows.add({'kind': kind, 'row_key': key, 'data': data});
      }
    }
    if (seenSheets.length != fields.length ||
        rows.length > 1000 ||
        rows.isEmpty) {
      throw const FormatException(
        'Use all template sheets; enter 1 to 1000 rows.',
      );
    }
    return ImportWorkbook(rows, errors);
  }
}
