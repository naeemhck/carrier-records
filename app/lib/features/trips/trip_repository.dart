import 'package:supabase_flutter/supabase_flutter.dart';

import 'trip_draft.dart';

class TripPage {
  TripPage(this.scope, this.rows);
  final String scope;
  final List<Map<String, dynamic>> rows;
}

abstract interface class TripRepository {
  Future<TripPage> list({
    String search = '',
    int offset = 0,
    String? office,
    String? vehicle,
    String? state,
    String? from,
    String? to,
  });
  Future<Map<String, dynamic>> detail(String id);
  Future<List<Map<String, dynamic>>> history(String id, {int offset = 0});
  Future<Map<String, dynamic>> operate(
    String action,
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> overlap(TripDraft draft);
  Future<Map<String, dynamic>> defaults(TripDraft draft);
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  );
}

class SupabaseTripRepository implements TripRepository {
  SupabaseTripRepository(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> params,
  ) async =>
      Map<String, dynamic>.from(await client.rpc(name, params: params) as Map);
  @override
  Future<TripPage> list({
    String search = '',
    int offset = 0,
    String? office,
    String? vehicle,
    String? state,
    String? from,
    String? to,
  }) async {
    final result = await call('list_trips', {
      'search_text': search,
      'page_offset': offset,
      'office_id': office,
      'vehicle_id': vehicle,
      'trip_state': state,
      'date_from': from,
      'date_to': to,
    });
    return TripPage(
      result['scope'] as String,
      (result['rows'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>> detail(String id) =>
      call('get_trip_detail', {'trip_id': id});
  @override
  Future<List<Map<String, dynamic>>> history(
    String id, {
    int offset = 0,
  }) async {
    final result = await call('get_trip_history', {
      'trip_id': id,
      'page_offset': offset,
    });
    return (result['rows'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> operate(
    String action,
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) => call(
    action == 'DISPATCH'
        ? 'dispatch_trip'
        : action == 'ARRIVE'
        ? 'arrive_trip'
        : 'correct_trip_operation',
    {
      'target_id': id,
      'request_id': request,
      'expected_version': version,
      'payload': payload,
      if (action != 'DISPATCH' && action != 'ARRIVE') 'action': action,
    },
  );
  @override
  Future<Map<String, dynamic>> defaults(TripDraft d) =>
      call('get_trip_defaults', {
        'vehicle_id': d.vehicle,
        'route_id': d.route,
        'origin_office_id': d.origin,
        'destination_office_id': d.destination,
      });
  @override
  Future<Map<String, dynamic>> overlap(TripDraft d) =>
      call('review_trip_overlap', {
        'target_id': d.id,
        'vehicle_id': d.vehicle,
        'origin_office_id': d.origin,
        'destination_office_id': d.destination,
        'planned_dispatch_date': d.planned.isEmpty ? null : d.planned,
        'return_of_trip_id': d.parent,
      });
  @override
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> payload,
  ) => call('save_trip', {
    'target_id': id,
    'request_id': request,
    'expected_version': version,
    'payload': payload,
  });
}
