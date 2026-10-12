import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'public_config.dart';

/// Public configuration only. Sessions stay in the native protected store.
class InstalledConfig {
  static Future<PublicConfig> load({
    required PublicConfig compiled,
    bool? windows,
    String? localAppData,
  }) async {
    if (kIsWeb ||
        !(windows ?? Platform.isWindows) ||
        compiled.environment != 'production') {
      return compiled;
    }
    final root = localAppData ?? Platform.environment['LOCALAPPDATA'];
    if (root == null || root.isEmpty) {
      throw const FormatException(
        'Windows configuration location unavailable.',
      );
    }
    final file = File('$root/CarrierRecords/client.json');
    if (!await file.exists()) return compiled;
    if (await file.length() > 65536) {
      throw const FormatException('Invalid public configuration.');
    }
    return parse(await file.readAsString());
  }

  static PublicConfig parse(String text) {
    // Windows PowerShell 5.1 writes UTF-8 JSON with a BOM.
    final data = jsonDecode(
      text.startsWith('\uFEFF') ? text.substring(1) : text,
    );
    const keys = {'version', 'url', 'publishableKey', 'businessId'};
    if (data is! Map<String, dynamic> ||
        data.length != keys.length ||
        !data.keys.every(keys.contains) ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['url'] is! String ||
        data['publishableKey'] is! String ||
        data['businessId'] is! String) {
      throw const FormatException('Invalid public configuration.');
    }
    final config = PublicConfig(
      environment: 'production',
      url: data['url'] as String,
      key: data['publishableKey'] as String,
      businessId: data['businessId'] as String,
    );
    config.validate();
    return config;
  }
}
