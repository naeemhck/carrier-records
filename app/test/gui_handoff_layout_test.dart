import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:carrier_records/features/trips/trip_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'document_workspace_test.dart' show DocumentFake;
import 'expense_workspace_test.dart' show ExpenseMasters, ExpensesFake;
import 'gui_trip_detail_test.dart' show DetailFixture;
import 'output_workspace_test.dart' show OutputsFake;
import 'payment_workspace_test.dart' show PaymentsFake;
import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;
import 'trips_table_test.dart' show TableFakeTrips;

/// Regression coverage for the 2026-10-20 GUI handoff verification.
/// Baseline measurements (pre-fix, bilingual mode): trip-detail tab bar
/// at y=532.7 in the 460px panel with totals cells stacked one per row
/// and a 812px hero scroll extent; Outputs title clipped above the
/// AppBar (rect top = -69) at 390px; first trip card at y=451.5 at
/// 390x844; pagination rendered under empty lists.
void main() {
  final store = LanguageModeStore.instance;
  setUp(() {
    store.mode.value = KarvaanLanguageMode.bilingual;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => store.mode.value = KarvaanLanguageMode.bilingual);

  void setView(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('trip panel: compact header, tabs high, one scroll area', (    tester,
  ) async {
    setView(tester, 1440, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            // The desktop panel width openRecord now uses at >=1100px.
            child: SizedBox(
              width: 640,
              height: 900,
              child: TripDetail(
                repository: DetailFixture(),
                id: 'trip',
                canReturn: (_) => false,
                onEdit: (_) async {},
                onExpenses: () async {},
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Totals cells sit two-up, not stacked one per row.
    final charge = tester.getRect(
      find.byKey(const ValueKey('trip-total-customer_charge')),
    );
    final commission = tester.getRect(
      find.byKey(const ValueKey('trip-total-commission')),
    );
    expect((charge.top - commission.top).abs(), lessThan(8));
    expect(commission.left, greaterThan(charge.left));
    // Exactly ONE scroll area contains the header in the wide panel:
    // the single ListView — no nested capped hero region (baseline:
    // a 812px-extent scroll region nested inside the page scroll).
    final heroScrollables = find.ancestor(
      of: find.byKey(const ValueKey('trip-total-customer_charge')),
      matching: find.byType(Scrollable),
    );
    expect(heroScrollables, findsOneWidget);
    // The tab bar is reachable within a short scroll of that one area
    // and lands inside the viewport (the ListView builds it lazily).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('detail-tab-0')),
      120,
      scrollable: heroScrollables.first,
      maxScrolls: 10,
    );
    await tester.pumpAndSettle();
    final tabRect = tester.getRect(
      find.byKey(const ValueKey('detail-tab-0')),
    );
    expect(tabRect.top, lessThan(900));
    expect(tabRect.bottom, greaterThan(0));
  });

  for (final mode in KarvaanLanguageMode.values) {
    testWidgets('create-report header does not clip at 390px ($mode)', (
      tester,
    ) async {
      store.mode.value = mode;
      setView(tester, 390, 844);
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: OutputWorkspace(
            commands: OutputsFake(),
            masters: FakeMasters(),
            trips: FakeTrips(),
            offices: const [],
            administrator: false,
            documents: DocumentFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final titleText = mode == KarvaanLanguageMode.urdu
          ? L10n.createReport.ur
          : L10n.createReport.en;
      final titleRect = tester.getRect(find.text(titleText).first);
      expect(titleRect.top, greaterThanOrEqualTo(0));
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(titleRect.bottom, lessThanOrEqualTo(appBarBottom + 1));
      // Issued documents is a body header action below the AppBar now.
      final actionText = mode == KarvaanLanguageMode.urdu
          ? L10n.issuedDocuments.ur
          : L10n.issuedDocuments.en;
      final actionRect = tester.getRect(find.text(actionText).first);
      expect(actionRect.top, greaterThanOrEqualTo(appBarBottom - 1));
    });
  }

  testWidgets('trips at 390x844: first card high, chip overflow affordance', (
    tester,
  ) async {
    setView(tester, 390, 844);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: TripWorkspace(
          repository: TableFakeTrips(),
          masters: FakeMasters(),
          offices: const [
            {'id': 'origin', 'name': 'Origin'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final top = tester.getRect(find.text('TRIP-001').first).top;
    expect(top, lessThan(440), reason: 'first card top was $top');
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('trips empty states: unfiltered vs filtered, no pagination', (
    tester,
  ) async {
    setView(tester, 390, 844);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: TripWorkspace(
          repository: FakeTrips(),
          masters: FakeMasters(),
          offices: const [
            {'id': 'origin', 'name': 'Origin'},
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(L10n.noTripsInThisScope.en), findsOneWidget);
    expect(find.text(L10n.noMatchesForFilters.en), findsNothing);
    expect(
      find.widgetWithText(TextButton, L10n.previous.en),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('trip-filter-DRAFT')));
    await tester.pumpAndSettle();
    expect(find.text(L10n.noMatchesForFilters.en), findsOneWidget);
    expect(find.text(L10n.noTripsInThisScope.en), findsNothing);
    await tester.tap(find.text(L10n.clearRecordFilters.en));
    await tester.pumpAndSettle();
    expect(find.text(L10n.noTripsInThisScope.en), findsOneWidget);
  });

  testWidgets('expenses empty: one create action, no pagination', (
    tester,
  ) async {
    setView(tester, 1280, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: ExpenseWorkspace(
          expenses: ExpensesFake(),
          finance: PaymentsFake(),
          trips: FakeTrips(),
          masters: ExpenseMasters(),
          offices: const [
            {'id': 'office', 'name': 'Office'},
          ],
          guard: (w) => w,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // GPT QA F05: the main list's empty state names its scope; the
    // generic "No records found." line remains only in search pickers.
    expect(find.text(L10n.noExpensesInYourCurrentScope.en), findsOneWidget);
    expect(find.text(L10n.noRecordsFound.en), findsNothing);
    // Exactly one create action in the empty state: "Record expense"
    // in the empty state itself; the header "New expense" button is
    // suppressed while the list is empty (they competed — group 9).
    expect(find.text(L10n.recordExpense.en), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, L10n.newExpense.en),
      findsNothing,
    );
    expect(find.widgetWithText(TextButton, L10n.previous.en), findsNothing);
  });

  testWidgets('shell rail compacts in the tablet band', (tester) async {
    Future<void> pumpShell(double width) async {
      setView(tester, width, 900);
      final session = _ShellSession();
      session.profile = {
        'id': 'synthetic',
        'display_name': 'Synthetic review only',
        'role': 'STAFF',
        'must_change_password': false,
        'offices': [
          {'id': 'khi', 'name': 'Karachi'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: WorkspaceShell(
            session: session,
            navigatorKey: GlobalKey<NavigatorState>(),
            child: const Scaffold(body: Text('Synthetic page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(session.dispose);
    }

    await pumpShell(800);
    expect(
      tester.widget(find.byKey(const ValueKey('nav:trips'))),
      isA<IconButton>(),
      reason: 'tablet band should use the compact icon rail',
    );
    await pumpShell(1280);
    expect(
      tester.widget(find.byKey(const ValueKey('nav:trips'))),
      isA<InkWell>(),
      reason: 'desktop keeps the full labelled rail',
    );
  });
}

class _ShellSession extends ChangeNotifier implements StaffSession {
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
