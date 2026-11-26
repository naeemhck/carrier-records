import 'package:carrier_records/features/expenses/expense_repository.dart';
import 'package:carrier_records/features/masters/master_repository.dart';
import 'package:carrier_records/features/reports/document_repository.dart';
import 'package:carrier_records/features/reports/report_repository.dart';
import 'package:carrier_records/features/trips/trip_repository.dart';
import 'package:carrier_records/preview/preview_backend.dart';
import 'package:flutter_test/flutter_test.dart';

/// The design preview must feed the real repositories, so its payloads
/// are exercised through them rather than asserted as raw JSON.
void main() {
  test('preview session is a signed-in synthetic administrator', () async {
    final session = PreviewSession();
    expect(session.profile!['role'], 'ADMIN');
    expect(session.profile!['must_change_password'], false);
    await session.signOut();
    expect(session.profile, isNull);
    await session.signIn('anyone', 'anything');
    expect(session.profile!['display_name'], 'Demo Administrator');
  });

  test('read repositories load synthetic records', () async {
    final client = PreviewSession().client;
    final trips = SupabaseTripRepository(client);
    final page = await trips.list();
    expect(page.rows, isNotEmpty);
    expect((await trips.list(state: 'DRAFT')).rows, hasLength(1));
    final detail = await trips.detail(page.rows.first['id'] as String);
    expect(detail['consignments'], isNotEmpty);

    final report = await ReportRepository(client).report('MONTHLY_VEHICLE', {});
    expect((report['totals'] as Map).keys, containsAll(reportLabels.keys));
    expect(
      await SupabaseMasterRepository(client).list(MasterKind.vehicle),
      hasLength(3),
    );
    expect(await ExpenseRepository(client).list(), isNotEmpty);
    expect((await DocumentRepository(client).list({}, 0))['rows'], isNotEmpty);
  });

  test('writes are refused', () async {
    final trips = SupabaseTripRepository(PreviewSession().client);
    await expectLater(trips.save('id', 'request', 0, {}), throwsA(anything));
  });
}
