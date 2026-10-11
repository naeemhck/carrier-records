import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;

class ReportsFake implements ReportCommands {
  final offsets = <int>[];
  final filters = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> report(
    String kind,
    Map<String, dynamic> f, {
    int offset = 0,
  }) async {
    offsets.add(offset);
    filters.add(Map.from(f));
    return {
      'totals': {
        for (final key in reportLabels.keys) key: '0.00',
        'owner_due': '95000.00',
        'owner_profit': '85000.00',
      },
      'rows': [
        {
          'id': 'vehicle',
          'name': offset == 0 ? 'First vehicle' : 'Next vehicle',
          'values': {for (final key in reportLabels.keys) key: '0.00'},
        },
      ],
      'row_count': 51,
      'has_more': offset == 0,
      'scope': 'Assigned-office records — not a complete business balance',
      'offices': ['Test office'],
      'period': {'from': f['from'], 'to': f['to']},
      'lifetime': kind == 'TRIP_PROFIT',
      'generated_at': '2026-10-11T00:00:00Z',
    };
  }
}

void main() {
  testWidgets(
    'Scoped report pagination retains filters and distinct server totals',
    (t) async {
      final fake = ReportsFake();
      await t.pumpWidget(
        MaterialApp(
          home: ReportWorkspace(
            reports: fake,
            trips: FakeTrips(),
            masters: FakeMasters(),
            offices: const [],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('not a complete business balance'),
        findsOneWidget,
      );
      expect(find.textContaining('Owner profit —'), findsOneWidget);
      expect(find.textContaining('85000.00'), findsOneWidget);
      expect(find.textContaining('95000.00'), findsOneWidget);
      await t.ensureVisible(find.text('Next'));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(fake.offsets, [0, 50]);
      expect(fake.filters[0], fake.filters[1]);
      expect(find.text('Next vehicle'), findsOneWidget);
    },
  );
  testWidgets('Dashboard balances navigate to same scoped filters', (t) async {
    final fake = ReportsFake();
    await t.pumpWidget(
      MaterialApp(
        home: ReportWorkspace(
          reports: fake,
          trips: FakeTrips(),
          masters: FakeMasters(),
          offices: const [],
          dashboard: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.textContaining('Owner settlement due'));
    await t.tap(find.textContaining('Owner settlement due'));
    await t.pumpAndSettle();
    expect(fake.offsets, [0, 0]);
    expect(fake.filters[0], fake.filters[1]);
    expect(find.text('Pending arrivals (up to 5; all dates)'), findsOneWidget);
  });
}
