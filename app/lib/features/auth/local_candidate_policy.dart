import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_config.dart';

/// This review branch defaults to an isolated candidate, never a shipping client.
const karvaanLocalOnly = bool.fromEnvironment(
  'KARVAAN_LOCAL_ONLY',
  defaultValue: true,
);

abstract final class LocalCandidatePolicy {
  static const project = 'karvaan_bilingual_u20261013';
  static const apiPort = 60321;
  static const sessionPrefix = 'karvaan.candidate.session';

  static void validate(PublicConfig config) {
    config.validate();
    final uri = Uri.parse(config.url);
    if (config.environment != 'test' ||
        uri.scheme != 'http' ||
        !{'127.0.0.1', '10.0.2.2'}.contains(uri.host) ||
        uri.port != apiPort ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Isolated local test configuration required.');
    }
  }

  static void validateIdentity(dynamic identity) {
    if (identity is! Map ||
        identity.length != 3 ||
        identity['project_id'] != project ||
        identity['api_port'] != apiPort ||
        identity['purpose'] != 'synthetic-only') {
      throw const FormatException('Isolated test backend identity mismatch.');
    }
  }

  static Future<void> verify(PublicConfig config) async {
    // Reject the URL before constructing any network client or reading sessions.
    validate(config);
    final probe = SupabaseClient(config.url, config.key);
    try {
      validateIdentity(await probe.rpc('karvaan_local_identity'));
    } finally {
      await probe.dispose();
    }
  }
}
