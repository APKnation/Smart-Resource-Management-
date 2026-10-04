import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../services/resource_service.dart';
import '../widgets/widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Resource>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.resources
        .list(const ResourceQuery(onlyFavorites: true, limit: 200));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      body: FutureBuilder<List<Resource>>(
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
                    child: Text('Favorites',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: () => setState(_reload))
                  else if (!snap.hasData)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (snap.data!.isEmpty)
                    Expanded(
                      child: EmptyState(
                        icon: Icons.star_border,
                        title: 'No favorites yet',
                        message: 'Tap the star on any resource to bookmark it.',
                        actionLabel: 'Browse resources',
                        onAction: () => context.push(Routes.resources),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in snap.data!)
                            ResourceCard(
                              resource: r,
                              isFavorite: true,
                              onToggleFavorite: () async {
                                await app.toggleFavorite(r.id);
                                if (mounted) setState(_reload);
                              },
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
