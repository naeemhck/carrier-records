import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/features/reports/authorized_output.dart';

/// One-record MONTHLY_VEHICLE template-2 payload reconstructed from the
/// owner's live sample exports (monthly-vehicle-live.pdf / .xlsx):
/// one vehicle record (QA-ONLY-001), the six distinct measures from the
/// acceptance checks, and the full 25-key totals map in server order.
/// Distinct measures — never additive: customer charge 100,000.00;
/// brokerage 5,000.00; owner fare share 95,000.00; customer outstanding
/// 100,000.00; intermediary-held 0.00; owner settlement due 95,000.00.
Map<String, dynamic> monthlyVehicleFixture() {
  final base = <String, dynamic>{
    'schema_version': 1,
    'template_version': 1,
    'report_kind': 'MONTHLY_VEHICLE',
    'recipient_kind': 'INTERNAL',
    'issued': false,
    'field_order': [
      'period',
      'scope',
      'generated_at',
      'recipient_name',
      'record_name',
      'vehicle_registration',
      'customer_fare',
      'owner_earnings',
      'brokerage',
      'vehicle_cost',
      'operating_profit',
      'customer_outstanding',
      'custody',
      'owner_due',
    ],
    'fields': [
      {
        'field_key': 'period',
        'label': 'Report period',
        'value_type': 'TEXT',
        'header': true,
      },
      {
        'field_key': 'scope',
        'label': 'Office scope',
        'value_type': 'TEXT',
        'header': true,
      },
      {
        'field_key': 'generated_at',
        'label': 'Generated at',
        'value_type': 'TEXT',
        'header': true,
      },
      {
        'field_key': 'recipient_name',
        'label': 'Recipient',
        'value_type': 'TEXT',
        'header': true,
      },
      {
        'field_key': 'record_name',
        'label': 'Record',
        'value_type': 'TEXT',
        'header': false,
      },
      {
        'field_key': 'vehicle_registration',
        'label': 'Vehicle',
        'value_type': 'TEXT',
        'header': false,
      },
      {
        'field_key': 'customer_fare',
        'label': 'Customer charge',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'owner_earnings',
        'label': 'Owner fare share',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'brokerage',
        'label': 'Brokerage earned',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'vehicle_cost',
        'label': 'All vehicle costs',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'operating_profit',
        'label': 'Vehicle operating profit',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'customer_outstanding',
        'label': 'Customer outstanding',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'custody',
        'label': 'Intermediary-held money',
        'value_type': 'MONEY',
        'header': false,
      },
      {
        'field_key': 'owner_due',
        'label': 'Owner settlement due',
        'value_type': 'MONEY',
        'header': false,
      },
    ],
    'summary_fields': [
      {'field_key': 'arrived', 'label': 'Arrived trips'},
      {'field_key': 'custody', 'label': 'Intermediary-held money'},
      {'field_key': 'refunds', 'label': 'Customer refunds'},
      {'field_key': 'receipts', 'label': 'Customer receipts'},
      {'field_key': 'brokerage', 'label': 'Brokerage earned'},
      {'field_key': 'owner_due', 'label': 'Owner settlement due'},
      {'field_key': 'dispatched', 'label': 'Dispatched trips'},
      {'field_key': 'owner_cost', 'label': 'Owner-borne costs'},
      {'field_key': 'funding_due', 'label': 'Personal funding due'},
      {'field_key': 'owner_profit', 'label': 'Owner profit'},
      {'field_key': 'vehicle_cost', 'label': 'All vehicle costs'},
      {'field_key': 'brokerage_due', 'label': 'Brokerage due'},
      {'field_key': 'cost_recovery', 'label': 'Cost recovery'},
      {'field_key': 'customer_fare', 'label': 'Customer charge'},
      {'field_key': 'owner_settled', 'label': 'Owner cash settlement'},
      {'field_key': 'credit_applied', 'label': 'Customer credits applied'},
      {'field_key': 'credit_created', 'label': 'Customer credits created'},
      {'field_key': 'owner_earnings', 'label': 'Owner fare share'},
      {'field_key': 'owner_recovery', 'label': 'Owner recovery'},
      {'field_key': 'customer_credit', 'label': 'Customer credit'},
      {'field_key': 'operating_profit', 'label': 'Vehicle operating profit'},
      {'field_key': 'reimbursement_due', 'label': 'Expense reimbursement due'},
      {'field_key': 'brokerage_recovery', 'label': 'Broker recovery'},
      {
        'field_key': 'commission_settled',
        'label': 'Commission retained / paid',
      },
      {'field_key': 'customer_outstanding', 'label': 'Customer outstanding'},
    ],
    'metadata': {
      'period': '2026-10-01 to 2026-10-31',
      'scope': 'Assigned-office records — not a complete business balance',
      'generated_at': '2026-10-20T18:33:33.010201+00:00',
      'recipient_name': 'Internal',
      'offices': ['Karachi — synthetic'],
      'date_bases': {
        'claims': 'Customer claim date',
        'earnings': 'Dispatch date',
      },
    },
    'totals': {
      'arrived': 1,
      'custody': '0.00',
      'refunds': '0.00',
      'receipts': '0.00',
      'brokerage': '5000.00',
      'owner_due': '95000.00',
      'dispatched': 1,
      'owner_cost': '0.00',
      'funding_due': '0.00',
      'owner_profit': '95000.00',
      'vehicle_cost': '0.00',
      'brokerage_due': '5000.00',
      'cost_recovery': '0.00',
      'customer_fare': '100000.00',
      'owner_settled': '0.00',
      'credit_applied': '0.00',
      'credit_created': '0.00',
      'owner_earnings': '95000.00',
      'owner_recovery': '0.00',
      'customer_credit': '0.00',
      'operating_profit': '95000.00',
      'reimbursement_due': '0.00',
      'brokerage_recovery': '0.00',
      'commission_settled': '0.00',
      'customer_outstanding': '100000.00',
    },
    'rows': [
      {
        'record_name': 'QA-ONLY-001',
        'vehicle_registration': 'QA-ONLY-001',
        'customer_fare': '100000.00',
        'owner_earnings': '95000.00',
        'brokerage': '5000.00',
        'vehicle_cost': '0.00',
        'operating_profit': '95000.00',
        'customer_outstanding': '100000.00',
        'custody': '0.00',
        'owner_due': '95000.00',
      },
    ],
    'row_count': 1,
    'page_offset': 0,
    'has_more': false,
    'format_options': {'orientation': 'AUTO', 'sheet_name': 'Records'},
  };
  final parsed = AuthorizedOutput.fromPayload(base);
  Map<String, String> pair(String en) => {
    'en': en,
    'ur': ownedMessage(en).ur.isEmpty ? 'محفوظ عنوان' : ownedMessage(en).ur,
  };
  base['template_version'] = 2;
  base['presentation'] = {
    'version': 2,
    'font_set': 'noto-karvaan-20261013',
    'brand': pair('Karvaan'),
    'title': {'en': parsed.title, 'ur': 'گاڑی کی ماہانہ رپورٹ - غیر جاری شدہ'},
    'fields': {for (final f in parsed.fields) f.key: pair(f.label)},
    'summaries': {
      for (final e in parsed.summaries.entries) e.key: pair(e.value),
    },
    'frames': {
      'offices': pair('Offices'),
      'date_bases': pair('Date bases'),
      'currency': pair('Currency'),
      'records': pair('Records'),
      'supersedes': pair('Supersedes'),
      'row': pair('Row'),
      'summary': pair('Authoritative summary'),
      'no_records': pair('No records in this period/scope.'),
      'selected': pair('Selected attributes {0}-{1} of {2}'),
      'page': pair('Page {0} of {1}'),
      'issued': pair('Issued snapshot'),
      'live': pair('Current authorized records'),
      'continuation': pair(
        'Long text continues in visible rows; amounts appear once per source record.',
      ),
      'precision': pair(
        'Amounts exceeding Excel numeric precision remain exact decimal text; PKR is the currency.',
      ),
      'totals': pair(
        'Totals are server-calculated for all {0} authorized records.',
      ),
    },
    'date_bases': {
      for (final e in parsed.bases.entries)
        e.key: {'en': '${e.key}: ${e.value}', 'ur': 'تاریخ کی محفوظ بنیاد'},
    },
  };
  return base;
}
