import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.notifications.list();
    app.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Scaffold(
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 24 : 16, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Notifications',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        TextButton(
                          onPressed: () async {
                            await app.notifications.markAllRead();
                            if (mounted) setState(_reload);
                          },
                          child: const Text('Mark all read'),
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
                        icon: Icons.notifications_off_outlined,
                        title: 'No notifications',
                        message: 'Updates about resources and system activity appear here.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        children: [
                          for (final n in snap.data!)
                            Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              color: n.read
                                  ? null
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.4),
                              child: ListTile(
                                leading: Icon(
                                  switch (n.type) {
                                    NotificationType.approved => Icons.check_circle_outline,
                                    NotificationType.rejected => Icons.cancel_outlined,
                                    NotificationType.newResource => Icons.fiber_new_outlined,
                                    NotificationType.updated => Icons.update_outlined,
                                    NotificationType.system => Icons.info_outline,
                                  },
                                ),
                                title: Text(n.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (n.body?.isNotEmpty == true)
                                      Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    Text(formatDate(n.createdAt),
                                        style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                                onTap: () async {
                                  if (!n.read) {
                                    await app.notifications.markRead(n.id);
                                    app.refreshUnread();
                                  }
                                  final link = n.link;
                                  if (link != null && link.startsWith('/')) {
                                    context.go(link);
                                  } else if (mounted) {
                                    setState(_reload);
                                  }
                                },
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
