import 'package:flutter/material.dart';

import '../../services/hrms_service.dart';

enum HrmsModule {
  requests,
  transfers,
  procurement,
  equipment,
  maintenance,
  reports,
  users,
}

class HrmsWorkflowsScreen extends StatefulWidget {
  const HrmsWorkflowsScreen({super.key, required this.module});
  final HrmsModule module;
  @override
  State<HrmsWorkflowsScreen> createState() => _HrmsWorkflowsScreenState();
}

class _HrmsWorkflowsScreenState extends State<HrmsWorkflowsScreen> {
  final _service = HrmsService();
  late Future<List<HrmsHospital>> _hospitals;
  String? _hospitalId;
  Set<String> _roles = {};
  Future<List<Map<String, dynamic>>>? _rows;
  List<Map<String, dynamic>> _items = [],
      _departments = [],
      _suppliers = [],
      _assets = [];
  List<HrmsWarehouse> _warehouses = [];
  String get _title => switch (widget.module) {
    HrmsModule.requests => 'Resource requests',
    HrmsModule.transfers => 'Stock transfers',
    HrmsModule.procurement => 'Procurement',
    HrmsModule.equipment => 'Medical equipment',
    HrmsModule.maintenance => 'Maintenance',
    HrmsModule.reports => 'Hospital reports',
    HrmsModule.users => 'Users and roles',
  };

  @override
  void initState() {
    super.initState();
    _hospitals = _service.hospitals();
  }

  Future<List<Map<String, dynamic>>> _load(String id) async {
    switch (widget.module) {
      case HrmsModule.requests:
        _departments = await _service.departments(id);
        _items = (await _service.inventory(id))
            .map(
              (e) => {
                'id': e.id,
                'name': '${e.name} (${e.code})',
                'unit': e.unit,
              },
            )
            .toList();
        return _service.requests(id);
      case HrmsModule.transfers:
        _warehouses = await _service.warehouses(id);
        _items = (await _service.inventory(id))
            .map((e) => {'id': e.id, 'name': '${e.name} (${e.code})'})
            .toList();
        return _service.transfers(id);
      case HrmsModule.procurement:
        _departments = await _service.departments(id);
        _suppliers = await _service.suppliers(id);
        return _service.requisitions(id);
      case HrmsModule.equipment:
        _departments = await _service.departments(id);
        return _service.assets(id);
      case HrmsModule.maintenance:
        _assets = await _service.assets(id);
        return _service.maintenance(id);
      case HrmsModule.users:
        return _service.hospitalUsers(id);
      case HrmsModule.reports:
        final d = await _service.dashboard(id);
        return [
          {'_section': 'Inventory summary'},
          {'label': 'Catalog items', 'value': d.items.length},
          {'label': 'Items currently stocked', 'value': d.stockedItemsCount},
          {'label': 'Low or out of stock', 'value': d.lowStockItems.length},
          {
            'label': 'Batches expiring within 30 days',
            'value': d.expiringBatchCount,
          },
          {'label': 'Expired batches', 'value': d.expiredBatchCount},
          {'_section': 'Low stock items'},
          ...d.lowStockItems.map(
            (e) => {
              'label': e.name,
              'value':
                  '${e.quantity} ${e.unit} on hand · minimum ${e.minimumStock}',
            },
          ),
          {'_section': 'Recent stock activity'},
          ...d.recentMovements,
        ];
    }
  }

  void _select(HrmsHospital h) {
    setState(() {
      _hospitalId = h.id;
      _roles = h.roles;
      _rows = _load(h.id);
    });
  }

  bool get _admin => _roles.contains('hospital_admin');
  bool get _canCreate => switch (widget.module) {
    HrmsModule.requests => _roles.intersection({
      'hospital_admin',
      'inventory_manager',
      'storekeeper',
      'pharmacist',
      'department_head',
      'healthcare_worker',
    }).isNotEmpty,
    HrmsModule.transfers => _roles.intersection({
      'hospital_admin',
      'inventory_manager',
      'storekeeper',
    }).isNotEmpty,
    HrmsModule.procurement => _roles.intersection({
      'hospital_admin',
      'procurement_officer',
      'department_head',
      'inventory_manager',
    }).isNotEmpty,
    HrmsModule.equipment || HrmsModule.maintenance => _roles.intersection({
      'hospital_admin',
      'biomedical_engineer',
      'healthcare_worker',
    }).isNotEmpty,
    HrmsModule.users => _admin,
    HrmsModule.reports => false,
  };

