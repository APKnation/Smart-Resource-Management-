import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../services/hrms_service.dart';

class HrmsDashboardScreen extends StatefulWidget {
  const HrmsDashboardScreen({super.key});
  @override
  State<HrmsDashboardScreen> createState() => _HrmsDashboardScreenState();
}

class _HrmsDashboardScreenState extends State<HrmsDashboardScreen> {
  final _service = HrmsService();
  late Future<List<HrmsHospital>> _hospitals;
  String? _hospitalId;
  Set<String> _roles = {};
  Future<HrmsDashboardData>? _data;

  @override
  void initState() {
    super.initState();
    _hospitals = _service.hospitals();
  }

  void _selectHospital(HrmsHospital? hospital) {
    if (hospital == null) return;
    setState(() {
      _hospitalId = hospital.id;
      _roles = hospital.roles;
      _data = _service.dashboard(hospital.id);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HrmsHospital>>(
    future: _hospitals,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return _DashboardMessage(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your hospitals',
          message: '${snapshot.error}',
          action: TextButton.icon(
            onPressed: () => setState(() => _hospitals = _service.hospitals()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        );
      if (!snapshot.hasData)
        return const Center(child: CircularProgressIndicator());
      final hospitals = snapshot.data!;
      if (hospitals.isEmpty)
        return const _DashboardMessage(
          icon: Icons.domain_disabled_outlined,
          title: 'No hospital access',
          message: 'Ask a hospital administrator to assign you an active membership.',
        );
      if (_hospitalId == null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _selectHospital(hospitals.first),
        );
      }
      final hospital =
          hospitals.where((h) => h.id == _hospitalId).firstOrNull ??
          hospitals.first;
      return RefreshIndicator(
        onRefresh: () async {
          if (_hospitalId != null)
            setState(() => _data = _service.dashboard(_hospitalId!));
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _welcome(context, hospital, hospitals),
            const SizedBox(height: 20),
            _rolePanel(context),
            const SizedBox(height: 20),
            if (_data == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              FutureBuilder<HrmsDashboardData>(
                future: _data,
                builder: (context, data) {
                  if (data.hasError)
                    return _DashboardMessage(
                      icon: Icons.error_outline,
                      title: 'Dashboard data is unavailable',
                      message: '${data.error}',
                      action: TextButton(
                        onPressed: () => setState(
                          () => _data = _service.dashboard(hospital.id),
                        ),
                        child: const Text('Retry'),
                      ),
                    );
                  if (!data.hasData)
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  return _dashboardContent(context, data.data!);
                },
              ),
          ],
        ),
      );
    },
  );

  Widget _welcome(
    BuildContext context,
    HrmsHospital hospital,
    List<HrmsHospital> hospitals,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hospital overview',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        'A role-based view of stock, activity, and operational alerts.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DropdownButtonFormField<String>(
          key: ValueKey(_hospitalId),
          initialValue: hospital.id,
          decoration: const InputDecoration(
            labelText: 'Hospital',
            prefixIcon: Icon(Icons.local_hospital_outlined),
          ),
          items: [
            for (final h in hospitals)
              DropdownMenuItem(value: h.id, child: Text(h.name)),
          ],
          onChanged: (id) =>
              _selectHospital(hospitals.where((h) => h.id == id).firstOrNull),
        ),
      ),
    ],
  );

  Widget _rolePanel(BuildContext context) {
    final labels = _roles.map(_roleLabel).toList()..sort();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your workspace',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(_roleSummary(_roles)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in labels)
                  Chip(
                    avatar: const Icon(Icons.verified_user_outlined, size: 16),
                    label: Text(label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardContent(BuildContext context, HrmsDashboardData data) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metrics(context, data),
          const SizedBox(height: 24),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _quickActions(context),
          const SizedBox(height: 24),
          if (_roles.contains('pharmacist') ||
              _roles.contains('inventory_manager') ||
              _roles.contains('hospital_admin')) ...[
            Text(
              'Medicine safety',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _expiryAlerts(context, data),
            const SizedBox(height: 24),
          ],
          Text(_lowStockHeading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _lowStockList(context, data),
          const SizedBox(height: 24),
          Text(_activityHeading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _movementList(context, data),
        ],
      );

  Widget _metrics(BuildContext context, HrmsDashboardData data) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 340
              ? 2
              : 1;
          const gap = 12.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          final cards = <Widget>[
            _MetricCard(
              title: 'Active item types',
              value: '${data.items.length}',
              icon: Icons.inventory_2_outlined,
              color: Colors.blue,
            ),
            _MetricCard(
              title: 'Low stock',
              value: '${data.lowStockItems.length}',
              icon: Icons.warning_amber_outlined,
              color: data.lowStockItems.isEmpty
                  ? Colors.green
                  : Colors.deepOrange,
            ),
            _MetricCard(
              title: 'Item types in stock',
              value: '${data.stockedItemsCount}',
              icon: Icons.stacked_bar_chart,
              color: Colors.teal,
            ),
            _MetricCard(
              title: 'Recent movements',
              value: '${data.recentMovements.length}',
              icon: Icons.swap_horiz,
              color: Colors.purple,
            ),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final card in cards) SizedBox(width: width, child: card),
            ],
          );
        },
      );

  Widget _quickActions(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      if (_roles.contains('hospital_admin'))
        _ActionCard(
          icon: Icons.domain_outlined,
          title: 'Manage facilities',
          subtitle: 'Departments and warehouses',
          onTap: () => context.go(Routes.facilities),
        ),
      if (_canManageInventory)
        _ActionCard(
          icon: Icons.add_box_outlined,
          title: 'Manage inventory',
          subtitle: 'Catalog and stock levels',
          onTap: () => context.go(Routes.inventory),
        ),
      if (_canMoveStock)
        _ActionCard(
          icon: Icons.swap_horiz,
          title: 'Stock movements',
          subtitle: 'Receipts, issues, and adjustments',
          onTap: () => context.go(Routes.movements),
        ),
      if (_roles.contains('auditor') || _roles.contains('finance_officer'))
        _ActionCard(
          icon: Icons.fact_check_outlined,
          title: 'Review activity',
          subtitle: 'Recent stock movement history',
          onTap: () => context.go(Routes.movements),
        ),
      if (_roles.contains('procurement_officer'))
        _ActionCard(
          icon: Icons.shopping_cart_outlined,
          title: 'Replenishment signals',
          subtitle: 'Review low-stock items',
          onTap: () => context.go(Routes.inventory),
        ),
      if (_roles.contains('department_head') ||
          _roles.contains('healthcare_worker'))
        _ActionCard(
          icon: Icons.search,
          title: 'Check availability',
          subtitle: 'View current stock by location',
          onTap: () => context.go(Routes.inventory),
        ),
      if (_roles.contains('biomedical_engineer'))
        const _ActionCard(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Equipment workspace',
          subtitle: 'Equipment registry is not enabled yet',
        ),
    ],
  );

