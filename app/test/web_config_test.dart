import 'package:carrier_records/features/auth/installed_config.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web startup uses compiled public configuration without native I/O',
    () async {
      if (!kIsWeb) return;
      const config = PublicConfig(
        environment: 'production',
        url: 'https://example.supabase.co',
        key: 'sb_publishable_test',
        businessId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      );
      expect(
        await InstalledConfig.load(compiled: config, windows: true),
        same(config),
      );
    },
  );
}
