import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashData> _future;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _future = _load();
    }
  }

  Future<_DashData> _load() async {
    final app = AppStateScope.of(context);
    final results = await Future.wait([
      app.resources.list(const ResourceQuery(limit: 6)),
      app.admin.counts(),
      app.notifications.list(limit: 5),
      app.canApprove
          ? app.resources
              .list(const ResourceQuery(status: ResourceStatus.pending, limit: 5))
          : Future.value(<Resource>[]),
    ]);
    return _DashData(
      recent: results[0] as List<Resource>,
      counts: results[1] as Map<String, int>,
      notifications: results[2] as List<AppNotification>,
      pending: results[3] as List<Resource>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    final me = app.me;
    return FutureBuilder<_DashData>(
      future: _future,
      builder: (context, snap) {
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final content = <Widget>[
          Text(
            'Welcome back, ${me?.fullName.split(' ').first ?? 'there'} 👋',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(me?.role.label ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          if (snap.hasError)
            ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()))
          else if (!snap.hasData)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else ..._buildContent(context, app, snap.data!),
        ];
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: wide ? 24 : 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildContent(
      BuildContext context, AppState app, _DashData data) {
    final c = data.counts;
    return [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          StatCard(label: 'Resources', value: '${c['resources'] ?? 0}', icon: Icons.library_books_outlined),
          StatCard(label: 'Approved', value: '${c['approved'] ?? 0}', icon: Icons.check_circle_outline, color: Colors.green),
          StatCard(label: 'Downloads', value: '${c['downloads'] ?? 0}', icon: Icons.download_outlined, color: Colors.purple),
          StatCard(label: 'Users', value: '${c['users'] ?? 0}', icon: Icons.groups_outlined, color: Colors.teal),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => context.push(Routes.resources),
            icon: const Icon(Icons.search),
            label: const Text('Browse resources'),
          ),
          if (app.canUpload)
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.upload),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload resource'),
            ),
          if (app.canApprove && (c['pending'] ?? 0) > 0)
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.approvals),
              icon: const Icon(Icons.fact_check),
              label: Text('${c['pending']} pending approval'),
            ),
        ],
      ),
      if (app.canApprove && data.pending.isNotEmpty) ...[
        SectionHeader(
          title: 'Awaiting approval',
          trailing: TextButton(
              onPressed: () => context.push(Routes.approvals),
              child: const Text('Review all')),
        ),
        for (final r in data.pending)
          ResourceCard(resource: r),
      ],
      SectionHeader(
        title: 'Recently updated',
        trailing: TextButton(
            onPressed: () => context.push(Routes.resources),
            child: const Text('View all')),
      ),
      if (data.recent.isEmpty)
        const EmptyState(
          icon: Icons.library_books_outlined,
          title: 'No resources yet',
          message: 'Approved resources will appear here.',
        )
      else
        for (final r in data.recent) ResourceCard(resource: r),
      if (data.notifications.isNotEmpty) ...[
        SectionHeader(
          title: 'Latest notifications',
          trailing: TextButton(
              onPressed: () => context.push(Routes.notifications),
              child: const Text('View all')),
        ),
        Card(
          child: Column(
            children: [
              for (final n in data.notifications)
                ListTile(
                  leading: Icon(
                    switch (n.type) {
                      NotificationType.approved => Icons.check_circle_outline,
                      NotificationType.rejected => Icons.cancel_outlined,
                      NotificationType.newResource => Icons.fiber_new_outlined,
                      NotificationType.updated => Icons.update_outlined,
                      NotificationType.system => Icons.info_outline,
                    },
                    color: n.read ? null : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(n.title),
                  subtitle: Text(n.body ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ),
      ],
    ];
  }
}

class _DashData {
  final List<Resource> recent;
  final Map<String, int> counts;
  final List<AppNotification> notifications;
  final List<Resource> pending;

  _DashData({
    required this.recent,
    required this.counts,
    required this.notifications,
    required this.pending,
  });
}
