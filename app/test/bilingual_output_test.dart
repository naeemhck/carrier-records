import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/features/reports/authorized_output.dart';
import 'package:carrier_records/features/reports/bilingual_output.dart';
import 'package:carrier_records/features/reports/output_pdf_v2.dart';
import 'package:carrier_records/features/reports/output_xlsx_v2.dart';
import 'package:flutter_test/flutter_test.dart';

import 'output_export_test.dart' show exportFixture;

Map<String, dynamic> bilingualFixture({
  bool hidden = false,
  bool wide = false,
}) {
  final p = exportFixture(hidden: hidden, wide: wide),
      base = AuthorizedOutput.fromPayload(p);
  Map<String, String> pair(String en) => {
    'en': en,
    'ur': ownedMessage(en).ur.isEmpty ? 'محفوظ عنوان' : ownedMessage(en).ur,
  };
  p['template_version'] = 2;
  p['presentation'] = {
    'version': 2,
    'font_set': 'noto-karvaan-20261013',
    'brand': pair('Karvaan'),
    'title': {'en': base.title, 'ur': 'مالک کا گوشوارہ - غیر جاری شدہ'},
    'fields': {for (final f in base.fields) f.key: pair(f.label)},
    'summaries': {for (final e in base.summaries.entries) e.key: pair(e.value)},
    'frames': {
      for (final key in BilingualOutput.frameKeys)
        key: pair(
          {
            'offices': 'Offices',
            'date_bases': 'Date bases',
            'currency': 'Currency',
            'records': 'Records',
            'supersedes': 'Supersedes',
            'row': 'Row',
            'summary': 'Authoritative summary',
            'no_records': 'No records in this period/scope.',
            'selected': 'Selected attributes {0}-{1} of {2}',
            'page': 'Page {0} of {1}',
            'issued': 'Issued snapshot',
            'live': 'Current authorized records',
            'continuation': 'Long text continues in visible rows; amounts appear once per source record.',
            'precision': 'Amounts exceeding Excel numeric precision remain exact decimal text; PKR is the currency.',
            'totals':
                'Totals are server-calculated for all {0} authorized records.',
          }[key]!,
        ),
    },
    'date_bases': {
      for (final e in base.bases.entries)
        e.key: {'en': '${e.key}: ${e.value}', 'ur': 'تاریخ کی محفوظ بنیاد'},
    },
  };
  p['metadata']['recipient_name'] =
      'مصنوعی مالک Synthetic fleet TRP-000001 2026-10-13 ' * 3;
  return p;
}

Map<String, dynamic> fontArgs(Map<String, dynamic> p) => {
  'payload': p,
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

void main() {
  test('frozen labels, selected order, hidden columns and exact totals', () {
    final full = BilingualOutput(bilingualFixture()),
        hidden = BilingualOutput(bilingualFixture(hidden: true));
    expect(full.totals, hidden.totals);
    expect(hidden.columns.map((f) => f.key), isNot(contains('owner_cost')));
    expect(
      hidden.base.fields.map((f) => f.key),
      bilingualFixture(hidden: true)['field_order'],
    );
    final old = bilingualFixture();
    old['presentation']['fields']['owner_profit']['ur'] = 'پرانا محفوظ لفظ';
    expect(BilingualOutput(old).labels['owner_profit']!.ur, 'پرانا محفوظ لفظ');
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (p) => p['presentation']['fields']['customer_outstanding'] = {
        'en': 'Leak',
        'ur': 'راز',
      },
      (p) =>
          p['presentation']['frames']['hidden'] = {'en': 'Leak', 'ur': 'راز'},
      (p) => p['presentation']['fields']['owner_profit']['en'] =
          'Changed identity',
      (p) => p['presentation']['version'] = 3,
      (p) => p['presentation']['frames']['row']['ur'] = 'قطار ۱۲',
      (p) =>
          p['totals'] = Map<String, dynamic>.from(p['totals'] as Map)
            ..['owner_profit'] = 85000.0,
      (p) => p['field_order'].remove('record_name'),
    ]) {
      final p = bilingualFixture();
      mutation(p);
      expect(
        () => BilingualOutput(p),
        throwsA(anyOf(isA<FormatException>(), isA<StateError>())),
      );
    }
  });
  test(
    'actual v2 workbook is formula safe, exact and redacted throughout ZIP',
    () {
      final p = bilingualFixture(),
          zip = ZipDecoder().decodeBytes(renderOutputXlsxV2(p));
      final xml = zip.files
          .where((f) => f.isFile)
          .map((f) => utf8.decode(f.content as List<int>))
          .join();
      expect(xml, contains('inlineStr'));
      expect(xml, contains('=HYPERLINK'));
      expect(xml, isNot(contains('<f>')));
      expect(xml, isNot(contains('FORBIDDEN-T14-PRIVATE')));
      expect(xml, isNot(contains('hidden="')));
      expect(xml, contains('<v>95000.00</v>'));
      expect(xml, contains('مالک'));
      expect(xml, contains('readingOrder="1"'));
      // Reports pass: no date-bases block in the workbook, and the
      // generated-at header is human — never the raw ISO stamp.
      expect(xml, isNot(contains('Date bases')));
      expect(xml, isNot(contains('2026-10-11T12:00:00Z')));
      expect(xml, contains('11 Oct 2026, 12:00'));
      expect(
        zip.files.where((f) => f.name.startsWith('xl/worksheets/')).length,
        1,
      );
    },
  );
  test(
    'render actual compact, hidden and wide bilingual synthetic files',
    () async {
      final dir = Directory('../tools/.local/karvaan-documents')
        ..createSync(recursive: true);
      for (final item in [
        ('unit_owner', bilingualFixture()),
        ('unit_hidden', bilingualFixture(hidden: true)),
        ('unit_wide', bilingualFixture(wide: true)),
      ]) {
        final bytes = await renderOutputPdfV2(fontArgs(item.$2));
        await File('${dir.path}/${item.$1}.pdf').writeAsBytes(bytes);
        await File('${dir.path}/${item.$1}.xlsx')
            .writeAsBytes(renderOutputXlsxV2(item.$2));
        await File('${dir.path}/${item.$1}.json')
            .writeAsString(jsonEncode(item.$2));
        expect(bytes.length, greaterThan(1000));
      }
    },
  );
  test('changed font bytes cannot silently alter frozen v2 reprints', () async {
    final args = fontArgs(bilingualFixture());
    (args['arabic'] as Uint8List)[100] ^= 1;
    await expectLater(renderOutputPdfV2(args), throwsFormatException);
  });
}
