import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import '../trips/trip_workspace.dart';
import 'output_repository.dart';
import 'document_repository.dart';
import 'document_workspace.dart';
import 'output_export_service.dart';
import 'output_file_actions.dart';

const outputReports = {
  'MONTHLY_VEHICLE': 'Vehicle monthly',
  'OWNER_STATEMENT': 'Owner statement',
  'BROKER_MONTHLY': 'Broker monthly',
  'CUSTOMER_STATEMENT': 'Customer statement',
  'TRIP_PROFIT': 'Lifetime trip profit',
  'CUSTOMER_INVOICE': 'Customer invoice preview',
  'PAYMENT_RECEIPT': 'Payment receipt preview',
};
String outputError(Object error) => error is FormatException
    ? error.message
    : error is PostgrestException && error.code == 'PT409'
    ? 'Preset changed. Reload presets and review before saving again.'
    : error is PostgrestException && error.message == 'COMPANY_SETUP_REQUIRED'
    ? 'Administrator company setup is required for document previews.'
    : 'Unable to prepare output or manage preset. Check the required filters and current permission, then retry.';

class OutputWorkspace extends StatefulWidget {
  const OutputWorkspace({
    super.key,
    required this.commands,
    required this.masters,
    required this.trips,
    required this.offices,
    required this.administrator,
    this.guard = unguardedTrip,
    this.documents,
    this.exporter,
    this.initialCommand,
    this.supersedesId,
  });
  final OutputCommands commands;
  final MasterRepository masters;
  final TripRepository trips;
  final List<Map<String, dynamic>> offices;
  final bool administrator;
  final Widget Function(Widget) guard;
  final DocumentCommands? documents;
  final OutputExportService? exporter;
  final Map<String, dynamic>? initialCommand;
  final String? supersedesId;
  @override
  State<OutputWorkspace> createState() => _OutputWorkspaceState();
}

