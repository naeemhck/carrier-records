import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ExpenseCommands {
  Future<List<Map<String, dynamic>>> list({int offset = 0});
  Future<Map<String, dynamic>> post(
    String request,
    Map<String, dynamic> payload,
  );
  Future<List<Map<String, dynamic>>> claims(String expense);
  Future<Map<String, dynamic>> attach(
    String expense,
    String request,
    ReceiptSelection receipt,
  );
  Future<Uint8List?> download(String expense);
  Future<int> cleanup();
}

class ReceiptSelection {
  ReceiptSelection(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

abstract interface class ReceiptPicker {
  Future<ReceiptSelection?> pick();
}

class NativeReceiptPicker implements ReceiptPicker {
  @override
  Future<ReceiptSelection?> pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Receipt evidence',
          extensions: ['png', 'jpg', 'jpeg', 'pdf'],
          mimeTypes: ['image/png', 'image/jpeg', 'application/pdf'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > 5242880) {
      throw const FormatException('Receipt must be at most 5 MB.');
    }
    final ext = file.name.split('.').last.toLowerCase();
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'pdf'
        ? 'application/pdf'
        : 'image/jpeg';
    return ReceiptSelection(await file.readAsBytes(), mime);
  }
}

class ExpenseRepository implements ExpenseCommands {
  ExpenseRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<Map<String, dynamic>>> list({int offset = 0}) async =>
      (await client.rpc(
        'list_expenses',
        params: {'offset_rows': offset},
      ) as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  @override
  Future<Map<String, dynamic>> post(
    String request,
    Map<String, dynamic> payload,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'post_financial_event',
      params: {
        'event_kind': 'EXPENSE',
        'request_id': request,
        'expected_version': 0,
        'payload': payload,
      },
    ) as Map,
  );
  @override
  Future<List<Map<String, dynamic>>> claims(String expense) async =>
      (await client.rpc(
        'get_expense_claims',
        params: {'expense_id': expense},
      ) as List).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  @override
  Future<Map<String, dynamic>> attach(
    String expense,
    String request,
    ReceiptSelection receipt,
  ) async {
    final r = await client.functions.invoke(
      'expense-receipts',
      body: {
        'expense_id': expense,
        'request_id': request,
        'expected_version': 1,
        'mime_type': receipt.mime,
        'base64': base64Encode(receipt.bytes),
      },
    );
    final data = Map<String, dynamic>.from(r.data as Map);
    if (data['receipt_status'] != 'ATTACHED') {
      throw const FormatException(
        'Expense remains posted. Receipt attachment failed.',
      );
    }
    return data;
  }

  @override
  Future<int> cleanup() async {
    final result = await client.functions.invoke(
      'expense-receipts',
      body: {'action': 'cleanup'},
    );
    return (result.data as Map)['removed_abandoned'] as int;
  }

  @override
  Future<Uint8List?> download(String expense) async {
    final linked = await client
        .from('expense_evidence')
        .select('receipt_id')
        .eq('expense_id', expense)
        .maybeSingle();
    if (linked == null) return null;
    final file = await client
        .from('receipt_files')
        .select('object_path')
        .eq('id', linked['receipt_id'])
        .single();
    // Authenticated download, never a reusable signed URL that outlives permissions.
    return client.storage
        .from('receipts')
        .download(file['object_path'] as String);
  }
}
