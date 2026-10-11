import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'public_config.dart';
import 'secure_session_storage.dart';

class StaffSession extends ChangeNotifier {
  StaffSession(this.client, this.config, this.storage) {
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (event.session == null) {
        _generation++;
        profile = null;
        notifyListeners();
      } else if (event.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(refresh());
      }
    });
  }
  final SupabaseClient client;
  final PublicConfig config;
  final SecureSessionStorage storage;
  late final StreamSubscription<AuthState> _subscription;
  Map<String, dynamic>? profile;
  String? error;
  int _generation = 0;
  Future<void> refresh() async {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) return;
    final generation = ++_generation;
    try {
      final verified = Map<String, dynamic>.from(
        await client.rpc('get_session_profile') as Map,
      );
      if (generation != _generation ||
          token != client.auth.currentSession?.accessToken) {
        return;
      }
      profile = verified;
      error = null;
    } catch (_) {
      if (generation != _generation) return;
      profile = null;
      error = 'Access could not be verified. Sign in again or contact your administrator.';
    }
    notifyListeners();
  }

  Future<void> signIn(String username, String password) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: config.emailFor(username),
        password: password,
      );
      // The SDK logs persistence errors; explicitly await the protected write
      // before reporting a usable sign-in.
      await storage.persistSession(jsonEncode(response.session!.toJson()));
      await refresh();
      if (profile == null) {
        throw StateError('Account unavailable.');
      }
    } catch (_) {
      await signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _generation++;
    profile = null;
    notifyListeners();
    try {
      await client.auth.signOut(scope: SignOutScope.global);
    } finally {
      // Clear local persistence even when the network is unavailable.
      await client.auth.signOut(scope: SignOutScope.local).catchError((_) {});
      await storage.removePersistedSession();
      profile = null;
      notifyListeners();
    }
  }

  Future<void> changePassword(String current, String next) async {
    await command({
      'action': 'change',
      'current_password': current,
      'password': next,
      'expected_version': profile!['version'],
    });
    await signOut();
  }

  Future<dynamic> command(Map<String, dynamic> body) async {
    final result = await client.functions.invoke('staff-accounts', body: body);
    if (result.status != 200) throw StateError('Account operation failed.');
    return result.data;
  }

  Future<List<Map<String, dynamic>>> accounts() async =>
      (await client.rpc('list_staff_accounts') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