  Widget _expiryAlerts(BuildContext context, HrmsDashboardData data) => Card(
    child: Column(
      children: [
        ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.event_available_outlined),
          ),
          title: const Text('Expiring within 30 days'),
          trailing: Text(
            '${data.expiringBatchCount}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: CircleAvatar(
            child: Icon(
              data.expiredBatchCount > 0
                  ? Icons.warning_amber_outlined
                  : Icons.check_circle_outline,
              color: data.expiredBatchCount > 0
                  ? Colors.deepOrange
                  : Colors.green,
            ),
          ),
          title: const Text('Expired batches'),
          trailing: Text(
            '${data.expiredBatchCount}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    ),
  );

  Widget _lowStockList(BuildContext context, HrmsDashboardData data) {
    if (data.lowStockItems.isEmpty)
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline, color: Colors.green),
          title: Text('No low-stock items'),
        ),
      );
    return Card(
      child: Column(
        children: [
          for (final item in data.lowStockItems.take(6))
            ListTile(
              leading: const Icon(
                Icons.warning_amber_outlined,
                color: Colors.deepOrange,
              ),
              title: Text(item.name),
              subtitle: Text(
                '${item.code} · minimum ${_quantity(item.minimumStock)} ${item.unit}',
              ),
              trailing: Text(
                '${_quantity(item.quantity)} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          if (data.lowStockItems.length > 6)
            TextButton(
              onPressed: () => context.go(Routes.inventory),
              child: Text(
                'View all ${data.lowStockItems.length} low-stock items',
              ),
            ),
        ],
      ),
    );
  }

  Widget _movementList(BuildContext context, HrmsDashboardData data) {
    if (data.recentMovements.isEmpty)
      return const Card(
        child: ListTile(
          leading: Icon(Icons.history),
          title: Text('No stock movement has been recorded yet.'),
        ),
      );
    return Card(
      child: Column(
        children: [
          for (final row in data.recentMovements.take(6))
            ListTile(
              leading: Icon(_movementIcon(row['kind'] as String? ?? '')),
              title: Text(
                '${row['kind']} · ${_relationName(row['inventory_items'], 'name')}',
              ),
              subtitle: Text(
                '${_relationName(row['warehouses'], 'name')} · ${row['reason'] ?? ''}',
              ),
              trailing: Text(
                '${_quantity((row['quantity'] as num?)?.toDouble() ?? 0)}',
              ),
            ),
          TextButton(
            onPressed: () => context.go(Routes.movements),
            child: const Text('View movement history'),
          ),
        ],
      ),
    );
  }

  bool get _canManageInventory => _roles.any(
    const {'hospital_admin', 'inventory_manager', 'pharmacist'}.contains,
  );
  bool get _canMoveStock => _roles.any(
    const {
      'hospital_admin',
      'inventory_manager',
      'storekeeper',
      'pharmacist',
    }.contains,
  );
  String get _lowStockHeading => _roles.contains('procurement_officer')
      ? 'Replenishment signals'
      : 'Low-stock alerts';
  String get _activityHeading =>
      _roles.contains('auditor') ? 'Audit activity' : 'Recent stock activity';

  String _roleLabel(String role) => switch (role) {
    'hospital_admin' => 'Hospital administrator',
    'inventory_manager' => 'Inventory manager',
    'storekeeper' => 'Storekeeper',
    'pharmacist' => 'Pharmacist',
    'procurement_officer' => 'Procurement officer',
    'department_head' => 'Department head',
    'healthcare_worker' => 'Healthcare worker',
    'biomedical_engineer' => 'Biomedical engineer',
    'finance_officer' => 'Finance officer',
    'auditor' => 'Auditor',
    _ => role,
  };

  String _roleSummary(Set<String> roles) {
    if (roles.contains('hospital_admin'))
      return 'Manage hospital locations and oversee inventory activity for your facility.';
    if (roles.contains('pharmacist'))
      return 'Monitor medicine batches and expiry alerts, and manage authorized pharmacy stock operations.';
    if (roles.contains('inventory_manager'))
      return 'Manage item records, monitor stock levels, and oversee authorized stock movements.';
    if (roles.contains('storekeeper'))
      return 'Review available stock and record authorized receipts, issues, and returns.';
    if (roles.contains('auditor'))
      return 'Review stock balances and inspect the recorded movement history.';
    if (roles.contains('finance_officer'))
      return 'Review inventory levels and stock activity for financial oversight.';
    if (roles.contains('procurement_officer'))
      return 'Use current stock and low-stock alerts to guide replenishment planning.';
    if (roles.contains('department_head'))
      return 'Review current resource availability for your hospital.';
    if (roles.contains('healthcare_worker'))
      return 'Check current resource availability at your hospital.';
    if (roles.contains('biomedical_engineer'))
      return 'Your equipment management workspace is being prepared.';
    return 'View hospital resource information available to your assigned role.';
  }

  String _relationName(dynamic relation, String key) {
    if (relation is Map<String, dynamic>)
      return relation[key]?.toString() ?? 'Unknown';
    if (relation is List && relation.isNotEmpty && relation.first is Map)
      return relation.first[key]?.toString() ?? 'Unknown';
    return 'Unknown';
  }

  IconData _movementIcon(String kind) => switch (kind) {
    'receipt' || 'return' || 'transfer_in' => Icons.south_west,
    'issue' || 'wastage' || 'transfer_out' => Icons.north_east,
    _ => Icons.tune,
  };

  String _quantity(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(3);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(title, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
