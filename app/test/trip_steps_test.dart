import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeTrips, FakeMasters, emptyDraft;

void main() {
  for (final reduced in [false, true]) {
    testWidgets('steps retain entry, no implicit save, reduced=$reduced', (
      tester,
    ) async {
      final draft = emptyDraft();
      final repository = FakeTrips();
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TripEditor(
              repository: repository,
              masters: FakeMasters(),
              offices: const [
                {'id': 'origin', 'name': 'Karachi'},
                {'id': 'destination', 'name': 'Islamabad'},
              ],
              draft: draft,
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notes:')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('notes:')),
        'Synthetic QA 123 / Urdu retained',
      );
      await tester.tap(find.byKey(const Key('trip-next')));
      await tester.pumpAndSettle();
      expect(find.text(L10n.pickupDropStops.en), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-next')));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic QA 123 / Urdu retained'), findsOneWidget);
      expect(repository.requests, isEmpty);
      expect(repository.reviews, 0);
      await tester.tap(find.byKey(const ValueKey('trip-step-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notes:')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Synthetic QA 123 / Urdu retained'), findsOneWidget);
      // Interrupt a transition with a second selection. Latest step wins.
      await tester.tap(find.byKey(const ValueKey('trip-step-1')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byKey(const ValueKey('trip-step-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-step-content-2')), findsOneWidget);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
