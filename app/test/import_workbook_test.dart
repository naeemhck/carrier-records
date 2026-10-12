import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:carrier_records/features/imports/import_workbook.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fields = {
    'EXPENSE_DRAFT': ['row_key', 'expense_date', 'amount', 'notes'],
  };
  final rows = [
    {
      'kind': 'EXPENSE_DRAFT',
      'row_key': 'cost1',
      'data': {
        'expense_date': '2026-10-13',
        'amount': '9999999999999999.99',
        'notes': 'Synthetic',
      },
    },
  ];
  Uint8List modified(String path, String Function(String) change) {
    final zip = ZipDecoder().decodeBytes(importTemplate(fields, rows: rows)),
        a = Archive();
    for (final f in zip.files) {
      final data = f.name == path
          ? utf8.encode(change(utf8.decode(f.content)))
          : f.content;
      a.addFile(ArchiveFile(f.name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(a));
  }

  test(
    'versioned template roundtrip preserves exact text money and ISO date',
    () {
      final parsed = ImportWorkbook.parse(
        importTemplate(fields, rows: rows),
        fields,
      );
      expect(parsed.errors, isEmpty);
      expect(parsed.rows, rows);
    },
  );
  test('formula cells are row errors even with cached benign values', () {
    final bytes = modified(
      'xl/worksheets/sheet1.xml',
      (s) => s.replaceFirst(
        '<c r="C3" s="1" t="inlineStr">',
        '<c r="C3" s="1" t="inlineStr"><f>1+1</f>',
      ),
    );
    expect(
      ImportWorkbook.parse(bytes, fields).errors.single['code'],
      'FORMULA_NOT_ALLOWED',
    );
  });
  test('Excel numeric amounts cannot disguise rounded money', () {
    final bytes = modified(
      'xl/worksheets/sheet1.xml',
      (s) => s.replaceFirst(
        RegExp(r'<c r="C3".*?</c>'),
        '<c r="C3"><v>10000000000000000</v></c>',
      ),
    );
    expect(
      ImportWorkbook.parse(bytes, fields).errors.single['code'],
      'AMOUNTS_AND_DATES_MUST_BE_TEXT',
    );
  });
  test('wrong version and changed headers are rejected', () {
    for (final change in [
      (String s) => s.replaceAll('import v1', 'import v2'),
      (String s) => s.replaceAll('expense_date', 'date'),
    ]) {
      expect(
        () => ImportWorkbook.parse(
          modified('xl/worksheets/sheet1.xml', change),
          fields,
        ),
        throwsFormatException,
      );
    }
  });
  test('hidden unsupported sheets and entity documents rejected', () {
    expect(
      () => ImportWorkbook.parse(
        modified(
          'xl/workbook.xml',
          (s) => s.replaceFirst('sheetId="1"', 'state="hidden" sheetId="1"'),
        ),
        fields,
      ),
      throwsFormatException,
    );
    expect(
      () => ImportWorkbook.parse(
        modified('xl/workbook.xml', (s) => '<!DOCTYPE workbook>$s'),
        fields,
      ),
      throwsFormatException,
    );
  });
  test('duplicate row keys and formula-like text produce row errors', () {
    final p = ImportWorkbook.parse(
      importTemplate(
        fields,
        rows: [
          ...rows,
          {
            'kind': 'EXPENSE_DRAFT',
            'row_key': 'cost1',
            'data': {'notes': '=1+1'},
          },
        ],
      ),
      fields,
    );
    expect(
      p.errors.map((e) => e['code']),
      containsAll(['FORMULA_NOT_ALLOWED', 'INVALID_OR_DUPLICATE_ROW_KEY']),
    );
  });
  test('external worksheet links and duplicate parts cannot bypass parsing', () {
    expect(() => ImportWorkbook.parse(modified('xl/_rels/workbook.xml.rels', (s) => s.replaceFirst('Target="worksheets/', 'TargetMode="External" Target="worksheets/')), fields), throwsFormatException);
    expect(() => ImportWorkbook.parse(modified('xl/worksheets/sheet1.xml', (s) => s.replaceFirst('<cols>', '<cols><col min="1" max="1" hidden="1"/>')), fields), throwsFormatException);
  });
}
