import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:carrier_records/features/reports/authorized_output.dart';
import 'package:carrier_records/features/reports/output_pdf.dart';
import 'package:carrier_records/features/reports/output_xlsx.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> exportFixture({bool hidden = false, bool wide = false}) {
  final spec = [
    ('scope', 'Scope', 'TEXT', true),
    ('period', 'Period', 'TEXT', true),
    ('generated_at', 'Generated', 'TEXT', true),
    ('recipient_name', 'Recipient', 'TEXT', true),
    ('record_name', 'Trip', 'TEXT', false),
    ('owner_earnings', 'Owner fare share', 'MONEY', false),
    if (!hidden) ('owner_cost', 'Owner-borne costs', 'MONEY', false),
    ('owner_profit', 'Owner profit', 'MONEY', false),
    ('car_identifiers', 'Car identifiers', 'TEXT', false),
    if (wide) ...[
      ('vehicle_registration', 'Vehicle', 'TEXT', false),
      ('dispatch_date', 'Dispatch date', 'DATE', false),
      ('arrival_date', 'Arrival date', 'DATE', false),
      ('origin', 'Origin', 'TEXT', false),
      ('destination', 'Destination', 'TEXT', false),
      ('owner_settled', 'Owner settlements', 'MONEY', false),
      ('owner_due', 'Owner due', 'MONEY', false),
    ],
  ];
  return {
    'schema_version': 1,
    'template_version': 1,
    'report_kind': 'OWNER_STATEMENT',
    'recipient_kind': 'OWNER',
    'issued': false,
    'field_order': [for (final f in spec) f.$1],
    'fields': [
      for (final f in spec)
        {'field_key': f.$1, 'label': f.$2, 'value_type': f.$3, 'header': f.$4},
    ],
    'summary_fields': [
      {'field_key': 'owner_earnings', 'label': 'Owner fare share'},
      {'field_key': 'owner_cost', 'label': 'Owner-borne costs'},
      {'field_key': 'owner_profit', 'label': 'Owner profit'},
    ],
    'metadata': {
      'scope': 'Assigned-office records - not a complete business balance',
      'period': '2026-01-01 to 2026-04-30',
      'generated_at': '2026-10-11T12:00:00Z',
      'recipient_name': 'A very long synthetic owner name for wrapping, with transport and fleet responsibilities repeated across the full width of the header',
      'offices': ['Synthetic office zero'],
      'date_bases': {'earnings': 'Dispatch date', 'expenses': 'Expense date'},
      'private_source': 'FORBIDDEN-T14-PRIVATE',
    },
    'totals': {
      'owner_earnings': wide ? '760000.00' : '95000.00',
      'owner_cost': wide ? '80000.00' : '10000.00',
      'owner_profit': wide ? '680000.00' : '85000.00',
    },
    'rows': [
      for (var i = 0; i < (wide ? 8 : 1); i++)
        {
          'record_name': 'T14-TRIP-${i + 1}',
          'owner_earnings': '95000.00',
          'owner_cost': '10000.00',
          'owner_profit': '85000.00',
          'car_identifiers': wide
              ? List.generate(
                  12,
                  (n) => 'IDENTIFIER-${i + 1}-$n-LONG-CAR-TRANSPORT-REFERENCE',
                ).join(', ')
              : '=HYPERLINK("https://example.invalid","untrusted")',
          'vehicle_registration': 'T14-WIDE',
          'dispatch_date': '2026-01-30',
          'arrival_date': '2026-02-02',
          'origin': 'A long synthetic pickup office and customer loading point',
          'destination':
              'A long synthetic destination office and drop location',
          'owner_settled': '0.00',
          'owner_due': '95000.00',
          'private_source': 'FORBIDDEN-T14-PRIVATE',
        },
    ],
    'row_count': wide ? 8 : 1,
    'page_offset': 0,
    'has_more': false,
    'format_options': {'orientation': 'AUTO', 'sheet_name': 'Owner statement'},
    'raw_backend_object': {'secret': 'FORBIDDEN-T14-PRIVATE'},
  };
}

void main() {
  test('Selected fields never change canonical amounts; unsupported and forbidden data rejected', () {
    final full = AuthorizedOutput.fromPayload(exportFixture()),
        small = AuthorizedOutput.fromPayload(exportFixture(hidden: true));
    expect(full.totals, small.totals);
    expect(small.columns.any((f) => f.key == 'owner_cost'), isFalse);
    expect(
      () => AuthorizedOutput.fromPayload(
        exportFixture()..['totals'] = {'brokerage': '5000.00'},
      ),
      throwsFormatException,
    );
    expect(
      () => AuthorizedOutput.fromPayload(exportFixture()..['has_more'] = true),
      throwsFormatException,
    );
    expect(
      () => AuthorizedOutput.fromPayload(
        exportFixture()..['totals'] = {'owner_profit': 85000.0},
      ),
      throwsFormatException,
    );
  });
  test('Money formatting uses exact strings beyond double precision', () {
    expect(
      displayValue('MONEY', '123456789012345678901234567890.99'),
      'PKR 123,456,789,012,345,678,901,234,567,890.99',
    );
    expect(displayValue('MONEY', '-0.01'), 'PKR -0.01');
  });
  test('Actual XLSX uses explicit text, exact numeric tokens and no private source payload', () {
    final bytes = renderOutputXlsx(exportFixture());
    final zip = ZipDecoder().decodeBytes(bytes),
        xml = zip.files
            .where((f) => f.isFile)
            .map((f) => utf8.decode(f.content as List<int>))
            .join();
    expect(xml, contains('<v>95000.00</v>'));
    expect(xml, contains('inlineStr'));
    expect(xml, contains('=HYPERLINK'));
    expect(xml, isNot(contains('<f>')));
    expect(xml, isNot(contains('FORBIDDEN-T14-PRIVATE')));
    expect(xml, isNot(contains('hidden="')));
    expect(
      zip.files.where((f) => f.name.startsWith('xl/worksheets/')).length,
      1,
    );
  });
  test(
    'Actual XLSX preserves large money as canonical text rather than rounding',
    () {
      final payload = exportFixture();
      payload['totals']['owner_profit'] = '12345678901234567890.99';
      final bytes = renderOutputXlsx(payload),
          zip = ZipDecoder().decodeBytes(bytes);
      final xml = utf8.decode(
        zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
      );
      expect(xml, contains('12345678901234567890.99'));
      expect(xml, contains('numeric precision'));
    },
  );
  test('Generate actual compact, hidden-column and wide multi-page files for independent inspection', () async {
    final directory = Directory('../tools/.local/t14-unit-files')
      ..createSync(recursive: true);
    final regular = File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync(),
        bold = File('assets/fonts/NotoSans-Bold.ttf').readAsBytesSync();
    for (final item in [
      ('owner_full', exportFixture()),
      ('owner_hidden', exportFixture(hidden: true)),
      ('wide', exportFixture(wide: true)),
    ]) {
      final pdf = await renderOutputPdf({
        'payload': item.$2,
        'regular': Uint8List.fromList(regular),
        'bold': Uint8List.fromList(bold),
      });
      await File('${directory.path}/${item.$1}.pdf').writeAsBytes(pdf);
      await File('${directory.path}/${item.$1}.xlsx')
          .writeAsBytes(renderOutputXlsx(item.$2));
      await File('${directory.path}/${item.$1}.json')
          .writeAsString(jsonEncode(item.$2));
      expect(pdf.length, greaterThan(1000));
    }
  });
}
