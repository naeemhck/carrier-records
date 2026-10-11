import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/money.dart';

enum MasterKind {
  company('COMPANY', 'Company', [
    'name',
    'address',
    'phone',
    'email',
    'logo_url',
  ]),
  office('OFFICE', 'Offices', ['code', 'name']),
  party('PARTY', 'Parties', [
    'code',
    'display_name',
    'address',
    'phone',
    'email',
  ]),
  vehicle('VEHICLE', 'Vehicles', ['registration']),
  route('ROUTE', 'Routes', [
    'code',
    'origin_label',
    'destination_label',
    'suggested_fare',
  ]),
  category('CATEGORY', 'Expense categories', ['name']);

  const MasterKind(this.code, this.label, this.fields);
  final String code, label;
  final List<String> fields;
}

class MasterRecord {
  MasterRecord(Map<String, dynamic> value) : data = Map.unmodifiable(value);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get version => data['version'] as int;
  bool get archived => data['archived_at'] != null;
  String get label =>
      '${data['name'] ?? data['display_name'] ?? data['registration'] ?? data['code']}';
  String value(String field) =>
      '${data[field] ?? (data['contact_details'] as Map?)?[field] ?? ''}';
  List<String> get roles => (data['roles'] as List? ?? []).cast<String>();
}

String newRecordId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Map<String, dynamic> masterPayload(
  MasterKind kind,
  Map<String, String> fields, {
  bool archived = false,
  Set<String> roles = const {},
  String? ownerId,
  String? driverId,
}) {
  final result = <String, dynamic>{};
  final contacts = <String, String>{};
  for (final field in kind.fields) {
    final value = (fields[field] ?? '').trim();
    if (['address', 'phone', 'email', 'logo_url'].contains(field)) {
      contacts[field] = value;
    } else if (field == 'suggested_fare') {
      final fare = value.isEmpty ? null : Money.parse(value);
      if (fare?.isNegative == true) {
        throw const FormatException('Suggested fare must be nonnegative.');
      }
      result[field] = fare?.toString();
    } else {
      if (value.isEmpty) {
        throw FormatException('Enter ${MasterStrings.fieldLabels[field]}.');
      }
      result[field] = value;
    }
  }
  if (kind == MasterKind.company || kind == MasterKind.party) {
    result['contact_details'] = contacts;
  }
  if (kind != MasterKind.company) result['archived'] = archived;
  if (kind == MasterKind.party) {
    if (roles.isEmpty) {
      throw const FormatException('Choose at least one party role.');
    }
    result['roles'] = roles.toList()..sort();
  }
  if (kind == MasterKind.vehicle) {
    if (ownerId == null) throw const FormatException('Choose an owner.');
    result['current_owner_id'] = ownerId;
    result['default_driver_id'] = driverId;
  }
  return result;
}

abstract interface class MasterRepository {
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  });
  Future<MasterRecord> save(
    MasterKind kind,
    String id,
    String requestId,
    int version,
    Map<String, dynamic> payload,
  );
}

class SupabaseMasterRepository implements MasterRepository {
  SupabaseMasterRepository(this.client);
  final SupabaseClient client;
  @override
  Future<List<MasterRecord>> list(
    MasterKind kind, {
    String search = '',
    int offset = 0,
    bool archived = false,
  }) async =>
      (await client.rpc(
            'list_master_records',
            params: {
              'kind': kind.code,
              'search_text': search,
              'page_offset': offset,
              'include_archived': archived,
            },
          ) as List)
          .map((v) => MasterRecord(Map<String, dynamic>.from(v as Map)))
          .toList();
  @override
  Future<MasterRecord> save(
    MasterKind kind,
    String id,
    String requestId,
    int version,
    Map<String, dynamic> payload,
  ) async => MasterRecord(
    Map<String, dynamic>.from(
      await client.rpc(
        'save_master_record',
        params: {
          'kind': kind.code,
          'target_id': id,
          'request_id': requestId,
          'expected_version': version,
          'payload': payload,
        },
      ) as Map,
    ),
  );
}

