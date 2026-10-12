import 'dart:convert';
import 'dart:io';

import 'package:carrier_records/features/auth/installed_config.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const empty = PublicConfig(
    environment: 'production',
    url: '',
    key: '',
    businessId: '',
  );
  Map<String, dynamic> valid() => {
    'version': 1,
    'url': 'https://example.supabase.co',
    'publishableKey': 'sb_publishable_example_public_value',
    'businessId': '00000000-0000-4000-8000-000000000001',
  };
  test('installed public configuration validates production contract', () {
    final config = InstalledConfig.parse(jsonEncode(valid()));
    expect(config.environment, 'production');
    expect(config.configured, true);
    expect(
      InstalledConfig.parse('\uFEFF${jsonEncode(valid())}').url,
      config.url,
    );
    for (final invalid in [
      {...valid(), 'version': 2},
      {...valid(), 'version': 1.0},
      {...valid(), 'url': 'http://localhost:54321'},
      {...valid(), 'url': 'https://user:password@example.supabase.co'},
      {...valid(), 'publishableKey': 'sb_secret_forbidden_value'},
      {...valid(), 'businessId': 'not-a-uuid'},
      {...valid(), 'password': 'forbidden'},
      {...valid(), 'environment': 'test'},
      {...valid(), 'publishableKey': 42},
    ]) {
      expect(
        () => InstalledConfig.parse(jsonEncode(invalid)),
        throwsFormatException,
      );
    }
    expect(() => InstalledConfig.parse('{}'), throwsFormatException);
    expect(() => InstalledConfig.parse('[]'), throwsFormatException);
  });
  test(
    'installed file loads without rewrites and fails closed when corrupt',
    () async {
      final root = await Directory.systemTemp.createTemp('carrier-config-');
      addTearDown(() => root.delete(recursive: true));
      Future<PublicConfig> load() => InstalledConfig.load(
        compiled: empty,
        windows: true,
        localAppData: root.path,
      );
      expect((await load()).configured, false);
      final file = File('${root.path}/CarrierRecords/client.json');
      await file.parent.create();
      await file.writeAsString(jsonEncode(valid()));
      final before = await load();
      final after = await load();
      expect(after.url, before.url);
      expect(after.businessId, before.businessId);
      expect(await file.readAsString(), jsonEncode(valid()));
      await file.writeAsString('{malformed');
      await expectLater(load(), throwsFormatException);
      await file.writeAsString('x' * 65537);
      await expectLater(load(), throwsFormatException);
    },
  );
  test(
    'non-Windows and development configurations keep their explicit source',
    () async {
      expect(
        await InstalledConfig.load(compiled: empty, windows: false),
        same(empty),
      );
      final local = PublicConfig.fromEnvironment();
      expect(
        await InstalledConfig.load(compiled: local, windows: true),
        same(local),
      );
    },
  );
}
