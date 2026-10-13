import 'dart:convert';

import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/features/auth/secure_session_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const business = '00000000-0000-4000-8000-000000000001';
  String jwt(String role) =>
      'e30.${base64Url.encode(utf8.encode(jsonEncode({'role': role}))).replaceAll('=', '')}.signature';
  test('configuration accepts public keys and normalizes usernames', () {
    final c = PublicConfig(
      environment: 'local',
      url: 'http://127.0.0.1:54321',
      key: jwt('anon'),
      businessId: business,
    );
    c.validate();
    expect(c.emailFor('  Office.One '), 'office.one.$business@staff.invalid');
    expect(() => c.emailFor('bad@user'), throwsFormatException);
  });
  test(
    'configuration rejects privileged keys and insecure production URLs',
    () {
      for (final key in [jwt('service_role'), 'sb_secret_example', 'invalid']) {
        expect(
          () => PublicConfig(
            environment: 'local',
            url: 'http://localhost:54321',
            key: key,
            businessId: business,
          ).validate(),
          throwsFormatException,
        );
      }
      expect(
        () => PublicConfig(
          environment: 'production',
          url: 'http://localhost:54321',
          key: jwt('anon'),
          businessId: business,
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => PublicConfig(
          environment: 'local',
          url: 'http://example.com',
          key: jwt('anon'),
          businessId: business,
        ).validate(),
        throwsFormatException,
      );
    },
  );
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  test(
    'session writes are serialized and logout deletion wins pending writes',
    () async {
      final values = <String, String>{};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            final key = args['key'] as String;
            switch (call.method) {
              case 'write':
                await Future<void>.delayed(const Duration(milliseconds: 15));
                values[key] = args['value'];
                return null;
              case 'read':
                return values[key];
              case 'delete':
                values.remove(key);
                return null;
              case 'containsKey':
                return values.containsKey(key);
              default:
                throw UnsupportedError(call.method);
            }
          });
      final store = SecureSessionStorage(namespace: 'test');
      await store.initialize();
      final writing = store.persistSession('synthetic-session');
      final deleting = store.removePersistedSession();
      await Future.wait([writing, deleting]);
      expect(await store.hasAccessToken(), false);
      await store.persistSession('synthetic-session');
      expect(await store.accessToken(), 'synthetic-session');
      final candidate = SecureSessionStorage(
        namespace: 'test',
        keyPrefix: 'karvaan.candidate.session',
      );
      expect(await candidate.accessToken(), isNull);
      await candidate.persistSession('synthetic-candidate-session');
      expect(await store.accessToken(), 'synthetic-session');
      await candidate.removePersistedSession();
      expect(await store.accessToken(), 'synthetic-session');
      expect(
        await SecureSessionStorage(namespace: 'different').accessToken(),
        isNull,
      );
      await store.removePersistedSession();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
  test('secure storage errors propagate without plaintext fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'locked'),
        );
    final store = SecureSessionStorage(namespace: 'locked');
    await expectLater(
      store.persistSession('synthetic-session'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(store.initialize(), throwsA(isA<PlatformException>()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
