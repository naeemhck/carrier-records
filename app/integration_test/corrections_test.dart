import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:carrier_records/features/finance/correction_repository.dart';
import 'package:carrier_records/features/finance/correction_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real Windows creator expense reversal and replacement', (
    tester,
  ) async {
    final config = PublicConfig.fromEnvironment()..validate();
    final storage = SecureSessionStorage(
      namespace: 'native-corrections.${DateTime.now().microsecondsSinceEpoch}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(localStorage: storage),
    );
    final client = Supabase.instance.client,
        session = StaffSession(Supabase.instance.client, config, storage);
    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    Future<void> field(String label, String value) async {
      final f = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(f);
      await settle();
      await tester.enterText(f, value);
      await tester.pump();
    }

    Future<void> tap(String label) async {
      final f = find.text(label);
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await tester.scrollUntilVisible(
          f,
          250,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(f);
      await settle();
      await tester.tap(f);
      await settle();
    }

    try {
      await session.signIn(
        const String.fromEnvironment('TEST_USERNAME'),
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      final commands = CorrectionRepository(client);
      const id = String.fromEnvironment('TEST_EVENT_ID');
      final events = await commands.history(null, 0),
          event = events.firstWhere((e) => e['id'] == id);
      final review = await commands.review(id);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CorrectionForm(
                      commands: commands,
                      id: id,
                      review: review,
                      event: event,
                    ),
                  ),
                ),
                child: const Text('Open correction'),
              ),
            ),
          ),
        ),
      );
      await tap('Open correction');
      await field('Reason', 'Synthetic native T10 correction');
      await field('Corrected amount', '3600.13');
      await tap('Review correction');
      await tap('Confirm reviewed correction');
      expect(find.textContaining('Correction committed.'), findsOneWidget);
      final history = await commands.history(null, 0);
      expect(
        history
            .where(
              (e) => e['replacement_of_id'] == id && e['amount'] == '3600.13',
            )
            .length,
        1,
      );
      expect(history.where((e) => e['reversal_of_id'] == id).length, 1);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await session.signOut();
      session.dispose();
      await Supabase.instance.dispose();
      await storage.removePersistedSession();
    }
  });
}
