import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;

class TableFakeTrips extends FakeTrips {
  @override
  Future<TripPage> list({
    String search = '',
    int offset = 0,
    String? office,
    String? vehicle,
    String? state,
    String? from,
    String? to,
  }) async => TripPage('ASSIGNED_OFFICES', [
    {
      'id': 't1',
      'trip_number': 'TRIP-001',
      'state': 'DISPATCHED',
      'origin_name': 'Karachi',
      'destination_name': 'Lahore',
      'registration': 'QA-ONLY-001',
      'owner_name': 'Synthetic owner',
      'dispatch_date': '2026-10-15',
      'planned_dispatch_date': '2026-10-15',
      'arrival_date': null,
    },
  ]);
}

Future<void> pumpTrips(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: KarvaanDesign.theme(),
      home: TripWorkspace(
        repository: TableFakeTrips(),
        masters: FakeMasters(),
        offices: const [],
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('wide trips list defaults to the table, toggles to cards', (
    t,
  ) async {
    await pumpTrips(t, const Size(1280, 900));
    // Table by default on desktop (density pass): no toggle tap needed.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('TRIP-001'), findsOneWidget);
    expect(find.text('Karachi → Lahore'), findsOneWidget);
    expect(find.text('QA-ONLY-001'), findsWidgets);
    // Toggle to compact cards.
    await t.tap(find.byKey(const ValueKey('trips-view-cards')));
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    // The compact card still shows the full route as one wrapping line,
    // the vehicle/owner line, and the date.
    expect(find.text('Karachi → Lahore'), findsOneWidget);
    expect(find.text('QA-ONLY-001 · Synthetic owner'), findsOneWidget);
    expect(find.text('2026-10-15'), findsOneWidget);
    expect(find.byType(TripStatusBadge), findsOneWidget);
    // And back to the table.
    await t.tap(find.byKey(const ValueKey('trips-view-table')));
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('narrow trips list has no view toggle and one heading', (
    t,
  ) async {
    await pumpTrips(t, const Size(400, 900));
    expect(find.byKey(const ValueKey('trips-view-table')), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    // One page heading only: the AppBar. The old duplicate body heading
    // is gone (density pass).
    expect(find.text(L10n.trips.en), findsOneWidget);
    // Compact card renders on phone widths.
    expect(find.text('Karachi → Lahore'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('filters stay collapsed until the toolbar toggle opens them', (
    t,
  ) async {
    await pumpTrips(t, const Size(1280, 900));
    // Search is always visible; the panel and its fields are not.
    expect(
      find.widgetWithText(TextField, L10n.searchTripVehicleOrParty.en),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('trips-filters-panel')), findsNothing);
    expect(find.text(L10n.dateFrom.en), findsNothing);
    await t.tap(find.byKey(const ValueKey('trips-filters-toggle')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('trips-filters-panel')), findsOneWidget);
    // Short From/To labels with date pickers, office and vehicle filters
    // in the same aligned panel.
    expect(find.text(L10n.dateFrom.en), findsOneWidget);
    expect(find.text(L10n.dateTo.en), findsOneWidget);
    expect(find.text(L10n.officeFilter.en), findsOneWidget);
    await t.tap(find.text(L10n.dateFrom.en));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(t.takeException(), isNull);
  });
}