  @override
  Widget build(BuildContext context) => FutureBuilder<List<HrmsHospital>>(
    future: _hospitals,
    builder: (context, s) {
      if (s.hasError)
        return Center(
          child: Text('Could not load hospital access: ${s.error}'),
        );
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final hospitals = s.data!;
      if (hospitals.isEmpty)
        return const Center(
          child: Text(
            'No active hospital membership is assigned to this account.',
          ),
        );
      if (_hospitalId == null)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hospitalId == null) _select(hospitals.first);
        });
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (widget.module == HrmsModule.procurement &&
                    _roles.intersection({
                      'hospital_admin',
                      'procurement_officer',
                    }).isNotEmpty)
                  IconButton(
                    tooltip: 'Add supplier',
                    onPressed: _supplierForm,
                    icon: const Icon(Icons.local_shipping_outlined),
                  ),
                if (_canCreate)
                  FilledButton.icon(
                    onPressed: () => _create(),
                    icon: const Icon(Icons.add),
                    label: Text(_createLabel),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _hospitalId,
              decoration: const InputDecoration(labelText: 'Hospital'),
              items: [
                for (final h in hospitals)
                  DropdownMenuItem(value: h.id, child: Text(h.name)),
              ],
              onChanged: (id) {
                final h = hospitals.where((x) => x.id == id).firstOrNull;
                if (h != null) _select(h);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _rows,
                builder: (context, data) {
                  if (data.hasError)
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Could not load $_title'),
                          TextButton(
                            onPressed: () =>
                                setState(() => _rows = _load(_hospitalId!)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  if (!data.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (data.data!.isEmpty)
                    return Center(
                      child: Text('No ${_title.toLowerCase()} yet.'),
                    );
                  return RefreshIndicator(
                    onRefresh: () async =>
                        setState(() => _rows = _load(_hospitalId!)),
                    child: ListView(
                      children: [for (final row in data.data!) _rowCard(row)],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  String get _createLabel => switch (widget.module) {
    HrmsModule.requests => 'New request',
    HrmsModule.transfers => 'Transfer stock',
    HrmsModule.procurement => 'New requisition',
    HrmsModule.equipment => 'Add equipment',
    HrmsModule.maintenance => 'Report issue',
    HrmsModule.users => 'Assign user',
    _ => 'Add',
  };

  Widget _rowCard(Map<String, dynamic> row) {
    if (row.containsKey('_section'))
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
        child: Text(
          '${row['_section']}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    final title = switch (widget.module) {
      HrmsModule.requests => '${row['purpose']}',
      HrmsModule.transfers =>
        '${_nested(row['inventory_items'], 'name')} · ${row['quantity']}',
      HrmsModule.procurement => '${row['title']}',
      HrmsModule.equipment => '${row['name']} · ${row['asset_tag']}',
      HrmsModule.maintenance => '${row['title']}',
      HrmsModule.users => '${row['email']}',
      HrmsModule.reports =>
        '${row['label'] ?? _nested(row['inventory_items'], 'name') ?? row['kind'] ?? 'Activity'}',
    };
    final subtitle = switch (widget.module) {
      HrmsModule.requests =>
        '${_nested(row['departments'], 'name') ?? ''} · ${_requestLineSummary(row['resource_request_lines'])} · ${row['priority'] ?? ''} · ${row['status'] ?? ''}',
      HrmsModule.transfers =>
        '${_nested(row['source'], 'name')} → ${_nested(row['destination'], 'name')} · ${row['status']}',
      HrmsModule.procurement =>
        '${row['status']} · ${row['estimated_cost'] ?? 'Cost not set'}',
      HrmsModule.equipment =>
        '${row['asset_tag']} · ${row['status']} · ${_nested(row['departments'], 'name') ?? ''}',
      HrmsModule.maintenance =>
        '${_nested(row['medical_assets'], 'name') ?? ''} · ${row['priority']} · ${row['status']}',
      HrmsModule.users =>
        '${row['role']} · ${row['is_active'] == true ? 'Active' : 'Inactive'}',
      HrmsModule.reports =>
        '${row['value'] ?? '${row['kind'] ?? ''} · ${row['quantity'] ?? ''}'}',
    };
    return Card(
      child: ListTile(
        leading: Icon(_icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: _actions(row),
      ),
    );
  }

  IconData get _icon => switch (widget.module) {
    HrmsModule.requests => Icons.assignment_outlined,
    HrmsModule.transfers => Icons.compare_arrows,
    HrmsModule.procurement => Icons.shopping_cart_outlined,
    HrmsModule.equipment => Icons.medical_services_outlined,
    HrmsModule.maintenance => Icons.build_outlined,
    HrmsModule.users => Icons.person_outline,
    HrmsModule.reports => Icons.insights,
  };
  String? _nested(dynamic v, String key) =>
      v is Map ? v[key]?.toString() : null;

  String _requestLineSummary(dynamic value) {
    if (value is! List || value.isEmpty) return 'No item details';
    return value
        .map((line) {
          final item = line is Map ? line['inventory_items'] : null;
          final itemName = item is Map ? item['name'] : 'Item';
          return '$itemName × ${line is Map ? line['quantity'] : ''}';
        })
        .join(', ');
  }

  Widget? _actions(Map<String, dynamic> row) {
    if (widget.module == HrmsModule.requests &&
        _roles.intersection({
          'hospital_admin',
          'inventory_manager',
          'department_head',
          'storekeeper',
          'pharmacist',
        }).isNotEmpty &&
        row['status'] == 'pending')
      return PopupMenuButton<String>(
        onSelected: (v) => _run(() => _service.reviewRequest(row['id'], v)),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'approved', child: Text('Approve')),
          PopupMenuItem(value: 'rejected', child: Text('Reject')),
        ],
      );
    if (widget.module == HrmsModule.procurement &&
        _roles.intersection({
          'hospital_admin',
          'procurement_officer',
          'finance_officer',
        }).isNotEmpty &&
        row['status'] == 'submitted')
      return PopupMenuButton<String>(
        onSelected: (v) =>
            _run(() => _service.setRequisitionStatus(row['id'], v)),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'approved', child: Text('Approve')),
          PopupMenuItem(value: 'rejected', child: Text('Reject')),
        ],
      );
    if (widget.module == HrmsModule.maintenance &&
        _roles.intersection({
          'hospital_admin',
          'biomedical_engineer',
        }).isNotEmpty &&
        row['status'] != 'completed')
      return PopupMenuButton<String>(
        onSelected: (v) =>
            _run(() => _service.setMaintenanceStatus(row['id'], v)),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'in_progress', child: Text('Start work')),
          PopupMenuItem(value: 'completed', child: Text('Complete')),
          PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
        ],
      );
    if (widget.module == HrmsModule.users && _admin)
      return IconButton(
        tooltip: row['is_active'] == true ? 'Deactivate' : 'Reactivate',
        onPressed: () => _run(
          () =>
              _service.setMembershipActive(row['id'], row['is_active'] != true),
        ),
        icon: Icon(
          row['is_active'] == true
              ? Icons.person_off_outlined
              : Icons.person_add_alt_1,
        ),
      );
    return null;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) {
        setState(() => _rows = _load(_hospitalId!));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _create() async {
    switch (widget.module) {
      case HrmsModule.requests:
        return _requestForm();
      case HrmsModule.transfers:
        return _transferForm();
      case HrmsModule.procurement:
        return _procurementForm();
      case HrmsModule.equipment:
        return _equipmentForm();
      case HrmsModule.maintenance:
        return _maintenanceForm();
      case HrmsModule.users:
        return _userForm();
      case HrmsModule.reports:
        return;
    }
  }

  Future<void> _supplierForm() async {
    final name = TextEditingController(),
        contact = TextEditingController(),
        email = TextEditingController(),
        phone = TextEditingController(),
        address = TextEditingController();
    final ok = await _dialog('Add supplier', [
      _field(name, 'Supplier / company name'),
      _field(contact, 'Contact person'),
      _field(email, 'Email'),
      _field(phone, 'Phone'),
      _field(address, 'Address', lines: 2),
    ], () => name.text.trim().isNotEmpty);
    if (ok == true)
      await _run(
        () => _service.createSupplier(
          _hospitalId!,
          name: name.text,
          contactName: contact.text,
          email: email.text,
          phone: phone.text,
          address: address.text,
        ),
      );
  }

  Future<void> _requestForm() async {
    final purpose = TextEditingController(),
        qty = TextEditingController(),
        due = TextEditingController();
    String? dep, item;
    String priority = 'normal';
    final ok = await _dialog(
      'Submit resource request',
      [
        _select('Department', _departments, 'name', (v) => dep = v),
        _select('Inventory item', _items, 'name', (v) => item = v),
        _field(purpose, 'Purpose / clinical need'),
        _field(qty, 'Quantity', numeric: true),
        _field(due, 'Required by (YYYY-MM-DD)'),
        DropdownButtonFormField<String>(
          value: priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: [
            'low',
            'normal',
            'high',
            'urgent',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) => priority = v ?? 'normal',
        ),
      ],
      () =>
          dep != null &&
          item != null &&
          purpose.text.trim().isNotEmpty &&
          (double.tryParse(qty.text) ?? 0) > 0,
    );
    if (ok == true)
      await _run(
        () => _service.submitRequest(
          hospitalId: _hospitalId!,
          departmentId: dep!,
          itemId: item!,
          quantity: double.parse(qty.text),
          purpose: purpose.text,
          priority: priority,
          requiredBy: due.text.isEmpty ? null : due.text,
        ),
      );
  }

  Future<void> _transferForm() async {
    String? source, dest, item;
    final qty = TextEditingController(),
        reason = TextEditingController(),
        ref = TextEditingController();
    final ok = await _dialog(
      'Transfer stock',
      [
        _selectWarehouse('Source warehouse', (v) => source = v),
        _selectWarehouse('Destination warehouse', (v) => dest = v),
        _select('Item', _items, 'name', (v) => item = v),
        _field(qty, 'Quantity', numeric: true),
        _field(reason, 'Reason'),
        _field(ref, 'Reference (optional)'),
      ],
      () =>
          source != null &&
          dest != null &&
          source != dest &&
          item != null &&
          (double.tryParse(qty.text) ?? 0) > 0 &&
          reason.text.trim().isNotEmpty,
    );
    if (ok == true)
      await _run(
        () => _service.transferStock(
          hospitalId: _hospitalId!,
          sourceId: source!,
          destinationId: dest!,
          itemId: item!,
          quantity: double.parse(qty.text),
          reason: reason.text,
          reference: ref.text,
        ),
      );
  }

  Future<void> _procurementForm() async {
    final title = TextEditingController(),
        why = TextEditingController(),
        cost = TextEditingController(),
        due = TextEditingController();
    String? dep, supplier;
    final ok = await _dialog(
      'Create purchase requisition',
      [
        _field(title, 'Request title'),
        _field(why, 'Justification', lines: 3),
        _select(
          'Department (optional)',
          _departments,
          'name',
          (v) => dep = v,
          optional: true,
        ),
        _select(
          'Supplier (optional)',
          _suppliers,
          'name',
          (v) => supplier = v,
          optional: true,
        ),
        _field(cost, 'Estimated cost', numeric: true),
        _field(due, 'Required by (YYYY-MM-DD)'),
      ],
      () =>
          title.text.trim().isNotEmpty &&
          why.text.trim().isNotEmpty &&
          (cost.text.isEmpty || double.tryParse(cost.text) != null),
    );
    if (ok == true)
      await _run(
        () => _service.createRequisition(
          _hospitalId!,
          departmentId: dep,
          supplierId: supplier,
          title: title.text,
          justification: why.text,
          estimatedCost: double.tryParse(cost.text),
          requiredBy: due.text.isEmpty ? null : due.text,
        ),
      );
  }

  Future<void> _equipmentForm() async {
    final tag = TextEditingController(),
        name = TextEditingController(),
        serial = TextEditingController(),
        maker = TextEditingController(),
        model = TextEditingController(),
        loc = TextEditingController();
    String? dep;
    final ok = await _dialog('Register medical equipment', [
      _field(tag, 'Asset tag'),
      _field(name, 'Equipment name'),
      _select(
        'Department (optional)',
        _departments,
        'name',
        (v) => dep = v,
        optional: true,
      ),
      _field(serial, 'Serial number'),
      _field(maker, 'Manufacturer'),
      _field(model, 'Model'),
      _field(loc, 'Location'),
    ], () => tag.text.trim().isNotEmpty && name.text.trim().isNotEmpty);
    if (ok == true)
      await _run(
        () => _service.createAsset(
          _hospitalId!,
          departmentId: dep,
          tag: tag.text,
          name: name.text,
          serial: serial.text,
          manufacturer: maker.text,
          model: model.text,
          location: loc.text,
        ),
      );
  }

  Future<void> _maintenanceForm() async {
    final title = TextEditingController(),
        desc = TextEditingController(),
        date = TextEditingController();
    String? asset;
    String priority = 'normal';
    final ok = await _dialog(
      'Report equipment issue',
      [
        _select('Equipment', _assets, 'name', (v) => asset = v),
        _field(title, 'Issue title'),
        _field(desc, 'Describe the problem', lines: 3),
        DropdownButtonFormField<String>(
          value: priority,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: [
            'low',
            'normal',
            'high',
            'urgent',
          ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
          onChanged: (v) => priority = v ?? 'normal',
        ),
        _field(date, 'Requested date (YYYY-MM-DD)'),
      ],
      () =>
          asset != null &&
          title.text.trim().isNotEmpty &&
          desc.text.trim().isNotEmpty,
    );
    if (ok == true)
      await _run(
        () => _service.createMaintenance(
          _hospitalId!,
          assetId: asset!,
          title: title.text,
          description: desc.text,
          priority: priority,
          scheduledFor: date.text.isEmpty ? null : date.text,
        ),
      );
  }

  Future<void> _userForm() async {
    final email = TextEditingController();
    String role = 'healthcare_worker';
    String? dep;
    final ok = await _dialog('Assign hospital membership', [
      _field(email, 'Existing account email'),
      DropdownButtonFormField<String>(
        value: role,
        decoration: const InputDecoration(labelText: 'Hospital role'),
        items:
            const [
                  'hospital_admin',
                  'inventory_manager',
                  'storekeeper',
                  'pharmacist',
                  'procurement_officer',
                  'department_head',
                  'healthcare_worker',
                  'biomedical_engineer',
                  'finance_officer',
                  'auditor',
                ]
                .map(
                  (x) => DropdownMenuItem(
                    value: x,
                    child: Text(x.replaceAll('_', ' ')),
                  ),
                )
                .toList(),
        onChanged: (v) => role = v ?? role,
      ),
      _select(
        'Department (optional)',
        _departments,
        'name',
        (v) => dep = v,
        optional: true,
      ),
    ], () => email.text.contains('@'));
    if (ok == true)
      await _run(
        () => _service.addHospitalUser(
          _hospitalId!,
          email: email.text,
          role: role,
          departmentId: dep,
        ),
      );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool numeric = false,
    int lines = 1,
  }) => TextFormField(
    controller: c,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : null,
    maxLines: lines,
    decoration: InputDecoration(labelText: label),
  );
  Widget _select(
    String label,
    List<Map<String, dynamic>> rows,
    String key,
    ValueChanged<String?> onChanged, {
    bool optional = false,
  }) => DropdownButtonFormField<String>(
    decoration: InputDecoration(labelText: label),
    items: [
      if (optional) const DropdownMenuItem(value: null, child: Text('None')),
      for (final row in rows)
        DropdownMenuItem(
          value: row['id'] as String,
          child: Text('${row[key]}'),
        ),
    ],
    onChanged: onChanged,
  );
  Widget _selectWarehouse(String label, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label),
        items: [
          for (final w in _warehouses)
            DropdownMenuItem(value: w.id, child: Text(w.name)),
        ],
        onChanged: onChanged,
      );
  Future<bool?> _dialog(
    String title,
    List<Widget> fields,
    bool Function() valid,
  ) async => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in fields)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: f),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => valid()
              ? Navigator.pop(ctx, true)
              : ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Complete the required fields with valid values.',
                    ),
                  ),
                ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
