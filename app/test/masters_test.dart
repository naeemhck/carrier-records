import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/masters/master_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FailingRepository implements MasterRepository {
  final requests = <String>[];
  bool conflict = false;
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
  ) async {
    requests.add(requestId);
    if (conflict) {
      throw const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'PT409',
      );
    }
    throw Exception('Lost response');
  }
}

void main() {
  testWidgets('master workspace and party picker load asynchronously', (
    tester,
  ) async {
    final repository = FailingRepository();
    await tester.pumpWidget(
      MaterialApp(home: MasterWorkspace(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text(MasterStrings.empty), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: PartyChoiceDialog(repository: repository, role: 'OWNER'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(MasterStrings.noRole), findsOneWidget);
  });
  test('route fare is exact, optional and rejects extra decimals', () {
    const fields = {
      'code': 'R',
      'origin_label': 'A',
      'destination_label': 'B',
      'suggested_fare': '9999999999999999.99',
    };
    expect(
      masterPayload(MasterKind.route, fields)['suggested_fare'],
      '9999999999999999.99',
    );
    expect(
      masterPayload(MasterKind.route, {
        ...fields,
        'suggested_fare': '',
      })['suggested_fare'],
      isNull,
    );
    expect(
      () => masterPayload(MasterKind.route, {
        ...fields,
        'suggested_fare': '1.001',
      }),
      throwsFormatException,
    );
  });
  test('one party has multiple roles without privileged or history fields', () {
    final payload = masterPayload(
      MasterKind.party,
      {'code': 'P', 'display_name': 'Party'},
      roles: {'OWNER', 'DRIVER'},
    );
    expect(payload['roles'], ['DRIVER', 'OWNER']);
    expect(payload.containsKey('business_id'), isFalse);
    expect(payload.containsKey('created_by'), isFalse);
    expect(payload.containsKey('owner_snapshot'), isFalse);
    expect(
      () => masterPayload(MasterKind.party, {
        'code': 'P',
        'display_name': 'Party',
      }),
      throwsFormatException,
    );
  });
  testWidgets(
    'failed save retains fields and retry ID; changed input gets a new ID',
    (tester) async {
      final repository = FailingRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MasterDialog(repository: repository, kind: MasterKind.category),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Diesel');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text(MasterStrings.failure), findsOneWidget);
      expect(find.text('Diesel'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.requests[0], repository.requests[1]);
      await tester.enterText(find.byType(TextField), 'Oil');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.requests[2], isNot(repository.requests[1]));
    },
  );
  testWidgets('version conflict retains edit and prevents silent overwrite', (
    tester,
  ) async {
    final repository = FailingRepository()..conflict = true;
    await tester.pumpWidget(
      MaterialApp(
        home: MasterDialog(
          repository: repository,
          kind: MasterKind.category,
          record: MasterRecord({
            'id': newRecordId(),
            'version': 1,
            'name': 'Diesel',
          }),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Edited diesel');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text(MasterStrings.conflict), findsOneWidget);
    expect(find.text('Edited diesel'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(repository.requests.length, 1);
  });
}
