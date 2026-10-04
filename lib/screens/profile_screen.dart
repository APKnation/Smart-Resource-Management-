import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../core/utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _fullName = TextEditingController();
  final _department = TextEditingController();
  final _institution = TextEditingController();
  final _newPassword = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final me = AppStateScope.of(context).me;
    _fullName.text = me?.fullName ?? '';
    _department.text = me?.department ?? '';
    _institution.text = me?.institution ?? '';
  }

  @override
  void dispose() {
    for (final c in [_fullName, _department, _institution, _newPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.auth.updateOwnProfile(
        fullName: _fullName.text.trim(),
        department: _department.text.trim().isEmpty ? null : _department.text.trim(),
        institution:
            _institution.text.trim().isEmpty ? null : _institution.text.trim(),
      );
      await app.refreshProfile();
      messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 8 characters.')));
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppStateScope.of(context).auth.updatePassword(_newPassword.text);
      _newPassword.clear();
      messenger.showSnackBar(
          const SnackBar(content: Text('Password changed.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final me = app.me;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      body: Center(
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 16, vertical: 16),
          shrinkWrap: true,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        child: Text(initialsOf(me?.fullName ?? '?'),
                            style: const TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me?.fullName.isEmpty == true
                                    ? (me?.email ?? '')
                                    : (me?.fullName ?? ''),
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(me?.email ?? '',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(me?.role.label ?? '',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Account details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fullName,
                    decoration:
                        const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _department,
                    decoration: const InputDecoration(
                        labelText: 'Department'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _institution,
                    decoration: const InputDecoration(
                        labelText: 'Institution'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save profile'),
                  ),
                  const SizedBox(height: 24),
                  Text('Change password',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'New password (min 8 characters)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _changePassword,
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Update password'),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Sign out?'),
                          content: const Text(
                              'You will need to sign in again to access resources.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sign out')),
                          ],
                        ),
                      );
                      if (ok == true && mounted) {
                        await app.signOut();
                        if (mounted) context.go(Routes.login);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
