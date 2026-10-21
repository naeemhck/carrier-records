import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_layout_qa_test.dart' show TextQaSession, captureTextQa;

void main() {
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'safe login feedback visible and synthetic password obscured $width/$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: KarvaanDesign.theme(),
              builder: (_, child) => RepaintBoundary(key: key, child: child!),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: StaffHome(session: TextQaSession()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).first,
            'synthetic-review',
          );
          const synthetic = 'qa-mask-123456';
          await tester.enterText(find.byType(TextField).last, synthetic);
          await tester.pump(const Duration(seconds: 2));
          final password = tester.widget<TextField>(
            find.byType(TextField).last,
          );
          expect(password.obscureText, isTrue);
          expect(password.enableSuggestions, isFalse);
          final editable = tester
              .state<EditableTextState>(find.byType(EditableText).last)
              .renderEditable;
          expect(editable.text!.toPlainText(), isNot(contains(synthetic)));
          await tester.runAsync(
            () => captureTextQa(tester, key, 'synthetic-mask-$width-$scale'),
          );
          await tester.ensureVisible(find.text(L10n.signIn.en));
          await tester.pumpAndSettle();
          await tester.tap(find.text(L10n.signIn.en));
          await tester.pumpAndSettle();
          final feedback = find.text(
            L10n
                .requestFailedCheckYourCredentialsConnectionOrAdministratorAccess
                .en,
          );
          expect(feedback, findsOneWidget);
          // Header compaction: the sign-in screen has no AppBar — its
          // title is the compact ShellHeader row. The feedback must sit
          // below that header row, as it sat below the AppBar before.
          expect(
            tester.getRect(feedback).top,
            greaterThanOrEqualTo(
              tester.getRect(find.byType(BilingualHeaderTitle)).bottom,
            ),
          );
          expect(tester.getRect(feedback).bottom, lessThanOrEqualTo(1100));
          expect(
            tester
                .widgetList<Semantics>(find.byType(Semantics))
                .any((w) => w.properties.liveRegion == true),
            isTrue,
          );
          expect(
            find.textContaining('Synthetic rejected sign-in'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => captureTextQa(tester, key, 'auth-error-$width-$scale'),
          );
        },
      );
    }
  }
}
