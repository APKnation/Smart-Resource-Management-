import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_state.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<_ReportData> _future;

  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      _future = _load();
    }
  }

  Future<_ReportData> _load() async {
    final app = AppStateScope.of(context);
    final results = await Future.wait([
      app.admin.counts(),
      app.admin.downloadsPerDay(days: 14),
      app.admin.popularByDownloads(limit: 8),
      app.admin.accessLogs(limit: 50),
    ]);
    return _ReportData(
      counts: results[0] as Map<String, int>,
      perDay: results[1] as Map<DateTime, int>,
      popular: results[2] as Map<String, int>,
      logs: results[3] as List<AccessLog>,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ReportData>(
        future: _future,
        builder: (context, snap) {
          final wide = MediaQuery.sizeOf(context).width >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: wide ? 24 : 16, vertical: 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Reports & analytics',
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snap.hasError)
                    ErrorView(error: snap.error!, onRetry: _reload)
                  else if (!snap.hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _buildStats(context, snap.data!.counts),
                    const SizedBox(height: 16),
                    _buildChart(context, snap.data!.perDay),
                    const SizedBox(height: 16),
                    _buildPopular(context, snap.data!.popular),
                    const SizedBox(height: 16),
                    _buildRecentActivity(context, snap.data!.logs),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(BuildContext context, Map<String, int> c) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatCard(
            label: 'Total resources',
            value: '${c['resources'] ?? 0}',
            icon: Icons.library_books_outlined),
        StatCard(
            label: 'Downloads',
            value: '${c['downloads'] ?? 0}',
            icon: Icons.download_outlined,
            color: Colors.purple),
        StatCard(
            label: 'Views',
            value: '${c['views'] ?? 0}',
            icon: Icons.visibility_outlined,
            color: Colors.blue),
        StatCard(
            label: 'Active users',
            value: '${c['activeUsers'] ?? 0}',
            icon: Icons.groups_outlined,
            color: Colors.teal),
      ],
    );
  }

  Widget _buildChart(BuildContext context, Map<DateTime, int> perDay) {
    final days = List.generate(14, (i) {
      final d = DateTime.now().subtract(Duration(days: 13 - i));
      return DateTime(d.year, d.month, d.day);
    });
    final values = [for (final d in days) (perDay[d] ?? 0).toDouble()];
    final maxV = values.fold(1.0, (a, b) => b > a ? b : a);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloads — last 14 days',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxV + 1,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true, reservedSize: 28),
                    ),
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) =>
                            _dayLabel(value, meta, days),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: values[i],
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayLabel(double value, TitleMeta meta, List<DateTime> days) {
    final idx = value.toInt();
    if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(DateFormat('MM/dd').format(days[idx]),
          style: const TextStyle(fontSize: 9)),
    );
  }

  Widget _buildPopular(BuildContext context, Map<String, int> popular) {
    if (popular.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.emoji_events_outlined),
          title: Text('No downloads recorded yet'),
        ),
      );
    }
    final maxCount = popular.values.fold(1, (a, b) => b > a ? b : a);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most downloaded resources',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in popular.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(entry.key,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: LinearProgressIndicator(
                        value: entry.value / maxCount,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text('${entry.value}',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<AccessLog> logs) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Recent access activity',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          if (logs.isEmpty)
            const ListTile(
              leading: Icon(Icons.timeline),
              title: Text('No activity yet'),
            )
          else
            for (final l in logs.take(20))
              ListTile(
                dense: true,
                leading: Icon(
                  l.action == 'download'
                      ? Icons.download_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                title: Text(l.resource?.title ?? '(deleted resource)',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(l.user?.fullName ?? l.user?.email ?? 'Unknown'),
                trailing: Text(formatDateOnly(l.createdAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
        ],
      ),
    );
  }
}

class _ReportData {
  final Map<String, int> counts;
  final Map<DateTime, int> perDay;
  final Map<String, int> popular;
  final List<AccessLog> logs;

  _ReportData({
    required this.counts,
    required this.perDay,
    required this.popular,
    required this.logs,
  });
}
