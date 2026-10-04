import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ResourceDetailScreen extends StatefulWidget {
  const ResourceDetailScreen({super.key, required this.resourceId});

  final String resourceId;

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen> {
  late Future<Resource> _future;
  late Future<List<ResourceVersion>> _versionsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final app = AppStateScope.of(context);
    _future = app.resources.get(widget.resourceId);
    _versionsFuture = app.resources.versions(widget.resourceId);
  }

  Future<void> _openFile(Resource r, {required bool download}) async {
    final app = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await app.resources.signedUrl(r, download: download);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(
            const SnackBar(content: Text('No app available to open this file.')));
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not open file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return FutureBuilder<Resource>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(error: snap.error!, onRetry: _reload);
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = snap.data!;
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final canEdit = app.canManageResources ||
            (app.canUpload && r.uploadedBy == app.me?.id);
        final canDelete = app.canManageResources;
        final canModerate = app.canApprove;
        final fav = app.isFavorite(r.id);

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (r.isDownloadable && r.storagePath != null)
              FilledButton.icon(
                onPressed: () => _openFile(r, download: false),
                icon: const Icon(Icons.visibility),
                label: const Text('View'),
              ),
            if (r.isDownloadable && r.storagePath != null)
              OutlinedButton.icon(
                onPressed: () => _openFile(r, download: true),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            if (r.externalUrl != null && r.externalUrl!.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openFile(r, download: false),
                icon: const Icon(Icons.link),
                label: const Text('Open link'),
              ),
            IconButton.filledTonal(
              tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () async {
                await app.toggleFavorite(r.id);
                if (mounted) setState(() {});
              },
              icon: Icon(fav ? Icons.star : Icons.star_border,
                  color: fav ? Colors.amber : null),
            ),
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () async {
                  await context.push('${Routes.resources}/${r.id}/edit');
                  if (mounted) setState(() => _reload());
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),
            if (canDelete)
              IconButton.filledTonal(
                tooltip: 'Delete',
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      title: 'Delete resource?',
                      message:
                          'This permanently removes "${r.title}" and its file.',
                      confirmLabel: 'Delete',
                      destructive: true);
                  if (!ok || !mounted) return;
                  await app.resources.delete(r.id);
                  if (!mounted) return;
                  if (context.mounted) context.go(Routes.resources);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
          ],
        );

        final info = <(String, String)>[
          ('Type', r.resourceType.label),
          ('Status', r.status.label),
          ('Availability', r.availability.label),
          ('Version', 'v${r.version}'),
          ('Author', r.author?.isNotEmpty == true ? r.author! : '—'),
          ('File', r.fileName ?? (r.externalUrl != null ? 'External link' : '—')),
          ('Size', formatBytes(r.fileSize)),
          ('Uploaded by', r.uploader?.fullName ?? '—'),
          ('Uploaded', formatDate(r.createdAt)),
          ('Updated', formatDate(r.updatedAt)),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorForType(context, r.resourceType.name)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                            iconForType(r.resourceType.name, r.fileName),
                            size: 36,
                            color: colorForType(context, r.resourceType.name)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title,
                                style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                StatusChip(status: r.status),
                                AvailabilityChip(availability: r.availability),
                                for (final c in r.categories)
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(c.name,
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  actions,
                  const SizedBox(height: 16),
                  if (r.description?.isNotEmpty == true) ...[
                    Text('Description',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(r.description!),
                    const SizedBox(height: 16),
                  ],
                  Text('Details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final (i, e) in info.indexed)
                          ListTile(
                            dense: true,
                            leading: Text(e.$1,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            title: Align(
                              alignment: Alignment.centerRight,
                              child: Text(e.$2),
                            ),
                            trailing: const SizedBox(width: 0),
                            subtitle: i == info.length - 1 ? const SizedBox(height: 0) : null,
                          ),
                      ],
                    ),
                  ),
                  if (canModerate) ...[
                    const SizedBox(height: 16),
                    Text('Moderation',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in ResourceStatus.values)
                              if (s != r.status)
                                OutlinedButton(
                                  onPressed: () async {
                                    await app.resources.setStatus(r.id, s);
                                    if (mounted) setState(_reload);
                                  },
                                  child: Text('Mark ${s.label}'),
                                ),
                            const SizedBox(width: 8),
                            for (final a in ResourceAvailability.values)
                              if (a != r.availability)
                                OutlinedButton(
                                  onPressed: () async {
                                    await app.resources.setAvailability(r.id, a);
                                    if (mounted) setState(_reload);
                                  },
                                  child: Text('Set ${a.label}'),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Versions',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _VersionsSection(
                    resource: r,
                    versionsFuture: _versionsFuture,
                    onChanged: () => setState(_reload),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VersionsSection extends StatelessWidget {
  const _VersionsSection({
    required this.resource,
    required this.versionsFuture,
    required this.onChanged,
  });

  final Resource resource;
  final Future<List<ResourceVersion>> versionsFuture;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppStateScope.of(context);
    return Card(
      child: FutureBuilder<List<ResourceVersion>>(
        future: versionsFuture,
        builder: (context, snap) {
          final versions = snap.data ?? const <ResourceVersion>[];
          return Column(
            children: [
              if (snap.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (versions.isEmpty)
                const ListTile(
                  leading: Icon(Icons.history),
                  title: Text('No prior versions'),
                  subtitle: Text('Version history appears when files are replaced.'),
                )
              else
                for (final v in versions)
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('Version ${v.version}'),
                    subtitle: Text(
                        '${v.fileName ?? ''} · ${formatBytes(v.fileSize)} · ${formatDate(v.createdAt)}'
                        '${v.notes?.isNotEmpty == true ? '\n${v.notes}' : ''}'),
                    isThreeLine: v.notes?.isNotEmpty == true,
                    trailing: app.canManageResources
                        ? TextButton(
                            onPressed: () async {
                              final ok = await confirmDialog(context,
                                  title: 'Restore version ${v.version}?',
                                  message:
                                      'The current file will be snapshotted first.');
                              if (ok) {
                                await app.resources.restoreVersion(v);
                                onChanged();
                              }
                            },
                            child: const Text('Restore'),
                          )
                        : null,
                  ),
            ],
          );
        },
      ),
    );
  }
}
