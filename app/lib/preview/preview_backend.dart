import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/public_config.dart';
import '../features/auth/secure_session_storage.dart';
import '../features/auth/staff_session.dart';
import '../features/reports/report_repository.dart';

/// Design-preview backend: answers the app's read RPCs with synthetic
/// records so every screen can be reviewed without a Supabase project.
/// Nothing here is reachable from `lib/main.dart`; it is compiled only
/// into the `lib/main_preview.dart` entrypoint. Writes are refused.
class PreviewBackend extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    Map<String, dynamic> params = const {};
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) params = Map<String, dynamic>.from(decoded);
    }
    const rpcPrefix = '/rest/v1/rpc/';
    if (path.startsWith(rpcPrefix)) {
      final result = _rpc(path.substring(rpcPrefix.length), params);
      if (result != null) return _json(request, 200, result);
    }
    return _json(request, 400, {
      'message': 'Design preview: this action is not available.',
      'code': 'PREVIEW',
    });
  }

  http.StreamedResponse _json(
    http.BaseRequest request,
    int status,
    Object body,
  ) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Object? _rpc(String name, Map<String, dynamic> params) => switch (name) {
    'list_trips' => _listTrips(params),
    'get_trip_detail' => _tripDetail('${params['trip_id']}'),
    'get_trip_history' => {'rows': const []},
    'get_trip_financials' => {
      'scope': 'TRIP',
      'complete': true,
      'balances': const [],
      'claims': const [],
    },
    'list_financial_history' => {'rows': const []},
    'get_scoped_report' => _report('${params['report_kind']}', params),
    'list_master_records' => _masters('${params['kind']}'),
    'list_expenses' => _expenses,
    'list_issued_documents' => {'rows': _documents, 'has_more': false},
    'list_output_presets' => const [],
    'list_output_receipts' => const [],
    'list_staff_accounts' => const [],
    'get_backup_status' => {
      'outcome': 'SUCCESS',
      'last_verified_success_at': '2026-11-25T21:10:00Z',
      'last_attempt_at': '2026-11-25T21:10:00Z',
      'schedule': const {},
      'metrics': const {},
    },
    _ => null,
  };

  static const _offices = [
    {'id': 'office-khi', 'code': 'KHI', 'name': 'Karachi'},
    {'id': 'office-lhe', 'code': 'LHE', 'name': 'Lahore'},
    {'id': 'office-isb', 'code': 'ISB', 'name': 'Islamabad'},
  ];

  static Map<String, dynamic> _trip(
    int n,
    String state,
    String origin,
    String destination,
    String registration,
    String owner,
    String date, {
    String? arrival,
    int cars = 6,
  }) => {
    'id': 'trip-$n',
    'trip_number': 'TRP-${n.toString().padLeft(6, '0')}',
    'state': state,
    'load_kind': 'LOADED',
    'registration': registration,
    'owner_name': owner,
    'origin_name': origin,
    'destination_name': destination,
    'planned_dispatch_date': date,
    'dispatch_date': state == 'DRAFT' ? null : date,
    'arrival_date': arrival,
    'return_of_trip_id': null,
    'car_count': cars,
    'created_at': '${date}T08:30:00Z',
    'notes': '',
  };

  static final _trips = [
    _trip(
      118,
      'DRAFT',
      'Karachi',
      'Lahore',
      'DEMO-TKA-482',
      'Demo Owner A',
      '2026-11-27',
    ),
    _trip(
      117,
      'DISPATCHED',
      'Karachi',
      'Islamabad',
      'DEMO-JZ-9031',
      'ڈیمو مالک ب',
      '2026-11-25',
      cars: 7,
    ),
    _trip(
      116,
      'DISPATCHED',
      'Lahore',
      'Karachi',
      'DEMO-LES-2207',
      'Demo Owner C',
      '2026-11-24',
      cars: 5,
    ),
    _trip(
      115,
      'ARRIVED',
      'Karachi',
      'Lahore',
      'DEMO-TKA-482',
      'Demo Owner A',
      '2026-11-21',
      arrival: '2026-11-23',
    ),
    _trip(
      114,
      'ARRIVED',
      'Islamabad',
      'Karachi',
      'DEMO-JZ-9031',
      'ڈیمو مالک ب',
      '2026-11-19',
      arrival: '2026-11-22',
      cars: 8,
    ),
    _trip(
      113,
      'ARRIVED',
      'Karachi',
      'Islamabad',
      'DEMO-LES-2207',
      'Demo Owner C',
      '2026-11-16',
      arrival: '2026-11-18',
    ),
    _trip(
      112,
      'CANCELLED',
      'Lahore',
      'Islamabad',
      'DEMO-TKA-482',
      'Demo Owner A',
      '2026-11-14',
      cars: 4,
    ),
    _trip(
      111,
      'ARRIVED',
      'Karachi',
      'Lahore',
      'DEMO-JZ-9031',
      'ڈیمو مالک ب',
      '2026-11-11',
      arrival: '2026-11-13',
    ),
  ];

  Map<String, dynamic> _listTrips(Map<String, dynamic> p) {
    final state = p['trip_state'] as String?;
    final search = '${p['search_text'] ?? ''}'.toLowerCase();
    final offset = (p['page_offset'] as int?) ?? 0;
    final rows = offset > 0
        ? const <Map<String, dynamic>>[]
        : _trips
              .where(
                (t) =>
                    (state == null || t['state'] == state) &&
                    (search.isEmpty ||
                        '${t['trip_number']} ${t['registration']} ${t['owner_name']}'
                            .toLowerCase()
                            .contains(search)),
              )
              .toList();
    return {'scope': 'ALL_OFFICES', 'rows': rows};
  }

  Map<String, dynamic> _tripDetail(String id) {
    final row = _trips.firstWhere(
      (t) => t['id'] == id,
      orElse: () => _trips[1],
    );
    return {
      ...row,
      'version': 3,
      'driver_name': 'Demo Driver',
      'origin_office_id': 'office-khi',
      'destination_office_id': 'office-isb',
      'owner_snapshot': {'display_name': row['owner_name']},
      'route_snapshot': {'code': 'KHI-ISB'},
      'notes': 'Synthetic preview record.',
      'overlap_confirmed': false,
      'overlap_reason': null,
      'earnings_recognized': row['state'] != 'DRAFT',
      'linked_returns': const [],
      'stops': const [],
      'consignments': [
        {
          'id': 'consignment-1',
          'customer_name': 'Demo Motors (Pvt) Ltd',
          'state': 'ACTIVE',
          'car_count': 4,
          'quoted_amount': '180000.00',
          'quote_mode': 'DEDUCTED',
          'commission_method': 'FIXED',
          'commission_value': '9000.00',
          'customer_charge': '180000.00',
          'commission': '9000.00',
          'owner_entitlement': '171000.00',
          'pickup_stop_id': null,
          'drop_stop_id': null,
          'notes': '',
          'cars': const [],
        },
        {
          'id': 'consignment-2',
          'customer_name': 'ڈیمو آٹوز',
          'state': 'ACTIVE',
          'car_count': 3,
          'quoted_amount': '135000.00',
          'quote_mode': 'DEDUCTED',
          'commission_method': 'FIXED',
          'commission_value': '6000.00',
          'customer_charge': '135000.00',
          'commission': '6000.00',
          'owner_entitlement': '129000.00',
          'pickup_stop_id': null,
          'drop_stop_id': null,
          'notes': '',
          'cars': const [],
        },
      ],
      'can_cancel_consignment': false,
      'totals': {
        'customer_charge': '315000.00',
        'commission': '15000.00',
        'owner_entitlement': '300000.00',
        'car_count': 7,
      },
    };
  }

  static const _figures = <String, String>{
    'customer_fare': '2145000.00',
    'owner_earnings': '2032500.00',
    'brokerage': '112500.00',
    'vehicle_cost': '486200.00',
    'owner_cost': '401700.00',
    'operating_profit': '1658800.00',
    'owner_profit': '1630800.00',
    'receipts': '1720000.00',
    'refunds': '0.00',
    'owner_settled': '1250000.00',
    'commission_settled': '84000.00',
    'credit_created': '15000.00',
    'credit_applied': '0.00',
    'customer_outstanding': '425000.00',
    'customer_credit': '15000.00',
    'custody': '96000.00',
    'owner_due': '380800.00',
    'owner_recovery': '0.00',
    'brokerage_due': '28500.00',
    'brokerage_recovery': '0.00',
    'funding_due': '12400.00',
    'reimbursement_due': '8600.00',
    'cost_recovery': '0.00',
    'dispatched': '8',
    'arrived': '5',
  };

  Map<String, dynamic> _row(String id, String name, int divisor) => {
    'id': id,
    'name': name,
    'values': {
      for (final key in reportLabels.keys)
        key: key == 'dispatched' || key == 'arrived'
            ? '${int.parse(_figures[key]!) ~/ divisor}'
            : _scaled(_figures[key]!, divisor),
    },
  };

  /// Presentation-only sample scaling on integer paisa; never a ledger rule.
  static String _scaled(String amount, int divisor) {
    final parts = amount.split('.');
    final paisa =
        (BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(parts[1])) ~/
        BigInt.from(divisor);
    return '${paisa ~/ BigInt.from(100)}.${(paisa % BigInt.from(100)).toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _report(String kind, Map<String, dynamic> params) {
    final filters = (params['filters'] as Map?) ?? const {};
    final claims = kind == 'CLAIMS';
    return {
      'totals': claims ? const <String, dynamic>{} : _figures,
      'rows': claims
          ? [
              _row('party-1', 'Demo Motors (Pvt) Ltd', 2),
              _row('party-2', 'ڈیمو آٹوز', 3),
              _row('party-3', 'Demo Owner A', 4),
              _row('party-4', 'Demo Broker', 6),
            ]
          : [
              _row('vehicle-1', 'DEMO-TKA-482', 2),
              _row('vehicle-2', 'DEMO-JZ-9031', 3),
              _row('vehicle-3', 'DEMO-LES-2207', 6),
            ],
      'row_count': claims ? 4 : 3,
      'has_more': false,
      'scope': 'All offices',
      'offices': ['Karachi', 'Lahore', 'Islamabad'],
      'period': {'from': filters['from'], 'to': filters['to']},
      'lifetime': kind == 'TRIP_PROFIT',
      'generated_at': '2026-11-26T07:30:00Z',
    };
  }

  List<Map<String, dynamic>> _masters(String kind) => switch (kind) {
    'OFFICE' => [
      for (final o in _offices) {...o, 'version': 1, 'archived_at': null},
    ],
    'PARTY' => [
      for (final (i, name) in const [
        'Demo Motors (Pvt) Ltd',
        'ڈیمو آٹوز',
        'Demo Owner A',
        'ڈیمو مالک ب',
        'Demo Owner C',
        'Demo Broker',
      ].indexed)
        {
          'id': 'party-${i + 1}',
          'version': 1,
          'code': 'P-${(i + 1).toString().padLeft(3, '0')}',
          'display_name': name,
          'roles': i < 2
              ? ['CUSTOMER']
              : i < 5
              ? ['OWNER']
              : ['BROKER'],
          'archived_at': null,
        },
    ],
    'VEHICLE' => [
      for (final (i, reg) in const [
        'DEMO-TKA-482',
        'DEMO-JZ-9031',
        'DEMO-LES-2207',
      ].indexed)
        {
          'id': 'vehicle-${i + 1}',
          'version': 1,
          'registration': reg,
          'archived_at': null,
        },
    ],
    'ROUTE' => const [
      {
        'id': 'route-1',
        'version': 1,
        'code': 'KHI-LHE',
        'origin_label': 'Karachi',
        'destination_label': 'Lahore',
        'suggested_fare': '45000.00',
        'archived_at': null,
      },
      {
        'id': 'route-2',
        'version': 1,
        'code': 'KHI-ISB',
        'origin_label': 'Karachi',
        'destination_label': 'Islamabad',
        'suggested_fare': '52000.00',
        'archived_at': null,
      },
    ],
    'CATEGORY' => [
      for (final (i, name) in const [
        'Diesel',
        'Tolls',
        'Driver allowance',
        'Repairs',
        'Tyres',
      ].indexed)
        {
          'id': 'category-${i + 1}',
          'version': 1,
          'name': name,
          'archived_at': null,
        },
    ],
    'COMPANY' => const [
      {
        'id': 'company-1',
        'version': 1,
        'name': 'Karvaan Demo Carriers',
        'address': 'Synthetic address, Karachi',
        'phone': '',
        'email': '',
        'archived_at': null,
      },
    ],
    _ => const [],
  };

  static const _expenses = [
    {
      'id': 'expense-1',
      'expense_date': '2026-11-25',
      'trip_id': 'trip-117',
      'amount': '68500.00',
      'notes': 'Diesel',
      'funding_source': 'HELD_TRIP_FUNDS',
      'effective': true,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
    {
      'id': 'expense-2',
      'expense_date': '2026-11-24',
      'trip_id': 'trip-116',
      'amount': '12400.00',
      'notes': 'Tolls',
      'funding_source': 'PERSONAL_FUNDS',
      'effective': true,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
    {
      'id': 'expense-3',
      'expense_date': '2026-11-22',
      'trip_id': null,
      'amount': '34000.00',
      'notes': 'Tyres',
      'funding_source': 'PERSONAL_FUNDS',
      'effective': true,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
    {
      'id': 'expense-4',
      'expense_date': '2026-11-21',
      'trip_id': 'trip-115',
      'amount': '8600.00',
      'notes': 'Driver allowance',
      'funding_source': 'PERSONAL_FUNDS',
      'effective': false,
      'replaces_expense_id': null,
      'correction_reason': null,
    },
  ];

  static const _documents = [
    {
      'id': 'document-3',
      'permanent_number': 'DOC-2026-0043',
      'recipient': 'Demo Motors (Pvt) Ltd',
      'issued_at': '2026-11-24T10:12:00Z',
      'issuer': 'Demo Administrator',
      'superseded': false,
    },
    {
      'id': 'document-2',
      'permanent_number': 'DOC-2026-0042',
      'recipient': 'ڈیمو مالک ب',
      'issued_at': '2026-11-22T15:40:00Z',
      'issuer': 'Demo Administrator',
      'superseded': false,
    },
    {
      'id': 'document-1',
      'permanent_number': 'DOC-2026-0041',
      'recipient': 'Demo Owner A',
      'issued_at': '2026-11-19T09:05:00Z',
      'issuer': 'Demo Administrator',
      'superseded': true,
    },
  ];
}

/// A signed-in session that never contacts a backend. Any username and
/// password signs in as the synthetic administrator.
class PreviewSession extends StaffSession {
  PreviewSession._(super.client, super.config, super.storage) {
    profile = Map.of(_administrator);
  }

  factory PreviewSession() => PreviewSession._(
    SupabaseClient(
      'http://preview.invalid',
      'preview',
      httpClient: PreviewBackend(),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
    const PublicConfig(
      environment: 'local',
      url: 'http://preview.invalid',
      key: 'preview',
      businessId: '00000000-0000-4000-8000-000000000000',
    ),
    SecureSessionStorage(namespace: 'preview', keyPrefix: 'karvaan.preview'),
  );

  static const _administrator = <String, dynamic>{
    'id': 'preview-admin',
    'role': 'ADMIN',
    'display_name': 'Demo Administrator',
    'must_change_password': false,
    'version': 1,
    'offices': PreviewBackend._offices,
  };

  @override
  Future<void> refresh() async {}

  @override
  Future<void> signIn(String username, String password) async {
    profile = Map.of(_administrator);
    error = null;
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    profile = null;
    notifyListeners();
  }

  @override
  Future<void> changePassword(String current, String next) => signOut();

  @override
  Future<dynamic> command(Map<String, dynamic> body) async =>
      throw StateError('Design preview: account changes are disabled.');

  @override
  Future<List<Map<String, dynamic>>> accounts() async => const [];
}
