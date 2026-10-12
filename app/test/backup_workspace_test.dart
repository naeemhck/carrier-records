import 'package:carrier_records/features/backup/backup_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets(
    'failed manual helper never claims backup success or active schedule',
    (t) async {
      await t.pumpWidget(
        MaterialApp(home: BackupWorkspace(commands: FakeBackup())),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Backup is stale'), findsOneWidget);
      expect(find.textContaining('No active schedule'), findsOneWidget);
      expect(find.textContaining('90_PERCENT'), findsOneWidget);
      await t.ensureVisible(find.text('Run manual Windows backup'));
      await t.tap(find.text('Run manual Windows backup'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Helper did not report completion'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-10T12:00:00Z'), findsOneWidget);
      expect(
        find.textContaining('Archive creation does not verify restoration'),
        findsOneWidget,
      );
    },
  );
}
