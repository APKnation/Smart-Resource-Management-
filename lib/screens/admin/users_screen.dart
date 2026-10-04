import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  late Future<List<Profile>> _future;
  String _query = '';

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _reload();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.admin.users(search: _query);
  }

  Future<void> _changeRole(Profile p, UserRole? role) async {
    if (role == null || role == p.role) return;
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.admin.setUserRole(p.id, role);
      messenger.showSnackBar(SnackBar(
          content: Text('${p.fullName} is now ${role.label}.')));
      setState(_reload);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _toggleActive(Profile p) async {
    final app = AppStateScope.of(context);
    await app.admin.setUserActive(p.id, !p.isActive);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search users by name or email…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (v) {
                      _query = v;
                      setState(_reload);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Profile>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: () => setState(_reload));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snap.data!;
                if (users.isEmpty) {
                  return const EmptyState(
                      icon: Icons.groups_outlined, title: 'No users found');
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final p = users[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(initialsOf(p.fullName.isEmpty
                              ? p.email
                              : p.fullName)),
                        ),
                        title: Text(p.fullName.isEmpty ? p.email : p.fullName),
                        subtitle: Text(
                            '${p.email}${p.department != null ? ' · ${p.department}' : ''}'),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<UserRole>(
                              value: p.role,
                              underline: const SizedBox(),
                              items: [
                                for (final r in UserRole.values)
                                  DropdownMenuItem(
                                      value: r, child: Text(r.label)),
                              ],
                              onChanged: (r) => _changeRole(p, r),
                            ),
                            Switch(
                              value: p.isActive,
                              onChanged: (_) => _toggleActive(p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
