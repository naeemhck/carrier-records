import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';

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
    animationStyle: AnimationStyle.noAnimation,
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
            child: ListView(
              children: [
                for (final row in rows)
                  BilingualListTile(
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
          FilledButton(
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
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.add),
                SizedBox(width: 16),
                Expanded(child: BilingualText(L10n.newExpense)),
              ],
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
            const BilingualText(L10n.noRecordsFound),
          for (final row in rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BilingualText(
                      L10n.labelValuesfb62fe.withValues([
                        row['expense_date'],
                        row['trip_id'] == null
                            ? L10n.standaloneMaintenance
                            : L10n.tripCost,
                      ]),
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
    enabled: !locked,
    onChanged: (_) => setState(() => reviewed = null),
    decoration: bilingualDecoration(
      context,
      InputDecoration(label: BilingualOwnedCaption(label)),
    ),
  );
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
              L10n.expenseConfirmedPKRReceiptStatusIsSeparate.withValues([
                posted!['amount'],
              ]),
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
                      '${c['account_purpose'] == 'OWNER_PAYABLE' ? 'Owner offset' : 'Held cash source'} | remaining PKR ${c['remaining']}',
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
                L10n.expensePKR.withValues([
                  reviewed!['amount'],
                  funding.label,
                ]),
              ),
              BilingualText(
                L10n.cashSpentPKROwnerOffsetPKR.withValues([
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
                ]),
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
            child: ListView(
              children: [
                for (final t in rows)
                  BilingualListTile(
                    title: Text((t['trip_number']).toString()),
                    subtitle: BilingualOwnedText(t['state']),
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
              L10n.expenseSettlementConfirmedPKRNoAdditionalExpenseOrBrokerage
                  .withValues([total]),
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
              L10n.originalExpensePKRSettlementAddsNoCostOrBrokerage.withValues(
                [widget.expense['expense_date'], widget.expense['amount']],
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
                      L10n.cashAllocationClaimRemainingPKR.withValues([
                        c['remaining'],
                      ]),
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
                            L10n.remainingPKR.withValues([s['remaining']]),
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
                L10n.cashPKRNonCashOffsetPKROriginalExpenseIs.withValues([
                  offset ? '0.00' : reviewed!['amount'],
                  offset ? reviewed!['amount'] : '0.00',
                ]),
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
