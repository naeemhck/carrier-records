import 'dart:convert';

class PublicConfig {
  const PublicConfig({
    required this.environment,
    required this.url,
    required this.key,
    required this.businessId,
  });
  factory PublicConfig.fromEnvironment() => const PublicConfig(
    environment: String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    url: String.fromEnvironment('SUPABASE_URL'),
    key: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    businessId: String.fromEnvironment('APP_BUSINESS_ID'),
  );
  final String environment, url, key, businessId;
  bool get configured =>
      url.isNotEmpty && key.isNotEmpty && businessId.isNotEmpty;
  void validate() {
    final uri = Uri.tryParse(url);
    final local = [
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
      '::1',
    ].contains(uri?.host);
    if (!['local', 'test', 'production'].contains(environment) ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.scheme != 'https' &&
            !(environment != 'production' && local && uri.scheme == 'http'))) {
      throw const FormatException('Invalid backend configuration.');
    }
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    ).hasMatch(businessId)) {
      throw const FormatException('Invalid business identifier.');
    }
    if (key.startsWith('sb_publishable_') && key.length > 20) return;
    try {
      final parts = key.split('.');
      if (parts.length == 3 &&
          (jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              ) as Map)['role'] ==
              'anon') {
        return;
      }
    } catch (_) {
      /* Invalid public configuration is rejected below. */
    }
    throw const FormatException('A public project key is required.');
  }

  String emailFor(String username) {
    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_.-]{2,31}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid username.');
    }
    return '$normalized.$businessId@staff.invalid';
  }
}
