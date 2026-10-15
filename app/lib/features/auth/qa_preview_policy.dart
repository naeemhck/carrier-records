import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_config.dart';

/// Separate opt-in hosted QA boundary; local candidate checks stay unchanged.
const karvaanQaPreview = bool.fromEnvironment('KARVAAN_QA_PREVIEW');

abstract final class QaPreviewPolicy {
  static const projectRef = 'nxyjjjxvgibehovlyycx';
  static const businessId = '9807abdd-e187-4774-8d08-7220a9062524';
  static const api = 'https://nxyjjjxvgibehovlyycx.supabase.co';
  static const sessionPrefix = 'karvaan.qa.preview.session';

  static void validate(PublicConfig config) {
    config.validate();
    if (config.environment != 'test' ||
        config.url != api ||
        config.businessId != businessId) {
      throw const FormatException('Explicit synthetic QA target required.');
    }
  }

  static void validateIdentity(dynamic identity) {
    if (identity is! Map ||
        identity.length != 3 ||
        identity['project_ref'] != projectRef ||
        identity['business_id'] != businessId ||
        identity['purpose'] != 'synthetic-only') {
      throw const FormatException('Synthetic QA identity mismatch.');
    }
  }

  static Future<void> verify(PublicConfig config) async {
    // Reject targets before opening a network client or reading a session.
    validate(config);
    final probe = SupabaseClient(config.url, config.key);
    try {
      validateIdentity(await probe.rpc('karvaan_qa_identity'));
    } finally {
      await probe.dispose();
    }
  }
}
