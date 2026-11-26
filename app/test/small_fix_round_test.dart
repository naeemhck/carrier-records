import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_workspace_test.dart' show FakeTrips, FakeMasters, emptyDraft;
import 'trips_table_test.dart' show RegisterFakeTrips;

/// Widget tests for the owner-approved small fix round (2026-10-22):
/// Q4 (step-row chevron overlaying the Review step's tap target) and
/// the blank sign-in validation. The chips guard at the bottom records
/// the inspection of the similar Trips status-chip pattern.
class RecordingSession extends ChangeNotifier implements StaffSession {
  @override
  Map<String, dynamic>? profile;
  @override
  String? error;
  int signInCalls = 0;
  Object? signInError;
  @override
  Future<void> signIn(String username, String password) async {
    signInCalls++;
    final failure = signInError;
    if (failure != null) throw failure;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    LanguageModeStore.instance.mode.value = KarvaanLanguageMode.bilingual;
    SharedPreferences.setMockInitialValues({});
  });

  void setView(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

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

  // The step row scrolls only when its steps do not fit. With the bundled
  // faces it fits a 390px phone outright; a 280px pane still has to scroll.
  for (final (width, scrolls) in [(390.0, false), (280.0, true)]) {
    testWidgets(
      'Q4: Review centre tap opens Review, chevron never in the way $width',
      (tester) async {
        setView(tester, Size(width, 844));
        await tester.pumpWidget(editor());
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byKey(const ValueKey('trip-steps-scroll')),
          matching: find.byType(Scrollable),
        );
        final next = find.byKey(const ValueKey('trip-steps-next'));
        double offset() =>
            tester.state<ScrollableState>(scrollable).position.pixels;
        if (scrolls) {
          // Scroll the strip to its end with the chevron, as a user would.
          var previous = -1.0;
          for (var i = 0; i < 5 && offset() != previous; i++) {
            previous = offset();
            await tester.tap(next);
            await tester.pumpAndSettle();
          }
          expect(offset(), greaterThan(0), reason: 'the strip really scrolled');
          final review = tester.getRect(
            find.byKey(const ValueKey('trip-step-2')),
          );
          final chevron = tester.getRect(next);
          // The defect: the overlay covered the step's right portion even
          // at full scroll (48px intersection before the fix), and with
          // real fonts its centre too. After the fix they must not overlap.
          expect(
            review.intersect(chevron).isEmpty,
            isTrue,
            reason: 'Review $review must sit clear of the chevron $chevron',
          );
          expect(chevron.contains(review.center), isFalse);
        } else {
          // A row that already fits offers no chevron that does nothing.
          expect(next, findsNothing);
        }
        // Interaction-level proof: tap the button at its centre.
        await tester.tapAt(
          tester.getRect(find.byKey(const ValueKey('trip-step-2'))).center,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('trip-step-content-2')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('chips guard: last chip centre stays tappable at 390x844', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: TripWorkspace(
          repository: RegisterFakeTrips(),
          masters: FakeMasters(),
          offices: const [],
          guard: (child) => child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chipFinder = find.byKey(const ValueKey('trip-filter-CANCELLED'));
    expect(chipFinder, findsOneWidget);
    final scrollable = find
        .ancestor(of: chipFinder, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final chip = tester.getRect(chipFinder);
    final chevronButton = find.ancestor(
      of: find.byIcon(Icons.chevron_right).first,
      matching: find.byType(IconButton),
    );
    final chevron = tester.getRect(chevronButton);
    // Inspection outcome (small fix round): the CANCELLED chip is wide
    // (~160px), so its centre sits well left of the ~48px overlay — the
    // Q4 blockage does not occur here and the chips stay untouched.
    expect(chevron.contains(chip.center), isFalse);
    await tester.tapAt(chip.center);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(chipFinder).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  group('blank sign-in validation', () {
    Future<RecordingSession> pumpSignIn(WidgetTester tester) async {
      setView(tester, const Size(1280, 900));
      final session = RecordingSession();
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: StaffHome(session: session),
        ),
      );
      await tester.pumpAndSettle();
      return session;
    }

    Future<void> tapSignIn(WidgetTester tester) async {
      await tester.ensureVisible(find.text(L10n.signIn.en));
      await tester.pumpAndSettle();
      await tester.tap(find.text(L10n.signIn.en));
      await tester.pumpAndSettle();
    }

    testWidgets('both fields empty: specific message, sign-in not called', (
      tester,
    ) async {
      final session = await pumpSignIn(tester);
      await tapSignIn(tester);
      expect(find.text(L10n.enterYourUsernameAndPassword.en), findsOneWidget);
      expect(find.text(L10n.enterYourUsernameAndPassword.ur), findsOneWidget);
      expect(session.signInCalls, 0);
      expect(
        find.text(
          L10n
              .requestFailedCheckYourCredentialsConnectionOrAdministratorAccess
              .en,
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('password empty only: specific message, sign-in not called', (
      tester,
    ) async {
      final session = await pumpSignIn(tester);
      await tester.enterText(find.byType(TextField).first, 'qa_khi');
      await tapSignIn(tester);
      expect(find.text(L10n.enterYourUsernameAndPassword.en), findsOneWidget);
      expect(session.signInCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('username empty only: specific message, sign-in not called', (
      tester,
    ) async {
      final session = await pumpSignIn(tester);
      await tester.enterText(find.byType(TextField).last, 'some-password');
      await tapSignIn(tester);
      expect(find.text(L10n.enterYourUsernameAndPassword.en), findsOneWidget);
      expect(session.signInCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('wrong password still maps to the wrong-password message', (
      tester,
    ) async {
      final session = await pumpSignIn(tester);
      session.signInError = const AuthException('Invalid login credentials');
      await tester.enterText(find.byType(TextField).first, 'qa_khi');
      await tester.enterText(find.byType(TextField).last, 'wrong-password');
      await tapSignIn(tester);
      expect(session.signInCalls, 1);
      expect(find.text(L10n.signInFailed.en), findsOneWidget);
      expect(find.text(L10n.enterYourUsernameAndPassword.en), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
