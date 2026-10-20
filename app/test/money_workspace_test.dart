import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/finance/money_workspace.dart';
import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MoneyFake implements ReportCommands {
  final kinds = <String>[];
  @override
  Future<Map<String, dynamic>> report(
    String kind,
    Map<String, dynamic> f, {
    int offset = 0,
  }) async {
    kinds.add(kind);
    if (kind == 'CLAIMS') {
      return {
        'totals': const <String, dynamic>{},
        'rows': [
          {
            'name': 'Synthetic customer',
            'values': {
              'customer_outstanding': '12000.00',
              'owner_due': '0.00',
              'custody': '3000.00',
            },
          },
          {
            'name': 'Settled party',
            'values': {
              'customer_outstanding': '0.00',
              'owner_due': '0.00',
              'custody': '0.00',
            },
          },
        ],
        'row_count': 2,
        'has_more': false,
        'scope': 'scope',
        'offices': const [],
        'period': const {},
        'lifetime': false,
        'generated_at': '2026-10-11T00:00:00Z',
      };
    }
    return {
      'totals': {
        for (final key in reportLabels.keys) key: '0.00',
        'customer_outstanding': '12000.00',
        'owner_due': '95000.00',
        'custody': '3000.00',
      },
      'rows': const [],
      'row_count': 0,
      'has_more': false,
      'scope': 'scope',
      'offices': const [],
      'period': const {},
      'lifetime': false,
      'generated_at': '2026-10-11T00:00:00Z',
    };
  }
}

void main() {
  testWidgets('money workspace is balances-first with a party table', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var tripsOpened = 0;
    final fake = MoneyFake();
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: MoneyWorkspace(reports: fake, onViewTrips: () => tripsOpened++),
      ),
    );
    await t.pumpAndSettle();
    // Both reads happen: monthly totals for the band, claims for parties.
    expect(fake.kinds, containsAll(['MONTHLY_VEHICLE', 'CLAIMS']));
    // KPI band figures.
    expect(find.text('PKR 12,000.00'), findsWidgets);
    expect(find.text('PKR 95,000.00'), findsOneWidget);
    expect(find.text('PKR 3,000.00'), findsWidgets);
    // Party table: nonzero party shows, all-zero party is hidden.
    expect(find.text('Synthetic customer'), findsOneWidget);
    expect(find.text('Settled party'), findsNothing);
    // View trips opens the money-mode trip list.
    await t.tap(find.text(L10n.viewTrips.en));
    expect(tripsOpened, 1);
    // Tapping a party row also goes to the trips behind the balance.
    await t.tap(find.text('Synthetic customer'));
    expect(tripsOpened, 2);
    expect(t.takeException(), isNull);
  });
}
