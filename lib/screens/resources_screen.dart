import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _searchController = TextEditingController();
  ResourceType? _type;
  Category? _category;
  bool _favoritesOnly = false;
  String _search = '';
  late Future<List<Resource>> _future;

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _future = _load();
    }
  }

  Future<List<Resource>> _load() async {
    final app = AppStateScope.of(context);
    return app.resources.list(ResourceQuery(
      search: _search,
      type: _type,
      categoryId: _category?.id,
      onlyFavorites: _favoritesOnly,
    ));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by title, description, author…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _search = '';
                                    _reload();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (v) {
                          _search = v;
                          _reload();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Filter',
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('My favorites'),
                        selected: _favoritesOnly,
                        onSelected: (v) {
                          _favoritesOnly = v;
                          _reload();
                        },
                      ),
                      const SizedBox(width: 8),
                      if (_type != null)
                        Chip(
                          label: Text('Type: ${_type!.label}'),
                          onDeleted: () {
                            _type = null;
                            _reload();
                          },
                        ),
                      if (_category != null)
                        Chip(
                          label: Text('Category: ${_category!.name}'),
                          onDeleted: () {
                            _category = null;
                            _reload();
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Resource>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No resources found',
                    message: 'Try adjusting your search or filters.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) => ResourceCard(
                      resource: items[i],
                      isFavorite: app.isFavorite(items[i].id),
                      onToggleFavorite: () async {
                        await app.toggleFavorite(items[i].id);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters() async {
    final app = AppStateScope.of(context);
    ResourceType? type = _type;
    Category? category = _category;
    final cats = await app.resources.categories();
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<ResourceType>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Resource type'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any type')),
                  for (final t in ResourceType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setSheet(() => type = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Category>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Any category')),
                  for (final c in cats)
                    DropdownMenuItem(
                        value: c, child: Text('${c.type}: ${c.name}')),
                ],
                onChanged: (v) => setSheet(() => category = v),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      setState(() {
        _type = type;
        _category = category;
      });
      _reload();
    } else if (ok == false) {
      setState(() {
        _type = null;
        _category = null;
      });
      _reload();
    }
  }
}