class _OutputWorkspaceState extends State<OutputWorkspace> {
  String report = 'MONTHLY_VEHICLE',
      recipient = 'INTERNAL',
      orientation = 'AUTO';
  String? party,
      partyName,
      office,
      vehicle,
      vehicleName,
      owner,
      ownerName,
      trip,
      tripName,
      event,
      eventName,
      presetId;
  late final from = TextEditingController(
    text:
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-01',
  );
  late final to = TextEditingController(
    text: DateTime(
      DateTime.now().year,
      DateTime.now().month + 1,
      0,
    ).toIso8601String().substring(0, 10),
  );
  final search = TextEditingController(),
      sheet = TextEditingController(text: 'Records');
  OutputSelection? selection;
  List<Map<String, dynamic>> presets = [];
  Map<String, dynamic>? preview;
  String? error;
  bool busy = false;
  int offset = 0;
  Map<String, dynamic> get filters => {
    'from': from.text.trim(),
    'to': to.text.trim(),
    'office_id': office,
    'vehicle_id': vehicle,
    'owner_id': owner,
    'trip_id': trip,
    'search': search.text.trim(),
  };
  @override
  void initState() {
    super.initState();
    final initial = widget.initialCommand;
    if (initial != null) {
      report = initial['report_kind'] as String;
      recipient = initial['recipient_kind'] as String;
      party = initial['recipient_id'] as String?;
      final f = initial['filters'] as Map;
      from.text = f['from'] as String;
      to.text = f['to'] as String;
      office = f['office_id'] as String?;
      vehicle = f['vehicle_id'] as String?;
      owner = f['owner_id'] as String?;
      trip = f['trip_id'] as String?;
      search.text = f['search'] as String? ?? '';
      event = initial['event_id'] as String?;
      partyName = 'Saved document recipient';
      tripName = trip == null ? null : 'Saved document trip';
      eventName = event == null ? null : 'Saved document payment';
    }
    load();
  }

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    search.dispose();
    sheet.dispose();
    super.dispose();
  }

  List<String> get recipients => switch (report) {
    'OWNER_STATEMENT' || 'MONTHLY_VEHICLE' => ['INTERNAL', 'OWNER'],
    'BROKER_MONTHLY' => ['INTERNAL', 'BROKER'],
    'CUSTOMER_STATEMENT' => ['INTERNAL', 'CUSTOMER'],
    'CUSTOMER_INVOICE' => ['CUSTOMER'],
    _ => ['INTERNAL', 'CUSTOMER', 'OWNER', 'BROKER'],
  };
  Future<void> load() async {
    setState(() {
      busy = true;
      selection = null;
      preview = null;
      error = null;
      presetId = null;
    });
    try {
      final c = await widget.commands.catalogue(report, recipient);
      final p = await widget.commands.presets(report, recipient);
      if (!mounted) return;
      setState(() {
        selection = OutputSelection(c);
        presets = p;
        orientation = 'AUTO';
        sheet.text = 'Records';
        if (widget.initialCommand?['field_order'] != null) {
          selection!.load(
            (widget.initialCommand!['field_order'] as List).cast<String>(),
          );
          orientation =
              widget.initialCommand!['format_options']['orientation'] ?? 'AUTO';
          sheet.text =
              widget.initialCommand!['format_options']['sheet_name'] ??
              'Records';
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = outputError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changed() {
    setState(() {
      preview = null;
      offset = 0;
    });
  }

  Future<void> pick(String kind) async {
    final rows = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => widget.guard(
        _OutputChoice(
          commands: widget.commands,
          masters: widget.masters,
          trips: widget.trips,
          kind: kind,
          recipient: recipient,
          party: party,
          filters: filters,
        ),
      ),
    );
    if (rows == null || !mounted) return;
    setState(() {
      switch (kind) {
        case 'RECIPIENT':
          party = rows['id'];
          partyName = rows['label'];
          event = eventName = null;
        case 'VEHICLE':
          vehicle = rows['id'];
          vehicleName = rows['label'];
        case 'OWNER':
          owner = rows['id'];
          ownerName = rows['label'];
        case 'TRIP':
          trip = rows['id'];
          tripName = rows['label'];
          event = eventName = null;
        case 'RECEIPT':
          event = rows['id'];
          eventName = rows['label'];
      }
      preview = null;
    });
  }

  Future<void> prepare({int start = 0}) async {
    setState(() {
      busy = true;
      preview = null;
      error = null;
      offset = start;
    });
    try {
      final data = await widget.commands.prepare({
        'report_kind': report,
        'recipient_kind': recipient,
        'recipient_id': party,
        'filters': filters,
        'field_order': List.of(selection!.order),
        'format_options': {
          'orientation': orientation,
          'sheet_name': sheet.text.trim(),
        },
        'preset_id': presetId,
        'event_id': event,
        'page_offset': offset,
      });
      if (mounted) setState(() => preview = data);
    } catch (e) {
      if (mounted) setState(() => error = outputError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> usePreset(String? id) async {
    if (id == null) {
      setState(() {
        presetId = null;
        selection!.reset();
        orientation = 'AUTO';
        sheet.text = 'Records';
        preview = null;
      });
      return;
    }
    final p = presets.firstWhere((p) => p['id'] == id);
    try {
      if (p['valid'] == false) {
        throw const FormatException(
          'Preset is incompatible with the current catalogue. Reset and review a new selection.',
        );
      }
      selection!.load((p['field_order'] as List).cast<String>());
      setState(() {
        presetId = id;
        orientation = p['format_options']['orientation'] ?? 'AUTO';
        sheet.text = p['format_options']['sheet_name'] ?? 'Records';
        preview = null;
        error = null;
      });
      // Backend checks this preset and current filters on every use; no cached preview.
      await prepare();
    } catch (e) {
      if (mounted) {
        setState(() {
          presetId = null;
          preview = null;
          error = outputError(e);
        });
      }
    }
  }

  Future<void> issueDocument() async {
    final committed = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => widget.guard(
        IssueDocumentDialog(
          commands: widget.documents!,
          superseding: widget.supersedesId != null,
          payload: {
            'report_kind': report,
            'recipient_kind': recipient,
            'recipient_id': party,
            'filters': filters,
            'field_order': List.of(selection!.order),
            'format_options': {
              'orientation': orientation,
              'sheet_name': sheet.text.trim(),
            },
            'preset_id': presetId,
            'event_id': event,
            'supersedes_id': widget.supersedesId,
          },
        ),
      ),
    );
    if (committed != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.guard(
            IssuedDocumentView(
              document: committed,
              actions: widget.exporter == null
                  ? null
                  : OutputFileActions(
                      service: widget.exporter!,
                      load: () =>
                          widget.exporter!.issued(committed['id'] as String),
                    ),
            ),
          ),
        ),
      );
      if (mounted) setState(() => preview = null);
    }
  }

  void supersede(Map<String, dynamic> contextCommand, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => widget.guard(
          OutputWorkspace(
            commands: widget.commands,
            masters: widget.masters,
            trips: widget.trips,
            offices: widget.offices,
            administrator: widget.administrator,
            guard: widget.guard,
            documents: widget.documents,
            exporter: widget.exporter,
            initialCommand: contextCommand,
            supersedesId: id,
          ),
        ),
      ),
    );
  }

  Widget previewPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.documents != null &&
          ['CUSTOMER_INVOICE', 'PAYMENT_RECEIPT'].contains(report) &&
          recipient != 'INTERNAL')
        FilledButton(
          onPressed: busy ? null : issueDocument,
          child: const BilingualCaption(L10n.issueDocument),
        ),
      if (widget.exporter != null)
        OutputFileActions(
          service: widget.exporter!,
          load: () => widget.exporter!.live({
            'report_kind': report,
            'recipient_kind': recipient,
            'recipient_id': party,
            'filters': filters,
            'field_order': List.of(selection!.order),
            'format_options': {
              'orientation': orientation,
              'sheet_name': sheet.text.trim(),
            },
            'preset_id': presetId,
            'event_id': event,
          }),
        ),
      OutputPreview(
        data: preview!,
        onPage: (start) => prepare(start: start),
        busy: busy,
      ),
    ],
  );

  Future<void> manage({
    Map<String, dynamic>? existing,
    bool deleting = false,
  }) async {
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => widget.guard(
        _PresetDialog(
          commands: widget.commands,
          report: report,
          recipient: recipient,
          fields: List.of(selection!.order),
          options: {
            'orientation': orientation,
            'sheet_name': sheet.text.trim(),
          },
          administrator: widget.administrator,
          existing: existing,
          deleting: deleting,
        ),
      ),
    );
    if (done == true && mounted) {
      try {
        final p = await widget.commands.presets(report, recipient);
        if (mounted) {
          setState(() {
            presets = p;
            presetId = null;
            preview = null;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => error = 'Preset command committed, but refreshing presets failed. Reload catalogue and presets.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = selection;
    final current = presets.where((p) => p['id'] == presetId).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final configuration = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualText(
            L10n.previewOnlyNotAnIssuedDocumentFiltersDetermineRecords,
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            BilingualOwnedText(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          KarvaanSection(
            title: L10n.reportOutputType,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isDense: false,
                    isExpanded: true,
                    initialValue: report,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.reportOutputType),
                      ),
                    ),
                    items: [
                      for (final e in outputReports.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: BilingualOwnedText(e.value),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() {
                              report = v!;
                              recipient = recipients.first;
                              party = partyName = event = eventName = null;
                            });
                            load();
                          },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isDense: false,
                    itemHeight: null,
                    key: ValueKey('recipient-$report'),
                    isExpanded: true,
                    initialValue: recipient,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.recipientTemplate),
                      ),
                    ),
                    items: [
                      for (final r in recipients)
                        DropdownMenuItem(
                          value: r,
                          child: BilingualOwnedText(r),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() {
                              recipient = v!;
                              party = partyName = event = eventName = null;
                            });
                            load();
                          },
                  ),
                ),
                if (recipient != 'INTERNAL')
                  OutlinedButton(
                    onPressed: busy ? null : () => pick('RECIPIENT'),
                    child: BilingualCaption(
                      (partyName != null
                          ? Bilingual.data(partyName)
                          : L10n.selectRecipient),
                    ),
                  ),
                for (final entry in [
                  ('From (YYYY-MM-DD)', from),
                  ('To (YYYY-MM-DD)', to),
                  ('Trip / vehicle search', search),
                ])
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: entry.$2,
                      enabled: !busy,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(label: BilingualOwnedCaption(entry.$1)),
                      ),
                      onChanged: (_) => changed(),
                    ),
                  ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isDense: false,
                    isExpanded: true,
                    initialValue: office,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.officeScope),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: BilingualText(L10n.allPermittedOffices),
                      ),
                      for (final o in widget.offices)
                        DropdownMenuItem(
                          value: o['id'] as String,
                          child: Text(o['name'] as String),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            office = v;
                            preview = null;
                          }),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => pick('VEHICLE'),
                  child: BilingualCaption(
                    (vehicleName != null
                        ? Bilingual.data(vehicleName)
                        : L10n.selectVehicle),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => pick('OWNER'),
                  child: BilingualCaption(
                    (ownerName != null
                        ? Bilingual.data(ownerName)
                        : L10n.selectHistoricalOwner),
                  ),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => pick('TRIP'),
                  child: BilingualCaption(
                    (tripName != null
                        ? Bilingual.data(tripName)
                        : L10n.selectTrip),
                  ),
                ),
                if (report == 'PAYMENT_RECEIPT')
                  OutlinedButton(
                    onPressed: busy ? null : () => pick('RECEIPT'),
                    child: BilingualCaption(
                      (eventName != null
                          ? Bilingual.data(eventName)
                          : L10n.selectActualPaymentReceipt),
                    ),
                  ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          vehicle = vehicleName = owner = ownerName = trip =
                              tripName = event = eventName = null;
                          search.clear();
                          preview = null;
                        }),
                  child: const BilingualCaption(L10n.clearRecordFilters),
                ),
              ],
            ),
          ),
          if (s != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const BilingualCaption(L10n.reloadCatalogueAndPresets),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    isDense: false,
                    itemHeight: null,
                    key: ValueKey('preset-$presetId-${presets.length}'),
                    isExpanded: true,
                    initialValue: presetId,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.savedPreset),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: BilingualText(L10n.systemDefaults),
                      ),
                      for (final p in presets)
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: BilingualText(
                            L10n.labelValuesfb62fe.withValues([
                              p['shared'] == true ? 'Company' : 'Personal',
                              p['name'],
                            ]),
                          ),
                        ),
                    ],
                    onChanged: busy ? null : usePreset,
                  ),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          s.all();
                          preview = null;
                        }),
                  child: const BilingualCaption(L10n.selectAllPermitted),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          s.reset();
                          presetId = null;
                          preview = null;
                        }),
                  child: const BilingualCaption(L10n.resetDefaults),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => manage(),
                  child: const BilingualCaption(L10n.saveNamedPreset),
                ),
                if (current?['can_manage'] == true) ...[
                  OutlinedButton(
                    onPressed: busy ? null : () => manage(existing: current),
                    child: const BilingualCaption(L10n.updateRenamePreset),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => manage(existing: current, deleting: true),
                    child: const BilingualCaption(L10n.deletePreset),
                  ),
                ],
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    isDense: false,
                    itemHeight: null,
                    key: ValueKey(orientation),
                    isExpanded: true,
                    initialValue: orientation,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.pdfOrientation),
                      ),
                    ),
                    items: [
                      for (final v in ['AUTO', 'PORTRAIT', 'LANDSCAPE'])
                        DropdownMenuItem(
                          value: v,
                          child: BilingualOwnedText(v),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            orientation = v!;
                            preview = null;
                          }),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: sheet,
                    enabled: !busy,
                    decoration: bilingualDecoration(
                      context,
                      InputDecoration(
                        label: BilingualCaption(L10n.excelSheetLabel),
                      ),
                    ),
                    onChanged: (_) => changed(),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : () => prepare(),
                  child: const BilingualCaption(L10n.preview),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const BilingualText(
              L10n.requiredFieldsStayInTheHeaderOrSummarySelecting,
            ),
            for (final group
                in s.fields.map((f) => f['field_group'] as String).toSet())
              ExpansionTile(
                initiallyExpanded: true,
                title: BilingualOwnedText(group),
                children: [
                  for (final f in s.fields.where(
                    (f) => f['field_group'] == group,
                  ))
                    CheckboxListTile(
                      key: ValueKey('field-${f['field_key']}'),
                      dense: true,
                      title: BilingualOwnedText(f['label'] as String),
                      subtitle: f['required'] == true
                          ? const BilingualText(
                              L10n.requiredHeaderIdentityField,
                            )
                          : null,
                      secondary: f['required'] == true
                          ? const Icon(Icons.lock)
                          : null,
                      value: s.order.contains(f['field_key']),
                      onChanged: busy || f['required'] == true
                          ? null
                          : (v) => setState(() {
                              s.toggle(f['field_key'] as String, v!);
                              preview = null;
                            }),
                    ),
                ],
              ),
            const BilingualText(L10n.selectedFieldOrder),
            for (var i = 0; i < s.order.length; i++)
              BilingualListTile(
                dense: true,
                title: BilingualOwnedText(
                  s.fields.firstWhere(
                        (f) => f['field_key'] == s.order[i],
                      )['label']
                      as String,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: L10n.moveUp81ba09.withValues([
                        s.order[i],
                      ]).inline,
                      onPressed: busy || i == 0
                          ? null
                          : () => setState(() {
                              s.move(i, -1);
                              preview = null;
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: L10n.moveDowndcbe95.withValues([
                        s.order[i],
                      ]).inline,
                      onPressed: busy || i == s.order.length - 1
                          ? null
                          : () => setState(() {
                              s.move(i, 1);
                              preview = null;
                            }),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
        title: BilingualText(
          (widget.supersedesId == null
              ? L10n.outputsAndPresets
              : L10n.supersedingDocument),
        ),
        actions: [
          if (widget.documents != null)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => widget.guard(
                    DocumentWorkspace(
                      commands: widget.documents!,
                      onSupersede: supersede,
                      guard: widget.guard,
                      fileActions: widget.exporter == null
                          ? null
                          : (doc) => OutputFileActions(
                              service: widget.exporter!,
                              load: () =>
                                  widget.exporter!.issued(doc['id'] as String),
                            ),
                    ),
                  ),
                ),
              ),
              child: const BilingualCaption(L10n.issuedDocuments),
            ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 480, child: configuration),
                const VerticalDivider(),
                Expanded(
                  child: preview == null
                      ? const Center(
                          child: BilingualText(
                            L10n.chooseFieldsAndPreviewTheAuthorizedReport,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: previewPanel(),
                        ),
                ),
              ],
            )
          : preview == null
          ? configuration
          : Column(
              children: [
                TextButton(
                  onPressed: busy ? null : () => setState(() => preview = null),
                  child: const BilingualCaption(L10n.editConfiguration),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: previewPanel(),
                  ),
                ),
              ],
            ),
    );
  }
}

