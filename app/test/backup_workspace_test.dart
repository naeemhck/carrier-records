import 'bilingual_finders.dart';

import 'package:carrier_records/features/backup/backup_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carrier_records/features/auth/local_candidate_policy.dart';

class FakeBackup implements BackupCommands {
  bool success = false;
  @override
  Future<bool> manual() async => success;
  @override
  Future<Map<String, dynamic>> status() async => {
    'outcome': 'FAILED',
    'last_verified_success_at': '2026-10-10T12:00:00Z',
    'last_attempt_at': '2026-10-12T12:00:00Z',
    'safe_error_code': 'RECEIPT_COPY_FAILED',
    'stale': true,
    'interrupted': false,
    'pending_receipt_count': 2,
    'schedule': {'active': false},
    'quota_level': '90_PERCENT',
    'other_traffic_known': false,
  };
}

void main() {
  test('isolated candidate rejects installed helper before environment/file/process access', () async {
    expect(karvaanLocalOnly, isTrue);
    final client = SupabaseClient(
      'http://127.0.0.1:60321',
      'synthetic-public-only',
    );
    try {
      await expectLater(
        BackupRepository(client).manual(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'safe error',
            'Administrator helper is disabled in this isolated candidate.',
          ),
        ),
      );
    } finally {
      await client.dispose();
    }
  });
  testWidgets(
    'failed manual helper never claims backup success or active schedule',
    (t) async {
      await t.pumpWidget(
        MaterialApp(home: BackupWorkspace(commands: FakeBackup())),
      );
      await t.pumpAndSettle();
      expect(englishTextContaining('Backup is stale'), findsOneWidget);
      expect(englishTextContaining('No active schedule'), findsOneWidget);
      expect(englishTextContaining('90_PERCENT'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Run manual Windows backup'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(find.text('Run manual Windows backup'));
      await t.tap(find.text('Run manual Windows backup'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        englishTextContaining('Helper did not report completion'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        englishTextContaining('Helper did not report completion'),
        findsOneWidget,
      );
      expect(englishTextContaining('2026-10-10T12:00:00Z'), findsOneWidget);
      expect(
        englishTextContaining('Archive creation does not verify restoration'),
        findsOneWidget,
      );
    },
  );
}
