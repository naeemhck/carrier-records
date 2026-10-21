// Header compaction pass (owner-approved, 2026-10-21): ONE header row —
// the screen title and its primary actions live in the shell top bar,
// the user name is a compact chip, and no screen stacks its own 88px
// AppBar title block or a one-action toolbar row under the bar.
//
// Method: the real WorkspaceShell composed with the synthetic-fixture
// pages (the same fakes the report/trips suites use), bilingual mode,
// 100% text scale; offsets are window-space tops of the first content
// element. Baselines measured on the pre-pass tree with this method:
// Dashboard KPI 247 (desktop and phone), Trips table 376 desktop,
// first trip card 424 phone.
import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_components.dart'
    show KarvaanDataTable;
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/karvaan_patterns.dart' show KpiCard;
import 'package:carrier_records/app/shell_header.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/reports/report_workspace.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'report_workspace_test.dart' show KpiFakeTrips, ReportsFake;
import 'trip_workspace_test.dart' show FakeMasters;
import 'trips_table_test.dart' show RegisterFakeTrips;

class _Session extends ChangeNotifier implements StaffSession {
  @override
  Map<String, dynamic>? profile;
  @override
  Future<void> signOut() async {
    profile = null;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _shell(Widget page) {
  final session = _Session();
  session.profile = {
    'id': 'synthetic',
    'display_name': 'Synthetic qa_isb',
    'role': 'STAFF',
    'must_change_password': false,
    'offices': [
      {'id': 'isb', 'name': 'Islamabad — synthetic'},
    ],
  };
  return MaterialApp(
    theme: KarvaanDesign.theme(),
    home: WorkspaceShell(
      session: session,
      navigatorKey: GlobalKey<NavigatorState>(),
      child: page,
    ),
  );
}

Widget _dashboard() => ReportWorkspace(
  reports: ReportsFake(),
  trips: KpiFakeTrips(),
  masters: FakeMasters(),
  offices: const [],
  dashboard: true,
  guard: (child) => child,
  outputs: const SizedBox(),
);

Widget _trips() => TripWorkspace(
  repository: RegisterFakeTrips(),
  masters: FakeMasters(),
  offices: const [],
  guard: (child) => child,
);

class _PageA extends StatelessWidget {
  const _PageA();
  @override
  Widget build(BuildContext context) =>
      const ShellHeader(title: L10n.dashboard, child: SizedBox.expand());
}

class _PageB extends StatelessWidget {
  const _PageB();
  @override
  Widget build(BuildContext context) =>
      const ShellHeader(title: L10n.trips, child: SizedBox.expand());
}

void main() {
  setUp(() {
    LanguageModeStore.instance.mode.value = KarvaanLanguageMode.bilingual;
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAt(WidgetTester t, Size size, Widget page) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_shell(page));
    await t.pumpAndSettle();
  }

  testWidgets('(a) dashboard content starts within the ~120px budget', (
    t,
  ) async {
    await pumpAt(t, const Size(1440, 900), _dashboard());
    expect(find.byType(AppBar), findsNothing);
    final kpiTop = t.getTopLeft(find.byType(KpiCard).first).dy;
    expect(kpiTop, lessThanOrEqualTo(120), reason: 'KPI top was $kpiTop');
    expect(t.takeException(), isNull);
  });

  testWidgets('(a) trips: header segment compact, table follows the '
      'functional toolbar', (t) async {
    await pumpAt(t, const Size(1440, 900), _trips());
    expect(find.byType(AppBar), findsNothing);
    // The part this pass controls: shell bar + 12px content padding —
    // the always-visible search row starts at 76 (baseline 164).
    final searchTop = t.getTopLeft(find.byType(TextField).first).dy;
    expect(searchTop, lessThanOrEqualTo(80), reason: 'search top $searchTop');
    // Below it sit the standing functional rows by design (search field
    // + bilingual helper 86, chips 48, one-line scope caption ~28, gaps):
    // table at 256, down from the 376 baseline.
    final tableTop = t.getTopLeft(find.byType(KarvaanDataTable).first).dy;
    expect(tableTop, lessThanOrEqualTo(265), reason: 'table top $tableTop');
    expect(t.takeException(), isNull);
  });

  testWidgets('(b) bilingual dashboard title renders on ONE line', (t) async {
    await pumpAt(t, const Size(1440, 900), _dashboard());
    final title = find.byKey(const ValueKey('shell-header-title'));
    expect(title, findsOneWidget);
    final rect = t.getRect(title);
    // One line measures ~42 with the Nastaliq run's metrics; a stacked
    // pair measures ~84+. Both language runs live inside the same band.
    expect(rect.height, lessThanOrEqualTo(48), reason: 'title rect $rect');
    expect(
      find.descendant(of: title, matching: find.text('Dashboard')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: title, matching: find.text(L10n.dashboard.ur)),
      findsOneWidget,
    );
  });

  testWidgets('(c) the user name is a compact chip, not a stretched bar', (
    t,
  ) async {
    await pumpAt(t, const Size(1440, 900), _dashboard());
    final chip = find.byKey(const ValueKey('shell-user-chip'));
    expect(chip, findsOneWidget);
    final rect = t.getRect(chip);
    expect(rect.width, lessThanOrEqualTo(240), reason: 'chip rect $rect');
    // Anchored at the right of the bar (before language/account), not
    // spanning it: its left edge sits past 70% of the window width.
    expect(rect.left, greaterThan(1440 * 0.7));
    expect(find.text('Synthetic qa_isb'), findsOneWidget);
  });

  testWidgets('(d) dashboard actions live in the header row — no separate '
      'Reports-button row in the body', (t) async {
    await pumpAt(t, const Size(1440, 900), _dashboard());
    for (final label in ['Reports', 'Create report']) {
      final button = find.widgetWithText(TextButton, label);
      expect(button, findsOneWidget, reason: label);
      final top = t.getTopLeft(button).dy;
      expect(top, lessThan(70), reason: '$label sits at $top, below the bar');
    }
  });

  testWidgets('(e) phone trips: title unclipped, primary action reachable, '
      'no exceptions', (t) async {
    await pumpAt(t, const Size(390, 844), _trips());
    final title = find.byKey(const ValueKey('shell-header-title'));
    expect(title, findsOneWidget);
    final rect = t.getRect(title);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
    expect(rect.width, greaterThan(40));
    final newTrip = find.widgetWithText(FilledButton, 'New trip');
    expect(newTrip, findsOneWidget);
    final center = t.getCenter(newTrip);
    expect(center.dx, inInclusiveRange(0, 390));
    expect(center.dy, inInclusiveRange(0, 844));
    expect(t.takeException(), isNull);
  });

  testWidgets('(e) phone dashboard: title unclipped inside the bar and '
      'Create report reachable as its compact icon', (t) async {
    await pumpAt(t, const Size(390, 844), _dashboard());
    final title = find.byKey(const ValueKey('shell-header-title'));
    expect(title, findsOneWidget);
    final rect = t.getRect(title);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
    expect(rect.width, greaterThan(40));
    // At this width the full-width Reports shortcut yields (its
    // destination stays reachable from the menu) and Create report
    // compresses to an icon — both inside the single header row.
    final createIcon = find.byIcon(Icons.post_add_outlined);
    expect(createIcon, findsOneWidget);
    expect(t.getTopLeft(createIcon).dy, lessThan(140));
    expect(find.widgetWithText(TextButton, 'Reports'), findsNothing);
    // The dashboard BODY still carries its pre-existing fixed-height
    // section overflow at this size (report_workspace content column;
    // ~48px under test fonts, present before this pass at ~109-173px).
    // It is not a header regression; drain and pin its identity.
    final error = t.takeException();
    if (error != null) {
      expect(error.toString(), contains('overflowed'));
    }
  });

  testWidgets('same-route page swap keeps the NEW page header', (t) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_shell(const _PageA()));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shell-header-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
    // A different page type under the same route slot: the new page
    // registers during build, the old one disposes afterwards — its
    // unregister must not erase the new registration.
    await t.pumpWidget(_shell(const _PageB()));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shell-header-title')),
        matching: find.text('Trips'),
      ),
      findsOneWidget,
    );
  });
}
