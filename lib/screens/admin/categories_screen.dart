import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<Category>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.resources.categories();
  }

  Future<void> _editCategory([Category? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    String type = existing?.type ?? 'subject';
    String? parentId = existing?.parentId;
    final cats = await app_categories();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(existing == null ? 'New category' : 'Edit category'),
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
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type *'),
                  items: const [
                    DropdownMenuItem(value: 'subject', child: Text('Subject')),
                    DropdownMenuItem(value: 'type', child: Text('Type')),
                    DropdownMenuItem(value: 'department', child: Text('Department')),
                    DropdownMenuItem(value: 'institution', child: Text('Institution')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? 'subject'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentId,
                  decoration:
                      const InputDecoration(labelText: 'Parent (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final c in cats)
                      if (c.id != existing?.id)
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setDialog(() => parentId = v),
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
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await app.admin.upsertCategory(
        id: existing?.id,
        name: name.text.trim(),
        description: desc.text.trim().isEmpty ? null : desc.text.trim(),
        type: type,
        parentId: parentId,
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('Category saved.')));
      setState(_reload);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<List<Category>> app_categories() {
    final app = AppStateScope.of(context);
    return app.resources.categories();
  }

  Future<void> _delete(Category c) async {
    final ok = await confirmDialog(context,
        title: 'Delete "${c.name}"?',
        message: 'Resources keep their other categories; links to this one are removed.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    final app = AppStateScope.of(context);
    try {
      await app.admin.deleteCategory(c.id);
      setState(_reload);
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
      body: FutureBuilder<List<Category>>(
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
                          child: Text('Categories',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        FilledButton.icon(
                          onPressed: () => _editCategory(),
                          icon: const Icon(Icons.add),
                          label: const Text('New category'),
                        ),
                      ],
                    ),
                  ),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: () => setState(_reload))
                  else if (!snap.hasData)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (snap.data!.isEmpty)
                    const Expanded(
                      child: EmptyState(
                        icon: Icons.category_outlined,
                        title: 'No categories',
                        message: 'Create categories to organize resources.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final entry in _groupByType(snap.data!).entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(entry.key.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.bold)),
                            ),
                            for (final c in entry.value)
                              Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 3),
                                child: ListTile(
                                  leading: const Icon(Icons.label_outline),
                                  title: Text(c.name),
                                  subtitle: c.description == null
                                      ? null
                                      : Text(c.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _editCategory(c),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20, color: Colors.red),
                                        onPressed: () => _delete(c),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
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

  Map<String, List<Category>> _groupByType(List<Category> cats) {
    final map = <String, List<Category>>{};
    for (final c in cats) {
      map.putIfAbsent(c.type, () => []).add(c);
    }
    return map;
  }
}
