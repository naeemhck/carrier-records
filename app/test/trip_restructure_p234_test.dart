import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_patterns.dart';
import 'package:carrier_records/core/domain/record_context.dart';
import 'package:carrier_records/features/finance/financial_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeTrips, FakeMasters, emptyDraft;

const _tripId = '11111111-1111-1111-1111-111111111111';

class ListFixture extends FakeTrips {
  String? seenState;
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
    seenState = state;
    return TripPage('ASSIGNED_OFFICES', [
      {
        'id': _tripId,
        'trip_number': 'TRP-000001',
        'state': 'DISPATCHED',
        'load_kind': 'LOADED',
        'registration': 'LEA-24-8841',
        'owner_name': 'Synthetic owner',
        'origin_name': 'Karachi',
        'destination_name': 'Islamabad',
        'planned_dispatch_date': '2026-10-12',
        'dispatch_date': '2026-10-12',
        'arrival_date': null,
        'return_of_trip_id': null,
        'car_count': 3,
        'created_at': '2026-10-11T10:00:00Z',
        'notes':
            'A long synthetic note that must truncate behind the Read more control. ' *
            6,
      },
    ]);
  }
}

class FakeFinancialCommands implements FinancialCommands {
  FakeFinancialCommands(this.claims);
  final List<Map<String, dynamic>> claims;
  @override
  Future<Map<String, dynamic>> trip(RecordId id) async => {
    'scope': 'TRIP',
    'complete': true,
    'balances': [],
    'claims': claims,
  };
  @override
  Future<Map<String, dynamic>> post(
    String kind,
    String request,
    Map<String, dynamic> payload,
  ) => throw UnimplementedError();
}

Map<String, dynamic> detailFixture({bool cancellable = false}) => {
  'id': _tripId,
  'version': 3,
  'trip_number': 'TRP-000001',
  'registration': 'LEA-24-8841',
  'driver_name': 'Synthetic driver',
  'state': 'DISPATCHED',
  'origin_office_id': 'o1',
  'destination_office_id': 'o2',
  'origin_name': 'Karachi',
  'destination_name': 'Islamabad',
  'owner_snapshot': {'display_name': 'Synthetic owner'},
  'route_snapshot': {'code': 'R1'},
  'load_kind': 'LOADED',
  'planned_dispatch_date': '2026-10-12',
  'dispatch_date': '2026-10-12',
  'arrival_date': null,
  'notes': 'Synthetic detail note',
  'overlap_confirmed': false,
  'overlap_reason': null,
  'earnings_recognized': true,
  'return_of_trip_id': null,
  'linked_returns': [],
  'stops': [],
  'consignments': [
    {
      'id': 'c1',
      'customer_name': 'Synthetic customer',
      'state': 'ACTIVE',
      'car_count': 3,
      'quoted_amount': '200000.00',
      'quote_mode': 'DEDUCTED',
      'commission_method': 'FIXED',
      'commission_value': '10000.00',
      'customer_charge': '200000.00',
      'commission': '10000.00',
      'owner_entitlement': '190000.00',
      'pickup_stop_id': null,
      'drop_stop_id': null,
      'notes': '',
      'cars': [],
    },
  ],
  'can_cancel_consignment': cancellable,
  'totals': {
    'customer_charge': '200000.00',
    'commission': '10000.00',
    'owner_entitlement': '190000.00',
    'car_count': 3,
  },
};

class DetailFixture extends FakeTrips {
  DetailFixture(this.detailData, this.finance);
  final Map<String, dynamic> detailData;
  final FakeFinancialCommands finance;
  @override
  Future<Map<String, dynamic>> detail(String id) async => detailData;
  @override
  Future<List<Map<String, dynamic>>> history(
    String id, {
    int offset = 0,
  }) async => [];
}

Widget wrap(Widget child) => MaterialApp(
  theme: KarvaanDesign.theme(),
  home: Scaffold(body: child),
);

/// Result cards render below the fold in the 800x600 test viewport; card
/// assertions must not skip offstage widgets.
Finder cardText(String text) => find.text(text, skipOffstage: false);

