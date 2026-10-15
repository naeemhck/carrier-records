import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    for (final admin in [true, false]) {
      testWidgets('shell scope, account and wrapping $width admin=$admin', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = _ShellSession();
        session.profile = {
          'id': 'synthetic',
          'display_name': 'Synthetic review only',
          'role': admin ? 'ADMIN' : 'STAFF',
          'must_change_password': false,
          'offices': [
            {'id': 'khi', 'name': 'Karachi'},
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: KarvaanDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1100),
                textScaler: TextScaler.linear(2),
              ),
              child: WorkspaceShell(
                session: session,
                navigatorKey: GlobalKey<NavigatorState>(),
                child: const Scaffold(body: Text('Synthetic page')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (width < 760) {
          await tester.tap(find.byIcon(Icons.menu));
          await tester.pumpAndSettle();
        }
        final list = find.byType(ListView).first;
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('nav:imports')),
          150,
          scrollable: find.descendant(
            of: list,
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byKey(const ValueKey('nav:imports')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('nav:masters')),
          admin ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      });
    }
  }
  testWidgets(
    'accessible material is opaque; paired labels stack with RTL runs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: const Scaffold(
              body: KarvaanGlass(child: BilingualText(L10n.journeyStep)),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        tester.getTopLeft(find.text(L10n.journeyStep.ur)).dy,
        greaterThan(tester.getTopLeft(find.text(L10n.journeyStep.en)).dy),
      );
      expect(
        tester.widget<Text>(find.text(L10n.journeyStep.ur)).textDirection,
        TextDirection.rtl,
      );
      expect(
        tester.widget<Text>(find.text(L10n.journeyStep.en)).textDirection,
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    },
  );
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
