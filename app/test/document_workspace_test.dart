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

void main() {
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
      expect(find.text('Owner profit: 85000.00'), findsOneWidget);
      expect(find.text('Prepare superseding document'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
