import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/carrier_records_app.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:carrier_records/features/expenses/expense_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_layout_qa_test.dart' show TextQaSession, captureTextQa;
import 'expense_workspace_test.dart' show ExpensesFake, ExpenseMasters;
import 'payment_workspace_test.dart' show PaymentsFake;
import 'trip_workspace_test.dart' show FakeTrips;

void main() {
  for (final width in [320.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in ['account', 'navigation', 'expenses']) {
        testWidgets('visible controls $page $width/$scale', (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = TextQaSession()
            ..profile = {
              'id': 'synthetic',
              'role': 'STAFF',
              'must_change_password': false,
              'display_name': 'Synthetic QA',
              'offices': [
                {'id': 'khi', 'name': 'Karachi'},
              ],
            };
          final key = GlobalKey();
          final Widget screen = switch (page) {
            'account' => StaffHome(session: session),
            'navigation' => WorkspaceShell(
              session: session,
              navigatorKey: GlobalKey<NavigatorState>(),
              child: const Scaffold(body: Text('Synthetic workspace')),
            ),
            _ => ExpenseWorkspace(
              expenses: ExpensesFake(),
              finance: PaymentsFake(),
              trips: FakeTrips(),
              masters: ExpenseMasters(),
              offices: const [
                {'id': 'khi', 'name': 'Karachi'},
              ],
              guard: (w) => w,
            ),
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: KarvaanDesign.theme(),
              builder: (_, child) => RepaintBoundary(key: key, child: child!),
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 1100),
                  textScaler: TextScaler.linear(scale),
                ),
                child: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (page == 'navigation') {
            if (width < 760) {
              await tester.tap(find.byIcon(Icons.menu));
              await tester.pumpAndSettle();
            }
            // The rail shows the one-line label; the full name remains the
            // row's accessible name and each screen's own title.
            final label = find.text(WorkspaceDestination.expenses.railLabel.en);
            await tester.ensureVisible(label);
            await tester.pumpAndSettle();
            final semantics = tester.ensureSemantics();
            expect(
              tester
                  .getSemantics(find.byKey(const ValueKey('nav:expenses')))
                  .getSemanticsData()
                  .flagsCollection
                  .isButton,
              isTrue,
              reason: 'Navigation retains an announced button role',
            );
            semantics.dispose();
            expect(
              tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
              isFalse,
            );
          } else if (page == 'expenses') {
            // GUI handoff group 9 contract: with an empty list the one
            // create control is the empty state's "Record expense"
            // action; the header "New expense" button appears once the
            // list has rows, so the two never compete.
            final label = find.text(L10n.recordExpense.en);
            await tester.scrollUntilVisible(
              label,
              250,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 40,
            );
            await tester.ensureVisible(label);
            await tester.pumpAndSettle();
            expect(find.text(L10n.newExpense.en), findsNothing);
            expect(
              tester
                  .renderObject<RenderParagraph>(
                    find.text(L10n.expensesAndReimbursements.en),
                  )
                  .didExceedMaxLines,
              isFalse,
            );
            expect(
              tester
                  .renderObject<RenderParagraph>(
                    find.text(L10n.expensesAndReimbursements.ur),
                  )
                  .didExceedMaxLines,
              isFalse,
            );
            // Header compaction: no AppBar — the title lives in the
            // compact ShellHeader row. It must stay inside that row's
            // height budget (the old 88px bar) at this text scale.
            expect(
              tester.getRect(find.byType(BilingualHeaderTitle)).height,
              lessThanOrEqualTo(88 * scale + 8),
            );
            expect(
              tester
                  .getRect(find.text(L10n.expensesAndReimbursements.ur))
                  .bottom,
              // Floating-point slack: the Urdu run can be exactly as tall
              // as the title box.
              lessThanOrEqualTo(
                tester.getRect(find.byType(BilingualHeaderTitle)).bottom + 0.01,
              ),
            );
          } else {
            // Rule 4 layout: the username stands on its own LTR line
            // under the "Signed in as" label. Header compaction: the
            // anchor is the compact ShellHeader row, not an AppBar.
            final heading = find.text('Synthetic QA');
            expect(
              tester.getRect(heading).top,
              greaterThanOrEqualTo(
                tester.getRect(find.byType(BilingualHeaderTitle)).bottom,
              ),
            );
          }
          expect(tester.takeException(), isNull);
          await tester.runAsync(
            () => captureTextQa(tester, key, 'controls-$page-$width-$scale'),
          );
        });
      }
    }
  }
}
