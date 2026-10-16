import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/features/auth/staff_session.dart';

class TextQaSession extends ChangeNotifier implements StaffSession {
  @override
  Map<String, dynamic>? profile;
  @override
  String? error;
  @override
  Future<void> signIn(String username, String password) async {
    throw const FormatException('Synthetic rejected sign-in');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> captureTextQa(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  const phase = String.fromEnvironment('TEXT_QA_PHASE', defaultValue: 'after');
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('../tools/.local/text-qa/widgets/$phase/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final change in [false, true]) {
        testWidgets(
          'Arabic natural metrics auth change=$change width=$width scale=$scale',
          (tester) async {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final session = TextQaSession();
            if (change) {
              session.profile = {
                'id': 'synthetic',
                'role': 'STAFF',
                'must_change_password': true,
                'display_name': 'Synthetic',
                'offices': [],
              };
            }
            final key = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: KarvaanDesign.theme(),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: key,
                    child: StaffHome(session: session),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.runAsync(
              () => captureTextQa(
                tester,
                key,
                'auth-${change ? 'change' : 'signin'}-$width-$scale',
              ),
            );
            final phrase = change
                ? L10n.changeYourTemporaryPassword
                : L10n.staffSignIn;
            final text = tester.widget<Text>(find.text(phrase.ur));
            final actual = tester.getSize(find.text(phrase.ur));
            final natural = TextPainter(
              text: TextSpan(
                text: phrase.ur,
                style: TextStyle(
                  inherit: false,
                  fontFamily: 'NotoSansArabic',
                  fontSize: text.style!.fontSize,
                  fontWeight: FontWeight.w400,
                ),
              ),
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.linear(scale),
            )..layout(maxWidth: actual.width);
            expect(
              actual.height,
              greaterThanOrEqualTo(natural.height - .1),
              reason: 'Real bundled font descenders must fit; no smaller forced line height',
            );
            natural.dispose();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
