import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class CorrectionCommands {
  Future<List<Map<String, dynamic>>> history(String? trip, int offset);
  Future<Map<String, dynamic>> review(String id, {bool cancellation = false});
  Future<Map<String, dynamic>> confirm(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload, {
    bool cancellation = false,
  });
}

class CorrectionRepository implements CorrectionCommands {
  CorrectionRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> history(String? trip, int offset) async =>
      (await client.rpc(
        'list_financial_history',
        params: {'trip_id': trip, 'offset_rows': offset},
      ) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  @override
  Future<Map<String, dynamic>> review(
    String id, {
    bool cancellation = false,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
      cancellation ? 'review_cancellation' : 'review_financial_correction',
      params: {cancellation ? 'trip_id' : 'event_id': id},
    ) as Map,
  );
  @override
  Future<Map<String, dynamic>> confirm(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload, {
    bool cancellation = false,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
      cancellation ? 'cancel_and_adjust' : 'correct_financial_event',
      params: {
        cancellation ? 'trip_id' : 'event_id': id,
        'request_id': request,
        'expected_version': version,
        'payload': payload,
      },
    ) as Map,
  );
}
