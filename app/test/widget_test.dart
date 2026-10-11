import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('application harness loads the setup route', (tester) async {
    await tester.pumpWidget(const CarrierRecordsApp());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.title), findsOneWidget);
    expect(find.text(AppStrings.setupPending), findsOneWidget);
  });
}
