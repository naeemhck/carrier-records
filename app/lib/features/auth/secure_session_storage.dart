import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase persistence uses the native protected store, never SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({
    required String namespace,
    FlutterSecureStorage? storage,
  }) : _key = 'carrier.session.$namespace',
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(resetOnError: false),
           );
  final String _key;
  final FlutterSecureStorage _storage;
  Future<void> _pending = Future.value();
  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<void> initialize() async {
    await _storage.containsKey(key: _key);
  }

  @override
  Future<String?> accessToken() async {
    await _pending;
    return _storage.read(key: _key);
  }

  @override
  Future<bool> hasAccessToken() async => await accessToken() != null;
  @override
  Future<void> persistSession(String persistSessionString) =>
      _enqueue(() => _storage.write(key: _key, value: persistSessionString));
  @override
  Future<void> removePersistedSession() =>
      _enqueue(() => _storage.delete(key: _key));
}