class OutputPreview extends StatelessWidget {
  const OutputPreview({
    super.key,
    required this.data,
    required this.onPage,
    required this.busy,
  });
  final Map<String, dynamic> data;
  final void Function(int) onPage;
  final bool busy;
  @override
  Widget build(BuildContext c) {
    final fields = (data['fields'] as List).cast<Map>();
    final summaries =
        (data['summary_fields'] as List? ?? data['fields'] as List).cast<Map>();
    final columns = fields.where((f) => f['header'] != true).toList();
    final meta = data['metadata'] as Map;
    final offset = data['page_offset'] as int;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const BilingualText(
              L10n.authorizedPreview,
              style: TextStyle(fontSize: 20),
            ),
            for (final f in fields.where((f) => f['header'] == true))
              BilingualText(
                L10n.labelValuesfb62fe.withValues([
                  ownedMessage(f['label']),
                  meta[f['field_key']] ?? '',
                ]),
              ),
            BilingualText(
              L10n.dateBases.withValues([ownedDateBases(meta['date_bases'])]),
            ),
            const BilingualText(
              L10n.currentEffectiveRecordsEarlierPeriodsCanChangeAfterAudited,
            ),
            Wrap(
              spacing: 12,
              children: [
                for (final e in (data['totals'] as Map).entries)
                  BilingualText(
                    L10n.labelValuesfb62fe.withValues([
                      summaries
                              .where((f) => f['field_key'] == e.key)
                              .firstOrNull?['label'] ??
                          e.key,
                      e.value,
                    ]),
                  ),
              ],
            ),
            if ((data['rows'] as List).isEmpty)
              const BilingualText(L10n.noRecordsInThisPeriodScope),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 100 * MediaQuery.textScalerOf(c).scale(1),
                dataRowMinHeight: 56,
                dataRowMaxHeight: double.infinity,
                columns: [
                  for (final f in columns)
                    DataColumn(
                      label: SizedBox(
                        width: 220,
                        child: BilingualOwnedCaption(f['label'] as String),
                      ),
                    ),
                ],
                rows: [
                  for (final row in data['rows'] as List)
                    DataRow(
                      cells: [
                        for (final f in columns)
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                (row[f['field_key']] ?? '').toString(),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: busy || offset == 0
                      ? null
                      : () => onPage(offset - 50),
                  child: const BilingualCaption(L10n.previousPreviewPage),
                ),
                BilingualText(
                  L10n.recordsPage.withValues([
                    data['row_count'],
                    offset ~/ 50 + 1,
                  ]),
                ),
                TextButton(
                  onPressed: busy || data['has_more'] != true
                      ? null
                      : () => onPage(offset + 50),
                  child: const BilingualCaption(L10n.nextPreviewPage),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputChoice extends StatefulWidget {
  const _OutputChoice({
    required this.commands,
    required this.masters,
    required this.trips,
    required this.kind,
    required this.recipient,
    required this.party,
    required this.filters,
  });
  final OutputCommands commands;
  final MasterRepository masters;
  final TripRepository trips;
  final String kind, recipient;
  final String? party;
  final Map<String, dynamic> filters;
  @override
  State<_OutputChoice> createState() => _OutputChoiceState();
}

class _OutputChoiceState extends State<_OutputChoice> {
  final search = TextEditingController();
  int offset = 0;
  late Future<List<Map<String, dynamic>>> rows;
  @override
  void initState() {
    super.initState();
    rows = fetch();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> fetch() async {
    if (widget.kind == 'RECEIPT') {
      return widget.commands.receipts(
        widget.recipient,
        widget.party,
        widget.filters,
        offset,
      );
    }
    if (widget.kind == 'TRIP') {
      final p = await widget.trips.list(search: search.text, offset: offset);
      return p.rows
          .map((r) => {'id': r['id'], 'label': r['trip_number']})
          .toList();
    }
    final p = await widget.masters.list(
      widget.kind == 'VEHICLE' ? MasterKind.vehicle : MasterKind.party,
      search: search.text,
      offset: offset,
    );
    return p
        .where(
          (r) =>
              widget.kind == 'VEHICLE' ||
              r.roles.contains(
                widget.kind == 'OWNER' ? 'OWNER' : widget.recipient,
              ),
        )
        .map((r) => {'id': r.id, 'label': r.label})
        .toList();
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    scrollable: true,
    title: BilingualText(L10n.select.withValues([widget.kind.toLowerCase()])),
    content: SizedBox(
      width: 450,
      height: 450,
      child: Column(
        children: [
          if (widget.kind != 'RECEIPT')
            TextField(
              controller: search,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.search)),
              ),
              onSubmitted: (_) => setState(() {
                offset = 0;
                rows = fetch();
              }),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: rows,
              builder: (_, s) {
                if (s.hasError) {
                  return const BilingualText(
                    L10n.chooseTheRecipientDatesAndCurrentScopeFirst,
                  );
                }
                if (!s.hasData) return const LinearProgressIndicator();
                return ListView(
                  children: [
                    if (s.data!.isEmpty)
                      const BilingualText(
                        L10n.noPermittedRecordsInThisPageScope,
                      ),
                    for (final r in s.data!)
                      BilingualListTile(
                        title: Text(r['label'] as String),
                        onTap: () => Navigator.pop(c, r),
                      ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: offset > 0
                    ? () => setState(() {
                        offset -= 50;
                        rows = fetch();
                      })
                    : null,
                child: const BilingualCaption(L10n.previous),
              ),
              TextButton(
                onPressed: () => setState(() {
                  offset += 50;
                  rows = fetch();
                }),
                child: const BilingualCaption(L10n.next),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: const BilingualCaption(L10n.close),
      ),
    ],
  );
}

class _PresetDialog extends StatefulWidget {
  const _PresetDialog({
    required this.commands,
    required this.report,
    required this.recipient,
    required this.fields,
    required this.options,
    required this.administrator,
    required this.existing,
    required this.deleting,
  });
  final OutputCommands commands;
  final String report, recipient;
  final List<String> fields;
  final Map<String, dynamic> options;
  final bool administrator, deleting;
  final Map<String, dynamic>? existing;
  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  late final name = TextEditingController(
    text: widget.existing?['name'] as String? ?? '',
  );
  late bool shared = widget.existing?['shared'] == true;
  late final id = widget.existing?['id'] as String? ?? newRecordId();
  final request = newRecordId();
  Map<String, dynamic>? frozen;
  bool busy = false, review = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
      frozen ??= {
        'name': name.text.trim(),
        'shared': shared,
        'report_kind': widget.report,
        'recipient_kind': widget.recipient,
        'field_order': widget.fields,
        'format_options': widget.options,
      };
    });
    try {
      if (widget.deleting) {
        await widget.commands.delete(
          id,
          request,
          widget.existing!['version'] as int,
        );
      } else {
        await widget.commands.save(
          id,
          request,
          widget.existing?['version'] as int? ?? 0,
          frozen!,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = outputError(e);
          if (e is PostgrestException) {
            if (e.code == 'PT409') {
              review = true;
            } else {
              frozen = null;
            }
          }
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    scrollable: true,
    title: BilingualText(
      (widget.deleting ? L10n.deleteNamedPreset : L10n.saveNamedPreset),
    ),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) BilingualOwnedText(error!),
          if (!widget.deleting) ...[
            TextField(
              controller: name,
              enabled: !busy && frozen == null,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.presetName)),
              ),
            ),
            CheckboxListTile(
              title: const BilingualText(L10n.sharedCompanyPresetAdministrator),
              value: shared,
              onChanged:
                  widget.administrator &&
                      widget.existing == null &&
                      !busy &&
                      frozen == null
                  ? (v) => setState(() => shared = v!)
                  : null,
            ),
          ],
          const BilingualText(
            L10n.storesFieldsAndFormattingOnlyCurrentFiltersAndAccess,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(c, false),
        child: const BilingualCaption(L10n.close),
      ),
      FilledButton(
        onPressed: busy || review ? null : submit,
        child: BilingualCaption(
          (widget.deleting ? L10n.confirmDelete : L10n.savePreset),
        ),
      ),
    ],
  );
}
