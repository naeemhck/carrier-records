import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../masters/master_repository.dart';
import '../trips/trip_repository.dart';
import '../trips/trip_workspace.dart';
import 'output_repository.dart';
import 'document_repository.dart';
import 'document_workspace.dart';

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
          builder: (_) => widget.guard(IssuedDocumentView(document: committed)),
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
          child: const Text('Issue document'),
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
          const Text(
            'Preview only ? not an issued document. Filters determine records; checkboxes determine presentation.',
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: report,
                  decoration: const InputDecoration(
                    labelText: 'Report / output type',
                  ),
                  items: [
                    for (final e in outputReports.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
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
                  key: ValueKey('recipient-$report'),
                  isExpanded: true,
                  initialValue: recipient,
                  decoration: const InputDecoration(
                    labelText: 'Recipient template',
                  ),
                  items: [
                    for (final r in recipients)
                      DropdownMenuItem(value: r, child: Text(r)),
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
                  child: Text(partyName ?? 'Select recipient'),
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
                    decoration: InputDecoration(labelText: entry.$1),
                    onChanged: (_) => changed(),
                  ),
                ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: office,
                  decoration: const InputDecoration(labelText: 'Office scope'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All permitted offices'),
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
                child: Text(vehicleName ?? 'Select vehicle'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => pick('OWNER'),
                child: Text(ownerName ?? 'Select historical owner'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => pick('TRIP'),
                child: Text(tripName ?? 'Select trip'),
              ),
              if (report == 'PAYMENT_RECEIPT')
                OutlinedButton(
                  onPressed: busy ? null : () => pick('RECEIPT'),
                  child: Text(eventName ?? 'Select actual payment receipt'),
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
                child: const Text('Clear record filters'),
              ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const Text('Reload catalogue and presets'),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('preset-$presetId-${presets.length}'),
                    isExpanded: true,
                    initialValue: presetId,
                    decoration: const InputDecoration(
                      labelText: 'Saved preset',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('System defaults'),
                      ),
                      for (final p in presets)
                        DropdownMenuItem(
                          value: p['id'] as String,
                          child: Text(
                            '${p['shared'] == true ? 'Company' : 'Personal'}: ${p['name']}',
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
                  child: const Text('Select all permitted'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          s.reset();
                          presetId = null;
                          preview = null;
                        }),
                  child: const Text('Reset defaults'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => manage(),
                  child: const Text('Save named preset'),
                ),
                if (current?['can_manage'] == true) ...[
                  OutlinedButton(
                    onPressed: busy ? null : () => manage(existing: current),
                    child: const Text('Update / rename preset'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => manage(existing: current, deleting: true),
                    child: const Text('Delete preset'),
                  ),
                ],
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(orientation),
                    isExpanded: true,
                    initialValue: orientation,
                    decoration: const InputDecoration(
                      labelText: 'PDF orientation',
                    ),
                    items: [
                      for (final v in ['AUTO', 'PORTRAIT', 'LANDSCAPE'])
                        DropdownMenuItem(value: v, child: Text(v)),
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
                    decoration: const InputDecoration(
                      labelText: 'Excel sheet label',
                    ),
                    onChanged: (_) => changed(),
                  ),
                ),
                FilledButton(
                  onPressed: busy ? null : () => prepare(),
                  child: const Text('Preview'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Required fields stay in the header or summary. Selecting fewer columns never recalculates totals.',
            ),
            for (final group
                in s.fields.map((f) => f['field_group'] as String).toSet())
              ExpansionTile(
                initiallyExpanded: true,
                title: Text(group),
                children: [
                  for (final f in s.fields.where(
                    (f) => f['field_group'] == group,
                  ))
                    CheckboxListTile(
                      key: ValueKey('field-${f['field_key']}'),
                      dense: true,
                      title: Text(f['label'] as String),
                      subtitle: f['required'] == true
                          ? const Text('Required header / identity field')
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
            const Text('Selected field order'),
            for (var i = 0; i < s.order.length; i++)
              ListTile(
                dense: true,
                title: Text(
                  s.fields.firstWhere(
                        (f) => f['field_key'] == s.order[i],
                      )['label']
                      as String,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Move up ${s.order[i]}',
                      onPressed: busy || i == 0
                          ? null
                          : () => setState(() {
                              s.move(i, -1);
                              preview = null;
                            }),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move down ${s.order[i]}',
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
        title: Text(
          widget.supersedesId == null
              ? 'Outputs and presets'
              : 'Superseding document',
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
                    ),
                  ),
                ),
              ),
              child: const Text('Issued documents'),
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
                          child: Text(
                            'Choose fields and preview the authorized report.',
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
                  child: const Text('Edit configuration'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Authorized preview', style: TextStyle(fontSize: 20)),
        for (final f in fields.where((f) => f['header'] == true))
          Text('${f['label']}: ${meta[f['field_key']] ?? ''}'),
        Text('Date bases: ${meta['date_bases']}'),
        const Text(
          'Current effective records. Earlier periods can change after audited corrections.',
        ),
        Wrap(
          spacing: 12,
          children: [
            for (final e in (data['totals'] as Map).entries)
              Text(
                '${summaries.where((f) => f['field_key'] == e.key).firstOrNull?['label'] ?? e.key}: ${e.value}',
              ),
          ],
        ),
        if ((data['rows'] as List).isEmpty)
          const Text('No records in this period/scope.'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              for (final f in columns)
                DataColumn(label: Text(f['label'] as String)),
            ],
            rows: [
              for (final row in data['rows'] as List)
                DataRow(
                  cells: [
                    for (final f in columns)
                      DataCell(Text('${row[f['field_key']] ?? ''}')),
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
              onPressed: busy || offset == 0 ? null : () => onPage(offset - 50),
              child: const Text('Previous preview page'),
            ),
            Text('${data['row_count']} records · Page ${offset ~/ 50 + 1}'),
            TextButton(
              onPressed: busy || data['has_more'] != true
                  ? null
                  : () => onPage(offset + 50),
              child: const Text('Next preview page'),
            ),
          ],
        ),
      ],
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
    title: Text('Select ${widget.kind.toLowerCase()}'),
    content: SizedBox(
      width: 450,
      height: 450,
      child: Column(
        children: [
          if (widget.kind != 'RECEIPT')
            TextField(
              controller: search,
              decoration: const InputDecoration(labelText: 'Search'),
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
                  return const Text(
                    'Choose the recipient, dates and current scope first.',
                  );
                }
                if (!s.hasData) return const LinearProgressIndicator();
                return ListView(
                  children: [
                    if (s.data!.isEmpty)
                      const Text('No permitted records in this page/scope.'),
                    for (final r in s.data!)
                      ListTile(
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
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: () => setState(() {
                  offset += 50;
                  rows = fetch();
                }),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
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
    title: Text(widget.deleting ? 'Delete named preset' : 'Save named preset'),
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (!widget.deleting) ...[
            TextField(
              controller: name,
              enabled: !busy && frozen == null,
              decoration: const InputDecoration(labelText: 'Preset name'),
            ),
            CheckboxListTile(
              title: const Text('Shared company preset (administrator)'),
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
          const Text(
            'Stores fields and formatting only. Current filters and access are revalidated at preview time.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(c, false),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: busy || review ? null : submit,
        child: Text(widget.deleting ? 'Confirm delete' : 'Save preset'),
      ),
    ],
  );
}
