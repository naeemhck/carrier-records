import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeTrips implements TripRepository {
  final requests = <String>[], bodies = <Map<String, dynamic>>[];
  bool conflict = false;
  int reviews = 0;
  @override
  Future<Map<String, dynamic>> overlap(TripDraft d) async {
    reviews++;
    return {
      'review_token': 'ticket-$reviews',
      'requires_confirmation': false,
      'visible_trips': [],
      'restricted_conflict': false,
    };
  }

  @override
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) async {
    requests.add(request);
    bodies.add(payload);
    if (conflict) {
      throw const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'PT409',
      );
    }
    throw Exception('Response lost');
  }

  @override
  Future<List<Map<String, dynamic>>> history(
    String id, {
    int offset = 0,
  }) async => [];
  @override
  Future<Map<String, dynamic>> operate(
    String action,
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) async => {};
  @override
  Future<TripPage> list({
    String search = '',
    int offset = 0,
    String? office,
    String? vehicle,
    String? state,
    String? from,
    String? to,
  }) async => TripPage('ASSIGNED_OFFICES', []);
  @override
  Future<Map<String, dynamic>> detail(String id) async => {};
  @override
  Future<Map<String, dynamic>> defaults(TripDraft d) async => {};
}

class FakeMasters implements MasterRepository {
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async => [];
  @override
  Future<MasterRecord> save(
    MasterKind kind,
    String id,
    String requestId,
    int version,
    Map<String, dynamic> payload,
  ) => throw UnimplementedError();
}

TripDraft emptyDraft() => TripDraft()
  ..vehicle = 'vehicle'
  ..origin = 'origin'
  ..destination = 'destination'
  ..kind = 'EMPTY';
void main() {
  testWidgets('scope change hides an already opened draft editor', (
    tester,
  ) async {
    final access = ValueNotifier(true);
    Widget guard(Widget child) => ValueListenableBuilder<bool>(
      valueListenable: access,
      builder: (_, allowed, _) =>
          allowed ? child : const Scaffold(body: Text('Access changed')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TripWorkspace(
          repository: FakeTrips(),
          masters: FakeMasters(),
          offices: const [
            {'id': 'origin', 'name': 'Origin'},
          ],
          guard: guard,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(L10n.newTrip.en).first);
    await tester.pumpAndSettle();
    expect(find.byType(TripEditor), findsOneWidget);
    access.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(TripEditor), findsNothing);
    expect(find.text('Access changed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    access.dispose();
  });
  testWidgets(
    'office trip workspace loads without asynchronous setState return',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripWorkspace(
            repository: FakeTrips(),
            masters: FakeMasters(),
            offices: const [
              {'id': 'origin', 'name': 'Origin'},
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // QA text fixes 2026-10-20: scope header is now "Your office's trips".
      // Header compaction 2026-10-21: the scope line renders in the
      // one-line floating-label form, not a stacked BilingualText.
      final scopeFinder = find.byWidgetPredicate(
        (w) =>
            w is BilingualFloatingLabel &&
            w.message.en == L10n.assignedOfficeTrips.en,
      );
      await tester.scrollUntilVisible(
        scopeFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(scopeFinder, findsOneWidget);
      expect(find.text(TripStrings.empty), findsOneWidget);
    },
  );
  testWidgets(
    'lost save response retains request, prices and exact overlap ticket',
    (tester) async {
      final repository = FakeTrips();
      await tester.pumpWidget(
        MaterialApp(
          home: TripEditor(
            repository: repository,
            masters: FakeMasters(),
            offices: const [
              {'id': 'origin', 'name': 'Origin'},
            ],
            draft: emptyDraft(),
          ),
        ),
      );
      Future<void> save({bool review = true}) async {
        await tester.tap(find.byKey(const ValueKey('trip-step-2')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(TripStrings.save),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, TripStrings.save),
        );
        await tester.pump();
        await tester.tap(find.text(TripStrings.save));
        await tester.pump(const Duration(seconds: 1));
        if (review) {
          await tester.tap(find.text(TripStrings.confirm));
          await tester.pumpAndSettle();
        }
      }

      await save();
      expect(find.text(TripStrings.failed), findsOneWidget);
      await save(review: false);
      expect(repository.requests[0], repository.requests[1]);
      expect(repository.bodies[0], repository.bodies[1]);
      expect(repository.reviews, 1);
      await tester.tap(find.byKey(const ValueKey('trip-step-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notes:')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('trip-step-content-0')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('notes:')),
        'Changed draft',
      );
      await save();
      expect(repository.requests[2], isNot(repository.requests[1]));
      expect(repository.bodies[2]['review_token'], 'ticket-2');
    },
  );
  testWidgets(
    'version conflict keeps entries and disables overwrite until reopening',
    (tester) async {
      final repository = FakeTrips()..conflict = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TripEditor(
            repository: repository,
            masters: FakeMasters(),
            offices: const [
              {'id': 'origin', 'name': 'Origin'},
            ],
            draft: emptyDraft()..notes = 'Keep this entry',
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('trip-step-2')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(TripStrings.save),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, TripStrings.save),
      );
      await tester.pump();
      await tester.tap(find.text(TripStrings.save));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(TripStrings.confirm));
      await tester.pumpAndSettle();
      expect(find.text(TripStrings.conflict), findsOneWidget);
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, TripStrings.save),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, TripStrings.save),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('trip-step-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notes:')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('trip-step-content-0')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Keep this entry'), findsOneWidget);
    },
  );
}
