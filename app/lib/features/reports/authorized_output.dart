import 'dart:math' as math;

const outputTitles = {
  'MONTHLY_VEHICLE': 'Vehicle monthly report',
  'OWNER_STATEMENT': 'Owner statement',
  'BROKER_MONTHLY': 'Broker monthly statement',
  'CUSTOMER_STATEMENT': 'Customer statement',
  'TRIP_PROFIT': 'Lifetime trip profit',
  'CUSTOMER_INVOICE': 'Customer invoice',
  'PAYMENT_RECEIPT': 'Payment receipt',
};
const outputKeys = {
  'scope',
  'period',
  'generated_at',
  'recipient_name',
  'record_name',
  'company_name',
  'issuer_name',
  'document_number',
  'document_date',
  'invoice_total',
  'receipt_amount',
  'vehicle_registration',
  'trip_number',
  'dispatch_date',
  'arrival_date',
  'origin',
  'destination',
  'car_count',
  'car_identifiers',
  'pickup_drop',
  'notes',
  'customer_fare',
  'owner_earnings',
  'brokerage',
  'vehicle_cost',
  'owner_cost',
  'operating_profit',
  'owner_profit',
  'receipts',
  'refunds',
  'owner_settled',
  'commission_settled',
  'credit_created',
  'credit_applied',
  'customer_outstanding',
  'customer_credit',
  'custody',
  'owner_due',
  'owner_recovery',
  'brokerage_due',
  'brokerage_recovery',
  'funding_due',
  'reimbursement_due',
  'cost_recovery',
  'dispatched',
  'arrived',
  'payer_name',
  'payee_name',
  'payment_date',
  'allocation_amount',
};
const integerKeys = {'car_count', 'dispatched', 'arrived'};

/// Presentation helper for the report format: summary keys rendered as
/// balance-due rows (outstanding / *_due) get the #EAF4ED highlight in the
/// totals strip. Pure presentation; it never selects or computes data.
bool isBalanceDueKey(String key) =>
    key.contains('outstanding') || key.endsWith('_due');

class OutputField {
  OutputField(Map raw)
    : key = raw['field_key'] as String,
      label = raw['label'] as String,
      type = raw['value_type'] as String,
      header = raw['header'] == true {
    if (!outputKeys.contains(key) ||
        !{'TEXT', 'MONEY', 'DATE', 'INTEGER', 'BOOLEAN'}.contains(type) ||
        label.isEmpty ||
        label.length > 200) {
      throw const FormatException('Unsupported output field.');
    }
  }
  final String key, label, type;
  final bool header;
}

