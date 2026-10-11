import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/staff_session.dart';
import '../features/masters/master_repository.dart';
import '../features/masters/master_workspace.dart';
import 'strings.dart';

class CarrierRecordsApp extends StatefulWidget {
  const CarrierRecordsApp({super.key, this.session, this.setupError});
  final StaffSession? session;
  final String? setupError;
  @override
  State<CarrierRecordsApp> createState() => _CarrierRecordsAppState();
}

class _CarrierRecordsAppState extends State<CarrierRecordsApp> {
  late final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => widget.session == null
            ? Scaffold(
                appBar: AppBar(title: const Text(AppStrings.title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.setupError ?? AppStrings.setupPending,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : StaffHome(session: widget.session!),
      ),
    ],
  );
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppStrings.title,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00695C)),
      useMaterial3: true,
    ),
    routerConfig: _router,
  );
}

class StaffHome extends StatefulWidget {
  const StaffHome({super.key, required this.session});
  final StaffSession session;
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> with WidgetsBindingObserver {
  final username = TextEditingController(),
      password = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.session.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    username.dispose();
    password.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      password.clear();
      next.clear();
      confirm.clear();
    } catch (_) {
      if (mounted) message = 'Request failed. Check your credentials, connection or administrator access.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) {
      final p = widget.session.profile;
      return Scaffold(
        appBar: AppBar(
          title: const Text(AppStrings.title),
          actions: [
            if (p != null)
              TextButton(
                onPressed: busy ? null : () => run(widget.session.signOut),
                child: const Text('Sign out'),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (p == null) ...[
                  const Text('Staff sign-in', style: TextStyle(fontSize: 24)),
                  const Text('Use the account supplied by your administrator.'),
                  TextField(
                    controller: username,
                    enabled: !busy,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  TextField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) {
                      if (!busy) {
                        run(
                          () => widget.session.signIn(
                            username.text,
                            password.text,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            () => widget.session.signIn(
                              username.text,
                              password.text,
                            ),
                          ),
                    child: const Text('Sign in'),
                  ),
                ] else if (p['must_change_password'] == true) ...[
                  const Text(
                    'Change your temporary password',
                    style: TextStyle(fontSize: 24),
                  ),
                  const Text(
                    'Choose a new password of 12 to 128 characters. Sign in again after changing it.',
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                  TextField(
                    controller: next,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                  ),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                    ),
                  ),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            if (next.text != confirm.text ||
                                next.text.length < 12) {
                              throw const FormatException();
                            }
                            await widget.session.changePassword(
                              password.text,
                              next.text,
                            );
                          }),
                    child: const Text('Change password'),
                  ),
                ] else ...[
                  Text(
                    'Signed in as ${p['display_name']}',
                    style: const TextStyle(fontSize: 24),
                  ),
                  Text(
                    p['role'] == 'ADMIN'
                        ? 'Administrator — all offices'
                        : 'Assigned offices: ${(p['offices'] as List).map((o) => o['name']).join(', ')}',
                  ),
                  const SizedBox(height: 16),
                  if (p['role'] == 'ADMIN')
                    FilledButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text(MasterStrings.title),
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ListenableBuilder(
                              listenable: widget.session,
                              builder: (context, _) =>
                                  widget.session.profile?['role'] == 'ADMIN' &&
                                      widget
                                              .session
                                              .profile?['must_change_password'] ==
                                          false
                                  ? MasterWorkspace(
                                      repository: SupabaseMasterRepository(
                                        widget.session.client,
                                      ),
                                    )
                                  : const Scaffold(
                                      body: Center(
                                        child: Text(
                                          MasterStrings.accessRequired,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                        await widget.session.refresh();
                      },
                    ),
                  if (p['role'] == 'ADMIN')
                    AccountsPanel(session: widget.session),
                  if (p['role'] != 'ADMIN')
                    const Text(
                      'Your office access is active. Trip entry will be available in the next implementation tasks.',
                    ),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                            await showDialog<void>(
                              context: context,
                              builder: (context) =>
                                  PasswordDialog(session: widget.session),
                            );
                          }),
                    child: const Text('Change my password'),
                  ),
                ],
                if (busy) const LinearProgressIndicator(),
                if (message ?? widget.session.error case final String error)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(error),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.session});
  final StaffSession session;
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: current,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Current password'),
        ),
        TextField(
          controller: next,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password (12–128 characters)',
          ),
        ),
        TextField(
          controller: confirm,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm password'),
        ),
        if (error != null) Text(error!),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy
            ? null
            : () async {
                setState(() => busy = true);
                try {
                  if (next.text != confirm.text || next.text.length < 12) {
                    throw const FormatException();
                  }
                  await widget.session.changePassword(current.text, next.text);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => error = 'Password change failed. Reload account status before retrying.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        child: const Text('Change'),
      ),
    ],
  );
}

