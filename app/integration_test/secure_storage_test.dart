import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native protected session write, reopen, namespace isolation and logout deletion',
    (tester) async {
      final namespace =
          'native-verification.${DateTime.now().microsecondsSinceEpoch}';
      final first = SecureSessionStorage(namespace: namespace);
      try {
        await first.initialize();
        expect(await first.hasAccessToken(), false);
        await first.persistSession('{"synthetic_session":"no-real-token"}');
        final reopened = SecureSessionStorage(namespace: namespace);
        await reopened.initialize();
        expect(
          await reopened.accessToken(),
          '{"synthetic_session":"no-real-token"}',
        );
        expect(
          await SecureSessionStorage(namespace: '$namespace.other')
              .accessToken(),
          isNull,
        );
        await reopened.removePersistedSession();
        expect(await first.hasAccessToken(), false);
      } finally {
        await first.removePersistedSession();
      }
    },
  );
}
