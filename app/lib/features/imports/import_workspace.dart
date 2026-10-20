import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';
import '../../app/karvaan_typography.dart';

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
      animationStyle: AnimationStyle.noAnimation,
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

  /// Enablement mirrors the original gating exactly; the helpers only let
  /// the UI name the pending requirement for each disabled action.
  bool get _templateEnabled => !busy && fields.isNotEmpty;
  bool get _chooseEnabled => !busy && office != null;
  bool get _validateEnabled =>
      !busy && command != null && localErrors.isEmpty && result == null;

  Bilingual _validateDisabledReason() {
    if (localErrors.isNotEmpty) return L10n.importErrorsRequired;
    if (result != null) return L10n.importAlreadyCommitted;
    return L10n.importFileRequired;
  }

  /// A disabled button must explain why: the stacked caption under the
  /// actions names the pending requirement, and the tooltip repeats it in
  /// both languages for hover and focus users.
  Widget _explained({
    required bool enabled,
    required Bilingual whenEnabled,
    required Bilingual whenDisabled,
    required Widget child,
  }) => Tooltip(
    message: (enabled ? whenEnabled : whenDisabled).inline,
    child: child,
  );

  /// Confirm stays disabled until validation passes; the tooltip names the
  /// blocker (row errors or unacknowledged overlap warnings) in both
  /// languages instead of leaving a dead button.
  Widget _confirmButton() {
    final blocked =
        busy ||
        (preview!['errors'] as List).isNotEmpty ||
        ((preview!['warnings'] as List).isNotEmpty && !overlaps);
    return Tooltip(
      message:
          (blocked ? L10n.confirmImportBlocked : L10n.confirmReviewedImport)
              .inline,
      child: FilledButton(
        onPressed: blocked ? null : confirm,
        child: const BilingualCaption(L10n.confirmReviewedImport),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Density pass: on desktop the setup column sits beside the review
    // results, so the review queue is reachable without page-scrolling;
    // each column scrolls internally. On phones everything stacks in
    // one scrolling list, as before.
    final setup = <Widget>[
      const BilingualText(L10n.templateV1NewRecordsOnly),
      // The four steps, one line each (plan §5.9); the detailed rules
      // stay in the collapsible panel below.
      const _ImportStep(1, L10n.downloadTemplate),
      const _ImportStep(2, L10n.fillTemplateStep),
      const _ImportStep(3, L10n.chooseXLSX),
      const _ImportStep(4, L10n.validateAndPreview),
      ExpansionTile(
        expansionAnimationStyle: AnimationStyle.noAnimation,
        title: const BilingualText(L10n.howToFillTemplate),
        children: const [
          _TemplateRule(L10n.templateRuleDates),
          _TemplateRule(L10n.templateRuleAmounts),
          _TemplateRule(L10n.templateRuleCodes),
          _TemplateRule(L10n.templateRuleMasters),
          _TemplateRule(L10n.templateRuleDrafts),
        ],
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null) BilingualOwnedText(error!),
      KarvaanSection(
        title: L10n.excelImports,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KarvaanChoiceField<String>(
              initialValue: office,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.recordingOffice)),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _explained(
                  enabled: _templateEnabled,
                  whenEnabled: L10n.downloadTemplate,
                  whenDisabled: L10n.importSetupNotLoadedYet,
                  child: TextButton(
                    onPressed: _templateEnabled ? template : null,
                    child: const BilingualCaption(L10n.downloadTemplate),
                  ),
                ),
                _explained(
                  enabled: _chooseEnabled,
                  whenEnabled: L10n.chooseXLSX,
                  whenDisabled: L10n.importOfficeRequired,
                  child: TextButton(
                    onPressed: _chooseEnabled ? choose : null,
                    child: const BilingualCaption(L10n.chooseXLSX),
                  ),
                ),
                _explained(
                  enabled: _validateEnabled,
                  whenEnabled: L10n.validateAndPreview,
                  whenDisabled: _validateDisabledReason(),
                  child: TextButton(
                    onPressed: _validateEnabled ? validate : null,
                    child: const BilingualCaption(L10n.validateAndPreview),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      if (!busy && office == null)
        const BilingualText(L10n.importOfficeRequired)
      else if (!busy && command == null)
        const BilingualText(L10n.importFileRequired)
      else if (!busy && localErrors.isNotEmpty)
        const BilingualText(L10n.importErrorsRequired)
      else if (!busy && result != null)
        const BilingualText(L10n.importAlreadyCommitted),
      for (final e in localErrors)
        BilingualText(L10n.row.withValues([e['kind'], e['row'], e['code']])),
      if (command != null)
        BilingualText(
          L10n.readRows.withValues([(command!['rows'] as List).length]),
        ),
    ];
    final results = <Widget>[
      if (preview != null) ...[
        // Review queue heading: the count rides as a chip, not buried in
        // a sentence (plan §5.9).
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: BilingualText(
                  L10n.reviewQueue,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: KarvaanDesign.muted,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    displayCount((preview!['rows'] as List).length),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final e in preview!['errors'] as List)
          Text('${e['kind']} ${e['row_key']}: ${e['code']}'),
        for (final r in preview!['rows'] as List)
          ExpansionTile(
            expansionAnimationStyle: AnimationStyle.noAnimation,
            title: BilingualText(
              L10n.labelValues10866a.withValues([r['kind'], r['row_key']]),
            ),
            children: [
              // Readable field lines — never a raw JSON dump (plan §1).
              for (final entry in (r['values'] as Map).entries)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Text(
                    '${_importFieldLabel(entry.key)}: ${_importFieldValue(entry.value)}',
                    textDirection: TextDirection.ltr,
                  ),
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
        if (result == null) _confirmButton(),
      ],
      if (result != null)
        const BilingualText(
          L10n.importCommittedUseTripsToReviewDispatchTripDrafts,
        ),
      ExpansionTile(
        expansionAnimationStyle: AnimationStyle.noAnimation,
        title: const BilingualText(L10n.expenseCategoryCodes),
        children: [
          if (categories.isEmpty)
            const BilingualText(L10n.noExpenseCategoryCodesReturned)
          else
            for (final c in categories)
              SelectableText('${c['code']}: ${c['name']}'),
        ],
      ),
      KarvaanSection(
        title: L10n.labelValues10866a.withValues([
          L10n.importedExpenseDraftsAwaitingNormalReview,
          Bilingual.data(displayCount(drafts.length)),
        ]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (drafts.isEmpty && !busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BilingualText(
                      L10n.noExpenseDraftsAwaitingReview,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _explained(
                      enabled: _chooseEnabled,
                      whenEnabled: L10n.chooseXLSX,
                      whenDisabled: L10n.importOfficeRequired,
                      child: FilledButton(
                        onPressed: _chooseEnabled ? choose : null,
                        child: const BilingualCaption(L10n.chooseXLSX),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final d in drafts)
                BilingualListTile(
                  title: Text(
                    displayMoney(d['payload']['amount']),
                    style: KarvaanTypography.textTheme.headlineSmall,
                    textDirection: TextDirection.ltr,
                  ),
                  subtitle: Text(
                    '${d['payload']['effective_date']} | ${d['payload']['reason']}',
                    style: KarvaanTypography.textTheme.bodySmall?.copyWith(
                      color: KarvaanDesign.secondary,
                    ),
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
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
        title: const BilingualText(L10n.excelImports),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [...setup, ...results],
            );
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 400, child: ListView(children: setup)),
                const SizedBox(width: 16),
                Expanded(child: ListView(children: results)),
              ],
            ),
          );
        },
      ),
    );
  }
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

/// Human field label for the import review queue: snake_case internals
/// become plain words instead of raw field names.
String _importFieldLabel(Object? key) => (key ?? '')
    .toString()
    .split('_')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// Human field value for the review queue: timestamps use the one short
/// date-time format (rule 3); everything else is the recorded value itself.
String _importFieldValue(Object? value) {
  if (value == null) return '—';
  final text = value.toString();
  return RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T').hasMatch(text)
      ? displayTimestamp(text)
      : text;
}

/// One numbered step of the import checklist (plan §5.9).
class _ImportStep extends StatelessWidget {
  const _ImportStep(this.number, this.label);
  final int number;
  final Bilingual label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: KarvaanDesign.primary,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              '$number',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: BilingualText(label)),
      ],
    ),
  );
}

/// One numbered checklist row inside the "How to fill the template" guide.
class _TemplateRule extends StatelessWidget {
  const _TemplateRule(this.message);
  final Bilingual message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• '),
        Expanded(child: BilingualText(message)),
      ],
    ),
  );
}
