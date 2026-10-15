import 'package:carrier_records/app/bilingual.dart';

import '../auth/local_candidate_policy.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../../app/karvaan_design.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class BackupCommands {
  Future<Map<String, dynamic>> status();
  Future<bool> manual();
}

class BackupRepository implements BackupCommands {
  BackupRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Map<String, dynamic>> status() async =>
      Map<String, dynamic>.from(await client.rpc('get_backup_status') as Map);
  @override
  Future<bool> manual() async {
    if (karvaanLocalOnly) {
      throw const FormatException(
        'Administrator helper is disabled in this isolated candidate.',
      );
    }
    if (kIsWeb || !Platform.isWindows) {
      throw const FormatException(
        'Run backups on the configured administrator Windows PC.',
      );
    }
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null) {
      throw const FormatException(
        'Administrator Windows helper is not configured.',
      );
    }
    final path = '$base\\CarrierRecords\\BackupHelper\\run-backup.ps1';
    if (!await File(path).exists()) {
      throw const FormatException(
        'Install and configure the separate administrator backup helper first. See the backup setup guide.',
      );
    }
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-WindowStyle',
      'Hidden',
      '-File',
      path,
    ]);
    // Never display process output, which could contain utility diagnostics.
    try {
      return r.exitCode == 0 &&
          (jsonDecode(r.stdout as String) as Map)['outcome'] == 'SUCCESS';
    } catch (_) {
      return false;
    }
  }
}

class BackupSummary extends StatelessWidget {
  const BackupSummary({super.key, required this.status});
  final Map<String, dynamic> status;
  @override
  Widget build(BuildContext context) {
    final schedule = (status['schedule'] as Map?) ?? {},
        metrics = (status['metrics'] as Map?) ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BilingualText(
          L10n.lastVerifiedBackupSuccessUTC.withValues([
            status['last_verified_success_at'] ?? 'Never',
          ]),
        ),
        BilingualText(
          L10n.lastAttempt.withValues([
            status['last_attempt_at'] ?? 'Never',
            status['outcome'],
          ]),
        ),
        if (status['stale'] == true)
          const BilingualText(L10n.backupIsStaleOrHasNeverSucceededRunThe),
        if (status['outcome'] == 'FAILED')
          BilingualText(
            L10n.backupFailed.withValues([
              status['safe_error_code'] ??
                  'Review the administrator helper status.',
            ]),
          ),
        if (status['interrupted'] == true)
          const BilingualText(L10n.theLastRunMayHaveBeenInterruptedItHas),
        BilingualText(
          L10n.pendingReceiptCopies.withValues([
            status['pending_receipt_count'] ?? 0,
          ]),
        ),
        BilingualText(
          (schedule['active'] == true
              ? L10n.dailyScheduleVerifiedRunsDuringTheAdministratorWindowsSession
                    .withValues([schedule['daily_time'], schedule['time_zone']])
              : L10n.noActiveScheduleHasBeenVerifiedConfigureTheSeparate),
        ),
        BilingualText(
          L10n.estimatedBackupTrafficThisMonthBytesDatabaseBytesFiles
              .withValues([
                status['backup_traffic_monthly_bytes'] ?? '0',
                metrics['database_bytes'] ?? 'unknown',
                metrics['storage_bytes'] ?? 'unknown',
              ]),
        ),
        if (status['quota_level'] != 'NORMAL')
          BilingualText(
            L10n.freeTierUsageWarningReviewProviderQuotasAndBackup.withValues([
              status['quota_level'],
            ]),
          ),
        if ((status['incomplete_traffic_attempts'] as int? ?? 0) > 0)
          BilingualText(
            L10n.trafficForInterruptedOrIncompleteAttemptsMayBeMissing
                .withValues([status['incomplete_traffic_attempts']]),
          ),
        if (status['other_traffic_known'] != true)
          const BilingualText(
            L10n.otherApplicationProviderTrafficIsNotMeasuredHereCheck,
          ),
        const BilingualText(
          L10n.copyEncryptedDatabaseArchivesANDReceiptObjectBackupsOff,
        ),
      ],
    );
  }
}

class BackupStatusPanel extends StatefulWidget {
  const BackupStatusPanel({super.key, required this.commands});
  final BackupCommands commands;
  @override
  State<BackupStatusPanel> createState() => _BackupStatusPanelState();
}

class _BackupStatusPanelState extends State<BackupStatusPanel> {
  late Future<Map<String, dynamic>> status;
  @override
  void initState() {
    super.initState();
    status = widget.commands.status();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: status,
    builder: (_, snap) => Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: snap.hasData
            ? BackupSummary(status: snap.data!)
            : BilingualText(
                (snap.hasError
                    ? L10n.backupStatusUnavailableCheckTheAdministratorHelperAndConnection
                    : L10n.loadingBackupStatus),
              ),
      ),
    ),
  );
}

class BackupWorkspace extends StatefulWidget {
  const BackupWorkspace({super.key, required this.commands});
  final BackupCommands commands;
  @override
  State<BackupWorkspace> createState() => _BackupWorkspaceState();
}

class _BackupWorkspaceState extends State<BackupWorkspace> {
  Map<String, dynamic>? status;
  String? message;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final value = await widget.commands.status();
      if (mounted) {
        setState(() => status = value);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = 'Administrator backup status could not be read. Check current access and connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> manual() async {
    setState(() => busy = true);
    try {
      final completed = await widget.commands.manual();
      if (mounted) {
        setState(
          () => message = completed
              ? 'Helper finished. Refreshing the server verification status.'
              : 'Helper did not report completion. Last verified success is unchanged; inspect its local safe status.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is FormatException
              ? e.message
              : 'The administrator helper could not be started.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
    if (mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.administratorBackups),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (message != null) BilingualOwnedText(message!),
        if (status != null) BackupSummary(status: status!),
        KarvaanSection(
          title: L10n.administratorBackups,
          child: Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : manual,
                child: const BilingualCaption(L10n.runManualWindowsBackup),
              ),
              TextButton(
                onPressed: busy ? null : load,
                child: const BilingualCaption(L10n.refreshVerifiedStatus),
              ),
            ],
          ),
        ),
        const BilingualText(
          L10n.privilegedCredentialsAndEncryptionKeysAreConfiguredInThe,
        ),
      ],
    ),
  );
}
