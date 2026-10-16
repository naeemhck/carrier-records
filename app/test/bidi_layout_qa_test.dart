import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_layout_qa_test.dart' show captureTextQa;

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('structured route and isolated mixed runs $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const origin = 'Karachi کراچی KHI-01';
        const destination = 'Islamabad اسلام آباد ISB-02';
        final dates = L10n.dispatchArrival.withValues([
          '2026-10-16',
          '2026-10-17',
        ]);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Directionality(
                          textDirection: TextDirection.rtl,
                          child: RouteLabel(
                            origin: origin,
                            destination: destination,
                          ),
                        ),
                        BilingualText(dates),
                        const BilingualText(L10n.excelImports),
                        BilingualText(
                          L10n.reviewPKR.withValues([
                            'PAYMENT',
                            '2026-10-16',
                            'Payer کراچی',
                            'Payee اسلام آباد',
                            '100000.00',
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text(origin)).dx,
          lessThan(tester.getTopLeft(find.text(destination)).dx),
        );
        expect(tester.widget<Text>(find.text(origin)).data, origin);
        expect(tester.widget<Text>(find.text(destination)).data, destination);
        final excel = find.text(L10n.excelImports.ur);
        final paragraph = tester.renderObject<RenderParagraph>(excel);
        final start = L10n.excelImports.ur.indexOf('Excel');
        final latin = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 5),
        );
        expect(latin, hasLength(1));
        expect(latin.single.direction, TextDirection.ltr);
        expect(RegExp('[۰-۹٠-٩]').hasMatch(dates.ur), isFalse);
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => captureTextQa(tester, key, 'bidi-$width-$scale'),
        );
      });
    }
  }
}
