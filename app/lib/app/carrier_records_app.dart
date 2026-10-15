import 'package:carrier_records/app/karvaan_choice_field.dart';
import 'package:carrier_records/app/bilingual.dart';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../features/auth/staff_session.dart';
import '../features/auth/account_error.dart';
import 'strings.dart';
import 'karvaan_design.dart';
import 'workspace_shell.dart';

String tripScope(Map<String, dynamic>? profile) {
  final ids =
      (profile?['offices'] as List? ?? [])
          .map((o) => o['id'].toString())
          .toList()
        ..sort();
  return '${profile?['id']}:${profile?['role']}:$ids';
}

class CarrierRecordsApp extends StatefulWidget {
  const CarrierRecordsApp({super.key, this.session, this.setupError});
  final StaffSession? session;
  final String? setupError;
  @override
  State<CarrierRecordsApp> createState() => _CarrierRecordsAppState();
}

class _CarrierRecordsAppState extends State<CarrierRecordsApp> {
  final _workspaceNavigator = GlobalKey<NavigatorState>();
  final _workspaceObserver = WorkspaceRouteObserver();
  late final GoRouter _router = GoRouter(
    routes: [
      ShellRoute(
        navigatorKey: _workspaceNavigator,
        observers: [_workspaceObserver],
        builder: (context, state, child) => WorkspaceShell(
          session: widget.session,
          navigatorKey: _workspaceNavigator,
          canReturnHome: () => _workspaceObserver.canReturnHome,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => widget.session == null
                ? Scaffold(
                    appBar: AppBar(
                      toolbarHeight:
                          88 * MediaQuery.textScalerOf(context).scale(1),
                      title: const BilingualText(L10n.brand),
                    ),
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: BilingualText(
                          (widget.setupError != null
                              ? ownedMessage(widget.setupError)
                              : L10n.askYourAdministratorToConfigureThisInstallationForStaff),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : StaffHome(session: widget.session!),
          ),
        ],
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
    theme: KarvaanDesign.theme(),
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
    } catch (error) {
      if (mounted) message = accountErrorMessage(error);
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
          toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
          title: const BilingualText(L10n.brand),
          actions: [
            if (p != null && p['must_change_password'] == true)
              TextButton(
                onPressed: busy ? null : () => run(widget.session.signOut),
                child: const BilingualCaption(L10n.signOut),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (p == null) ...[
                    const BilingualText(
                      L10n.staffSignIn,
                      style: TextStyle(fontSize: 24),
                    ),
                    const BilingualText(L10n.accountInstruction),
                    TextField(
                      controller: username,
                      enabled: !busy,
                      autocorrect: false,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(label: BilingualCaption(L10n.username)),
                      ),
                    ),
                    TextField(
                      controller: password,
                      enabled: !busy,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(label: BilingualCaption(L10n.password)),
                      ),
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
                      child: const BilingualCaption(L10n.signIn),
                    ),
                  ] else if (p['must_change_password'] == true) ...[
                    const BilingualText(
                      L10n.changeYourTemporaryPassword,
                      style: TextStyle(fontSize: 24),
                    ),
                    const BilingualText(
                      L10n.chooseANewPasswordOfToCharactersSignIn,
                    ),
                    TextField(
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(L10n.currentPassword),
                        ),
                      ),
                    ),
                    TextField(
                      controller: next,
                      obscureText: true,
                      enableSuggestions: false,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(L10n.newPassword),
                        ),
                      ),
                    ),
                    TextField(
                      controller: confirm,
                      obscureText: true,
                      enableSuggestions: false,
                      decoration: bilingualDecoration(
                        context,
                        InputDecoration(
                          label: BilingualCaption(L10n.confirmNewPassword),
                        ),
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
                      child: const BilingualCaption(L10n.changePassword),
                    ),
                  ] else ...[
                    BilingualText(
                      L10n.signedInAs.withValues([p['display_name']]),
                      style: const TextStyle(fontSize: 24),
                    ),
                    BilingualText(
                      (p['role'] == 'ADMIN'
                          ? L10n.administratorAllOffices
                          : L10n.assignedOffices.withValues([
                              (p['offices'] as List)
                                  .map((o) => o['name'])
                                  .join(', '),
                            ])),
                    ),
                    const SizedBox(height: 16),
                    if (p['role'] == 'ADMIN')
                      AccountsPanel(session: widget.session),
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () => run(() async {
                              await showDialog<void>(
                                animationStyle: AnimationStyle.noAnimation,
                                context: context,
                                builder: (context) =>
                                    PasswordDialog(session: widget.session),
                              );
                            }),
                      child: const BilingualCaption(L10n.changeMyPassword),
                    ),
                  ],
                  if (busy) const LinearProgressIndicator(),
                  if (message ?? widget.session.error case final String error)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: BilingualOwnedText(error),
                    ),
                ],
              ),
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
    scrollable: true,
    title: const BilingualText(L10n.changePassword),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: current,
          obscureText: true,
          decoration: bilingualDecoration(
            context,
            InputDecoration(label: BilingualCaption(L10n.currentPassword)),
          ),
        ),
        TextField(
          controller: next,
          obscureText: true,
          decoration: bilingualDecoration(
            context,
            InputDecoration(
              label: BilingualCaption(L10n.newPasswordCharacters),
            ),
          ),
        ),
        TextField(
          controller: confirm,
          obscureText: true,
          decoration: bilingualDecoration(
            context,
            InputDecoration(label: BilingualCaption(L10n.confirmPassword)),
          ),
        ),
        if (error != null) BilingualOwnedText(error!),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const BilingualCaption(L10n.cancel),
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
        child: const BilingualCaption(L10n.change),
      ),
    ],
  );
}

