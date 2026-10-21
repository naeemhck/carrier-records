import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_components.dart';
import '../../app/karvaan_design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/record_context.dart';
import '../../core/domain/money.dart';
import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import '../finance/financial_repository.dart';
import '../finance/payment_model.dart';
import '../finance/correction_repository.dart';
import '../finance/correction_workspace.dart';
import 'expense_model.dart';
import 'expense_repository.dart';

typedef ExpenseGuard = Widget Function(Widget);
String expenseError(Object e) => e is PostgrestException && e.code == 'PT409'
    ? 'Claims changed. Reload and review.'
    : e is FormatException
    ? e.message
    : 'Request was not confirmed. Retry the same request; preserve your entry.';
Future<MasterRecord?> chooseExpenseMaster(
  BuildContext context,
  MasterRepository repo,
  MasterKind kind,
  ExpenseGuard guard,
) async {
  return showDialog<MasterRecord>(
    animationStyle: AnimationStyle.noAnimation,
    context: context,
    builder: (_) => guard(_MasterPicker(repo: repo, kind: kind)),
  );
}

/// Client-side record of which master records and trips staff picked in this
/// session, so the searchable pickers lead with the most-used items first.
/// Presentation only: ids and pick counts live in memory for the app session;
/// the server order is otherwise untouched and no extra request is made.
abstract final class PickerUsage {
  static const int promotedLimit = 5;
  static final Map<String, int> _masters = {}; // '<kind-code>:<record-id>'
  static final Map<String, int> _trips = {}; // trip id

  static void pickedMaster(MasterKind kind, String id) {
    final key = '${kind.code}:$id';
    _masters[key] = (_masters[key] ?? 0) + 1;
  }

  static void pickedTrip(String id) {
    _trips[id] = (_trips[id] ?? 0) + 1;
  }

  static int _count(Map<String, int> table, String key) => table[key] ?? 0;

  /// Reorders [rows] in place-order: the most-used picks (count descending,
  /// capped at [promotedLimit]) first, then everything else in server order.
  /// Returns the reordered list and how many leading rows were promoted.
  static ({List<MasterRecord> rows, int promoted}) promoteMasters(
    MasterKind kind,
    List<MasterRecord> rows,
  ) {
    final used =
        rows.where((r) => _count(_masters, '${kind.code}:${r.id}') > 0).toList()
          ..sort(
            (a, b) => _count(
              _masters,
              '${kind.code}:${b.id}',
            ).compareTo(_count(_masters, '${kind.code}:${a.id}')),
          );
    final promoted = used.take(promotedLimit).toList();
    final ids = promoted.map((r) => r.id).toSet();
    return (
      rows: [...promoted, ...rows.where((r) => !ids.contains(r.id))],
      promoted: promoted.length,
    );
  }

  static ({List<Map<String, dynamic>> rows, int promoted}) promoteTrips(
    List<Map<String, dynamic>> rows,
  ) {
    final used = rows.where((t) => _count(_trips, '${t['id']}') > 0).toList()
      ..sort(
        (a, b) => _count(
          _trips,
          '${b['id']}',
        ).compareTo(_count(_trips, '${a['id']}')),
      );
    final promoted = used.take(promotedLimit).toList();
    final ids = promoted.map((t) => '${t['id']}').toSet();
    return (
      rows: [...promoted, ...rows.where((t) => !ids.contains('${t['id']}'))],
      promoted: promoted.length,
    );
  }
}

