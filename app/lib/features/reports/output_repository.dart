import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class OutputCommands {
  Future<Map<String, dynamic>> catalogue(String report, String recipient);
  Future<List<Map<String, dynamic>>> presets(String report, String recipient);
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command);
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> delete(String id, String request, int version);
  Future<List<Map<String, dynamic>>> receipts(
    String recipient,
    String? party,
    Map<String, dynamic> filters,
    int offset,
  );
}

class OutputRepository implements OutputCommands {
  OutputRepository(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> p,
  ) async =>
      Map<String, dynamic>.from(await client.rpc(name, params: p) as Map);
  @override
  Future<Map<String, dynamic>> catalogue(String report, String recipient) =>
      call('get_output_catalogue', {
        'report_kind': report,
        'recipient_kind': recipient,
      });
  @override
  Future<List<Map<String, dynamic>>> presets(
    String report,
    String recipient,
  ) async => (await client.rpc(
    'list_output_presets',
    params: {'report_kind': report, 'recipient_kind': recipient},
  ) as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) =>
      call('prepare_output', command);
  @override
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) => call('save_output_preset', {
    'target_id': id,
    'request_id': request,
    'expected_version': version,
    'payload': payload,
  });
  @override
  Future<Map<String, dynamic>> delete(String id, String request, int version) =>
      call('delete_output_preset', {
        'target_id': id,
        'request_id': request,
        'expected_version': version,
      });
  @override
  Future<List<Map<String, dynamic>>> receipts(
    String recipient,
    String? party,
    Map<String, dynamic> filters,
    int offset,
  ) async => (await client.rpc(
    'list_output_receipts',
    params: {
      'recipient_kind': recipient,
      'recipient_id': party,
      'filters': filters,
      'page_offset': offset,
    },
  ) as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
}

class OutputSelection {
  OutputSelection(Map<String, dynamic> catalogue)
    : fields = (catalogue['fields'] as List)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList(),
      defaults = (catalogue['defaults'] as List).cast<String>() {
    reset();
  }
  final List<Map<String, dynamic>> fields;
  final List<String> defaults;
  final order = <String>[];
  bool required(String key) =>
      fields.firstWhere((f) => f['field_key'] == key)['required'] == true;
  void reset() {
    order
      ..clear()
      ..addAll(defaults);
  }

  void all() {
    order
      ..clear()
      ..addAll(fields.map((f) => f['field_key'] as String));
  }

  void toggle(String key, bool selected) {
    if (required(key)) return;
    if (selected) {
      if (!order.contains(key)) order.add(key);
    } else {
      order.remove(key);
    }
  }

  void move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= order.length) return;
    final key = order.removeAt(index);
    order.insert(target, key);
  }

  void load(List<String> keys) {
    if (keys.toSet().length != keys.length ||
        keys.any((k) => !fields.any((f) => f['field_key'] == k)) ||
        fields.any(
          (f) => f['required'] == true && !keys.contains(f['field_key']),
        )) {
      throw const FormatException(
        'Preset is incompatible with the current catalogue. Review a new selection.',
      );
    }
    order
      ..clear()
      ..addAll(keys);
  }
}
