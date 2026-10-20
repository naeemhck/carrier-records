import 'bilingual_finders.dart';

import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;

import 'package:carrier_records/app/karvaan_patterns.dart' show KpiCard;

/// Fake trips returning live-state rows so the dashboard KPI figures and
/// drill-downs exercise real counts and lists.
class KpiFakeTrips extends FakeTrips {
  @override
  Future<TripPage> list({
    String search = '',
    int offset = 0,
    String? office,
    String? vehicle,
    String? state,
    String? from,
    String? to,
  }) async {
    if (state == 'DISPATCHED') {
      return TripPage('ASSIGNED_OFFICES', [
        {'id': 'd1', 'trip_number': 'T14-DISPATCHED-1', 'state': 'DISPATCHED'},
        {'id': 'd2', 'trip_number': 'T14-DISPATCHED-2', 'state': 'DISPATCHED'},
      ]);
    }
    if (state == 'DRAFT') {
      return TripPage('ASSIGNED_OFFICES', [
        {'id': 'r1', 'trip_number': 'T14-DRAFT-1', 'state': 'DRAFT'},
      ]);
    }
    return TripPage('ASSIGNED_OFFICES', []);
  }
}

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
      'scope': "Your office's records — not a complete business balance",
      'offices': ['Test office'],
      'period': {'from': f['from'], 'to': f['to']},
      'lifetime': kind == 'TRIP_PROFIT',
      'generated_at': '2026-10-11T00:00:00Z',
    };
  }
}

void main() {  testWidgets(
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
        englishTextContaining('not a complete business balance'),
        findsOneWidget,
      );
      expect(englishTextContaining('Owner profit'), findsOneWidget);
      expect(englishTextContaining('PKR 85,000.00'), findsOneWidget);
      expect(englishTextContaining('PKR 95,000.00'), findsOneWidget);
      await t.ensureVisible(find.text('Next'));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(fake.offsets, [0, 50]);
      expect(fake.filters[0], fake.filters[1]);
      expect(find.text('Next vehicle'), findsOneWidget);
    },
  );
  testWidgets('Dashboard KPI cards drill down to the underlying records', (
    t,
  ) async {
    // Tall viewport: all four KPI cards and the builder button stay mounted
    // (a scrolling ListView unmounts far-offscreen children, which would make
    // finders miss them after ensureVisible scrolled).
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    // KPI labels can repeat in the attention list (same words, same drill
    // target), so KPI interactions are scoped to the cards themselves.
    Finder kpiLabel(String label) => find.descendant(
      of: find.byType(KpiCard),
      matching: englishTextContaining(label),
    );

    Future<void> tapKpi(String label) async {
      await t.tap(label == 'Reports' ? englishTextContaining(label) : kpiLabel(label));
      await t.pumpAndSettle();
    }

    final fake = ReportsFake();
    await t.pumpWidget(
      MaterialApp(
        home: ReportWorkspace(
          reports: fake,
          trips: KpiFakeTrips(),
          masters: FakeMasters(),
          offices: const [],
          dashboard: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(kpiLabel('In transit'), findsOneWidget);
    expect(kpiLabel('Customer outstanding'), findsOneWidget);
    expect(kpiLabel('Settlements due'), findsOneWidget);
    expect(kpiLabel('Draft trips'), findsOneWidget);
    expect(englishTextContaining('PKR 95,000.00'), findsWidgets);

    // Dispatched drill-down lists the dispatched trips behind the figure.
    await tapKpi('In transit');
    expect(find.text('T14-DISPATCHED-1'), findsOneWidget);
    expect(find.text('T14-DISPATCHED-2'), findsOneWidget);

    // Draft drill-down lists the draft trips (the attention list shows the
    // same draft, so scope to the drill panel card).
    await tapKpi('Draft trips');
    expect(
      find.descendant(
        of: find.byType(Card),
        matching: find.text('T14-DRAFT-1'),
      ),
      findsOneWidget,
    );
    expect(find.text('T14-DISPATCHED-1'), findsNothing);

    // Outstanding drill-down shows the claims breakdown for the same scope.
    await tapKpi('Customer outstanding');
    expect(find.text('First vehicle'), findsOneWidget);
    expect(fake.filters.last['office_id'], isNull);

    // The report builder is one tap away on its own page.
    await tapKpi('Reports');
    expect(englishTextContaining('Report period'), findsOneWidget);
  });
}