/// Status chip for an expense list row. Active expenses use the money green;
/// voided or replaced (historical) rows are neutral. Mirrors TripStatusBadge.
class ExpenseStatusChip extends StatelessWidget {
  const ExpenseStatusChip({super.key, required this.effective});
  final bool effective;
  @override
  Widget build(BuildContext context) {
    final (foreground, background) = effective
        ? (KarvaanDesign.money, KarvaanDesign.moneySurface)
        : (KarvaanDesign.secondary, KarvaanDesign.background);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: BilingualText(
          effective ? L10n.expenseActive : L10n.expenseHistorical,
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}

class _MasterPicker extends StatefulWidget {
  const _MasterPicker({required this.repo, required this.kind});
  final MasterRepository repo;
  final MasterKind kind;
  @override
  State<_MasterPicker> createState() => _MasterPickerState();
}

class _MasterPickerState extends State<_MasterPicker> {
  final search = TextEditingController();
  List<MasterRecord> rows = [];
  int offset = 0;
  int promoted = 0;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await widget.repo.list(
        widget.kind,
        search: search.text,
        offset: offset,
      );
      final promotedResult = PickerUsage.promoteMasters(
        widget.kind,
        r.where((x) => !x.archived).toList(),
      );
      if (mounted) {
        setState(() {
          rows = promotedResult.rows;
          promoted = promotedResult.promoted;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(MasterRecord row) {
    PickerUsage.pickedMaster(widget.kind, row.id);
    Navigator.pop(context, row);
  }

  Widget tile(MasterRecord row) =>
      BilingualListTile(title: Text(row.label), onTap: () => select(row));

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: BilingualOwnedText(widget.kind.label),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.searchRecords)),
            ),
            onSubmitted: (_) {
              offset = 0;
              load();
            },
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) BilingualOwnedText(error!),
          Expanded(
            child: rows.isEmpty && !busy && error == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BilingualText(L10n.noRecordsFound),
                      TextButton(
                        onPressed: () {
                          search.clear();
                          offset = 0;
                          load();
                        },
                        child: const BilingualCaption(L10n.clearSearch),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      if (promoted > 0) const BilingualCaption(L10n.mostUsed),
                      for (final row in rows.take(promoted)) tile(row),
                      if (promoted > 0 && rows.length > promoted)
                        const Divider(),
                      for (final row in rows.skip(promoted)) tile(row),
                    ],
                  ),
          ),
          // Wrap: bilingual buttons overflow a fixed Row at 200%.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: busy || offset == 0
                    ? null
                    : () {
                        offset -= 50;
                        load();
                      },
                child: const BilingualCaption(L10n.previous),
              ),
              TextButton(
                onPressed: busy || rows.length < 50
                    ? null
                    : () {
                        offset += 50;
                        load();
                      },
                child: const BilingualCaption(L10n.next),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class ExpenseWorkspace extends StatefulWidget {
  const ExpenseWorkspace({
    super.key,
    required this.expenses,
    required this.finance,
    required this.trips,
    required this.masters,
    required this.offices,
    required this.guard,
    this.picker,
    this.administrator = false,
    this.corrections,
  });
  final bool administrator;
  final CorrectionCommands? corrections;
  final ExpenseCommands expenses;
  final FinancialCommands finance;
  final TripRepository trips;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final ExpenseGuard guard;
  final ReceiptPicker? picker;
  @override
  State<ExpenseWorkspace> createState() => _ExpenseWorkspaceState();
}

class _ExpenseWorkspaceState extends State<ExpenseWorkspace> {
  List<Map<String, dynamic>> rows = [];
  int offset = 0;
  bool busy = false;
  String? error;

  /// Register sort (reports pass): page-local, over the loaded rows.
  int? _expenseSortColumn;
  bool _expenseSortAscending = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final r = await widget.expenses.list(offset: offset);
      if (mounted) setState(() => rows = r);
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Widget child) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => widget.guard(child)),
    );
    if (mounted) await load();
  }

  Widget newEntry() => ExpenseEntry(
    expenses: widget.expenses,
    finance: widget.finance,
    trips: widget.trips,
    masters: widget.masters,
    offices: widget.offices,
    guard: widget.guard,
    picker: widget.picker,
  );

  /// Sum of the amounts shown on the current page, formatted for display.
  /// A page subtotal, never an authoritative ledger total; hidden when any
  /// shown row cannot be parsed.
  String? pageTotal() {
    try {
      final paisa = AllocationTotals.sum([
        for (final r in rows) r['amount'] as String,
      ]);
      return displayMoney(Money.fromExactPaisa(paisa));
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// Summary-first totals strip: the page subtotal figure leads with its
  /// caption beneath, followed by the records/page count as metadata.
  Widget totalsStrip() {
    final total = pageTotal();
    final page = offset ~/ 50 + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (total != null)
              KarvaanMetric(
                label: L10n.pageExpensesTotal,
                formattedValue: total,
                hero: true,
              ),
            BilingualText(
              L10n.recordsPage.withValues([
                displayCount(rows.length),
                displayCount(page),
              ]),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: KarvaanDesign.secondary),
            ),
          ],
        ),
      ),
    );
  }

  /// One expense as a card (narrow layouts). The wide table renders the
  /// same rows; both share the settle/receipt actions.
  Widget _expenseCard(Map<String, dynamic> row) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BilingualText(
                  L10n.labelValuesfb62fe.withValues([
                    row['expense_date'],
                    row['trip_id'] == null
                        ? L10n.standaloneMaintenance
                        : L10n.tripCost,
                  ]),
                ),
              ),
              ExpenseStatusChip(effective: row['effective'] != false),
            ],
          ),
          KarvaanAmount(
            label: ownedMessage('Expense amount (PKR)'),
            value: row['amount'] as String,
          ),
          Text((row['notes']).toString()),
          BilingualOwnedText(row['funding_source']),
          if (row['effective'] == false)
            const BilingualText(
              L10n.historicalExpenseVoidedOrReplacedExcludedFromCurrentCosts,
            ),
          if (row['replaces_expense_id'] != null)
            BilingualText(
              L10n.replacesOriginalExpense.withValues([
                row['replaces_expense_id'],
                row['correction_reason'],
              ]),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => open(
                        ExpenseSettlement(
                          expense: row,
                          expenses: widget.expenses,
                          finance: widget.finance,
                          masters: widget.masters,
                          guard: widget.guard,
                        ),
                      ),
                child: const BilingualCaption(L10n.claimsReimburseRecover),
              ),
              TextButton(
                onPressed: busy ? null : () => receipt(row),
                child: const BilingualCaption(L10n.privateReceipt),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Table-first rendering for wide layouts (plan §5.6): date, scope,
  /// funding, amount and status, with the same actions as the cards. The
  /// list payload carries no category name, so none is invented.
  /// Register pattern (reports pass): the expenses table sorts by the
  /// columns its rows actually carry — date, scope, funding source,
  /// amount (exact paisa), status. Sorting is page-local.
  Widget _expensesTable() {
    String field(Map<String, dynamic> r, String key) =>
        (r[key] ?? '').toString();
    int moneyCompare(Object? a, Object? b) {
      try {
        return LedgerAmount.fromJson(a ?? '0.00').paisa
            .compareTo(LedgerAmount.fromJson(b ?? '0.00').paisa);
      } on FormatException {
        return (a ?? '').toString().compareTo((b ?? '').toString());
      }
    }

    int compare(Map<String, dynamic> a, Map<String, dynamic> b, int column) =>
        switch (column) {
          0 => field(a, 'expense_date').compareTo(field(b, 'expense_date')),
          1 => (a['trip_id'] == null ? 0 : 1).compareTo(
            b['trip_id'] == null ? 0 : 1,
          ),
          2 => field(a, 'funding_source').compareTo(field(b, 'funding_source')),
          3 => moneyCompare(a['amount'], b['amount']),
          _ => ((a['effective'] != false) ? 1 : 0).compareTo(
            (b['effective'] != false) ? 1 : 0,
          ),
        };
    final sorted = List.of(rows);
    final sortColumn = _expenseSortColumn;
    if (sortColumn != null) {
      sorted.sort((a, b) {
        final order = compare(a, b, sortColumn);
        return _expenseSortAscending ? order : -order;
      });
    }
    void onSort(int column, bool ascending) => setState(() {
      _expenseSortColumn = column;
      _expenseSortAscending = ascending;
    });
    return KarvaanDataTable(
      sortColumnIndex: sortColumn,
      sortAscending: _expenseSortAscending,
      columns: [
        DataColumn(label: const BilingualText(L10n.dateLabel), onSort: onSort),
        DataColumn(label: const BilingualText(L10n.scopeLabel), onSort: onSort),
        DataColumn(
          label: const BilingualText(L10n.fundingSource),
          onSort: onSort,
        ),
        DataColumn(
          label: const BilingualText(L10n.amountLabel),
          numeric: true,
          onSort: onSort,
        ),
        DataColumn(
          label: const BilingualText(L10n.historyFieldStatus),
          onSort: onSort,
        ),
        const DataColumn(label: BilingualText(L10n.claimsReimburseRecover)),
      ],
      rows: [
        for (final row in sorted)
          DataRow(
            cells: [
              DataCell(
                Text(
                  displayTimestamp(row['expense_date']),
                  textDirection: TextDirection.ltr,
                ),
              ),
              DataCell(
                BilingualText(
                  row['trip_id'] == null
                      ? L10n.standaloneMaintenance
                      : L10n.tripCost,
                ),
              ),
              DataCell(BilingualOwnedText(row['funding_source'])),
              DataCell(
                Text(
                  displayMoney(row['amount']),
                  textDirection: TextDirection.ltr,
                ),
              ),
              DataCell(ExpenseStatusChip(effective: row['effective'] != false)),
              DataCell(
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => open(
                              ExpenseSettlement(
                                expense: row,
                                expenses: widget.expenses,
                                finance: widget.finance,
                                masters: widget.masters,
                                guard: widget.guard,
                              ),
                            ),
                      child: const BilingualCaption(
                        L10n.claimsReimburseRecover,
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => receipt(row),
                      child: const BilingualCaption(L10n.privateReceipt),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> receipt(Map<String, dynamic> row) async {
    setState(() => busy = true);
    try {
      final bytes = await widget.expenses.download(row['id'] as String);
      if (!mounted) return;
      if (bytes == null) {
        final file = await (widget.picker ?? NativeReceiptPicker()).pick();
        if (file == null) return;
        await widget.expenses.attach(row['id'] as String, newRecordId(), file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: BilingualText(
                L10n.receiptAttachedExpensePostingIsUnchanged,
              ),
            ),
          );
        }
      } else {
        await showDialog<void>(
          animationStyle: AnimationStyle.noAnimation,
          context: context,
          builder: (_) => widget.guard(
            AlertDialog(
              scrollable: true,
              title: const BilingualText(L10n.privateReceipt),
              content: SizedBox(
                width: 500,
                child: bytes.length > 4 && bytes[0] == 37
                    ? BilingualText(
                        L10n.pdfReceiptDownloadedSecurelyBytes.withValues([
                          bytes.length,
                        ]),
                      )
                    : Image.memory(bytes),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const BilingualCaption(L10n.close),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Expense remains posted. Receipt upload or download failed; no financial retry was made.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Scaffold(
      appBar: AppBar(
        toolbarHeight: bilingualToolbarHeight(
          context,
          L10n.expensesAndReimbursements,
          constraints.maxWidth - kToolbarHeight - kMinInteractiveDimension - 32,
        ),
        title: DefaultTextStyle(
          style: Theme.of(context).textTheme.titleLarge!,
          child: const BilingualText(L10n.expensesAndReimbursements),
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const BilingualText(
            L10n.permittedOfficeAndTripExpensesMaintenanceRemainsUnlinkedUnless,
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) BilingualOwnedText(error!),
          if (!busy && error == null && rows.isNotEmpty) totalsStrip(),
          // One create action per state (handoff group 9): while the
          // list is empty, the empty state below carries the action
          // ("Record expense"); this header button serves the populated
          // and loading states.
          if (busy || error != null || rows.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : () => open(newEntry()),
                icon: const Icon(Icons.add),
                label: const BilingualText(L10n.newExpense),
              ),
            ),
          if (widget.corrections != null)
            TextButton(
              onPressed: () => open(
                CorrectionWorkspace(
                  commands: widget.corrections!,
                  trips: widget.trips,
                  guard: widget.guard,
                ),
              ),
              child: const BilingualCaption(L10n.correctionsAndHistory),
            ),
          if (widget.administrator)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final n = await widget.expenses.cleanup();
                        if (mounted) {
                          setState(
                            () => error =
                                'Removed $n abandoned uploads older than 24 hours. Referenced receipts are retained.',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(
                            () => error = 'Cleanup failed. Referenced receipts are retained.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const BilingualCaption(L10n.cleanAbandonedReceiptUploads),
            ),
          if (!busy && error == null && rows.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scope-specific empty wording, matching the registers
                // (GPT QA F05): the main list is scope-bound, unlike the
                // search pickers, which keep the generic line.
                const BilingualText(L10n.noExpensesInYourCurrentScope),
                TextButton(
                  onPressed: busy ? null : () => open(newEntry()),
                  child: const BilingualCaption(L10n.recordExpense),
                ),
              ],
            ),
          if (constraints.maxWidth >= 768 && rows.isNotEmpty)
            _expensesTable()
          else
            for (final row in rows) _expenseCard(row),
          // Pagination hides when there is nothing to page through.
          if (rows.isNotEmpty || offset > 0)
            Row(
              children: [
                TextButton(
                  onPressed: busy || offset == 0
                      ? null
                      : () {
                          offset -= 50;
                          load();
                        },
                  child: const BilingualCaption(L10n.previous),
                ),
                TextButton(
                  onPressed: busy || rows.length < 50
                      ? null
                      : () {
                          offset += 50;
                          load();
                        },
                  child: const BilingualCaption(L10n.next),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class ExpenseEntry extends StatefulWidget {
  const ExpenseEntry({
    super.key,
    required this.expenses,
    required this.finance,
    required this.trips,
    required this.masters,
    required this.offices,
    required this.guard,
    this.picker,
    this.initialDraft,
  });
  final ExpenseCommands expenses;
  final FinancialCommands finance;
  final TripRepository trips;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final ExpenseGuard guard;
  final ReceiptPicker? picker;
  final Map<String, dynamic>? initialDraft;
  @override
  State<ExpenseEntry> createState() => _ExpenseEntryState();
}

class _ExpenseEntryState extends State<ExpenseEntry> {
  final amount = TextEditingController(),
      notes = TextEditingController(),
      date = TextEditingController(
        text: DateTime.now()
            .toUtc()
            .add(const Duration(hours: 5))
            .toIso8601String()
            .substring(0, 10),
      );
  MasterRecord? vehicle, category, payer, bearer;
  Map<String, dynamic>? trip;
  String? office, owner;
  ExpenseFunding funding = ExpenseFunding.personal;
  bool agreed = false, busy = false, conflict = false;
  String? error, request, receiptRequest;
  Map<String, dynamic>? reviewed, posted;
  ReceiptSelection? evidence;
  String receiptStatus = 'Not selected';
  List<Map<String, dynamic>> claims = [];
  final inputs = <String, TextEditingController>{};
  bool get locked => busy || request != null || posted != null;
  @override
  void initState() {
    super.initState();
    office = widget.offices.firstOrNull?['id'] as String?;
    final d = widget.initialDraft;
    if (d != null) {
      final p = Map<String, dynamic>.from(d['payload'] as Map);
      vehicle = MasterRecord(Map<String, dynamic>.from(d['vehicle'] as Map));
      category = MasterRecord(Map<String, dynamic>.from(d['category'] as Map));
      payer = MasterRecord(Map<String, dynamic>.from(d['payer'] as Map));
      bearer = MasterRecord(Map<String, dynamic>.from(d['bearer'] as Map));
      office = p['office_id'] as String;
      owner = vehicle!.data['current_owner_id'] as String;
      amount.text = p['amount'] as String;
      notes.text = p['reason'] as String;
      date.text = p['effective_date'] as String;
      funding = ExpenseFunding.values.firstWhere(
        (f) => f.key == p['funding_source'],
      );
      if (d['trip'] != null) {
        trip = Map<String, dynamic>.from(d['trip'] as Map);
        owner = trip!['owner_id'] as String;
        WidgetsBinding.instance.addPostFrameCallback((_) => reload());
      }
    }
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    date.dispose();
    for (final c in inputs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> choose(MasterKind kind, String field) async {
    final r = await chooseExpenseMaster(
      context,
      widget.masters,
      kind,
      widget.guard,
    );
    if (r == null || !mounted) return;
    setState(() {
      if (field == 'vehicle') {
        vehicle = r;
        owner = r.data['current_owner_id'] as String?;
        trip = null;
        clearClaims();
      }
      if (field == 'category') category = r;
      if (field == 'payer') payer = r;
      if (field == 'bearer') bearer = r;
      reviewed = null;
    });
  }

  void clearClaims() {
    for (final c in inputs.values) {
      c.dispose();
    }
    inputs.clear();
    claims = [];
  }

  Future<void> chooseTrip() async {
    final selected = await showDialog<Map<String, dynamic>>(
      animationStyle: AnimationStyle.noAnimation,
      context: context,
      builder: (_) =>
          widget.guard(_TripPicker(repo: widget.trips, vehicle: vehicle!.id)),
    );
    if (selected == null || !mounted) return;
    setState(() => busy = true);
    try {
      final detail = await widget.trips.detail(selected['id'] as String);
      final ledger = await widget.finance.trip(
        RecordId(selected['id'] as String),
      );
      if (mounted) {
        setState(() {
          trip = detail;
          owner = detail['owner_id'] as String;
          clearClaims();
          claims = (ledger['claims'] as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          for (final c in claims) {
            inputs[c['line_id'] as String] = TextEditingController();
          }
          reviewed = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reload() async {
    if (trip == null) return;
    setState(() => busy = true);
    try {
      final ledger = await widget.finance.trip(RecordId(trip!['id'] as String));
      if (mounted) {
        setState(() {
          clearClaims();
          claims = (ledger['claims'] as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          for (final c in claims) {
            inputs[c['line_id'] as String] = TextEditingController();
          }
          request = null;
          reviewed = null;
          conflict = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  List<Map<String, dynamic>> get eligible => claims
      .where(
        (c) =>
            c['account_purpose'] == 'OWNER_PAYABLE' &&
                c['party_id'] == bearer?.id &&
                bearer?.id == owner &&
                funding != ExpenseFunding.self ||
            c['account_purpose'] == 'CUSTODY_RECEIVABLE' &&
                c['party_id'] == payer?.id &&
                funding == ExpenseFunding.held,
      )
      .toList();
  void review() {
    try {
      final p = expensePayload(
        vehicle: vehicle!.id,
        trip: trip?['id'] as String?,
        office: office!,
        category: category!.id,
        date: date.text,
        amount: amount.text,
        payer: payer!.id,
        bearer: bearer!.id,
        owner: owner!,
        funding: funding,
        earningsRecognized: trip?['dispatch_date'] != null,
        availableOwner: AllocationTotals.sum(
          claims
              .where(
                (c) =>
                    c['account_purpose'] == 'OWNER_PAYABLE' &&
                    c['party_id'] == owner,
              )
              .map((c) => c['remaining'] as String)
              .toList(),
        ).toString(),
        reason: notes.text,
        agreed: agreed,
        allocations: [
          for (final c in eligible)
            if (inputs[c['line_id']]!.text.isNotEmpty)
              {
                'line_id': c['line_id'],
                'version': c['version'],
                'amount': inputs[c['line_id']]!.text,
                'component': c['account_purpose'] == 'OWNER_PAYABLE'
                    ? 'OFFSET'
                    : 'CASH',
              },
        ],
      );
      setState(() {
        reviewed = p;
        error = null;
      });
    } catch (e) {
      setState(
        () => error = e is FormatException
            ? e.message
            : 'Choose vehicle, office, category, payer and cost bearer.',
      );
    }
  }

  Future<void> confirm() async {
    setState(() => busy = true);
    request ??= newRecordId();
    try {
      final r = await widget.expenses.post(request!, reviewed!);
      if (!mounted) return;
      setState(() => posted = r);
      if (evidence != null) await upload();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = expenseError(e);
          conflict = e is PostgrestException && e.code == 'PT409';
          if (e is PostgrestException && e.code == '22023') {
            request = null;
            reviewed = null;
            error =
                'Expense rejected: ${e.message}. Review the preserved entry.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> upload() async {
    receiptRequest ??= newRecordId();
    setState(() {
      busy = true;
      receiptStatus = 'Uploading receipt; expense is confirmed.';
    });
    try {
      await widget.expenses.attach(
        posted!['record_id'] as String,
        receiptRequest!,
        evidence!,
      );
      if (mounted) setState(() => receiptStatus = 'Receipt attached.');
    } catch (e) {
      if (mounted) {
        setState(
          () => receiptStatus = 'Receipt upload failed. Expense is confirmed. Retry attachment only.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick() async {
    try {
      final r = await (widget.picker ?? NativeReceiptPicker()).pick();
      if (r != null && mounted) {
        setState(() {
          evidence = r;
          receiptStatus =
              'Selected evidence (${r.bytes.length} bytes); not uploaded.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => receiptStatus =
              'Receipt selection failed; expense is not yet posted.',
        );
      }
    }
  }

  Widget field(TextEditingController c, String label) => TextField(
    controller: c,
    style: identical(c, amount)
        ? Theme.of(context).textTheme.displaySmall
        : Theme.of(context).textTheme.bodyMedium,
    textDirection: identical(c, amount) ? TextDirection.ltr : null,
    enabled: !locked,
    onChanged: (_) => setState(() => reviewed = null),
    decoration: bilingualDecoration(
      context,
      InputDecoration(label: BilingualOwnedCaption(label)),
    ),
  );

  /// The figure leads on money: a small caption beneath the large tabular
  /// amount input, showing the same value with thousands separators.
  /// Shown only while the typed text parses as money; invalid input shows
  /// nothing here and is reported by review validation as before.
  Widget amountFigure() {
    final text = amount.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    late final String formatted;
    try {
      formatted = displayMoney(Money.parse(text));
    } on FormatException {
      return const SizedBox.shrink();
    } on RangeError {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        formatted,
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: KarvaanDesign.secondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
        title: const BilingualText(L10n.recordExpense),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) BilingualOwnedText(error!),
          if (posted != null) ...[
            BilingualText(
              moneyMessage(
                L10n.expenseConfirmedPKRReceiptStatusIsSeparate,
                [posted!['amount']],
                {0},
              ),
            ),
            BilingualOwnedText(receiptStatus),
            if (evidence != null && receiptStatus != 'Receipt attached.')
              FilledButton(
                onPressed: busy ? null : upload,
                child: const BilingualCaption(L10n.retryReceiptOnly),
              ),
          ] else ...[
            KarvaanSection(
              title: L10n.whatSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () => choose(MasterKind.category, 'category'),
                    child: BilingualCaption(
                      (category?.label != null
                          ? Bilingual.data(category?.label)
                          : L10n.chooseCategory),
                    ),
                  ),
                  field(date, 'Expense date (YYYY-MM-DD)'),
                  field(amount, 'Expense amount (PKR)'),
                  amountFigure(),
                  field(notes, 'Notes / reason'),
                ],
              ),
            ),
            KarvaanSection(
              title: L10n.whoseMoneySection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () => choose(MasterKind.party, 'payer'),
                    child: BilingualCaption(
                      (payer == null
                          ? L10n.choosePayer
                          : L10n.payer.withValues([payer!.label])),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () => choose(MasterKind.party, 'bearer'),
                    child: BilingualCaption(
                      (bearer == null
                          ? L10n.chooseCostBearer
                          : L10n.costBearerf2e025.withValues([bearer!.label])),
                    ),
                  ),
                  BilingualText(
                    (trip != null
                        ? L10n.historicalOwner.withValues([
                            (trip!['owner_snapshot'] as Map)['display_name'],
                          ])
                        : L10n.confirmTheVehicleOwnerAsCostBearerWhenApplicable),
                  ),
                  KarvaanChoiceField<ExpenseFunding>(
                    initialValue: funding,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.fundingSource),
                      ),
                    ),
                    items: ExpenseFunding.values
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: BilingualOwnedText(f.label),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (v) => setState(() {
                            funding = v!;
                            reviewed = null;
                          }),
                  ),
                  if (payer?.id == owner &&
                      bearer?.id == owner &&
                      funding == ExpenseFunding.self)
                    const BilingualText(
                      L10n.ownerHasAlreadyPaidThisPersonallyOwnerSettlementIs,
                    ),
                  CheckboxListTile(
                    value: agreed,
                    onChanged: locked
                        ? null
                        : (v) => setState(() {
                            agreed = v!;
                            reviewed = null;
                          }),
                    title: const BilingualText(
                      L10n.confirmAgreedOwnerSettlementOffsetWhenApplicable,
                    ),
                  ),
                  const BilingualText(
                    L10n.allocateCashSpentFromCustodyAndNonCashOwner,
                  ),
                  for (final c in eligible)
                    field(
                      inputs[c['line_id']]!,
                      '${c['account_purpose'] == 'OWNER_PAYABLE' ? 'Owner offset' : 'Held cash source'} | remaining ${displayMoney(c['remaining'])}',
                    ),
                ],
              ),
            ),
            KarvaanSection(
              title: L10n.whereSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: locked
                        ? null
                        : () => choose(MasterKind.vehicle, 'vehicle'),
                    child: BilingualCaption(
                      (vehicle?.label != null
                          ? Bilingual.data(vehicle?.label)
                          : L10n.chooseVehicle),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: locked || vehicle == null ? null : chooseTrip,
                    child: BilingualCaption(
                      (trip == null
                          ? L10n.optionalTrip
                          : L10n.trip3c1efc.withValues([trip!['trip_number']])),
                    ),
                  ),
                  if (trip != null)
                    TextButton(
                      onPressed: locked
                          ? null
                          : () => setState(() {
                              trip = null;
                              reviewed = null;
                              owner =
                                  vehicle!.data['current_owner_id'] as String?;
                              clearClaims();
                            }),
                      child: const BilingualCaption(
                        L10n.keepAsStandaloneMaintenance,
                      ),
                    ),
                  KarvaanChoiceField<String>(
                    initialValue: office,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.expenseOffice),
                      ),
                    ),
                    items: widget.offices
                        .map(
                          (o) => DropdownMenuItem(
                            value: o['id'] as String,
                            child: Text(o['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: locked
                        ? null
                        : (v) => setState(() {
                            office = v;
                            reviewed = null;
                          }),
                  ),
                ],
              ),
            ),
            KarvaanSection(
              title: L10n.proofSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: locked ? null : pick,
                    child: const BilingualCaption(
                      L10n.optionalPrivateReceiptPNGJPEGPDFMB,
                    ),
                  ),
                  BilingualOwnedText(receiptStatus),
                ],
              ),
            ),
            if (conflict)
              TextButton(
                onPressed: busy ? null : reload,
                child: const BilingualCaption(L10n.reloadClaimsAndReview),
              ),
            if (reviewed == null)
              FilledButton(
                onPressed: locked ? null : review,
                child: const BilingualCaption(L10n.reviewExpense),
              )
            else ...[
              BilingualText(
                moneyMessage(
                  L10n.expensePKR,
                  [reviewed!['amount'], funding.label],
                  {0},
                ),
              ),
              BilingualText(
                moneyMessage(
                  L10n.cashSpentPKROwnerOffsetPKR,
                  [
                    AllocationTotals.decimal(
                      AllocationTotals.sum(
                        (reviewed!['allocations'] as List)
                            .where((x) => x['component'] == 'CASH')
                            .map((x) => x['amount'] as String)
                            .toList(),
                      ),
                    ),
                    AllocationTotals.decimal(
                      AllocationTotals.sum(
                        (reviewed!['allocations'] as List)
                            .where((x) => x['component'] == 'OFFSET')
                            .map((x) => x['amount'] as String)
                            .toList(),
                      ),
                    ),
                  ],
                  {0, 1},
                ),
              ),
              FilledButton(
                onPressed: busy || conflict ? null : confirm,
                child: BilingualCaption(
                  (request == null
                      ? L10n.confirmExpense
                      : L10n.retrySameExpenseRequest),
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

class _TripPicker extends StatefulWidget {
  const _TripPicker({required this.repo, required this.vehicle});
  final TripRepository repo;
  final String vehicle;
  @override
  State<_TripPicker> createState() => _TripPickerState();
}

class _TripPickerState extends State<_TripPicker> {
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  int offset = 0;
  int promoted = 0;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final p = await widget.repo.list(
        vehicle: widget.vehicle,
        search: search.text,
        offset: offset,
      );
      final promotedResult = PickerUsage.promoteTrips(p.rows);
      if (mounted) {
        setState(() {
          rows = promotedResult.rows;
          promoted = promotedResult.promoted;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void select(Map<String, dynamic> trip) {
    PickerUsage.pickedTrip('${trip['id']}');
    Navigator.pop(context, trip);
  }

  Widget tile(Map<String, dynamic> t) => BilingualListTile(
    title: Text((t['trip_number']).toString()),
    subtitle: BilingualOwnedText(t['state']),
    onTap: () => select(t),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const BilingualText(L10n.choosePermittedTrip),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(label: BilingualCaption(L10n.searchTrips)),
            ),
            onSubmitted: (_) {
              offset = 0;
              load();
            },
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) BilingualOwnedText(error!),
          Expanded(
            child: rows.isEmpty && !busy && error == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BilingualText(L10n.noRecordsFound),
                      TextButton(
                        onPressed: () {
                          search.clear();
                          offset = 0;
                          load();
                        },
                        child: const BilingualCaption(L10n.clearSearch),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      if (promoted > 0) const BilingualCaption(L10n.mostUsed),
                      for (final t in rows.take(promoted)) tile(t),
                      if (promoted > 0 && rows.length > promoted)
                        const Divider(),
                      for (final t in rows.skip(promoted)) tile(t),
                    ],
                  ),
          ),
          if (rows.isNotEmpty || offset > 0)
            Row(
              children: [
                TextButton(
                  onPressed: busy || offset == 0
                      ? null
                      : () {
                          offset -= 50;
                          load();
                        },
                  child: const BilingualCaption(L10n.previous),
                ),
                TextButton(
                  onPressed: busy || rows.length < 50
                      ? null
                      : () {
                          offset += 50;
                          load();
                        },
                  child: const BilingualCaption(L10n.next),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class ExpenseSettlement extends StatefulWidget {
  const ExpenseSettlement({
    super.key,
    required this.expense,
    required this.expenses,
    required this.finance,
    required this.masters,
    required this.guard,
  });
  final Map<String, dynamic> expense;
  final ExpenseCommands expenses;
  final FinancialCommands finance;
  final MasterRepository masters;
  final ExpenseGuard guard;
  @override
  State<ExpenseSettlement> createState() => _ExpenseSettlementState();
}

class _ExpenseSettlementState extends State<ExpenseSettlement> {
  bool recovery = false, offset = false, busy = false, conflict = false;
  String? error, request;
  Map<String, dynamic>? reviewed;
  MasterRecord? payer, payee;
  final date = TextEditingController(
        text: DateTime.now()
            .toUtc()
            .add(const Duration(hours: 5))
            .toIso8601String()
            .substring(0, 10),
      ),
      reason = TextEditingController();
  List<Map<String, dynamic>> claims = [], sources = [];
  final amounts = <String, TextEditingController>{};
  final selected = <String, String>{};
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    date.dispose();
    reason.dispose();
    for (final a in amounts.values) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final c = await widget.expenses.claims(widget.expense['id'] as String);
      final trip = widget.expense['trip_id'] as String?;
      final s = trip == null
          ? c
          : (await widget.finance.trip(RecordId(trip)))['claims'] as List;
      if (mounted) {
        setState(() {
          claims = c;
          sources = s
              .map((x) => Map<String, dynamic>.from(x as Map))
              .where(
                (x) =>
                    x['account_purpose'] == 'CUSTODY_RECEIVABLE' ||
                    x['account_purpose'] == 'OWNER_PAYABLE',
              )
              .toList();
          for (final a in amounts.values) {
            a.dispose();
          }
          amounts.clear();
          selected.clear();
          for (final x in c) {
            amounts[x['line_id'] as String] = TextEditingController();
          }
          request = null;
          reviewed = null;
          conflict = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> party(bool isPayer) async {
    final r = await chooseExpenseMaster(
      context,
      widget.masters,
      MasterKind.party,
      widget.guard,
    );
    if (r != null && mounted) {
      setState(() {
        if (isPayer) {
          payer = r;
        } else {
          payee = r;
        }
        selected.clear();
        reviewed = null;
      });
    }
  }

  List<Map<String, dynamic>> get targets => claims
      .where(
        (c) =>
            c['account_purpose'] ==
                (recovery
                    ? 'PARTY_COST_RECOVERY'
                    : 'EXPENSE_REIMBURSEMENT_PAYABLE') &&
            c['party_id'] == (recovery || offset ? payer?.id : payee?.id),
      )
      .toList();
  void review() {
    try {
      if (payer == null || payee == null || reason.text.trim().isEmpty) {
        throw const FormatException(
          'Choose actual payer/recipient and enter a reason.',
        );
      }
      final allocations = <Map<String, dynamic>>[];
      for (final c in targets) {
        final a = amounts[c['line_id']]!.text;
        if (a.isEmpty) continue;
        final row = <String, dynamic>{
          'target_line_id': c['line_id'],
          'target_version': c['version'],
          'amount': a,
        };
        if (!recovery || offset) {
          final source = sources.firstWhere(
            (x) => x['line_id'] == selected[c['line_id']],
          );
          row.addAll({
            'source_line_id': source['line_id'],
            'source_version': source['version'],
          });
        }
        allocations.add(row);
      }
      final total = AllocationTotals.sum(
        allocations.map((a) => a['amount'] as String).toList(),
      );
      if (total == BigInt.zero) {
        throw const FormatException(
          'Enter explicit allocations and select held sources.',
        );
      }
      setState(() {
        reviewed = {
          'payer_id': payer!.id,
          'payee_id': payee!.id,
          'office_id': widget.expense['office_id'],
          'effective_date': date.text,
          'amount': AllocationTotals.decimal(total),
          'reason': reason.text.trim(),
          'allocations': allocations,
        };
        error = null;
      });
    } catch (e) {
      setState(
        () => error = e is FormatException
            ? e.message
            : 'Choose an eligible held-funds source.',
      );
    }
  }

  Future<void> confirm() async {
    request ??= newRecordId();
    setState(() => busy = true);
    try {
      await widget.finance.post(
        offset
            ? 'EXPENSE_OFFSET'
            : recovery
            ? 'EXPENSE_RECOVERY'
            : 'REIMBURSEMENT',
        request!,
        reviewed!,
      );
      if (!mounted) return;
      final total = reviewed!['amount'];
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: BilingualText(
              moneyMessage(
                L10n.expenseSettlementConfirmedPKRNoAdditionalExpenseOrBrokerage,
                [total],
                {0},
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = expenseError(e);
          conflict = e is PostgrestException && e.code == 'PT409';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = busy || request != null;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
          title: const BilingualText(L10n.expenseClaimsAndSettlement),
          actions: [
            IconButton(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              tooltip: L10n.reloadClaimsAndReviewAccessibility,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BilingualText(
              moneyMessage(
                L10n.originalExpensePKRSettlementAddsNoCostOrBrokerage,
                [widget.expense['expense_date'], widget.expense['amount']],
                {1},
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) BilingualOwnedText(error!),
            SwitchListTile(
              value: recovery,
              onChanged: locked
                  ? null
                  : (v) => setState(() {
                      recovery = v;
                      offset = false;
                      reviewed = null;
                      selected.clear();
                    }),
              title: const BilingualText(
                L10n.receivePaymentFromADifferentCostBearer,
              ),
            ),
            if (widget.expense['trip_id'] != null)
              SwitchListTile(
                value: offset,
                onChanged: locked
                    ? null
                    : (v) => setState(() {
                        offset = v;
                        recovery = v;
                        selected.clear();
                        reviewed = null;
                      }),
                title: const BilingualText(
                  L10n.nonCashOwnerOffsetAgainstThisOriginalExpense,
                ),
              ),
            OutlinedButton(
              onPressed: locked ? null : () => party(true),
              child: BilingualCaption(
                (payer == null
                    ? L10n.actualPayer
                    : L10n.payer.withValues([payer!.label])),
              ),
            ),
            OutlinedButton(
              onPressed: locked ? null : () => party(false),
              child: BilingualCaption(
                (payee == null
                    ? L10n.actualRecipient
                    : L10n.recipient.withValues([payee!.label])),
              ),
            ),
            TextField(
              controller: date,
              onChanged: (_) => setState(() => reviewed = null),
              enabled: !locked,
              decoration: bilingualDecoration(
                context,
                InputDecoration(
                  label: BilingualCaption(L10n.paymentDateYYYYMMDD),
                ),
              ),
            ),
            TextField(
              controller: reason,
              onChanged: (_) => setState(() => reviewed = null),
              enabled: !locked,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.settlementReason)),
              ),
            ),
            for (final c in targets) ...[
              TextField(
                controller: amounts[c['line_id']],
                enabled: !locked,
                onChanged: (_) => setState(() => reviewed = null),
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualCaption(
                      moneyMessage(
                        L10n.cashAllocationClaimRemainingPKR,
                        [c['remaining']],
                        {0},
                      ),
                    ),
                  ),
                ),
              ),
              if (!recovery || offset)
                KarvaanChoiceField<String>(
                  initialValue: selected[c['line_id']],
                  decoration: bilingualDecoration(
                    context,
                    InputDecoration(
                      label: BilingualCaption(
                        (offset
                            ? L10n.ownerEntitlementSource
                            : L10n.heldFundsSource),
                      ),
                    ),
                  ),
                  items: sources
                      .where(
                        (s) =>
                            s['party_id'] == payer?.id &&
                            s['account_purpose'] ==
                                (offset
                                    ? 'OWNER_PAYABLE'
                                    : 'CUSTODY_RECEIVABLE'),
                      )
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['line_id'] as String,
                          child: BilingualText(
                            moneyMessage(
                              L10n.remainingPKR,
                              [s['remaining']],
                              {0},
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: locked
                      ? null
                      : (v) => setState(() {
                          selected[c['line_id'] as String] = v!;
                          reviewed = null;
                        }),
                ),
            ],
            if (conflict)
              TextButton(
                onPressed: busy ? null : load,
                child: const BilingualCaption(L10n.reloadClaimsAndReview),
              ),
            if (reviewed == null)
              FilledButton(
                onPressed: locked ? null : review,
                child: const BilingualCaption(L10n.reviewExpenseSettlement),
              )
            else ...[
              BilingualText(
                moneyMessage(
                  L10n.cashPKRNonCashOffsetPKROriginalExpenseIs,
                  [
                    offset ? '0.00' : reviewed!['amount'],
                    offset ? reviewed!['amount'] : '0.00',
                  ],
                  {0, 1},
                ),
              ),
              FilledButton(
                onPressed: busy || conflict ? null : confirm,
                child: BilingualCaption(
                  (request == null
                      ? L10n.confirmExpenseSettlement
                      : L10n.retrySameSettlementRequest),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
