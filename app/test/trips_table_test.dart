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

void main() {
  testWidgets('wide trips list toggles between route cards and table', (
    t,
  ) async {
    t.view.physicalSize = const Size(1280, 900);
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
    // Cards by default: the route line renders, no data table.
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Karachi'), findsOneWidget);
    // Toggle to the table view.
    await t.tap(find.byKey(const ValueKey('trips-view-table')));
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('TRIP-001'), findsOneWidget);
    expect(find.text('Karachi → Lahore'), findsOneWidget);
    expect(find.text('QA-ONLY-001'), findsOneWidget);
    // And back to cards.
    await t.tap(find.byKey(const ValueKey('trips-view-cards')));
    await t.pumpAndSettle();
    expect(find.byType(DataTable), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('narrow trips list has no view toggle', (t) async {
    t.view.physicalSize = const Size(400, 900);
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
    expect(find.byKey(const ValueKey('trips-view-table')), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });
}
