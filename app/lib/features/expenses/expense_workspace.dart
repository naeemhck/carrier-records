import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/record_context.dart';
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
    context: context,
    builder: (_) => guard(_MasterPicker(repo: repo, kind: kind)),
  );
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
      if (mounted) setState(() => rows = r.where((x) => !x.archived).toList());
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.kind.label),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Search records'),
            onSubmitted: (_) {
              offset = 0;
              load();
            },
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          Expanded(
            child: ListView(
              children: [
                for (final row in rows)
                  ListTile(
                    title: Text(row.label),
                    onTap: () => Navigator.pop(context, row),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: busy || offset == 0
                    ? null
                    : () {
                        offset -= 50;
                        load();
                      },
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: busy || rows.length < 50
                    ? null
                    : () {
                        offset += 50;
                        load();
                      },
                child: const Text('Next'),
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
              content: Text('Receipt attached. Expense posting is unchanged.'),
            ),
          );
        }
      } else {
        await showDialog<void>(
          context: context,
          builder: (_) => widget.guard(
            AlertDialog(
              title: const Text('Private receipt'),
              content: SizedBox(
                width: 500,
                child: bytes.length > 4 && bytes[0] == 37
                    ? Text(
                        'PDF receipt downloaded securely (${bytes.length} bytes).',
                      )
                    : Image.memory(bytes),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Expenses and reimbursements'),
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
        const Text(
          'Permitted office and trip expenses. Maintenance remains unlinked unless explicitly assigned to a trip.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => open(
                  ExpenseEntry(
                    expenses: widget.expenses,
                    finance: widget.finance,
                    trips: widget.trips,
                    masters: widget.masters,
                    offices: widget.offices,
                    guard: widget.guard,
                    picker: widget.picker,
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('New expense'),
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
            child: const Text('Corrections and history'),
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
            child: const Text('Clean abandoned receipt uploads'),
          ),
        for (final row in rows)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row['expense_date']} | PKR ${row['amount']} | ${row['trip_id'] == null ? 'Standalone maintenance' : 'Trip cost'}',
                  ),
                  Text('${row['notes']}'),
                  Text('${row['funding_source']}'),
                  if (row['effective'] == false)
                    const Text(
                      'Historical expense - voided or replaced; excluded from current costs.',
                    ),
                  if (row['replaces_expense_id'] != null)
                    Text(
                      'Replaces original expense ${row['replaces_expense_id']}. ${row['correction_reason']}',
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
                        child: const Text('Claims / reimburse / recover'),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => receipt(row),
                        child: const Text('Private receipt'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            TextButton(
              onPressed: busy || offset == 0
                  ? null
                  : () {
                      offset -= 50;
                      load();
                    },
              child: const Text('Previous'),
            ),
            TextButton(
              onPressed: busy || rows.length < 50
                  ? null
                  : () {
                      offset += 50;
                      load();
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ],
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
  });
  final ExpenseCommands expenses;
  final FinancialCommands finance;
  final TripRepository trips;
  final MasterRepository masters;
  final List<Map<String, dynamic>> offices;
  final ExpenseGuard guard;
  final ReceiptPicker? picker;
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
    enabled: !locked,
    onChanged: (_) => setState(() => reviewed = null),
    decoration: InputDecoration(labelText: label),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Record expense')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (posted != null) ...[
            Text(
              'Expense confirmed: PKR ${posted!['amount']}. Receipt status is separate.',
            ),
            Text(receiptStatus),
            if (evidence != null && receiptStatus != 'Receipt attached.')
              FilledButton(
                onPressed: busy ? null : upload,
                child: const Text('Retry receipt only'),
              ),
          ] else ...[
            OutlinedButton(
              onPressed: locked
                  ? null
                  : () => choose(MasterKind.vehicle, 'vehicle'),
              child: Text(vehicle?.label ?? 'Choose vehicle'),
            ),
            OutlinedButton(
              onPressed: locked || vehicle == null ? null : chooseTrip,
              child: Text(
                trip == null ? 'Optional trip' : 'Trip ${trip!['trip_number']}',
              ),
            ),
            if (trip != null)
              TextButton(
                onPressed: locked
                    ? null
                    : () => setState(() {
                        trip = null;
                        reviewed = null;
                        owner = vehicle!.data['current_owner_id'] as String?;
                        clearClaims();
                      }),
                child: const Text('Keep as standalone maintenance'),
              ),
            DropdownButtonFormField<String>(
              initialValue: office,
              decoration: const InputDecoration(labelText: 'Expense office'),
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
            OutlinedButton(
              onPressed: locked
                  ? null
                  : () => choose(MasterKind.category, 'category'),
              child: Text(category?.label ?? 'Choose category'),
            ),
            OutlinedButton(
              onPressed: locked
                  ? null
                  : () => choose(MasterKind.party, 'payer'),
              child: Text(
                payer == null ? 'Choose payer' : 'Payer: ${payer!.label}',
              ),
            ),
            OutlinedButton(
              onPressed: locked
                  ? null
                  : () => choose(MasterKind.party, 'bearer'),
              child: Text(
                bearer == null
                    ? 'Choose cost bearer'
                    : 'Cost bearer: ${bearer!.label}',
              ),
            ),
            Text(
              trip != null
                  ? 'Historical owner: ${(trip!['owner_snapshot'] as Map)['display_name']}'
                  : 'Confirm the vehicle owner as cost bearer when applicable.',
            ),
            field(date, 'Expense date (YYYY-MM-DD)'),
            field(amount, 'Expense amount (PKR)'),
            field(notes, 'Notes / reason'),
            DropdownButtonFormField<ExpenseFunding>(
              initialValue: funding,
              decoration: const InputDecoration(labelText: 'Funding source'),
              items: ExpenseFunding.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
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
              const Text(
                'Owner has already paid this personally. Owner settlement is unchanged.',
              ),
            CheckboxListTile(
              value: agreed,
              onChanged: locked
                  ? null
                  : (v) => setState(() {
                      agreed = v!;
                      reviewed = null;
                    }),
              title: const Text(
                'Confirm agreed owner settlement offset (when applicable)',
              ),
            ),
            const Text(
              'Allocate cash spent from custody and non-cash owner offsets separately. Remaining claims are server-calculated.',
            ),
            for (final c in eligible)
              field(
                inputs[c['line_id']]!,
                '${c['account_purpose'] == 'OWNER_PAYABLE' ? 'Owner offset' : 'Held cash source'} | remaining PKR ${c['remaining']}',
              ),
            OutlinedButton(
              onPressed: locked ? null : pick,
              child: const Text(
                'Optional private receipt (PNG / JPEG / PDF, 5 MB)',
              ),
            ),
            Text(receiptStatus),
            if (conflict)
              TextButton(
                onPressed: busy ? null : reload,
                child: const Text('Reload claims and review'),
              ),
            if (reviewed == null)
              FilledButton(
                onPressed: locked ? null : review,
                child: const Text('Review expense'),
              )
            else ...[
              Text('Expense PKR ${reviewed!['amount']} | ${funding.label}'),
              Text(
                'Cash spent: PKR ${AllocationTotals.decimal(AllocationTotals.sum((reviewed!['allocations'] as List).where((x) => x['component'] == 'CASH').map((x) => x['amount'] as String).toList()))} | Owner offset: PKR ${AllocationTotals.decimal(AllocationTotals.sum((reviewed!['allocations'] as List).where((x) => x['component'] == 'OFFSET').map((x) => x['amount'] as String).toList()))}',
              ),
              FilledButton(
                onPressed: busy || conflict ? null : confirm,
                child: Text(
                  request == null
                      ? 'Confirm expense'
                      : 'Retry same expense request',
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
      if (mounted) setState(() => rows = p.rows);
    } catch (e) {
      if (mounted) setState(() => error = expenseError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose permitted trip'),
    content: SizedBox(
      width: 500,
      height: 400,
      child: Column(
        children: [
          TextField(
            controller: search,
            decoration: const InputDecoration(labelText: 'Search trips'),
            onSubmitted: (_) {
              offset = 0;
              load();
            },
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          Expanded(
            child: ListView(
              children: [
                for (final t in rows)
                  ListTile(
                    title: Text('${t['trip_number']}'),
                    subtitle: Text('${t['state']}'),
                    onTap: () => Navigator.pop(context, t),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: busy || offset == 0
                    ? null
                    : () {
                        offset -= 50;
                        load();
                      },
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: busy || rows.length < 50
                    ? null
                    : () {
                        offset += 50;
                        load();
                      },
                child: const Text('Next'),
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
            content: Text(
              'Expense settlement confirmed: PKR $total. No additional expense or brokerage.',
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
          title: const Text('Expense claims and settlement'),
          actions: [
            IconButton(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload claims and review',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Original expense ${widget.expense['expense_date']} | PKR ${widget.expense['amount']}. Settlement adds no cost or brokerage.',
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
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
              title: const Text('Receive payment from a different cost bearer'),
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
                title: const Text(
                  'Non-cash owner offset against this original expense',
                ),
              ),
            OutlinedButton(
              onPressed: locked ? null : () => party(true),
              child: Text(
                payer == null ? 'Actual payer' : 'Payer: ${payer!.label}',
              ),
            ),
            OutlinedButton(
              onPressed: locked ? null : () => party(false),
              child: Text(
                payee == null
                    ? 'Actual recipient'
                    : 'Recipient: ${payee!.label}',
              ),
            ),
            TextField(
              controller: date,
              onChanged: (_) => setState(() => reviewed = null),
              enabled: !locked,
              decoration: const InputDecoration(
                labelText: 'Payment date (YYYY-MM-DD)',
              ),
            ),
            TextField(
              controller: reason,
              onChanged: (_) => setState(() => reviewed = null),
              enabled: !locked,
              decoration: const InputDecoration(labelText: 'Settlement reason'),
            ),
            for (final c in targets) ...[
              TextField(
                controller: amounts[c['line_id']],
                enabled: !locked,
                onChanged: (_) => setState(() => reviewed = null),
                decoration: InputDecoration(
                  labelText:
                      'Cash allocation ? claim remaining PKR ${c['remaining']}',
                ),
              ),
              if (!recovery || offset)
                DropdownButtonFormField<String>(
                  initialValue: selected[c['line_id']],
                  decoration: InputDecoration(
                    labelText: offset
                        ? 'Owner entitlement source'
                        : 'Held-funds source',
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
                          child: Text('Remaining PKR ${s['remaining']}'),
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
                child: const Text('Reload claims and review'),
              ),
            if (reviewed == null)
              FilledButton(
                onPressed: locked ? null : review,
                child: const Text('Review expense settlement'),
              )
            else ...[
              Text(
                'Cash: PKR ${offset ? '0.00' : reviewed!['amount']} | Non-cash offset: PKR ${offset ? reviewed!['amount'] : '0.00'}. Original expense is not reposted.',
              ),
              FilledButton(
                onPressed: busy || conflict ? null : confirm,
                child: Text(
                  request == null
                      ? 'Confirm expense settlement'
                      : 'Retry same settlement request',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
