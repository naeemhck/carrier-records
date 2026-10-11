import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:carrier_records/features/trips/trip_lifecycle.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native committed dispatch, destination arrival and audit', (
    tester,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate();
    final storage = SecureSessionStorage(
      namespace: 'native-lifecycle.${DateTime.now().microsecondsSinceEpoch}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(localStorage: storage),
    );
    final session = StaffSession(Supabase.instance.client, config, storage);
    final repository = SupabaseTripRepository(Supabase.instance.client);
    const id = String.fromEnvironment('TEST_TRIP_ID');
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 20),
    );
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: TripDetail(
            repository: repository,
            id: id,
            canReturn: (_) => false,
            onEdit: (_) async {},
          ),
        ),
      );
      await settle();
    }

    Future<void> action(TripAction action) async {
      final button = find.widgetWithText(TextButton, action.label);
      await tester.scrollUntilVisible(
        button,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle();
    }

    try {
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      await open();
      expect(find.text(TripAction.arrive.label), findsNothing);
      await action(TripAction.dispatch);
      await tester.enterText(
        find.byKey(const Key('operation-date')),
        '2026-01-30',
      );
      await tester.enterText(
        find.byKey(const Key('operation-reason')),
        'Native synthetic dispatch',
      );
      final review = find.widgetWithText(
        TextButton,
        LifecycleStrings.dispatchReview,
      );
      await tester.ensureVisible(review);
      await tester.tap(review);
      await settle();
      if (find.text(TripStrings.confirmOverlap).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text(TripStrings.confirmOverlap));
        await tester.tap(find.text(TripStrings.confirmOverlap));
        await tester.enterText(
          find.byType(TextField).last,
          'Native reviewed synthetic overlap',
        );
      }
      await tester.ensureVisible(find.text(LifecycleStrings.reviewed));
      await tester.tap(find.text(LifecycleStrings.reviewed));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(
        find.widgetWithText(FilledButton, LifecycleStrings.confirm),
      );
      await settle();
      expect(find.text(LifecycleStrings.success), findsOneWidget);
      expect((await repository.detail(id))['state'], 'DISPATCHED');
      await tester.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      await session.signIn(
        const String.fromEnvironment('TEST_DESTINATION_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      await open();
      expect(find.text(TripAction.correctDispatch.label), findsNothing);
      await action(TripAction.arrive);
      await tester.enterText(
        find.byKey(const Key('operation-date')),
        '2026-02-02',
      );
      await tester.enterText(
        find.byKey(const Key('operation-reason')),
        'Native destination arrival',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, LifecycleStrings.confirm),
      );
      await settle();
      expect(find.text(LifecycleStrings.success), findsOneWidget);
      final result = await repository.detail(id);
      expect(result['state'], 'ARRIVED');
      expect(
        (result['consignments'] as List)
            .where((c) => c['state'] == 'DELIVERED')
            .length,
        2,
      );
      expect(
        (result['consignments'] as List)
            .where((c) => c['state'] == 'CANCELLED')
            .length,
        1,
      );
      final history = find.widgetWithText(TextButton, LifecycleStrings.history);
      await tester.scrollUntilVisible(
        history,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(history);
      await tester.tap(history);
      await settle();
      expect(find.textContaining('ARRIVE'), findsWidgets);
      expect(find.text('Native destination arrival'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
