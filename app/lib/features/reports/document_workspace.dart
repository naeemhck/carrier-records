import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';

import '../../app/karvaan_choice_field.dart';
import '../../app/shell_header.dart';
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
    this.onConfigure,
  });
  final VoidCallback? onConfigure;
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

  /// Register sort (reports pass): client-side over the loaded page —
  /// 'newest' | 'oldest' | 'number'. The list payload carries no
  /// server-side sort control.
  String docSort = 'newest';
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
            content: BilingualText(
              L10n.unableToRetrieveDocumentCurrentAccessIsRequired,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ShellHeader(
    // Title + Create report live in the shell's single header row
    // (header compaction); the Create report action was a lone body row
    // here and is a header action now — same destination, same label.
    title: L10n.issuedDocuments,
    actions: [
      if (widget.onConfigure != null)
        ShellHeaderAction(
          child: TextButton.icon(
            onPressed: widget.onConfigure,
            icon: const Icon(Icons.post_add),
            label: const BilingualCaption(L10n.createReport),
          ),
          compactChild: IconButton(
            onPressed: widget.onConfigure,
            icon: const Icon(Icons.post_add),
            tooltip: L10n.createReport.inMode(
              LanguageModeStore.instance.mode.value,
            ),
          ),
        ),
    ],
    child: Scaffold(
      // One scroll flow gives large text its natural height; pagination cannot
      // squeeze an empty-state viewport to zero or paint over its Urdu lines.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          TextField(
            controller: search,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(L10n.documentNumberRecipient),
              ),
            ),
            // Apply as the user types (GPT QA F06): the register used to
            // wait for Enter, so a typed no-match search kept showing the
            // unfiltered scope empty state with no Clear action. Reloading
            // on change also rebuilds the empty-state branch below, which
            // keys off the current search text.
            onChanged: (_) => setState(() {
              offset = 0;
              reload();
            }),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
            future: rows,
            builder: (_, result) {
              if (result.hasError) {
                return const BilingualText(
                  L10n.unableToLoadAuthorizedDocuments,
                );
              }
              if (!result.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = result.data!;
              final list = List.of(data['rows'] as List);
              int byIssued(dynamic a, dynamic b) => (a['issued_at'] ?? '')
                  .toString()
                  .compareTo((b['issued_at'] ?? '').toString());
              switch (docSort) {
                case 'oldest':
                  list.sort(byIssued);
                case 'number':
                  list.sort(
                    (a, b) => (a['permanent_number'] ?? '')
                        .toString()
                        .compareTo((b['permanent_number'] ?? '').toString()),
                  );
                default:
                  list.sort((a, b) => byIssued(b, a));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (list.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: 240,
                          child: KarvaanChoiceField<String>(
                            key: ValueKey('documents-sort-$docSort'),
                            initialValue: docSort,
                            decoration: bilingualDecoration(
                              context,
                              const InputDecoration(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'newest',
                                child: BilingualText(L10n.sortNewestFirst),
                              ),
                              DropdownMenuItem(
                                value: 'oldest',
                                child: BilingualText(L10n.sortOldestFirst),
                              ),
                              DropdownMenuItem(
                                value: 'number',
                                child: BilingualText(L10n.sortByNumber),
                              ),
                            ],
                            onChanged: (v) => setState(() => docSort = v!),
                          ),
                        ),
                      ),
                    ),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: search.text.trim().isEmpty
                          ? const BilingualText(
                              L10n.noIssuedDocumentsInYourCurrentScope,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const BilingualText(L10n.noMatchesForFilters),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() {
                                    search.clear();
                                    offset = 0;
                                    reload();
                                  }),
                                  child: const BilingualCaption(L10n.clear),
                                ),
                              ],
                            ),
                    ),
                  for (final d in list)
                    BilingualListTile(
                      title: Text(
                        '${d['permanent_number']} - ${d['recipient']}',
                      ),
                      subtitle: BilingualText(
                        L10n.issuedBy.withValues([
                          displayTimestamp(d['issued_at']),
                          d['issuer'],
                          d['superseded'] == true
                              ? 'Superseded'
                              : 'Original / current',
                        ]),
                      ),
                      trailing: const Icon(Icons.description_outlined),
                      onTap: () => open(d['id'] as String),
                    ),
                  // Pagination sits adjacent to the list and hides when
                  // there is nothing to page through (handoff group 9).
                  if (list.isNotEmpty || offset > 0) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    SafeArea(
                      top: false,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: offset == 0
                                ? null
                                : () => setState(() {
                                    offset -= 50;
                                    reload();
                                  }),
                            child: const BilingualCaption(
                              L10n.previousDocuments,
                            ),
                          ),
                          BilingualText(
                            L10n.page.withValues([offset ~/ 50 + 1]),
                          ),
                          TextButton(
                            onPressed: data['has_more'] == true
                                ? () => setState(() {
                                    offset += 50;
                                    reload();
                                  })
                                : null,
                            child: const BilingualCaption(L10n.nextDocuments),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          // Report history (reports pass): generated reports and issued
          // documents stay distinct groups. The register above is the
          // permanent, numbered record; ad-hoc generations are working
          // copies and are not persisted anywhere, so this group states
          // that plainly — the Create report header action is where
          // reports are generated and issued — instead of inventing
          // history rows.
          const SizedBox(height: 24),
          const Divider(),
          BilingualText(
            L10n.generatedReportsGroup,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const BilingualText(L10n.generatedReportsHint),
        ],
      ),
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
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: Text(document['permanent_number'] as String),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BilingualText(
            L10n.issuedSnapshotReprintsRetainTheOriginalCompanyIssuerAmounts,
          ),
          if (document['superseded_by_number'] != null)
            BilingualText(
              L10n.supersededBy.withValues([document['superseded_by_number']]),
            ),
          if (document['supersedes_number'] != null)
            BilingualText(
              L10n.supersedes.withValues([document['supersedes_number']]),
            ),
          if (onSupersede != null)
            OutlinedButton(
              onPressed: onSupersede,
              child: const BilingualCaption(L10n.prepareSupersedingDocument),
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
      scrollable: true,
      title: BilingualText(
        (widget.superseding
            ? L10n.issueSupersedingDocument
            : L10n.issuePermanentDocument),
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BilingualText(
              L10n.theServerCapturesCurrentAuthorizedAmountsAndAssignsA,
            ),
            if (widget.superseding)
              TextField(
                controller: reason,
                enabled: frozen == null,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualCaption(L10n.correctionReason),
                  ),
                ),
              ),
            if (error != null) BilingualOwnedText(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const BilingualCaption(L10n.close),
        ),
        FilledButton(
          onPressed: busy ? null : issue,
          child: const BilingualCaption(L10n.confirmIssuance),
        ),
      ],
    ),
  );
}
