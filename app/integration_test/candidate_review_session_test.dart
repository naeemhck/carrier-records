import 'package:carrier_records/features/auth/local_candidate_policy.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:carrier_records/features/auth/staff_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Explicit fixture preparation for an ordinary candidate's restored-session
// smoke test. It never reads installed configuration or production sessions.
// Test credentials are only supplied through an ignored native-test define file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Prepare only isolated synthetic candidate protected session', (
    t,
  ) async {
    expect(karvaanLocalOnly, isTrue);
    const username = String.fromEnvironment('TEST_USERNAME');
    expect({'review_admin', 'review_khi', 'review_isb'}, contains(username));
    final config = PublicConfig.fromEnvironment()..validate();
    await LocalCandidatePolicy.verify(config);
    final storage = SecureSessionStorage(
      keyPrefix: LocalCandidatePolicy.sessionPrefix,
      namespace:
          '${config.environment}.${Uri.encodeComponent(config.url)}.${config.businessId}',
    );
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      authOptions: FlutterAuthClientOptions(
        localStorage: storage,
        detectSessionInUri: false,
      ),
    );
    final session = StaffSession(Supabase.instance.client, config, storage);
    try {
      await session.signIn(
        username,
        const String.fromEnvironment('TEST_PASSWORD'),
      );
      expect(session.profile?['username'], username);
      expect(
        (session.profile?['offices'] as List).length,
        username == 'review_admin' ? 2 : 1,
      );
      expect(await storage.hasAccessToken(), isTrue);
      await t.pumpWidget(const SizedBox.shrink());
    } finally {
      session.dispose();
      await Supabase.instance.dispose();
      // Deliberately retain only this verified synthetic candidate namespace.
      // Ordinary executable startup must revalidate its identity/session/profile.
    }
  });
}
