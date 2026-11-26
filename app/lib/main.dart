import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/carrier_records_app.dart';
import 'app/language_mode.dart';
import 'features/auth/public_config.dart';
import 'features/auth/installed_config.dart';
import 'features/auth/secure_session_storage.dart';
import 'features/auth/staff_session.dart';
import 'features/auth/local_candidate_policy.dart';
import 'features/auth/qa_preview_policy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore the saved display-language choice (presentation state only).
  await LanguageModeStore.instance.load();
  try {
    final compiled = PublicConfig.fromEnvironment();
    final config = (karvaanQaPreview || karvaanLocalOnly)
        ? compiled
        : await InstalledConfig.load(compiled: compiled);
    if (karvaanQaPreview) {
      if (!kIsWeb) throw const FormatException('QA preview is web-only.');
      await QaPreviewPolicy.verify(config);
    } else if (karvaanLocalOnly) {
      await LocalCandidatePolicy.verify(config);
    }
    if (!config.configured) {
      _launch(const CarrierRecordsApp());
      return;
    }
    config.validate();
    final storage = SecureSessionStorage(
      keyPrefix: karvaanQaPreview
          ? QaPreviewPolicy.sessionPrefix
          : karvaanLocalOnly
          ? LocalCandidatePolicy.sessionPrefix
          : 'carrier.session',
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
    await session.refresh();
    _launch(CarrierRecordsApp(session: session));
  } catch (_) {
    _launch(
      const CarrierRecordsApp(
        setupError: 'Secure sign-in could not start. Ask your administrator to check this installation.',
      ),
    );
  }
}

void _launch(Widget app) {
  runApp(ProviderScope(child: app));
}
