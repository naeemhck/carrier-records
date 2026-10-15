import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/features/masters/master_workspace.dart';
import 'package:carrier_records/features/backup/backup_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeMasters;
import 'backup_workspace_test.dart' show FakeBackup;

void main() {
  testWidgets('masters remain scrollable at320px and200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MasterWorkspace(repository: FakeMasters()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text(L10n.noRecordsFound.en),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    expect(find.text(L10n.noRecordsFound.ur), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('backup failure remains explicit in narrow large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: BackupWorkspace(commands: FakeBackup()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('RECEIPT_COPY_FAILED'), findsWidgets);
  });
}