class MasterStrings {
  static const serverValidation = {
    'ACTIVE_OWNER_REQUIRED': 'Choose an active party with the OWNER role.',
    'ACTIVE_DRIVER_REQUIRED': 'Choose an active party with the DRIVER role, or clear the default driver.',
    'INVALID_ROLES': 'Choose at least one valid party role.',
    'INVALID_CONTACTS':
        'Check the contact fields and use HTTPS for an optional logo URL.',
    'INVALID_LABEL': 'Enter a name or code of 1 to 150 characters.',
    'DECIMAL_STRING_REQUIRED':
        'Enter the suggested fare with at most two decimal places.',
    'FORBIDDEN': 'Administrator access could not be verified. Sign in again.',
  };
  static const companyHelp =
      'Enter your actual company identity. Save it before issuing documents. Contact and logo details are optional.';
  static const search = 'Search names / codes';
  static const newRecord = 'New record';
  static const refresh = 'Search / refresh';
  static const includeArchived = 'Include archived';
  static const retryRecords = 'Records unavailable. Retry';
  static const empty = 'No records found.';
  static const edit = 'Edit';
  static const archived = 'Archived';
  static const companyReady = 'Company identity configured';
  static const setupRequired = 'Setup required';
  static const previous = 'Previous';
  static const next = 'Next';
  static const rolesHelp =
      'One person can have several roles. Removed roles are archived; historical links remain.';
  static const owner = 'Current owner (required)';
  static const chooseOwner = 'Choose an active owner';
  static const ownerUnavailable = 'Owner unavailable';
  static const driver = 'Default driver (optional)';
  static const none = 'None';
  static const driverUnavailable = 'Driver unavailable';
  static const choose = 'Choose';
  static const clearDriver = 'Clear default driver';
  static const archiveHelp =
      'Excluded from new entry choices. Existing history is retained.';
  static const closeReview = 'Close and review';
  static const cancel = 'Cancel';
  static const save = 'Save';
  static const partySearch = 'Search party name / code';
  static const searchAction = 'Search';
  static const retry = 'Unavailable. Retry';
  static const noRole = 'No matching role on this page.';
  static const accessRequired = 'Administrator access required.';
  static const title = 'Company and master records';
  static const fieldLabels = {
    'name': 'Name',
    'code': 'Stable code',
    'display_name': 'Display name',
    'address': 'Address (optional)',
    'phone': 'Phone (optional)',
    'email': 'Email (optional)',
    'logo_url': 'Logo HTTPS URL (optional)',
    'registration': 'Vehicle registration',
    'origin_label': 'Route origin',
    'destination_label': 'Route destination',
    'suggested_fare': 'Suggested fare, PKR (optional)',
  };
  static String editTitle(bool creating, MasterKind kind) =>
      '${creating ? 'New' : 'Edit'} ${kind.label}';
  static String chooseRole(String role) => 'Choose ${role.toLowerCase()}';
  static String vehicleSummary(String owner, String driver) =>
      'Owner: $owner · Driver: $driver';
  static String routeSummary(String origin, String destination, String fare) =>
      '$origin → $destination · PKR $fare';
  static const partyRoles = [
    'OWNER',
    'CUSTOMER',
    'BROKER',
    'DRIVER',
    'BUSINESS',
    'OTHER',
  ];
  static const officeSuggestion =
      'Suggested office names: Karachi and Islamabad. Enter your actual office names and codes.';
  static const categorySuggestion =
      'Suggestions: Diesel, Oil change, Tolls, Driver allowance, Repairs, Tyres, Permits, Loading, Other.';
  static const saved = 'Saved by the server.';
  static const failure =
      'Save failed. Your entries are retained. Check your access and connection, then retry.';
  static const conflict =
      'This record changed. Close this form, refresh the list and review the current record before saving again.';
  static const history =
      'Owner changes apply to new trips. Saved trip owners and agreed fares stay unchanged.';
}
