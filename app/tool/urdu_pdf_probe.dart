// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final font = pw.Font.ttf(
    ByteData.sublistView(
      await File('assets/fonts/NotoSansArabic-Regular.ttf').readAsBytes(),
    ),
  );
  final latin = pw.Font.ttf(
    ByteData.sublistView(
      await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes(),
    ),
  );
  final pdf = pw.Document(
    creator: 'Karvaan local typography probe',
    theme: pw.ThemeData.withFont(base: latin),
  );
  final samples = <String, String>{
    'Karvaan': 'کارواں',
    'Consignment': 'کنسائنمنٹ',
    'Custody / held funds': 'تحویل / رقم زیرِ تحویل',
    'Cost bearer': 'اخراجات کا ذمہ دار',
    'Settlement': 'تصفیہ',
    'Brokerage': 'کمیشن',
    'Mixed values': 'ٹرپ TRP-000001، رقم PKR 125,000.00، تاریخ 2026-10-13',
    'Wrapping': 'مالک کا کرایے میں حصہ اور اخراجات الگ ہیں۔ گاہک کی وصولی مالک کے واجبات کی ادائیگی نہیں ہے۔',
  };
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(
          'Karvaan English / Urdu shaping prototype',
          style: const pw.TextStyle(fontSize: 16),
        ),
        pw.SizedBox(height: 24),
        for (final e in samples.entries)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 18),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text(e.key)),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Text(
                    e.value,
                    textDirection: pw.TextDirection.rtl,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 14,
                      lineSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  final target = File('../tools/.local/karvaan-urdu-probe.pdf');
  await target.writeAsBytes(await pdf.save());
  print('Created synthetic Urdu shaping prototype.');
}
