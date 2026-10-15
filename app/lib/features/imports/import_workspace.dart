import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../expenses/expense_repository.dart';
import '../expenses/expense_workspace.dart';
import '../finance/financial_repository.dart';
import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import 'import_workbook.dart';

abstract interface class ImportFiles {
  Future<Uint8List?> pick();
  Future<bool> save(Uint8List bytes);
}

class NativeImportFiles implements ImportFiles {
  @override
  Future<Uint8List?> pick() async {
    final f = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel import', extensions: ['xlsx']),
      ],
    );
    if (f == null) {
      return null;
    }
    if (await f.length() > 5242880) {
      throw const FormatException('XLSX must be at most 5 MB.');
    }
    return f.readAsBytes();
  }

  @override
  Future<bool> save(Uint8List bytes) async {
    final target = await getSaveLocation(
      suggestedName: 'carrier-records-import-v1.xlsx',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel template', extensions: ['xlsx']),
      ],
    );
    if (target == null) {
      return false;
    }
    await XFile.fromData(
      bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ).saveTo(target.path);
    return true;
  }
}

class ImportWorkspace extends StatefulWidget {
  const ImportWorkspace({
    super.key,
    required this.client,
    required this.offices,
    required this.guard,
    this.files,
  });
  final SupabaseClient client;
  final List<Map<String, dynamic>> offices;
  final Widget Function(Widget) guard;
  final ImportFiles? files;
  @override
  State<ImportWorkspace> createState() => _ImportWorkspaceState();
}

