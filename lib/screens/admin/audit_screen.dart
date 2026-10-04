import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  late Future<List<AuditLog>> _future;

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
    _future = app.admin.auditLogs(limit: 300);
  }

  IconData _iconFor(String action) => switch (action) {
        'create' => Icons.add_circle_outline,
        'update' => Icons.edit_outlined,
        'delete' => Icons.delete_outline,
        'download' => Icons.download_outlined,
        'view' => Icons.visibility_outlined,
        'approve' => Icons.check_circle_outline,
        'reject' => Icons.cancel_outlined,
        'login' => Icons.login_outlined,
        'logout' => Icons.logout_outlined,
        'archive' => Icons.archive_outlined,
        'restore' => Icons.restore_outlined,
        _ => Icons.circle_outlined,
      };

  Color _colorFor(String action) => switch (action) {
        'create' || 'approve' || 'restore' => Colors.green,
        'delete' || 'reject' => Colors.red,
        'update' => Colors.orange,
        'download' => Colors.purple,
        'view' => Colors.blue,
        _ => Colors.blueGrey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<AuditLog>>(
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
                          child: Text('Audit trail',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => setState(_reload),
                          icon: const Icon(Icons.refresh),
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
                        icon: Icons.receipt_long_outlined,
                        title: 'No audit entries',
                        message: 'Important activities will be recorded here.',
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: snap.data!.length,
                        itemBuilder: (context, i) {
                          final log = snap.data![i];
                          return ListTile(
                            dense: true,
                            leading: Icon(_iconFor(log.action),
                                color: _colorFor(log.action)),
                            title: Text(
                              '${log.action.toUpperCase()} · ${log.entity}'
                              '${log.entityLabel != null ? ' — ${log.entityLabel}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                                '${log.actorEmail ?? 'System'} · ${formatDate(log.createdAt)}'),
                          );
                        },
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
