import 'package:carrier_records/app/bilingual.dart';
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
        final repo = DetailFixture();
        var expensesOpened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
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
        expect(repo.details, 1);
        expect(repo.histories, 0);
        expect(find.text('Dispatch'), findsNothing);
        final scroller = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('detail-tab-0')),
          300,
          scrollable: scroller,
          maxScrolls: 40,
        );
        // Horizontal tab strip remains reachable at narrow width and200% scale.
        await tester.ensureVisible(find.byKey(const ValueKey('detail-tab-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('detail-tab-2')));
        await tester.pumpAndSettle();
        expect(find.text(L10n.tripExpensesScopeNotice.en), findsOneWidget);
        expect(expensesOpened, 0);
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