/// Renderer schema v1. It consumes selected data, never serializes source objects.
class AuthorizedOutput {
  AuthorizedOutput.fromPayload(Map<String, dynamic> raw) {
    if (raw['schema_version'] != 1 ||
        raw['template_version'] != 1 ||
        !outputTitles.containsKey(raw['report_kind'])) {
      throw const FormatException('Unsupported output version.');
    }
    report = raw['report_kind'] as String;
    recipient = raw['recipient_kind'] as String;
    issued = raw['issued'] == true;
    if (!{'INTERNAL', 'CUSTOMER', 'OWNER', 'BROKER'}.contains(recipient)) {
      throw const FormatException('Invalid recipient.');
    }
    final order = (raw['field_order'] as List).cast<String>();
    final sourceFields = (raw['fields'] as List).cast<Map>();
    if (order.toSet().length != order.length ||
        sourceFields.length != order.length) {
      throw const FormatException('Invalid field order.');
    }
    fields = [
      for (final key in order)
        OutputField(sourceFields.singleWhere((f) => f['field_key'] == key)),
    ];
    if (!fields.any((f) => f.key == 'record_name' && !f.header)) {
      throw const FormatException('Record identity required.');
    }
    final forbidden = switch (recipient) {
      'OWNER' => {
        'customer_fare',
        'brokerage',
        'brokerage_due',
        'brokerage_recovery',
        'customer_outstanding',
        'receipts',
        'refunds',
        'customer_credit',
        'credit_created',
        'credit_applied',
        'custody',
        'vehicle_cost',
        'operating_profit',
        'commission_settled',
      },
      'CUSTOMER' => {
        'owner_earnings',
        'owner_cost',
        'owner_profit',
        'owner_due',
        'owner_recovery',
        'owner_settled',
        'vehicle_cost',
        'operating_profit',
        'brokerage',
        'brokerage_due',
        'brokerage_recovery',
        'commission_settled',
        'custody',
        'funding_due',
        'reimbursement_due',
        'cost_recovery',
      },
      'BROKER' => {
        'owner_profit',
        'owner_cost',
        'vehicle_cost',
        'operating_profit',
        'cost_recovery',
      },
      _ => <String>{},
    };
    final suppliedTotals = Map<String, dynamic>.from(raw['totals'] as Map);
    if (fields.any((f) => forbidden.contains(f.key)) ||
        suppliedTotals.keys.any(forbidden.contains)) {
      throw const FormatException('Forbidden recipient information.');
    }
    final sourceMeta = raw['metadata'] as Map;
    metadata = {};
    for (final key in [
      'scope',
      'period',
      'generated_at',
      'recipient_name',
      'company_name',
      'issuer_name',
      'document_number',
      'document_date',
      'issued_at',
      'supersedes_number',
    ]) {
      final value = sourceMeta[key];
      if (value != null) {
        metadata[key] = cleanText(value as String);
      }
    }
    for (final f in fields.where((f) => f.header)) {
      if (sourceMeta[f.key] != null) {
        metadata[f.key] = validatedValue(f.type, sourceMeta[f.key]);
      }
    }
    offices = (sourceMeta['offices'] as List? ?? [])
        .map((v) => cleanText(v as String))
        .toList();
    bases = {};
    for (final e in (sourceMeta['date_bases'] as Map? ?? {}).entries) {
      if ({'earnings', 'expenses', 'payments', 'claims'}.contains(e.key)) {
        bases[e.key as String] = cleanText(e.value as String);
      }
    }
    summaries = {
      for (final f in (raw['summary_fields'] as List))
        f['field_key'] as String: cleanText(f['label'] as String),
    };
    totals = {};
    for (final e in suppliedTotals.entries) {
      if (!outputKeys.contains(e.key) || !summaries.containsKey(e.key)) {
        throw const FormatException('Unsupported summary.');
      }
      totals[e.key] = validatedValue(
        integerKeys.contains(e.key) ? 'INTEGER' : 'MONEY',
        e.value,
      );
    }
    rows = [
      for (final row in raw['rows'] as List)
        {
          for (final f in fields.where((f) => !f.header))
            f.key: validatedValue(f.type, (row as Map)[f.key]),
        },
    ];
    recordCount = raw['row_count'] as int;
    if (raw['has_more'] == true ||
        recordCount != rows.length ||
        (raw['page_offset'] as int? ?? 0) != 0) {
      throw const FormatException('Incomplete export payload.');
    }
    final formats = raw['format_options'] as Map;
    orientation = formats['orientation'] as String? ?? 'AUTO';
    sheetName = formats['sheet_name'] as String? ?? 'Records';
    if (!{'AUTO', 'PORTRAIT', 'LANDSCAPE'}.contains(orientation) ||
        sheetName.isEmpty ||
        sheetName.length > 31 ||
        RegExp(r'[\\/:*?\[\]]').hasMatch(sheetName)) {
      throw const FormatException('Invalid export format.');
    }
  }
  late final String report, recipient, orientation, sheetName;
  late final bool issued;
  late final int recordCount;
  late final List<OutputField> fields;
  late final Map<String, dynamic> metadata, totals;
  late final Map<String, String> bases, summaries;
  late final List<String> offices;
  late final List<Map<String, dynamic>> rows;
  String get title => '${outputTitles[report]}${issued ? '' : ' - not issued'}';
  List<OutputField> get columns => fields.where((f) => !f.header).toList();
  bool get landscape =>
      orientation == 'LANDSCAPE' || orientation == 'AUTO' && columns.length > 5;
  List<(String, String, String)> get headers => [
    for (final f in fields.where((f) => f.header))
      (f.label, f.type, displayValue(f.type, metadata[f.key])),
    ('Offices', 'TEXT', offices.join(', ')),
    (
      'Date bases',
      'TEXT',
      bases.entries.map((e) => '${e.key}: ${e.value}').join('; '),
    ),
    if (metadata['supersedes_number'] != null)
      ('Supersedes', 'TEXT', metadata['supersedes_number'] as String),
    ('Currency', 'TEXT', 'PKR'),
    ('Records', 'INTEGER', recordCount.toString()),
  ];