Bilingual accountStatusPresentation(Map<String, dynamic> account) =>
    L10n.labelValues.withValues([
      ownedMessage(account['role']),
      account['active'] ? L10n.accountStatusActive : L10n.accountStatusDisabled,
      account['must_change_password']
          ? L10n.passwordChangeRequiredSuffix
          : Bilingual.data(''),
    ]);

class AccountRow extends StatelessWidget {
  const AccountRow({super.key, required this.account, required this.onManage});
  final Map<String, dynamic> account;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => BilingualListTile(
    trailingBelow: true,
    title: Text('${account['display_name']} (${account['username']})'),
    subtitle: BilingualText(accountStatusPresentation(account)),
    trailing: TextButton(
      onPressed: onManage,
      child: const BilingualCaption(L10n.manage),
    ),
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
      animationStyle: AnimationStyle.noAnimation,
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
            child: const BilingualCaption(L10n.createStaffAccount),
          ),
          TextButton(
            onPressed: reload,
            child: const BilingualCaption(L10n.refreshAccounts),
          ),
        ],
      ),
      FutureBuilder(
        future: accounts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const BilingualText(
              L10n.accountsUnavailableVerifyYourSessionAndRetry,
            );
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return Column(
            children: snapshot.data!
                .map((a) => AccountRow(account: a, onManage: () => edit(a)))
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
    scrollable: true,
    title: BilingualText(
      (widget.account == null
          ? L10n.createStaffAccount
          : L10n.manageStaffAccount),
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
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.username)),
              ),
            ),
            TextField(
              controller: display,
              enabled: !busy,
              decoration: bilingualDecoration(
                context,
                InputDecoration(label: BilingualCaption(L10n.displayName)),
              ),
            ),
            KarvaanChoiceField<String>(
              initialValue: role,
              items: ['STAFF', 'ADMIN']
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: BilingualOwnedText(r),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : (r) => setState(() => role = r!),
            ),
            if (widget.account != null)
              SwitchListTile(
                title: const BilingualText(L10n.accountActive),
                value: active,
                onChanged: busy ? null : (v) => setState(() => active = v),
              ),
            const BilingualText(L10n.officeAssignments),
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
            const BilingualText(L10n.staffNeedAtLeastOneOfficeToSignIn),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              enableSuggestions: false,
              decoration: bilingualDecoration(
                context,
                InputDecoration(
                  label: BilingualCaption(L10n.temporaryPasswordCharacters),
                ),
              ),
            ),
            if (error != null) BilingualOwnedText(error!),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const BilingualCaption(L10n.cancel),
      ),
      if (widget.account != null)
        TextButton(
          onPressed: busy ? null : () => submit(true),
          child: const BilingualCaption(L10n.resetPassword),
        ),
      FilledButton(
        onPressed: busy ? null : () => submit(false),
        child: BilingualCaption(
          (widget.account == null ? L10n.create : L10n.saveAccount),
        ),
      ),
    ],
  );
}
