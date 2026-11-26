import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeTrips, FakeMasters, emptyDraft;

/// Widget tests for the owner-approved QA fix round (2026-10-21):
/// F04 (new-trip picker layout) and F07 (step label wrapping).
/// F06 lives in document_workspace_test.dart and the banner removal in
/// qa_preview_policy_test.dart.
void main() {
  Widget editor() => MaterialApp(
    theme: KarvaanDesign.theme(),
    home: TripEditor(
      repository: FakeTrips(),
      masters: FakeMasters(),
      offices: const [
        {'id': 'origin', 'name': 'Karachi'},
        {'id': 'destination', 'name': 'Islamabad'},
      ],
      draft: emptyDraft(),
    ),
  );

  void setView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Rect pickerRect(WidgetTester tester, String part) =>
      tester.getRect(find.byKey(ValueKey('trip-picker-vehicle-$part')));

  testWidgets('F04: desktop two-column form puts picker value beside label', (
    tester,
  ) async {
    setView(tester, const Size(1440, 900));
    await tester.pumpWidget(editor());
    await tester.pumpAndSettle();
    final labelRect = pickerRect(tester, 'label');
    final valueRect = pickerRect(tester, 'value');
    // Same row: the value's vertical span overlaps the label's, and it
    // starts to the label's right — not stacked underneath it.
    expect(valueRect.top, lessThan(labelRect.bottom));
    expect(valueRect.bottom, greaterThan(labelRect.top));
    expect(valueRect.left, greaterThan(labelRect.right));
    // The Choose action shares the row too.
    final chooseRect = tester.getRect(
      find.byKey(const ValueKey('trip-picker-vehicle-choose')),
    );
    expect(chooseRect.top, lessThan(labelRect.bottom));
    expect(chooseRect.bottom, greaterThan(labelRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F04: phone form stacks the picker label above the value', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(editor());
    await tester.pumpAndSettle();
    final labelRect = pickerRect(tester, 'label');
    final valueRect = pickerRect(tester, 'value');
    // Stacked: the value begins at or below the label's bottom edge,
    // aligned to the same left edge.
    expect(valueRect.top, greaterThanOrEqualTo(labelRect.bottom - 1));
    expect(valueRect.left, closeTo(labelRect.left, 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('F07: step labels stay on one line at 390x844 bilingual', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(editor());
    await tester.pumpAndSettle();
    final journey = find.descendant(
      of: find.byKey(const ValueKey('trip-step-0')),
      matching: find.text(L10n.journeyStep.en),
    );
    final consignments = find.descendant(
      of: find.byKey(const ValueKey('trip-step-1')),
      matching: find.text(L10n.consignmentsStep.en),
    );
    expect(journey, findsOneWidget);
    expect(consignments, findsOneWidget);
    // One line each: the long label is no taller than the short one.
    // (Before the fix it wrapped mid-word to two lines, ~double height.)
    expect(
      tester.getRect(consignments).height,
      closeTo(tester.getRect(journey).height, 1.5),
    );
    // Every step stays reachable: the Review step is fully on screen and
    // can be opened. The chevron only exists when the row has to scroll;
    // with the bundled faces the three steps fit this width outright.
    final next = find.byKey(const ValueKey('trip-steps-next'));
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final reviewRect = tester.getRect(
      find.byKey(const ValueKey('trip-step-2')),
    );
    expect(reviewRect.right, lessThanOrEqualTo(390));
    expect(reviewRect.left, greaterThanOrEqualTo(0));
    await tester.tap(find.byKey(const ValueKey('trip-step-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trip-step-content-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