void main() {
  testWidgets('trips list renders compact cards with money figure', (
    tester,
  ) async {
    final repository = ListFixture();
    final finance = FakeFinancialCommands([]);
    await tester.pumpWidget(
      wrap(
        TripWorkspace(
          repository: repository,
          masters: FakeMasters(),
          offices: const [
            {'id': 'o1', 'name': 'Karachi'},
          ],
          finance: finance,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Desktop defaults to the table; switch to the compact cards.
    await tester.tap(find.byKey(const ValueKey('trips-view-cards')));
    await tester.pumpAndSettle();
    // Compact card (density pass): number + status, the full route as one
    // wrapping line, vehicle · owner, dates, and the money figure. Notes
    // and timestamps live on the detail screen now, not on the card.
    expect(find.byType(TripStatusBadge, skipOffstage: false), findsOneWidget);
    expect(cardText('TRP-000001'), findsOneWidget);
    expect(cardText('Karachi → Islamabad'), findsOneWidget);
    expect(
      find.textContaining('LEA-24-8841', skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.textContaining('2026-10-12', skipOffstage: false),
      findsWidgets,
    );
    expect(find.text(L10n.readMore.en, skipOffstage: false), findsNothing);
    // Zero outstanding renders the settled zero-state wording, not PKR 0.00.
    expect(cardText(L10n.settled.en), findsOneWidget);
    expect(find.text('PKR 0.00', skipOffstage: false), findsNothing);
    // Filter chips drive the status filter; All clears it. The chips sit
    // in the fixed toolbar area, always reachable above the results.
    await tester.tap(find.byKey(const ValueKey('trip-filter-DRAFT')));
    await tester.pumpAndSettle();
    expect(repository.seenState, 'DRAFT');
    await tester.tap(find.byKey(const ValueKey('trip-filter-ALL')));
    await tester.pumpAndSettle();
    expect(repository.seenState, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trips list card shows outstanding as a money deep-link', (
    tester,
  ) async {
    final finance = FakeFinancialCommands([
      {
        'line_id': 'l1',
        'party_id': 'p1',
        'account_purpose': 'CUSTOMER_RECEIVABLE',
        'consignment_id': 'c1',
        'effective_date': '2026-10-12',
        'remaining': '165000.00',
        'version': 1,
      },
    ]);
    await tester.pumpWidget(
      wrap(
        TripWorkspace(
          repository: ListFixture(),
          masters: FakeMasters(),
          offices: const [
            {'id': 'o1', 'name': 'Karachi'},
          ],
          finance: finance,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('trips-view-cards')));
    await tester.pumpAndSettle();
    expect(find.byType(PaperTrailAmount, skipOffstage: false), findsOneWidget);
    expect(cardText('PKR 165,000.00'), findsOneWidget);
    expect(cardText(L10n.settled.en), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor cancel pops without saving; keyboard steps move', (
    tester,
  ) async {
    final repository = FakeTrips();
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => TripEditor(
                  repository: repository,
                  masters: FakeMasters(),
                  offices: const [
                    {'id': 'origin', 'name': 'Karachi'},
                  ],
                  draft: emptyDraft(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TripEditor), findsOneWidget);
    // advanceKeyboard/backKeyboard are public on the (private) state class.
    final dynamic state = tester.state(find.byType(TripEditor));
    // Keyboard logic: Enter advances, Esc goes back; step 2 keeps save manual.
    state.advanceKeyboard();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-1')), findsOneWidget);
    state.advanceKeyboard();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-2')), findsOneWidget);
    state.advanceKeyboard();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-2')), findsOneWidget);
    state.backKeyboard();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-1')), findsOneWidget);
    // Esc bubbles from a focused text field through the editor shortcuts.
    // moveStep unfocuses on every step change, so focus a field first.
    await tester.tap(find.text(L10n.addStop.en));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField).last);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-0')), findsOneWidget);
    // Cancel pops the editor with no save attempt.
    await tester.tap(find.byKey(const Key('trip-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(TripEditor), findsNothing);
    expect(repository.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail money tab shows per-trip paid-vs-outstanding', (
    tester,
  ) async {
    final finance = FakeFinancialCommands([
      {
        'line_id': 'l1',
        'party_id': 'p1',
        'account_purpose': 'CUSTOMER_RECEIVABLE',
        'consignment_id': 'c1',
        'effective_date': '2026-10-12',
        'remaining': '165000.00',
        'version': 1,
      },
    ]);
    var paymentsOpened = 0;
    await tester.pumpWidget(
      wrap(
        TripDetail(
          repository: DetailFixture(detailFixture(), finance),
          id: _tripId,
          canReturn: (_) => false,
          onEdit: (_) async {},
          finance: finance,
          onPayments: () async {
            paymentsOpened++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Hero carries the outstanding cell alongside the three quote cells.
    expect(cardText('PKR 165,000.00'), findsWidgets);
    final scroller = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final moneyTab = find.byKey(
      const ValueKey('detail-tab-1'),
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(moneyTab, 300, scrollable: scroller);
    await tester.pumpAndSettle();
    await tester.tap(moneyTab);
    await tester.pumpAndSettle();
    // Money tab: billed total from the strip plus the outstanding figure and
    // the open claim behind it, deep-linked to Payments & allocations.
    expect(cardText('PKR 200,000.00'), findsWidgets);
    expect(cardText('PKR 165,000.00'), findsWidgets);
    final claimLink = find.byType(PaperTrailAmount, skipOffstage: false);
    expect(claimLink, findsOneWidget);
    await tester.ensureVisible(claimLink);
    await tester.pumpAndSettle();
    await tester.tap(claimLink);
    await tester.pumpAndSettle();
    expect(paymentsOpened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consignment cancellation lives in an overflow menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        TripDetail(
          repository: DetailFixture(
            detailFixture(cancellable: true),
            FakeFinancialCommands([]),
          ),
          id: _tripId,
          canReturn: (_) => false,
          onEdit: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('consignment-menu-c1'), skipOffstage: false),
      findsOneWidget,
    );
    // No equal-weight inline cancellation button remains.
    expect(
      find.text('Cancel draft consignment', skipOffstage: false),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
