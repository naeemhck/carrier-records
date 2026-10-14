import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const fixtureAccounts = [
  {
    'id': 'synthetic-admin',
    'display_name': 'Opaque name نام',
    'username': 'synthetic_admin',
    'role': 'ADMIN',
    'active': true,
    'must_change_password': true,
  },
  {
    'id': 'synthetic-staff',
    'display_name': 'Unchanged staff',
    'username': 'synthetic_staff',
    'role': 'STAFF',
    'active': false,
    'must_change_password': false,
  },
];

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('actual account rows translate owned state at width $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final managed = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: fixtureAccounts
                    .map(
                      (account) => AccountRow(
                        account: account,
                        onManage: () => managed.add(account['id']! as String),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Opaque name نام (synthetic_admin)'), findsOneWidget);
      final rows = t
          .widgetList<BilingualText>(find.byType(BilingualText))
          .where((widget) => widget.text.key == L10n.labelValues.key)
          .map((widget) => widget.text)
          .toList();
      expect(rows.map((row) => row.en), [
        'ADMIN · Active · Password change required',
        'STAFF · Disabled',
      ]);
      expect(rows[0].ur, contains('منتظم'));
      expect(rows[0].ur, contains('فعال'));
      expect(rows[0].ur, contains('پاس ورڈ بدلنا ضروری ہے'));
      expect(rows[1].ur, contains('عملہ'));
      expect(rows[1].ur, contains('غیر فعال'));
      await t.tap(find.widgetWithText(TextButton, 'Manage').first);
      expect(managed, ['synthetic-admin']);
      expect(t.takeException(), isNull);
    });
  }
}