class _ImportWorkspaceState extends State<ImportWorkspace> {
  Map<String, List<String>> fields = {};
  List<Map<String, dynamic>> drafts = [], importOffices = [];
  List<dynamic> categories = [];
  Map<String, dynamic>? command, preview, result;
  List<Map<String, dynamic>> localErrors = [];
  String? error, office;
  bool busy = false, overlaps = false;
  int draftOffset = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final c = await widget.client.rpc('get_import_templates') as Map;
      if (c['template_version'] != 1) {
        throw const FormatException(
          'Update the app for this template version.',
        );
      }
      importOffices = (c['offices'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      office ??= importOffices.firstOrNull?['code'] as String?;
      categories = c['category_codes'] as List;
      fields = {
        for (final e in (c['fields'] as Map).entries)
          '${e.key}': (e.value as List).cast<String>(),
      };
      final r = await widget.client.rpc(
        'list_import_expense_drafts',
        params: {'page_offset': draftOffset},
      ) as List;
      if (mounted) {
        setState(
          () => drafts = r
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Could not load import setup. ${e is PostgrestException ? e.message : e}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> template() async {
    setState(() => busy = true);
    try {
      final saved = await (widget.files ?? NativeImportFiles()).save(
        await compute(importTemplate, fields),
      );
      if (mounted) {
        setState(
          () => error = saved
              ? 'Template saved. Keep amounts and dates as text.'
              : 'Save cancelled.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Template could not be saved.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> choose() async {
    setState(() => busy = true);
    try {
      final bytes = await (widget.files ?? NativeImportFiles()).pick();
      if (bytes == null) {
        return;
      }
      final parsed = await compute(
        (args) => ImportWorkbook.parse(args.$1, args.$2),
        (bytes, fields),
      );
      if (mounted) {
        setState(() {
          localErrors = parsed.errors;
          preview = null;
          result = null;
          overlaps = false;
          command = {
            'batch_id': newRecordId(),
            'template_version': 1,
            'office_code': office,
            'rows': parsed.rows,
          };
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Workbook could not be read.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> validate() async {
    setState(() => busy = true);
    try {
      final r = await widget.client.rpc(
        'validate_import',
        params: {'command': command},
      ) as Map;
      if (mounted) {
        setState(() {
          preview = Map<String, dynamic>.from(r);
          overlaps = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Validation failed. ${e is PostgrestException ? e.message : 'Try again online.'}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: const BilingualText(L10n.confirmReviewedImport),
        content: BilingualText(
          L10n.createNewRowsTogetherTripsAndExpensesRemainDrafts.withValues([
            command!['rows'].length,
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const BilingualCaption(L10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const BilingualCaption(L10n.confirmImport),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      final r = await widget.client.rpc(
        'commit_import',
        params: {
          'command': command,
          'review_token': preview!['review_token'],
          'confirm_overlap': overlaps,
        },
      ) as Map;
      if (mounted) {
        setState(() => result = Map<String, dynamic>.from(r));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PostgrestException && e.code == 'PT409'
              ? 'Import not committed. Records or access changed; validate and review again. A network retry uses this same batch.'
              : 'Import not confirmed. Retry this batch online; do not start a duplicate import.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> expense(Map<String, dynamic> d) async {
    final base = ExpenseRepository(widget.client);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => widget.guard(
          ExpenseEntry(
            expenses: _DraftExpenseCommands(widget.client, base, d),
            finance: FinancialRepository(widget.client),
            trips: SupabaseTripRepository(widget.client),
            masters: SupabaseMasterRepository(widget.client),
            offices: widget.offices,
            guard: widget.guard,
            initialDraft: d,
          ),
        ),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.excelImports),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const BilingualText(L10n.templateVersionNewRecordsOnlyEnterDatesAsYYYY),
        if (busy) const LinearProgressIndicator(),
        if (error != null) BilingualOwnedText(error!),
        KarvaanSection(
          title: L10n.excelImports,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                isDense: false,
                isExpanded: true,
                itemHeight: null,
                initialValue: office,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualCaption(L10n.recordingOffice),
                  ),
                ),
                items: [
                  for (final o in importOffices)
                    DropdownMenuItem(
                      value: o['code'] as String,
                      child: Text('${o['name']} (${o['code']})'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        office = v;
                        command = null;
                        preview = null;
                        result = null;
                      }),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy || fields.isEmpty ? null : template,
                    child: const BilingualCaption(L10n.downloadTemplate),
                  ),
                  TextButton(
                    onPressed: busy || office == null ? null : choose,
                    child: const BilingualCaption(L10n.chooseXLSX),
                  ),
                  TextButton(
                    onPressed:
                        busy ||
                            command == null ||
                            localErrors.isNotEmpty ||
                            result != null
                        ? null
                        : validate,
                    child: const BilingualCaption(L10n.validateAndPreview),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final e in localErrors)
          BilingualText(L10n.row.withValues([e['kind'], e['row'], e['code']])),
        if (command != null)
          BilingualText(
            L10n.readRows.withValues([(command!['rows'] as List).length]),
          ),
        if (preview != null) ...[
          for (final e in preview!['errors'] as List)
            Text('${e['kind']} ${e['row_key']}: ${e['code']}'),
          for (final r in preview!['rows'] as List)
            ExpansionTile(
              title: BilingualText(
                L10n.labelValues10866a.withValues([r['kind'], r['row_key']]),
              ),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(r['values']),
                ),
              ],
            ),
          if ((preview!['warnings'] as List).isNotEmpty)
            CheckboxListTile(
              value: overlaps,
              onChanged: busy ? null : (v) => setState(() => overlaps = v!),
              title: const BilingualText(
                L10n.iReviewedTheActiveVehicleOverlapWarningsAndThe,
              ),
            ),
          if (result == null)
            FilledButton(
              onPressed:
                  busy ||
                      (preview!['errors'] as List).isNotEmpty ||
                      ((preview!['warnings'] as List).isNotEmpty && !overlaps)
                  ? null
                  : confirm,
              child: const BilingualCaption(L10n.confirmReviewedImport),
            ),
        ],
        if (result != null)
          const BilingualText(
            L10n.importCommittedUseTripsToReviewDispatchTripDrafts,
          ),
        ExpansionTile(
          title: const BilingualText(L10n.expenseCategoryCodes),
          children: [
            for (final c in categories)
              SelectableText('${c['code']}: ${c['name']}'),
          ],
        ),
        const Divider(),
        const BilingualText(L10n.importedExpenseDraftsAwaitingNormalReview),
        for (final d in drafts)
          BilingualListTile(
            title: Text(
              '${d['payload']['effective_date']} | PKR ${d['payload']['amount']} | ${d['payload']['reason']}',
            ),
            trailing: TextButton(
              onPressed: busy ? null : () => expense(d),
              child: const BilingualCaption(L10n.reviewExpenseDraft),
            ),
          ),
        Row(
          children: [
            TextButton(
              onPressed: busy || draftOffset == 0
                  ? null
                  : () {
                      draftOffset -= 50;
                      load();
                    },
              child: const BilingualCaption(L10n.previous),
            ),
            TextButton(
              onPressed: busy || drafts.length < 50
                  ? null
                  : () {
                      draftOffset += 50;
                      load();
                    },
              child: const BilingualCaption(L10n.next),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DraftExpenseCommands implements ExpenseCommands {
  _DraftExpenseCommands(this.client, this.base, this.draft);
  final SupabaseClient client;
  final ExpenseCommands base;
  final Map<String, dynamic> draft;
  @override
  Future<Map<String, dynamic>> post(
    String request,
    Map<String, dynamic> payload,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'confirm_import_expense',
      params: {
        'target_id': draft['id'],
        'expected_version': draft['version'],
        'request_id': request,
        'payload': payload,
      },
    ) as Map,
  );
  @override
  Future<List<Map<String, dynamic>>> list({int offset = 0}) =>
      base.list(offset: offset);
  @override
  Future<List<Map<String, dynamic>>> claims(String expense) =>
      base.claims(expense);
  @override
  Future<Map<String, dynamic>> attach(
    String expense,
    String request,
    ReceiptSelection receipt,
  ) => base.attach(expense, request, receipt);
  @override
  Future<Uint8List?> download(String expense) => base.download(expense);
  @override
  Future<int> cleanup() => base.cleanup();
}