  /// Long text continues in visible rows; money is shown once per source record.
  List<List<dynamic>> get displayRows =>
      layoutRows.map((r) => r.values).toList();
  List<OutputRow> get layoutRows {
    final result = <OutputRow>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final chunks = [
        for (final f in columns)
          f.type == 'TEXT'
              ? textChunks(row[f.key] as String? ?? '', 280)
              : [row[f.key]],
      ];
      final count = chunks.map((c) => c.length).fold<int>(1, math.max);
      for (var part = 0; part < count; part++) {
        result.add(
          OutputRow(index + 1, part + 1, [
            for (var col = 0; col < columns.length; col++)
              columns[col].key == 'record_name'
                  ? '${row[columns[col].key]}${part == 0 ? '' : ' (continued)'}'
                  : part < chunks[col].length
                  ? chunks[col][part]
                  : null,
          ]),
        );
      }
    }
    return result;
  }
}

class OutputRow {
  OutputRow(this.record, this.part, this.values);
  final int record, part;
  final List<dynamic> values;
  String get label => part == 1 ? '$record' : '$record.$part';
}

String cleanText(String text) =>
    text.replaceAll(RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
dynamic validatedValue(String type, dynamic value) {
  if (value == null) {
    return null;
  }
  switch (type) {
    case 'MONEY':
      if (value is! String ||
          !RegExp(r'^-?(0|[1-9][0-9]*)\.[0-9]{2}$').hasMatch(value)) {
        throw const FormatException('Invalid exact money.');
      }
      return value;
    case 'INTEGER':
      if (value is! int) {
        throw const FormatException('Invalid count.');
      }
      return value;
    case 'BOOLEAN':
      if (value is! bool) {
        throw const FormatException('Invalid flag.');
      }
      return value;
    case 'DATE':
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('Invalid date.');
      }
      return value;
    default:
      if (value is! String) {
        throw const FormatException('Invalid text.');
      }
      return cleanText(value);
  }
}

String displayValue(String type, dynamic value) {
  if (value == null) {
    return '';
  }
  if (type == 'MONEY') {
    final text = value as String,
        negative = text.startsWith('-'),
        parts = text.replaceFirst('-', '').split('.');
    final digits = parts[0], groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(math.max(0, end - 3), end));
    }
    return 'PKR ${negative ? '-' : ''}${groups.join(',')}.${parts[1]}';
  }
  if (type == 'DATE') {
    final d = DateTime.parse(value as String);
    return '${d.day.toString().padLeft(2, '0')} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
  }
  if (type == 'BOOLEAN') {
    return value == true ? 'Yes' : 'No';
  }
  return value.toString();
}

List<String> textChunks(String text, int size) {
  if (text.isEmpty) {
    return [''];
  }
  final runes = text.runes.toList(), chunks = <String>[];
  for (var start = 0; start < runes.length;) {
    var end = math.min(start + size, runes.length);
    if (end < runes.length) {
      for (var split = end - 1; split >= start + size ~/ 2; split--) {
        if (runes[split] == 32 || runes[split] == 10) {
          end = split + 1;
          break;
        }
      }
    }
    chunks.add(String.fromCharCodes(runes.sublist(start, end)));
    start = end;
  }
  return chunks;
}
