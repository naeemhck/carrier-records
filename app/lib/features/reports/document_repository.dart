import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class DocumentCommands {
  Future<Map<String, dynamic>> issue(
    String request,
    Map<String, dynamic> payload,
  );
  Future<Map<String, dynamic>> get(String id);
  Future<Map<String, dynamic>> list(Map<String, dynamic> filters, int offset);
}

class DocumentRepository implements DocumentCommands {
  DocumentRepository(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> params,
  ) async =>
      Map<String, dynamic>.from(await client.rpc(name, params: params) as Map);
  @override
  Future<Map<String, dynamic>> issue(
    String request,
    Map<String, dynamic> payload,
  ) => call('issue_document', {
    'request_id': request,
    'expected_version': 0,
    'payload': {...payload, 'presentation_version': 2},
  });
  @override
  Future<Map<String, dynamic>> get(String id) =>
      call('get_issued_document', {'document_id': id});
  @override
  Future<Map<String, dynamic>> list(Map<String, dynamic> filters, int offset) =>
      call('list_issued_documents', {
        'filters': filters,
        'page_offset': offset,
      });
}
