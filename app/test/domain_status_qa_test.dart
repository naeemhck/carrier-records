import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/backup/backup_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_layout_qa_test.dart' show captureTextQa;

void main() {
  test('domain values remain distinct and translate only controlled codes', () {
    expect(consignmentStateLabel('ACTIVE').key, L10n.consignmentActive.key);
    expect(consignmentStateLabel('DELIVERED').key, L10n.delivered.key);
    expect(tripStateLabel('DISPATCHED').ur, L10n.dispatched.ur);
    expect(loadKindLabel('LOADED').ur, L10n.loaded.ur);
    expect(backupOutcomeLabel('NEVER_RUN').ur, L10n.backupNeverRun.ur);
    expect(tripStateLabel('ACTIVE').ur, isEmpty);
    expect(consignmentStateLabel('DISPATCHED').ur, isEmpty);
    expect(backupOutcomeLabel('UNKNOWN').en, 'UNKNOWN');
  });
  for (final width in [360.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('never-run backup and operational labels $width/$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BilingualText(
                          L10n.cars7b7a19.withValues([
                            'Synthetic customer',
                            consignmentStateLabel('ACTIVE'),
                            1,
                          ]),
                        ),
                        BilingualText(
                          L10n.labelValuescd55a9.withValues([
                            tripStateLabel('DISPATCHED'),
                            loadKindLabel('LOADED'),
                          ]),
                        ),
                        const BackupSummary(
                          status: {
                            'outcome': 'NEVER_RUN',
                            'quota_level': 'NORMAL',
                            'stale': true,
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('NEVER_RUN'), findsNothing);
        expect(find.textContaining('(UTC) Never'), findsNothing);
        expect(find.text(L10n.noVerifiedBackupYet.en), findsOneWidget);
        expect(find.text(L10n.noBackupAttemptYet.ur), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => captureTextQa(tester, key, 'statuses-$width-$scale'),
        );
      });
    }
  }
}