class AccountsPanel extends StatefulWidget {
  const AccountsPanel({super.key, required this.session});
  final StaffSession session;
  @override
  State<AccountsPanel> createState() => _AccountsPanelState();
}

class _AccountsPanelState extends State<AccountsPanel> {
  late Future<List<Map<String, dynamic>>> accounts;
  @override
  void initState() {
    super.initState();
    accounts = widget.session.accounts();
  }

  void reload() {
    setState(() => accounts = widget.session.accounts());
  }

  Future<void> edit([Map<String, dynamic>? account]) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          AccountDialog(session: widget.session, account: account),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        children: [
          FilledButton(
            onPressed: () => edit(),
            child: const Text('Create staff account'),
          ),
          TextButton(onPressed: reload, child: const Text('Refresh accounts')),
        ],
      ),
      FutureBuilder(
        future: accounts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Accounts unavailable. Verify your session and retry.',
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: snapshot.data!
                .map(
                  (a) => ListTile(
                    title: Text('${a['display_name']} (${a['username']})'),
                    subtitle: Text(
                      '${a['role']} · ${a['active'] ? 'Active' : 'Disabled'}${a['must_change_password'] ? ' · Password change required' : ''}',
                    ),
                    trailing: TextButton(
                      onPressed: () => edit(a),
                      child: const Text('Manage'),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class AccountDialog extends StatefulWidget {
  const AccountDialog({super.key, required this.session, this.account});
  final StaffSession session;
  final Map<String, dynamic>? account;
  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> {
  final username = TextEditingController(),
      display = TextEditingController(),
      password = TextEditingController();
  String role = 'STAFF';
  bool active = true, busy = false;
  String? error;
  final offices = <String>{};
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    if (a != null) {
      username.text = a['username'];
      display.text = a['display_name'];
      role = a['role'];
      active = a['active'];
      offices.addAll((a['office_ids'] as List).cast<String>());
    }
  }

  @override
  void dispose() {
    username.dispose();
    display.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit(bool reset) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final a = widget.account;
      if (a == null) {
        await widget.session.command({
          'action': 'create',
          'username': username.text.trim().toLowerCase(),
          'display_name': display.text.trim(),
          'role': role,
          'office_ids': offices.toList(),
          'password': password.text,
        });
      } else if (reset) {
        await widget.session.command({
          'action': 'reset',
          'target_id': a['id'],
          'expected_version': a['version'],
          'password': password.text,
        });
      } else {
        await widget.session.client.rpc(
          'admin_manage_staff',
          params: {
            'target_id': a['id'],
            'expected_version': a['version'],
            'display_name': display.text.trim(),
            'account_role': role,
            'active': active,
            'office_ids': offices.toList(),
          },
        );
      }
      password.clear();
      final changedOwnAccount =
          a != null && a['id'] == widget.session.profile?['id'];
      if (mounted) Navigator.pop(context);
      if (changedOwnAccount) await widget.session.signOut();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Account operation failed. Close and reload before retrying. Password operations may require administrator recovery.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.account == null ? 'Create staff account' : 'Manage staff account',
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: username,
              enabled: widget.account == null && !busy,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: display,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            DropdownButtonFormField<String>(
              initialValue: role,
              items: [
                'STAFF',
                'ADMIN',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: busy ? null : (r) => setState(() => role = r!),
            ),
            if (widget.account != null)
              SwitchListTile(
                title: const Text('Account active'),
                value: active,
                onChanged: busy ? null : (v) => setState(() => active = v),
              ),
            const Text('Office assignments'),
            for (final o in widget.session.profile!['offices'] as List)
              CheckboxListTile(
                title: Text(o['name']),
                value: offices.contains(o['id']),
                onChanged: busy
                    ? null
                    : (v) => setState(
                        () => v == true
                            ? offices.add(o['id'])
                            : offices.remove(o['id']),
                      ),
              ),
            const Text('Staff need at least one office to sign in.'),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Temporary password (12–128 characters)',
              ),
            ),
            if (error != null) Text(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (widget.account != null)
        TextButton(
          onPressed: busy ? null : () => submit(true),
          child: const Text('Reset password'),
        ),
      FilledButton(
        onPressed: busy ? null : () => submit(false),
        child: Text(widget.account == null ? 'Create' : 'Save account'),
      ),
    ],
  );
}
