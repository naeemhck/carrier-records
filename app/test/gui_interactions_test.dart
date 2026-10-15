import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'choice Escape is not a null selection; keyboard selection is explicit',
    (tester) async {
      final selected = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: KarvaanDesign.theme(),
          home: Scaffold(
            body: KarvaanChoiceField<String>(
              initialValue: 'khi',
              decoration: const InputDecoration(
                label: BilingualCaption(L10n.officeFilter),
              ),
              items: const [
                DropdownMenuItem(value: 'khi', child: Text('Karachi')),
                DropdownMenuItem(
                  value: null,
                  child: BilingualText(L10n.allOffices),
                ),
              ],
              onChanged: selected.add,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text(L10n.allOffices.en), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(find.text(L10n.allOffices.en), findsNothing);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text(L10n.allOffices.en));
      await tester.pumpAndSettle();
      expect(selected, [null]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('account navigation observes pending posting PopScope', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = WorkspaceRouteObserver();
    final busy = ValueNotifier(true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Account')),
      ),
    );
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ValueListenableBuilder(
          valueListenable: busy,
          builder: (_, value, _) => PopScope(
            canPop: !value,
            child: const Scaffold(body: Text('Pending synthetic operation')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(observer.canReturnHome, isFalse);
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Pending synthetic operation'), findsOneWidget);
    busy.value = false;
    await tester.pumpAndSettle();
    expect(observer.canReturnHome, isTrue);
    await nav.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
    busy.dispose();
  });
}
