import 'package:flutter/material.dart';

import 'document_repository.dart';
import '../masters/master_repository.dart';
import 'output_workspace.dart';

class DocumentWorkspace extends StatefulWidget {
  const DocumentWorkspace({
    super.key,
    required this.commands,
    required this.onSupersede,
    required this.guard,
    this.fileActions,
  });
  final DocumentCommands commands;
  final void Function(Map<String, dynamic>, String) onSupersede;
  final Widget Function(Widget) guard;
  final Widget Function(Map<String, dynamic>)? fileActions;
  @override
  State<DocumentWorkspace> createState() => _DocumentWorkspaceState();
}

class _DocumentWorkspaceState extends State<DocumentWorkspace> {
  final search = TextEditingController();
  int offset = 0;
  late Future<Map<String, dynamic>> rows;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    rows = widget.commands.list({'search': search.text.trim()}, offset);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> open(String id) async {
    try {
      final doc = await widget.commands.get(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => widget.guard(
            IssuedDocumentView(
              document: doc,
              actions: widget.fileActions?.call(doc),
              onSupersede: doc['can_supersede'] == true
                  ? () {
                      Navigator.of(context).pop();
                      widget.onSupersede(
                        Map<String, dynamic>.from(doc['reissue_context'] as Map)
                          ..['field_order'] = doc['snapshot']['field_order']
                          ..['format_options'] =
                              doc['snapshot']['format_options'],
                        id,
                      );
                    }
                  : null,
            ),
          ),
        ),
      );
      if (mounted) setState(reload);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to retrieve document. Current access is required.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Issued documents')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            decoration: const InputDecoration(
              labelText: 'Document number / recipient',
            ),
            onSubmitted: (_) => setState(() {
              offset = 0;
              reload();
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: rows,
            builder: (_, result) {
              if (result.hasError) {
                return const Center(
                  child: Text('Unable to load authorized documents.'),
                );
              }
              if (!result.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = result.data!, list = data['rows'] as List;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        if (list.isEmpty)
                          const ListTile(
                            title: Text(
                              'No issued documents in your current scope.',
                            ),
                          ),
                        for (final d in list)
                          ListTile(
                            title: Text(
                              '${d['permanent_number']} - ${d['recipient']}',
                            ),
                            subtitle: Text(
                              '${d['issued_at']} | Issued by ${d['issuer']} | ${d['superseded'] == true ? 'Superseded' : 'Original / current'}',
                            ),
                            trailing: const Icon(Icons.description_outlined),
                            onTap: () => open(d['id'] as String),
                          ),
                      ],
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: offset == 0
                            ? null
                            : () => setState(() {
                                offset -= 50;
                                reload();
                              }),
                        child: const Text('Previous documents'),
                      ),
                      Text('Page ${offset ~/ 50 + 1}'),
                      TextButton(
                        onPressed: data['has_more'] == true
                            ? () => setState(() {
                                offset += 50;
                                reload();
                              })
                            : null,
                        child: const Text('Next documents'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class IssuedDocumentView extends StatelessWidget {
  const IssuedDocumentView({
    super.key,
    required this.document,
    this.onSupersede,
    this.actions,
  });
  final Map<String, dynamic> document;
  final VoidCallback? onSupersede;
  final Widget? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(document['permanent_number'] as String)),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issued snapshot. Reprints retain the original company, issuer, amounts and selected layout.',
          ),
          if (document['superseded_by_number'] != null)
            Text('Superseded by ${document['superseded_by_number']}'),
          if (document['supersedes_number'] != null)
            Text('Supersedes ${document['supersedes_number']}'),
          if (onSupersede != null)
            OutlinedButton(
              onPressed: onSupersede,
              child: const Text('Prepare superseding document'),
            ),
          ?actions,
          OutputPreview(
            data: Map<String, dynamic>.from(document['snapshot'] as Map),
            onPage: (_) {},
            busy: false,
          ),
        ],
      ),
    ),
  );
}

class IssueDocumentDialog extends StatefulWidget {
  const IssueDocumentDialog({
    super.key,
    required this.commands,
    required this.payload,
    required this.superseding,
  });
  final DocumentCommands commands;
  final Map<String, dynamic> payload;
  final bool superseding;
  @override
  State<IssueDocumentDialog> createState() => _IssueDocumentDialogState();
}

class _IssueDocumentDialogState extends State<IssueDocumentDialog> {
  final reason = TextEditingController();
  String? request, error;
  Map<String, dynamic>? frozen;
  bool busy = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> issue() async {
    if (widget.superseding && reason.text.trim().isEmpty) {
      setState(() => error = 'A correction reason is required.');
      return;
    }
    frozen ??= {
      ...widget.payload,
      'reason': widget.superseding ? reason.text.trim() : null,
    };
    request ??= newRecordId();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final committed = await widget.commands.issue(request!, frozen!);
      if (mounted) Navigator.of(context).pop(committed);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Document was not confirmed. Retry the same request, or close and reload issued documents before preparing a changed request.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(
        widget.superseding
            ? 'Issue superseding document'
            : 'Issue permanent document',
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The server captures current authorized amounts and assigns a permanent number. The issued original remains available.',
            ),
            if (widget.superseding)
              TextField(
                controller: reason,
                enabled: frozen == null,
                decoration: const InputDecoration(
                  labelText: 'Correction reason',
                ),
              ),
            if (error != null) Text(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: busy ? null : issue,
          child: const Text('Confirm issuance'),
        ),
      ],
    ),
  );
}
