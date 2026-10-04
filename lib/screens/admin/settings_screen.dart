import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../widgets/widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late Future<Map<String, dynamic>> _future;
  final _siteName = TextEditingController();
  final _maxSize = TextEditingController();
  bool _allowRegistration = true;
  bool _requireApproval = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _siteName.dispose();
    _maxSize.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final app = AppStateScope.of(context);
    final s = await app.admin.settings();
    _siteName.text = (s['site_name'] ?? 'E-Resource Portal').toString().replaceAll('"', '');
    _maxSize.text = ((s['max_file_size_mb'] ?? 100) as num).toString();
    _allowRegistration = _toBool(s['allow_self_registration'], true);
    _requireApproval = _toBool(s['require_approval'], true);
    return s;
  }

  bool _toBool(dynamic v, bool fallback) {
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.admin.saveSetting('site_name', _siteName.text.trim());
      await app.admin
          .saveSetting('max_file_size_mb', int.tryParse(_maxSize.text) ?? 100);
      await app.admin
          .saveSetting('allow_self_registration', _allowRegistration);
      await app.admin.saveSetting('require_approval', _requireApproval);
      await app.refreshSettings();
      messenger.showSnackBar(
          const SnackBar(content: Text('Settings saved.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _broadcast() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast notification'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title,
                  decoration: const InputDecoration(labelText: 'Title *')),
              const SizedBox(height: 12),
              TextField(controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final app = AppStateScope.of(context);
    try {
      await app.admin.broadcast(title.text.trim(), body.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Broadcast sent to all active users.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 24 : 16, vertical: 16),
                children: [
                  Text('System settings',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()))
                  else if (snap.connectionState == ConnectionState.waiting)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    TextField(
                      controller: _siteName,
                      decoration:
                          const InputDecoration(labelText: 'Site name'),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow self-registration'),
                      subtitle: const Text(
                          'Users can create their own accounts (role: User).'),
                      value: _allowRegistration,
                      onChanged: (v) =>
                          setState(() => _allowRegistration = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Require resource approval'),
                      subtitle: const Text(
                          'Uploads by Staff stay pending until approved.'),
                      value: _requireApproval,
                      onChanged: (v) => setState(() => _requireApproval = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _maxSize,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max file size (MB)',
                          helperText: 'Applied client-side on upload'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save settings'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Communications',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _broadcast,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Send broadcast notification'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
