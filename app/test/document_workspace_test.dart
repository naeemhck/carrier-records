import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';

import 'dart:async';

import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:carrier_records/features/reports/document_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'output_workspace_test.dart' show OutputsFake;

class DocumentFake implements DocumentCommands {
  final requests = <String>[], bodies = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<Map<String, dynamic>> issue(
    String request,
    Map<String, dynamic> payload,
  ) {
    requests.add(request);
    bodies.add(Map.from(payload));
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> get(String id) async => {};
  @override
  Future<Map<String, dynamic>> list(
    Map<String, dynamic> filters,
    int offset,
  ) async => {'rows': [], 'has_more': false};
}

/// Two issued documents, newest first in service order (reports pass).
class RegisterDocumentFake extends DocumentFake {
  @override
  Future<Map<String, dynamic>> list(
    Map<String, dynamic> filters,
    int offset,
  ) async => {
    'rows': [
      {
        'id': 'a',
        'permanent_number': 'DOC-2026-0002',
        'recipient': 'Second recipient',
        'issued_at': '2026-10-12T09:00:00Z',
        'issuer': 'Office',
        'superseded': false,
      },
      {
        'id': 'b',
        'permanent_number': 'DOC-2026-0001',
        'recipient': 'First recipient',
        'issued_at': '2026-10-10T09:00:00Z',
        'issuer': 'Office',
        'superseded': false,
      },
    ],
    'has_more': false,
  };
}

/// Search-aware register fake (GPT QA F06): one document while the
/// search is empty, none once any search text is applied. Records every
/// search value the workspace sends, so the test can prove the reload
/// came from typing alone.
class SearchDocumentFake extends DocumentFake {
  final searches = <String>[];
  @override
  Future<Map<String, dynamic>> list(
    Map<String, dynamic> filters,
    int offset,
  ) async {
    final s = (filters['search'] as String? ?? '');
    searches.add(s);
    if (s.isNotEmpty) return {'rows': [], 'has_more': false};
    return {
      'rows': [
        {
          'id': 'a',
          'permanent_number': 'DOC-2026-0001',
          'recipient': 'Only recipient',
          'issued_at': '2026-10-10T09:00:00Z',
          'issuer': 'Office',
          'superseded': false,
        },
      ],
      'has_more': false,
    };
  }
}

void main() {
  testWidgets('document list keeps configuration reachable at320px and200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var configured = false;
    final commands = DocumentFake();
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: DocumentWorkspace(
            commands: commands,
            onSupersede: (_, _) {},
            guard: (w) => w,
            onConfigure: () => configured = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(L10n.issuedDocuments.en), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Header compaction: at this narrow width the header's Create
    // report action takes its compact icon form (tooltip carries the
    // label); tapping it must still reach the configuration flow.
    await tester.tap(find.byIcon(Icons.post_add));
    await tester.pumpAndSettle();
    expect(configured, isTrue);
    final empty = find.text(L10n.noIssuedDocumentsInYourCurrentScope.ur);
    expect(empty, findsOneWidget);
    // GUI handoff group 9: pagination hides entirely while the list is
    // empty, so nothing can paint over the empty-state Urdu lines.
    expect(find.text(L10n.previousDocuments.en), findsNothing);
    expect(find.text(L10n.nextDocuments.en), findsNothing);

    expect(commands.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Issuance waits for commit and ambiguous retry preserves UUID and reason',
    (t) async {
      final fake = DocumentFake();
      await t.pumpWidget(
        MaterialApp(
          home: IssueDocumentDialog(
            commands: fake,
            payload: const {'supersedes_id': 'old'},
            superseding: true,
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Corrected customer charge');
      await t.tap(find.text('Confirm issuance'));
      await t.pump();
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byType(AlertDialog), findsOneWidget);
      fake.pending.completeError(Exception('Lost response'));
      await t.pumpAndSettle();
      fake.pending = Completer();
      await t.tap(find.text('Confirm issuance'));
      await t.pump();
      expect(fake.requests[0], fake.requests[1]);
      expect(fake.bodies[0], fake.bodies[1]);
      fake.pending.complete({'id': 'new'});
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'Reprint view displays original snapshot and supersession without joins',
    (t) async {
      final snap = await OutputsFake().prepare({
        'field_order': [
          'scope',
          'period',
          'generated_at',
          'recipient_name',
          'record_name',
        ],
      });
      snap['metadata']['company_name'] = 'Original company';
      await t.pumpWidget(
        MaterialApp(
          home: IssuedDocumentView(
            document: {
              'permanent_number': 'INV-2026-000001',
              'snapshot': snap,
              'superseded_by_number': 'INV-2026-000002',
            },
          ),
        ),
      );
      expect(find.text('INV-2026-000001'), findsOneWidget);
      expect(find.text('Superseded by INV-2026-000002'), findsOneWidget);
      expect(find.text('Owner profit: PKR 85,000.00'), findsOneWidget);
      expect(find.text('Prepare superseding document'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('issued register sorts and shows the generated group', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: DocumentWorkspace(
          commands: RegisterDocumentFake(),
          onSupersede: (_, _) {},
          guard: (w) => w,
        ),
      ),
    );
    await t.pumpAndSettle();
    double rowY(String title) => t.getTopLeft(find.text(title)).dy;
    // Default: newest first.
    expect(
      rowY('DOC-2026-0002 - Second recipient') <
          rowY('DOC-2026-0001 - First recipient'),
      isTrue,
    );
    // Sort by document number flips the register.
    await t.tap(find.byKey(const ValueKey('documents-sort-newest')));
    await t.pumpAndSettle();
    await t.tap(find.text(L10n.sortByNumber.en).last);
    await t.pumpAndSettle();
    expect(
      rowY('DOC-2026-0001 - First recipient') <
          rowY('DOC-2026-0002 - Second recipient'),
      isTrue,
    );
    // Report history: the generated-reports group sits below the register
    // and explains that ad-hoc generations are not persisted.
    await t.scrollUntilVisible(
      find.text(L10n.generatedReportsGroup.en),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    expect(find.text(L10n.generatedReportsGroup.en), findsOneWidget);
    expect(find.text(L10n.generatedReportsHint.en), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  // GPT QA F06 regression: the Documents search must apply while typing.
  // The previous pass only tested the rendered empty-state branch; this
  // test drives the interaction — enterText, no submit action — and
  // checks both the no-match state and recovery on clear.
  testWidgets('documents search filters as you type, no Enter needed', (
    t,
  ) async {
    final fake = SearchDocumentFake();
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: DocumentWorkspace(
          commands: fake,
          onSupersede: (_, _) {},
          guard: (w) => w,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('DOC-2026-0001 - Only recipient'), findsOneWidget);

    // Type a no-match string. enterText fires onChanged only — it never
    // submits — so any reload observed comes from the typing path.
    await t.enterText(find.byType(TextField), 'QA_NO_MATCH');
    await t.pumpAndSettle();
    expect(fake.searches, contains('QA_NO_MATCH'));
    expect(find.text('DOC-2026-0001 - Only recipient'), findsNothing);
    expect(find.text(L10n.noMatchesForFilters.en), findsOneWidget);
    expect(
      find.text(L10n.noIssuedDocumentsInYourCurrentScope.en),
      findsNothing,
    );
    expect(find.text(L10n.clear.en), findsOneWidget);

    // The Clear action restores the unfiltered register.
    await t.tap(find.text(L10n.clear.en));
    await t.pumpAndSettle();
    expect(find.text('DOC-2026-0001 - Only recipient'), findsOneWidget);
    expect(find.text(L10n.noMatchesForFilters.en), findsNothing);

    // Clearing the field by typing back to empty also restores it.
    await t.enterText(find.byType(TextField), 'ZZZ');
    await t.pumpAndSettle();
    expect(find.text(L10n.noMatchesForFilters.en), findsOneWidget);
    await t.enterText(find.byType(TextField), '');
    await t.pumpAndSettle();
    expect(find.text('DOC-2026-0001 - Only recipient'), findsOneWidget);
    expect(find.text(L10n.noMatchesForFilters.en), findsNothing);
    expect(t.takeException(), isNull);
  });
}
