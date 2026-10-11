import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ReportCommands {
  Future<Map<String, dynamic>> report(
    String kind,
    Map<String, dynamic> filters, {
    int offset = 0,
  });
}

class ReportRepository implements ReportCommands {
  ReportRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> report(
    String kind,
    Map<String, dynamic> filters, {
    int offset = 0,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
      'get_scoped_report',
      params: {'report_kind': kind, 'filters': filters, 'page_offset': offset},
    ) as Map,
  );
}

const reportLabels = <String, String>{
  'customer_fare': 'Customer fare — dispatch / adjustment date',
  'owner_earnings': 'Owner earnings — dispatch / adjustment date',
  'brokerage': 'Brokerage earned — dispatch / adjustment date',
  'vehicle_cost': 'Vehicle costs — expense date',
  'owner_cost': 'Owner-borne costs — expense date',
  'operating_profit': 'Vehicle operating profit — earnings less period costs',
  'owner_profit': 'Owner profit — owner earnings less owner-borne costs',
  'receipts': 'Customer receipts — payment date',
  'refunds': 'Customer refunds — payment date',
  'owner_settled': 'Owner cash settlements — payment date',
  'commission_settled': 'Commission settled — payment date',
  'credit_created': 'Credits created — event date',
  'credit_applied': 'Credits applied — application date',
  'customer_outstanding': 'Customer outstanding — period end',
  'customer_credit': 'Customer credit — period end',
  'custody': 'Intermediary-held money — period end',
  'owner_due': 'Owner settlement due — period end',
  'owner_recovery': 'Owner recovery — period end',
  'brokerage_due': 'Brokerage due — period end',
  'brokerage_recovery': 'Broker recovery — period end',
  'funding_due': 'Personal funding due — period end',
  'reimbursement_due': 'Expense reimbursement due — period end',
  'cost_recovery': 'Cost recovery — period end',
  'dispatched': 'Dispatched trips — dispatch date',
  'arrived': 'Arrived trips — arrival date',
};
