import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late Future<List<Role>> _future;

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _reload();
    }
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.admin.roles();
  }

  Future<void> _editRole([Role? role]) async {
    final name = TextEditingController(text: role?.name ?? '');
    final desc = TextEditingController(text: role?.description ?? '');
    final perms = TextEditingController(text: role?.permissions.join(', ') ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(role == null ? 'New role' : 'Edit role'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration:
                    const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: perms,
                decoration: const InputDecoration(
                  labelText: 'Permissions (comma separated)',
                  hintText: 'resource.upload, resource.approve, …',
                ),
                minLines: 2,
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.admin.upsertRole(
        id: role?.id,
        name: name.text.trim(),
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        permissions: perms.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Role saved.')));
      setState(_reload);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteRole(Role role) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(context,
        title: 'Delete role "${role.name}"?',
        message: 'Users keep their core enum role; this removes the custom role record.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    if (!mounted) return;
    final app = AppStateScope.of(context);
    try {
      await app.admin.deleteRole(role.id);
      setState(_reload);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Role>>(
        future: _future,
        builder: (context, snap) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 24 : 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Roles & permissions',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        FilledButton.icon(
                          onPressed: () => _editRole(),
                          icon: const Icon(Icons.add),
                          label: const Text('New role'),
                        ),
                      ],
                    ),
                  ),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: () => setState(_reload))
                  else if (!snap.hasData)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final role in snap.data!)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: ExpansionTile(
                                leading: const Icon(Icons.verified_user_outlined),
                                title: Text(role.name),
                                subtitle: Text(role.description ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (role.isSystem)
                                      const Tooltip(
                                        message: 'System role',
                                        child: Icon(Icons.lock_outline,
                                            size: 18),
                                      )
                                    else ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20),
                                        onPressed: () => _editRole(role),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20, color: Colors.red),
                                        onPressed: () => _deleteRole(role),
                                      ),
                                    ],
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final p in role.permissions)
                                          Chip(
                                            visualDensity:
                                                VisualDensity.compact,
                                            label: Text(p,
                                                style: const TextStyle(
                                                    fontSize: 11)),
                                          ),
                                        if (role.permissions.isEmpty)
                                          Text('No permissions defined',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
      },
      ),
    );
  }
}
