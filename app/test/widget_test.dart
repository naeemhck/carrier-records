import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/strings.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('application harness loads the setup route', (tester) async {
    await tester.pumpWidget(const CarrierRecordsApp());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.title), findsOneWidget);
    expect(find.text(AppStrings.setupPending), findsOneWidget);
  });
  testWidgets('failed secure startup displays both languages without sign-in', (
    tester,
  ) async {
    const message =
        'Secure sign-in could not start. Ask your administrator to check this installation.';
    await tester.pumpWidget(const CarrierRecordsApp(setupError: message));
    await tester.pumpAndSettle();
    final error = tester
        .widgetList<BilingualText>(find.byType(BilingualText))
        .singleWhere((widget) => widget.text.en == message);
    expect(error.text.ur, contains('محفوظ'));
    expect(error.text.ur, contains('منتظم'));
    expect(find.byType(BilingualCaption), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
