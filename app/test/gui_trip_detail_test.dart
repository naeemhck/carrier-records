import 'text_layout_qa_test.dart' show captureTextQa;

import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_components.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeTrips;
import 'trip_lifecycle_test.dart' show journey;

class DetailFixture extends FakeTrips {
  int details = 0, histories = 0;
  @override
  Future<Map<String, dynamic>> detail(String id) async {
    details++;
    return {
      ...journey(),
      'trip_number': 'QA-GUI-000001',
      'registration': 'SYNTHETIC-123',
      'origin_name': 'Karachi',
      'destination_name': 'Islamabad',
      'destination_office_id': 'isb',
      'owner_snapshot': {'display_name': 'Synthetic owner'},
      'linked_returns': [],
      'consignments': [
        {
          'id': 'synthetic-consignment',
          'customer_name': 'Synthetic customer',
          'state': 'ACTIVE',
          'car_count': 1,
          'quoted_amount': '100000.00',
          'quote_mode': 'DEDUCTED',
          'commission_method': 'FIXED',
          'commission_value': '5000.00',
          'customer_charge': '100000.00',
          'commission': '5000.00',
          'owner_entitlement': '95000.00',
          'pickup_stop_id': null,
          'drop_stop_id': null,
          'notes': 'Synthetic opaque note',
          'cars': [],
        },
      ],
      'totals': {
        'customer_charge': '100000.00',
        'commission': '5000.00',
        'owner_entitlement': '95000.00',
        'car_count': 1,
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String id, {
    int offset = 0,
  }) async {
    histories++;
    return [];
  }
}

void main() {
  for (final width in [320.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('detail keeps money separate and lazy tabs $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final captureKey = GlobalKey();
        final repo = DetailFixture();
        var expensesOpened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            builder: (_, child) =>
                RepaintBoundary(key: captureKey, child: child!),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: TripDetail(
                repository: repo,
                id: 'trip',
                canReturn: (_) => false,
                onEdit: (_) async {},
                onExpenses: () async {
                  expensesOpened++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => captureTextQa(tester, captureKey, 'trip-detail-$width-$scale'),
        );
        expect(repo.details, 1);
        expect(repo.histories, 0);
        // Redesign §5.4: the consignment money block is the ledger strip —
        // fare -> −commission -> =net, each amount shown once.
        // Density pass: tab content scrolls in its own ListView below the
        // always-visible tab bar (no page-level CustomScrollView anymore).
        await tester.scrollUntilVisible(
          find.byType(LedgerStrip),
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 60,
        );
        await tester.pumpAndSettle();
        final strip = tester.widget<LedgerStrip>(
          find.byType(LedgerStrip).first,
        );
        final fare = strip.segments.singleWhere(
          (s) => s.label.key == L10n.agreedFare.key,
        );
        expect(fare.formattedValue, contains('100,000.00'));
        expect(fare.label.ur, contains('طے شدہ کرایہ'));
        final commission = strip.segments.singleWhere(
          (s) => s.label.key == L10n.brokerCommissionFixed.key,
        );
        expect(commission.formattedValue, contains('5,000.00'));
        expect(commission.label.ur, isNot(contains('DEDUCTED')));
        final net = strip.segments.singleWhere(
          (s) => s.label.key == L10n.netOwnerShare.key,
        );
        expect(net.formattedValue, contains('95,000.00'));
        final stopText = tester
            .widgetList<BilingualText>(find.byType(BilingualText))
            .singleWhere((w) => w.text.key == L10n.pickupDrop.key);
        expect(stopText.text.ur, isNot(contains('None')));
        await tester.runAsync(
          () => captureTextQa(tester, captureKey, 'consignment-$width-$scale'),
        );

        expect(find.text('Dispatch'), findsNothing);
        // The tab bar is always visible (density pass) — no scrolling to
        // reach it, at any width or text scale.
        expect(
          tester.getRect(find.byKey(const ValueKey('detail-tab-0'))).top,
          lessThan(1000),
        );
        // Horizontal tab strip remains reachable at narrow width and200% scale.
        await tester.ensureVisible(find.byKey(const ValueKey('detail-tab-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-tab-2')));
        await tester.pumpAndSettle();
        // QA text fixes 2026-10-20: expenses tab shows a short empty state,
        // not the long disclaimer.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is BilingualText &&
                w.text.key == L10n.noTripExpensesRecorded.key,
          ),
          findsOneWidget,
        );
        expect(expensesOpened, 0);
        final notice = tester.getRect(
          find.byWidgetPredicate(
            (w) =>
                w is BilingualText &&
                w.text.key == L10n.noTripExpensesRecorded.key,
          ),
        );
        final tabs = tester.getRect(find.byKey(const ValueKey('detail-tabs')));
        expect(
          notice.top,
          greaterThanOrEqualTo(tabs.bottom),
          reason: 'Selected tab content stays below the tab bar',
        );
        expect(
          notice.top,
          lessThan(1000),
          reason: 'Selecting a tab reveals its content, not only its offscreen element',
        );

        await tester.runAsync(
          () => captureTextQa(tester, captureKey, 'trip-detail-$width-$scale'),
        );
        expect(repo.details, 1);
        expect(repo.histories, 0);
        await tester.ensureVisible(find.byKey(const ValueKey('detail-tab-3')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-tab-3')));
        await tester.pumpAndSettle();
        expect(repo.histories, 1);
        expect(find.text(L10n.noRecordedHistoryInThisScope.en), findsOneWidget);
        expect(repo.requests, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
