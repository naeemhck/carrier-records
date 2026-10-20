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
            final label = find.text(L10n.expensesAndReimbursements.en);
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
            final label = find.text(L10n.newExpense.en);
            await tester.scrollUntilVisible(
              label,
              250,
              scrollable: find.byType(Scrollable).first,
              maxScrolls: 40,
            );
            await tester.ensureVisible(label);
            await tester.pumpAndSettle();
            final icon = find.byIcon(Icons.add);
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
            expect(
              tester.getRect(icon).right,
              lessThan(tester.getRect(label).left),
            );
            expect(
              tester
                  .getRect(find.text(L10n.expensesAndReimbursements.ur))
                  .bottom,
              lessThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
            );
          } else {
            // Rule 4 layout: the username stands on its own LTR line
            // under the "Signed in as" label.
            final heading = find.text('Synthetic QA');
            expect(
              tester.getRect(heading).top,
              greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
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
