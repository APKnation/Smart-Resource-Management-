import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_state.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
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
    _future = app.resources
        .list(const ResourceQuery(status: ResourceStatus.pending, limit: 200));
  }

  Future<void> _decide(Resource r, bool approve) async {
    final app = AppStateScope.of(context);
    await app.resources.setStatus(
        r.id, approve ? ResourceStatus.approved : ResourceStatus.rejected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve
          ? '"${r.title}" approved.'
          : '"${r.title}" rejected.'),
    ));
    setState(_reload);
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
                    child: Text('Approval queue',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: () => setState(_reload))
                  else if (!snap.hasData)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (snap.data!.isEmpty)
                    const Expanded(
                      child: EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'Queue is clear',
                        message: 'No resources awaiting review.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in snap.data!)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              child: ListTile(
                                onTap: () => context
                                    .push('${Routes.resources}/${r.id}'),
                                leading: Icon(iconForType(
                                    r.resourceType.name, r.fileName)),
                                title: Text(r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    '${r.uploader?.fullName ?? 'Unknown'} · '
                                    '${r.resourceType.label} · ${r.fileName ?? 'link'}'),
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    IconButton(
                                      tooltip: 'Approve',
                                      onPressed: () => _decide(r, true),
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                    ),
                                    IconButton(
                                      tooltip: 'Reject',
                                      onPressed: () => _decide(r, false),
                                      icon: const Icon(Icons.cancel,
                                          color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
