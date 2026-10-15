import 'package:carrier_records/app/bilingual.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'master_repository.dart';

Bilingual masterRecordSummary(MasterKind kind, MasterRecord row) {
  final parts = <Bilingual>[
    if (row.data['code'] != null) Bilingual.data(row.value('code')),
    ...row.roles.map(ownedMessage),
    if (kind == MasterKind.vehicle)
      L10n.vehicleOwnerDriverSummary.withValues([
        row.value('current_owner_name'),
        row.value('default_driver_name'),
      ]),
    if (kind == MasterKind.route)
      Bilingual.data(
        MasterStrings.routeSummary(
          row.value('origin_label'),
          row.value('destination_label'),
          row.value('suggested_fare'),
        ),
      ),
    if (row.archived) ownedMessage(MasterStrings.archived),
    if (kind == MasterKind.company)
      ownedMessage(
        row.data['setup_completed'] == true
            ? MasterStrings.companyReady
            : MasterStrings.setupRequired,
      ),
  ];
  return Bilingual(
    'master.recordSummary',
    parts.map((p) => p.en).join(' · '),
    parts.map((p) => p.ur.isEmpty ? '\u2068${p.en}\u2069' : p.ur).join(' · '),
  );
}

class MasterWorkspace extends StatefulWidget {
  const MasterWorkspace({super.key, required this.repository});
  final MasterRepository repository;
  @override
  State<MasterWorkspace> createState() => _MasterWorkspaceState();
}

