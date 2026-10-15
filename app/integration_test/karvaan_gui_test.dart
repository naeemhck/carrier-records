import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/features/auth/local_candidate_policy.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/features/reports/document_workspace.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native Flutter engine + real pinned local backend. Framework-driven input,
/// expressly separate from Computer Use / physical keyboard verification.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets('isolated native shell, scoped trip and retained stepped entry', (
    tester,
  ) async {
    expect(karvaanLocalOnly, isTrue);
    const username = String.fromEnvironment('TEST_USERNAME');
    const id = String.fromEnvironment('TEST_TRIP_ID');
    expect(username, 'review_admin');
    expect(id, isNotEmpty);
    const authPath = String.fromEnvironment('TEST_AUTH_FILE');
    expect(authPath, isNotEmpty);
    final credentials = jsonDecode(await File(authPath).readAsString()) as Map;
    expect(credentials['username'], username);
    final config = PublicConfig.fromEnvironment()..validate();
    await LocalCandidatePolicy.verify(config);
    final storage = SecureSessionStorage(
      keyPrefix: 'karvaan.gui.integration',
      namespace: 'local.${config.businessId}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(
        localStorage: storage,
        detectSessionInUri: false,
      ),
    );
    final client = Supabase.instance.client;
    final session = StaffSession(client, config, storage);
    final boundary = GlobalKey();
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 60),
    );
    Future<void> waitForTripPage() async {
      await tester.pump();
      final finder = find.descendant(
        of: find.byType(TripWorkspace),
        matching: find.byWidgetPredicate(
          (widget) => widget is FutureBuilder<TripPage>,
        ),
      );
      final future = tester.widget<FutureBuilder<TripPage>>(finder).future;
      expect(future, isNotNull);
      await future;
      await settle();
    }

    Future<void> capture(String name) async {
      final box =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      const evidence = String.fromEnvironment('TEST_EVIDENCE_DIR');
      expect(evidence, isNotEmpty);
      final folder = Directory(evidence)..createSync(recursive: true);
      await File('${folder.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    try {
      await session.signIn(username, credentials['password'] as String);
      expect(session.profile?['role'], 'ADMIN');
      final before = Map<String, dynamic>.from(
        await client.rpc('get_trip_detail', params: {'trip_id': id}) as Map,
      );
      expect(before['state'], 'DRAFT');
      expect(before['can_edit'], isTrue);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: CarrierRecordsApp(session: session),
        ),
      );
      await settle();
      if (find.byKey(const ValueKey('nav:trips')).evaluate().isEmpty) {
        await tester.tap(find.byIcon(Icons.menu));
        await settle();
      }
      await tester.tap(find.byKey(const ValueKey('nav:trips')));
      await settle();
      expect(find.byType(TripWorkspace), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        before['trip_number'] as String,
      );
      final refresh = find.text(L10n.searchRefresh.en);
      await tester.scrollUntilVisible(
        refresh,
        250,
        scrollable: find
            .descendant(
              of: find.byType(TripWorkspace),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(refresh);
      await settle();
      final row = find.byKey(ValueKey('trip:$id'));
      await tester.scrollUntilVisible(
        row,
        250,
        scrollable: find
            .descendant(
              of: find.byType(TripWorkspace),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await waitForTripPage();
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await settle();
      await capture('trip-list');
      await tester.tap(row);
      await settle();
      expect(find.byType(TripDetail), findsOneWidget);
      await capture('trip-detail');
      final edit = find.text(L10n.editDraft.en);
      final detailScroll = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(edit, 250, scrollable: detailScroll);
      await tester.ensureVisible(edit);
      await settle();
      await tester.tap(edit);
      await settle();
      expect(find.byType(TripEditor), findsOneWidget);
      await capture('journey');
      final journeyScroll = find
          .descendant(
            of: find.byKey(const ValueKey('trip-step-content-0')),
            matching: find.byType(Scrollable),
          )
          .first;
      final notes = find.byKey(const ValueKey('notes:'));
      await tester.scrollUntilVisible(notes, 250, scrollable: journeyScroll);
      const marker = 'SYNTHETIC NATIVE GUI12 UNSAVED — Latin 123';
      await tester.enterText(notes, marker);
      await tester.tap(find.byKey(const ValueKey('trip-step-1')));
      await settle();
      await capture('consignments');
      await tester.tap(find.byKey(const ValueKey('trip-step-2')));
      await settle();
      expect(find.text(marker), findsOneWidget);
      await capture('review');
      await tester.tap(find.byKey(const ValueKey('trip-step-0')));
      await settle();
      await tester.scrollUntilVisible(
        notes,
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('trip-step-content-0')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(marker), findsOneWidget);
      await tester.pageBack();
      await settle();
      final after = Map<String, dynamic>.from(
        await client.rpc('get_trip_detail', params: {'trip_id': id}) as Map,
      );
      expect(after['version'], before['version']);
      expect(after['state'], 'DRAFT');
      expect(after['notes'], before['notes']);
      expect(after['totals'], before['totals']);
      if (find.byKey(const ValueKey('nav:documents')).evaluate().isEmpty) {
        await tester.tap(find.byIcon(Icons.menu));
        await settle();
      }
      await tester.ensureVisible(find.byKey(const ValueKey('nav:documents')));
      await settle();
      await tester.tap(find.byKey(const ValueKey('nav:documents')));
      await settle();
      expect(find.byType(DocumentWorkspace), findsOneWidget);
      await capture('documents');
      await tester.tap(find.text(L10n.outputsAndPresets.en));
      await settle();
      expect(find.byType(OutputWorkspace), findsOneWidget);
      await capture('document-configuration');
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await client.auth.signOut(scope: SignOutScope.local);
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
