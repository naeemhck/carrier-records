import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
    if (!Platform.isWindows) {
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
        Text(
          'Last verified backup success: ${status['last_verified_success_at'] ?? 'Never'} (UTC)',
        ),
        Text(
          'Last attempt: ${status['last_attempt_at'] ?? 'Never'} | ${status['outcome']}',
        ),
        if (status['stale'] == true)
          const Text(
            'Backup is stale or has never succeeded. Run the administrator helper when the PC is online.',
          ),
        if (status['outcome'] == 'FAILED')
          Text(
            'Backup failed: ${status['safe_error_code'] ?? 'Review the administrator helper status.'}',
          ),
        if (status['interrupted'] == true)
          const Text(
            'The last run may have been interrupted. It has no verified success.',
          ),
        Text('Pending receipt copies: ${status['pending_receipt_count'] ?? 0}'),
        Text(
          schedule['active'] == true
              ? 'Daily schedule verified: ${schedule['daily_time']} | ${schedule['time_zone']}. Runs during the administrator Windows session; catches up when available.'
              : 'No active schedule has been verified. Configure the separate Windows helper.',
        ),
        Text(
          'Estimated backup traffic this month: ${status['backup_traffic_monthly_bytes'] ?? '0'} bytes. Database: ${metrics['database_bytes'] ?? 'unknown'} bytes. Files: ${metrics['storage_bytes'] ?? 'unknown'} bytes.',
        ),
        if (status['quota_level'] != 'NORMAL')
          Text(
            'Free-tier usage warning: ${status['quota_level']}. Review provider quotas and backup/export options.',
          ),
        if ((status['incomplete_traffic_attempts'] as int? ?? 0) > 0)
          Text(
            'Traffic for ${status['incomplete_traffic_attempts']} interrupted or incomplete attempts may be missing. Check provider usage.',
          ),
        if (status['other_traffic_known'] != true)
          const Text(
            'Other application/provider traffic is not measured here. Check provider usage; the backup estimate excludes protocol overhead.',
          ),
        const Text(
          'Copy encrypted database archives AND receipt object backups off this PC. Keep the recovery key and its passphrase separately. Archive creation does not verify restoration; complete the restoration rehearsal before production use.',
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
            : Text(
                snap.hasError
                    ? 'Backup status unavailable. Check the administrator helper and connection.'
                    : 'Loading backup status...',
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
    appBar: AppBar(title: const Text('Administrator backups')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
        if (status != null) BackupSummary(status: status!),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: busy ? null : manual,
              child: const Text('Run manual Windows backup'),
            ),
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Refresh verified status'),
            ),
          ],
        ),
        const Text(
          'Privileged credentials and encryption keys are configured in the separate trusted helper, outside the staff app. No schedule is installed by this screen.',
        ),
      ],
    ),
  );
}