class _MasterWorkspaceState extends State<MasterWorkspace> {
  MasterKind kind = MasterKind.company;
  final search = TextEditingController();
  int offset = 0;
  bool archived = false;
  late Future<List<MasterRecord>> records;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() {
    records = widget.repository.list(
      kind,
      search: search.text.trim(),
      offset: offset,
      archived: archived,
    );
  });
  Future<void> edit([MasterRecord? record]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MasterDialog(
        repository: widget.repository,
        kind: kind,
        record: record,
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BilingualText(L10n.savedByTheServer)),
      );
    }
    reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.companyAndMasterRecords),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final item in MasterKind.values)
              ChoiceChip(
                label: BilingualOwnedText(item.label),
                selected: item == kind,
                onSelected: (_) {
                  kind = item;
                  offset = 0;
                  search.clear();
                  reload();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (kind == MasterKind.company)
          const BilingualText(
            L10n.enterYourActualCompanyIdentitySaveItBeforeIssuing,
          ),
        if (kind == MasterKind.office)
          const BilingualText(
            L10n.suggestedOfficeNamesKarachiAndIslamabadEnterYourActual,
          ),
        if (kind == MasterKind.category)
          const BilingualText(
            L10n.suggestionsDieselOilChangeTollsDriverAllowanceRepairsTyres,
          ),
        if (kind == MasterKind.vehicle || kind == MasterKind.route)
          const BilingualText(L10n.ownerChangesApplyToNewTripsSavedTripOwners),
        if (kind != MasterKind.company) ...[
          TextField(
            controller: search,
            maxLength: 100,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(L10n.searchNamesCodes),
                suffixIcon: Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) {
              offset = 0;
              reload();
            },
          ),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(
                onPressed: () => edit(),
                child: const BilingualCaption(L10n.newRecord),
              ),
              TextButton(
                onPressed: () {
                  offset = 0;
                  reload();
                },
                child: const BilingualCaption(L10n.searchRefresh),
              ),
              FilterChip(
                label: const BilingualText(L10n.includeArchived),
                selected: archived,
                onSelected: (v) {
                  archived = v;
                  offset = 0;
                  reload();
                },
              ),
            ],
          ),
        ],
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: FutureBuilder<List<MasterRecord>>(
            future: records,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: reload,
                    child: const BilingualCaption(L10n.recordsUnavailableRetry),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!;
              return Column(
                children: [
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: BilingualText(L10n.noRecordsFound),
                          )
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (context, i) {
                              final row = rows[i];
                              return Card(
                                child: BilingualListTile(
                                  title: Text(row.label),
                                  subtitle: BilingualText(
                                    masterRecordSummary(kind, row),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => edit(row),
                                    child: const BilingualCaption(L10n.edit),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (kind != MasterKind.company)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: offset == 0
                              ? null
                              : () {
                                  offset -= 50;
                                  reload();
                                },
                          child: const BilingualCaption(L10n.previous),
                        ),
                        Text('${offset + 1}–${offset + rows.length}'),
                        TextButton(
                          onPressed: rows.length < 50
                              ? null
                              : () {
                                  offset += 50;
                                  reload();
                                },
                          child: const BilingualCaption(L10n.next),
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

class MasterDialog extends StatefulWidget {
  const MasterDialog({
    super.key,
    required this.repository,
    required this.kind,
    this.record,
  });
  final MasterRepository repository;
  final MasterKind kind;
  final MasterRecord? record;
  @override
  State<MasterDialog> createState() => _MasterDialogState();
}

class _MasterDialogState extends State<MasterDialog> {
  final fields = <String, TextEditingController>{};
  final roles = <String>{};
  late final String id;
  bool archived = false, busy = false, conflict = false;
  String? owner, driver, ownerName, driverName, error, lastBody, requestId;
  @override
  void initState() {
    super.initState();
    id = widget.record?.id ?? newRecordId();
    for (final field in widget.kind.fields) {
      fields[field] = TextEditingController(
        text: widget.record?.value(field) ?? '',
      );
    }
    roles.addAll(widget.record?.roles ?? []);
    archived = widget.record?.archived ?? false;
    owner = widget.record?.data['current_owner_id'] as String?;
    driver = widget.record?.data['default_driver_id'] as String?;
    ownerName = widget.record?.data['current_owner_name'] as String?;
    driverName = widget.record?.data['default_driver_name'] as String?;
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> chooseParty(bool forOwner) async {
    final selected = await showDialog<MasterRecord>(
      context: context,
      builder: (_) => PartyChoiceDialog(
        repository: widget.repository,
        role: forOwner ? 'OWNER' : 'DRIVER',
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (forOwner) {
          owner = selected.id;
          ownerName = selected.label;
        } else {
          driver = selected.id;
          driverName = selected.label;
        }
      });
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = masterPayload(
        widget.kind,
        fields.map((key, controller) => MapEntry(key, controller.text)),
        archived: archived,
        roles: roles,
        ownerId: owner,
        driverId: driver,
      );
      final body = jsonEncode(payload);
      // Retain the retry ID only for the same user input after an uncertain response.
      if (body != lastBody) {
        lastBody = body;
        requestId = newRecordId();
      }
      await widget.repository.save(
        widget.kind,
        id,
        requestId!,
        widget.record?.version ?? 0,
        payload,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          conflict = e.code == 'PT409' || e.code == '40001';
          error = conflict
              ? MasterStrings.conflict
              : MasterStrings.serverValidation[e.message] ??
                    MasterStrings.failure;
        });
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = MasterStrings.failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: BilingualText(
      L10n.labelValues10866a.withValues([
        widget.record == null ? L10n.newRecordWord : L10n.edit,
        ownedMessage(widget.kind.label),
      ]),
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.kind.fields)
              TextField(
                controller: fields[field],
                enabled: !busy && !conflict,
                maxLength:
                    ['address', 'phone', 'email', 'logo_url'].contains(field)
                    ? 500
                    : 150,
                decoration: bilingualDecoration(
                  context,
                  InputDecoration(
                    label: BilingualOwnedCaption(
                      MasterStrings.fieldLabels[field],
                    ),
                  ),
                ),
                keyboardType: field == 'suggested_fare'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
              ),
            if (widget.kind == MasterKind.party) ...[
              const BilingualText(
                L10n.onePersonCanHaveSeveralRolesRemovedRolesAre,
              ),
              for (final role in MasterStrings.partyRoles)
                CheckboxListTile(
                  title: BilingualOwnedText(role),
                  value: roles.contains(role),
                  onChanged: busy || conflict
                      ? null
                      : (v) => setState(() {
                          v == true ? roles.add(role) : roles.remove(role);
                        }),
                ),
            ],
            if (widget.kind == MasterKind.vehicle) ...[
              BilingualListTile(
                title: const BilingualText(L10n.currentOwnerRequired),
                subtitle: BilingualText(
                  (owner == null
                      ? L10n.chooseAnActiveOwner
                      : (ownerName != null
                            ? Bilingual.data(ownerName)
                            : L10n.ownerUnavailable)),
                ),
                trailing: TextButton(
                  onPressed: busy || conflict ? null : () => chooseParty(true),
                  child: const BilingualCaption(L10n.choose),
                ),
              ),
              BilingualListTile(
                title: const BilingualText(L10n.defaultDriverOptional),
                subtitle: BilingualText(
                  (driver == null
                      ? L10n.none
                      : (driverName != null
                            ? Bilingual.data(driverName)
                            : L10n.driverUnavailable)),
                ),
                trailing: TextButton(
                  onPressed: busy || conflict ? null : () => chooseParty(false),
                  child: const BilingualCaption(L10n.choose),
                ),
              ),
              if (driver != null)
                TextButton(
                  onPressed: busy || conflict
                      ? null
                      : () => setState(() => driver = null),
                  child: const BilingualCaption(L10n.clearDefaultDriver),
                ),
              const BilingualText(
                L10n.ownerChangesApplyToNewTripsSavedTripOwners,
              ),
            ],
            if (widget.kind != MasterKind.company && widget.record != null)
              SwitchListTile(
                title: const BilingualText(L10n.archived),
                subtitle: const BilingualText(
                  L10n.excludedFromNewEntryChoicesExistingHistoryIsRetained,
                ),
                value: archived,
                onChanged: busy || conflict
                    ? null
                    : (v) => setState(() => archived = v),
              ),
            if (error != null)
              BilingualOwnedText(error!, key: const Key('master-error')),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        child: BilingualCaption((conflict ? L10n.closeAndReview : L10n.cancel)),
      ),
      FilledButton(
        onPressed: busy || conflict ? null : save,
        child: const BilingualCaption(L10n.save),
      ),
    ],
  );
}

class PartyChoiceDialog extends StatefulWidget {
  const PartyChoiceDialog({
    super.key,
    required this.repository,
    required this.role,
  });
  final MasterRepository repository;
  final String role;
  @override
  State<PartyChoiceDialog> createState() => _PartyChoiceDialogState();
}

class _PartyChoiceDialogState extends State<PartyChoiceDialog> {
  final search = TextEditingController();
  int offset = 0;
  late Future<List<MasterRecord>> records;
  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void reload() => setState(() {
    records = widget.repository.list(
      MasterKind.party,
      search: search.text.trim(),
      offset: offset,
    );
  });
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: BilingualText(
      L10n.chooseRole.withValues([ownedMessage(widget.role.toLowerCase())]),
    ),
    content: SizedBox(
      width: 450,
      height: 400,
      child: Column(
        children: [
          TextField(
            controller: search,
            maxLength: 100,
            decoration: bilingualDecoration(
              context,
              InputDecoration(
                label: BilingualCaption(L10n.searchPartyNameCode),
              ),
            ),
            onSubmitted: (_) {
              offset = 0;
              reload();
            },
          ),
          TextButton(
            onPressed: () {
              offset = 0;
              reload();
            },
            child: const BilingualCaption(L10n.search),
          ),
          Expanded(
            child: FutureBuilder<List<MasterRecord>>(
              future: records,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: reload,
                    child: const BilingualCaption(L10n.unavailableRetry),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data!,
                    eligible = all
                        .where((r) => r.roles.contains(widget.role))
                        .toList();
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          if (eligible.isEmpty)
                            const BilingualText(L10n.noMatchingRoleOnThisPage),
                          for (final row in eligible)
                            BilingualListTile(
                              title: Text(row.label),
                              subtitle: Text(row.value('code')),
                              onTap: () => Navigator.pop(context, row),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: offset == 0
                              ? null
                              : () {
                                  offset -= 50;
                                  reload();
                                },
                          child: const BilingualCaption(L10n.previous),
                        ),
                        TextButton(
                          onPressed: all.length < 50
                              ? null
                              : () {
                                  offset += 50;
                                  reload();
                                },
                          child: const BilingualCaption(L10n.next),
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const BilingualCaption(L10n.cancel),
      ),
    ],
  );
}
