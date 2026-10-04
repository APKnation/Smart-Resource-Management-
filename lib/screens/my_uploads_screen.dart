import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class MyUploadsScreen extends StatefulWidget {
  const MyUploadsScreen({super.key});

  @override
  State<MyUploadsScreen> createState() => _MyUploadsScreenState();
}

class _MyUploadsScreenState extends State<MyUploadsScreen> {
  late Future<List<Resource>> _future;
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
    _future = app.resources.list(const ResourceQuery(onlyMine: true, limit: 200));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Resource>>(
      future: _future,
      builder: (context, snap) {
        final wide = MediaQuery.sizeOf(context).width >= 900;
        return Scaffold(
          body: Center(
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
                          child: Text('My uploads',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            await context.push(Routes.upload);
                            if (mounted) setState(_reload);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Upload'),
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
                    Expanded(
                      child: EmptyState(
                        icon: Icons.upload_file_outlined,
                        title: 'Nothing uploaded yet',
                        message: 'Share your first resource with the institution.',
                        actionLabel: 'Upload resource',
                        onAction: () async {
                          await context.push(Routes.upload);
                          if (mounted) setState(_reload);
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in snap.data!)
                            ResourceCard(resource: r),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
