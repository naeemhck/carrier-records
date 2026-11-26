import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:carrier_records/app/workspace_shell.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Density pass (2026-10-20): the three display-language modes. Bilingual
/// stacking is the default; single-language modes render one line only,
/// keep the layout LTR, and shrink the shell navigation rows.
void main() {
  final store = LanguageModeStore.instance;

  setUp(() {
    store.mode.value = KarvaanLanguageMode.bilingual;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => store.mode.value = KarvaanLanguageMode.bilingual);

  Future<void> pumpText(WidgetTester t, Widget child) => t.pumpWidget(
    MaterialApp(
      theme: KarvaanDesign.theme(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('default mode is bilingual and stacks both lines', (t) async {
    await pumpText(t, const BilingualText(L10n.customerOutstanding));
    expect(find.text(L10n.customerOutstanding.en), findsOneWidget);
    expect(find.text(L10n.customerOutstanding.ur), findsOneWidget);
  });

  testWidgets('english mode renders the English line only', (t) async {
    store.mode.value = KarvaanLanguageMode.english;
    await pumpText(
      t,
      const Column(
        children: [
          BilingualText(L10n.customerOutstanding),
          BilingualCaption(L10n.settlementsDue),
        ],
      ),
    );
    expect(find.text(L10n.customerOutstanding.en), findsOneWidget);
    expect(find.text(L10n.customerOutstanding.ur), findsNothing);
    expect(find.text(L10n.settlementsDue.en), findsOneWidget);
    expect(find.text(L10n.settlementsDue.ur), findsNothing);
  });

  testWidgets('urdu mode renders the Urdu line only, layout stays LTR', (
    t,
  ) async {
    store.mode.value = KarvaanLanguageMode.urdu;
    await pumpText(t, const BilingualText(L10n.customerOutstanding));
    expect(find.text(L10n.customerOutstanding.en), findsNothing);
    final urdu = t.widget<Text>(find.text(L10n.customerOutstanding.ur));
    expect(urdu.textDirection, TextDirection.rtl);
    // No ancestor flips the layout direction.
    expect(
      Directionality.of(t.element(find.text(urdu.data!))),
      TextDirection.ltr,
    );
  });

  testWidgets('switching mode rebuilds already-mounted bilingual text', (
    t,
  ) async {
    await pumpText(t, const BilingualText(L10n.customerOutstanding));
    expect(find.text(L10n.customerOutstanding.ur), findsOneWidget);
    store.mode.value = KarvaanLanguageMode.english;
    await t.pump();
    expect(find.text(L10n.customerOutstanding.ur), findsNothing);
    store.mode.value = KarvaanLanguageMode.urdu;
    await t.pump();
    expect(find.text(L10n.customerOutstanding.en), findsNothing);
    expect(find.text(L10n.customerOutstanding.ur), findsOneWidget);
  });

  testWidgets('inline line shows one label per mode, value stays single', (
    t,
  ) async {
    String plain() => t
        .widget<Text>(
          find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
        )
        .textSpan!
        .toPlainText();
    store.mode.value = KarvaanLanguageMode.english;
    await pumpText(
      t,
      BilingualInlineLine(
        L10n.brokerLine,
        value: Bilingual.data('Synthetic broker'),
      ),
    );
    expect(plain(), '${L10n.brokerLine.en}: Synthetic broker');
    store.mode.value = KarvaanLanguageMode.urdu;
    await t.pump();
    // A left-to-right mark follows an Urdu label so a date or amount after
    // it keeps its own order (GUI refresh).
    expect(plain(), '${L10n.brokerLine.ur}\u200E: Synthetic broker');
    store.mode.value = KarvaanLanguageMode.bilingual;
    await t.pump();
    expect(
      plain(),
      '${L10n.brokerLine.en} / ${L10n.brokerLine.ur}\u200E: Synthetic broker',
    );
  });

  // GUI refresh: the Urdu companion shares the field's one label line; it
  // no longer adds a helper row under every field in any mode.
  testWidgets('field label carries both languages on one line, no helper', (
    t,
  ) async {
    late InputDecoration decorated;
    Future<void> pump() => t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            decorated = bilingualDecoration(
              context,
              const InputDecoration(label: BilingualCaption(L10n.username)),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    await pump();
    expect(decorated.helper, isNull);
    expect(decorated.label, isA<BilingualFloatingLabel>());
    store.mode.value = KarvaanLanguageMode.english;
    await pump();
    expect(decorated.helper, isNull);
    expect(decorated.label, isA<BilingualFloatingLabel>());
    store.mode.value = KarvaanLanguageMode.urdu;
    await pump();
    expect(decorated.helper, isNull);
  });

  testWidgets('picker switches and persists the mode', (t) async {
    await pumpText(t, const LanguageModePicker());
    await t.tap(find.text('اردو'));
    await t.pump();
    expect(store.mode.value, KarvaanLanguageMode.urdu);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(LanguageModeStore.storageKey),
      KarvaanLanguageMode.urdu.name,
    );
    await t.tap(find.text('English'));
    await t.pump();
    expect(store.mode.value, KarvaanLanguageMode.english);
  });

  test(
    'saved mode is restored on load; unknown values keep the default',
    () async {
      SharedPreferences.setMockInitialValues({
        LanguageModeStore.storageKey: 'urdu',
      });
      await store.load();
      expect(store.mode.value, KarvaanLanguageMode.urdu);
      SharedPreferences.setMockInitialValues({
        LanguageModeStore.storageKey: 'klingon',
      });
      store.mode.value = KarvaanLanguageMode.bilingual;
      await store.load();
      expect(store.mode.value, KarvaanLanguageMode.bilingual);
    },
  );

  testWidgets('nav rows are compact in every language mode', (t) async {
    t.view.physicalSize = const Size(1280, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
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
    await t.pumpWidget(
      MaterialApp(
        theme: KarvaanDesign.theme(),
        home: WorkspaceShell(
          session: session,
          navigatorKey: GlobalKey<NavigatorState>(),
          child: const Scaffold(body: Text('Synthetic page')),
        ),
      ),
    );
    await t.pumpAndSettle();
    double navHeight() =>
        t.getSize(find.byKey(const ValueKey('nav:trips'))).height;
    final bilingualHeight = navHeight();
    store.mode.value = KarvaanLanguageMode.english;
    await t.pumpAndSettle();
    final englishHeight = navHeight();
    expect(englishHeight, inInclusiveRange(40, 48));
    // GUI refresh: the Urdu companion shares the row's one line, so a
    // bilingual row is as compact as a single-language one.
    expect(bilingualHeight, inInclusiveRange(40, 48));
    // The top bar offers the language switch next to the account menu.
    expect(find.byIcon(Icons.language_outlined), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    session.dispose();
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
