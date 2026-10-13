import 'package:flutter/material.dart';

import '../../services/hrms_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _service = HrmsService();
  final _search = TextEditingController();
  late Future<List<HrmsHospital>> _hospitals;
  String? _hospitalId;
  Set<String> _hospitalRoles = {};
  String? _warehouseId;
  List<HrmsWarehouse> _warehouses = const [];
  late Future<List<InventoryItem>> _items;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _hospitals = _service.hospitals();
    _items = Future.value(const []);
  }

  Future<void> _selectHospital(HrmsHospital? hospital) async {
    if (hospital == null) return;
    final id = hospital.id;
    setState(() {
      _hospitalId = id;
      _hospitalRoles = hospital.roles;
      _warehouseId = null;
      _warehouses = const [];
      _ready = false;
    });
    try {
      final warehouses = await _service.warehouses(id);
      if (!mounted || _hospitalId != id) return;
      setState(() {
        _warehouses = warehouses;
        _ready = true;
        _items = _service.inventory(id, search: _search.text);
      });
    } catch (e) {
      if (mounted && _hospitalId == id) setState(() => _ready = true);
    }
  }

  void _reload() {
    final hospitalId = _hospitalId;
    if (hospitalId == null) return;
    setState(
      () => _items = _service.inventory(
        hospitalId,
        warehouseId: _warehouseId,
        search: _search.text,
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<List<HrmsHospital>>(
      future: _hospitals,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorPanel(
            error: snapshot.error!,
            retry: () => setState(() => _hospitals = _service.hospitals()),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final hospitals = snapshot.data!;
        if (hospitals.isEmpty)
          return const _EmptyPanel(
            title: 'No hospital access',
            message: 'Your account is not an active member of a hospital. Ask a hospital administrator to assign your membership.',
          );
        if (_hospitalId == null)
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _selectHospital(hospitals.first),
          );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _hospitalId,
                          decoration: const InputDecoration(
                            labelText: 'Hospital',
                          ),
                          items: [
                            for (final h in hospitals)
                              DropdownMenuItem(
                                value: h.id,
                                child: Text(h.name),
                              ),
                          ],
                          onChanged: (id) => _selectHospital(
                            hospitals.where((h) => h.id == id).firstOrNull,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          initialValue: _warehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Warehouse',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All locations'),
                            ),
                            for (final w in _warehouses)
                              DropdownMenuItem<String?>(
                                value: w.id,
                                child: Text(w.name),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() => _warehouseId = v);
                            _reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _canManageItems ? _createItem : null,
                        icon: const Icon(Icons.add),
                        label: const Text('New item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search items by name or code',
                      suffixIcon: IconButton(
                        onPressed: _reload,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                    onSubmitted: (_) => _reload(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !_ready
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<InventoryItem>>(
                      future: _items,
                      builder: (context, itemSnapshot) {
                        if (itemSnapshot.hasError)
                          return _ErrorPanel(
                            error: itemSnapshot.error!,
                            retry: _reload,
                          );
                        if (!itemSnapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final items = itemSnapshot.data!;
                        if (items.isEmpty)
                          return const _EmptyPanel(
                            title: 'No inventory items',
                            message: 'Add an item to start tracking stock.',
                          );
                        return RefreshIndicator(
                          onRefresh: () async => _reload(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      item.kind == 'medicine'
                                          ? Icons.medication_outlined
                                          : Icons.inventory_2_outlined,
                                    ),
                                  ),
                                  title: Text(item.name),
                                  subtitle: Text(
                                    '${item.code} · ${item.kind} · min ${item.minimumStock} ${item.unit}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${item.quantity} ${item.unit}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (item.lowStock)
                                        const Text(
                                          'LOW STOCK',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: _canMoveStock
                                      ? () => _movement(item)
                                      : null,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
    floatingActionButton: !_canMoveStock
        ? null
        : FloatingActionButton.extended(
            onPressed: _movementPicker,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Stock movement'),
          ),
  );

  Future<void> _createItem() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final unit = TextEditingController(text: 'unit');
    final min = TextEditingController(text: '0');
    final reorder = TextEditingController(text: '0');
    var kind = 'supply';
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New inventory item'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Item code'),
                  validator: _required,
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _required,
                ),
                DropdownButtonFormField<String>(
                  value: kind,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'supply', child: Text('Supply')),
                    DropdownMenuItem(
                      value: 'medicine',
                      child: Text('Medicine'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) kind = v;
                  },
                ),
                TextFormField(
                  controller: unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit (e.g. box, vial)',
                  ),
                  validator: _required,
                ),
                TextFormField(
                  controller: min,
                  decoration: const InputDecoration(labelText: 'Minimum stock'),
                  keyboardType: TextInputType.number,
                  validator: _number,
                ),
                TextFormField(
                  controller: reorder,
                  decoration: const InputDecoration(labelText: 'Reorder level'),
                  keyboardType: TextInputType.number,
                  validator: _number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (ok == true && _hospitalId != null) {
      try {
        await _service.createItem(
          hospitalId: _hospitalId!,
          code: code.text,
          name: name.text,
          kind: kind,
          unit: unit.text,
          minimumStock: double.parse(min.text),
          reorderLevel: double.parse(reorder.text),
        );
        _reload();
      } catch (e) {
        if (mounted) _message('Could not create item: $e');
      }
    }
    code.dispose();
    name.dispose();
    unit.dispose();
    min.dispose();
    reorder.dispose();
  }

  Future<void> _movementPicker() async {
    final items = await _items;
    if (!mounted || items.isEmpty) return;
    final item = await showModalBottomSheet<InventoryItem>(
      context: context,
      builder: (context) => ListView(
        children: [
          for (final i in items)
            ListTile(
              title: Text(i.name),
              subtitle: Text(i.code),
              onTap: () => Navigator.pop(context, i),
            ),
        ],
      ),
    );
    if (item != null) _movement(item);
  }

  Future<void> _movement(InventoryItem item) async {
    if (_hospitalId == null || _warehouses.isEmpty) {
      _message('This hospital has no active warehouse.');
      return;
    }
    var batches = item.kind == 'medicine'
        ? await _service.batches(_hospitalId!, item.id)
        : <Map<String, dynamic>>[];
    if (!mounted) return;
    final canManage = _canManageItems;
    var kind = canManage ? 'receipt' : 'issue';
    var warehouseId = _warehouseId ?? _warehouses.first.id;
    String? batchId;
    final qty = TextEditingController();
    final reason = TextEditingController();
    final ref = TextEditingController();
    final form = GlobalKey<FormState>();
    if (item.kind == 'medicine' && batches.isEmpty && canManage) {
      final add = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Medicine batch required'),
          content: const Text(
            'Medicine stock must be received against a traceable batch and expiry date.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create batch'),
            ),
          ],
        ),
      );
      if (add != true || !mounted) return;
      if (!await _createBatch(item)) return;
      if (!mounted) return;
      batches = await _service.batches(_hospitalId!, item.id);
      if (!mounted) return;
    }
    if (item.kind == 'medicine' && batches.isEmpty) {
      _message(
        'No medicine batch is available. Ask a pharmacist or inventory manager to register one.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Stock movement · ${item.name}'),
          content: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Operation'),
                    items: [
                      if (canManage)
                        const DropdownMenuItem(
                          value: 'receipt',
                          child: Text('Receive stock'),
                        ),
                      const DropdownMenuItem(
                        value: 'issue',
                        child: Text('Issue stock'),
                      ),
                      if (canManage)
                        const DropdownMenuItem(
                          value: 'adjustment',
                          child: Text('Positive adjustment'),
                        ),
                      if (canManage)
                        const DropdownMenuItem(
                          value: 'wastage',
                          child: Text('Record wastage'),
                        ),
                      const DropdownMenuItem(
                        value: 'return',
                        child: Text('Return to stock'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) update(() => kind = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: warehouseId,
                    decoration: const InputDecoration(labelText: 'Warehouse'),
                    items: [
                      for (final w in _warehouses)
                        DropdownMenuItem(value: w.id, child: Text(w.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) update(() => warehouseId = v);
                    },
                  ),
                  if (batches.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: batchId,
                      decoration: const InputDecoration(labelText: 'Batch'),
                      items: [
                        for (final b in batches)
                          DropdownMenuItem<String?>(
                            value: b['id'] as String,
                            child: Text(
                              '${b['batch_number']}${b['expires_on'] == null ? '' : ' · exp ${b['expires_on']}'}',
                            ),
                          ),
                      ],
                      onChanged: (v) => update(() => batchId = v),
                      validator: (v) => v == null ? 'Select a batch' : null,
                    ),
                  TextFormField(
                    controller: qty,
                    decoration: InputDecoration(
                      labelText: 'Quantity (${item.unit})',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positiveNumber,
                  ),
                  TextFormField(
                    controller: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: ref,
                    decoration: const InputDecoration(
                      labelText: 'Reference (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await _service.recordMovement(
          hospitalId: _hospitalId!,
          warehouseId: warehouseId,
          itemId: item.id,
          batchId: batchId,
          kind: kind,
          quantity: double.parse(qty.text),
          reason: reason.text,
          reference: ref.text.trim().isEmpty ? null : ref.text.trim(),
        );
        _reload();
        if (mounted) _message('Stock movement recorded.');
      } catch (e) {
        if (mounted) _message('Movement rejected: $e');
      }
    }
    qty.dispose();
    reason.dispose();
    ref.dispose();
  }

  Future<bool> _createBatch(InventoryItem item) async {
    final number = TextEditingController();
    final expiry = TextEditingController();
    final manufactured = TextEditingController();
    final cost = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New batch · ${item.name}'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: number,
                decoration: const InputDecoration(
                  labelText: 'Batch / lot number',
                ),
                validator: _required,
              ),
              TextFormField(
                controller: manufactured,
                decoration: const InputDecoration(
                  labelText: 'Manufactured on (YYYY-MM-DD)',
                ),
              ),
              TextFormField(
                controller: expiry,
                decoration: const InputDecoration(
                  labelText: 'Expires on (YYYY-MM-DD)',
                ),
                validator: _date,
              ),
              TextFormField(
                controller: cost,
                decoration: const InputDecoration(
                  labelText: 'Unit cost (optional)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save batch'),
          ),
        ],
      ),
    );
    var created = false;
    if (ok == true) {
      try {
        await _service.createBatch(
          hospitalId: _hospitalId!,
          itemId: item.id,
          number: number.text,
          expiresOn: expiry.text.trim().isEmpty ? null : expiry.text.trim(),
          manufacturedOn: manufactured.text.trim().isEmpty
              ? null
              : manufactured.text.trim(),
          unitCost: cost.text.trim().isEmpty ? null : double.parse(cost.text),
        );
        created = true;
      } catch (e) {
        if (mounted) _message('Could not create batch: $e');
      }
    }
    number.dispose();
    expiry.dispose();
    manufactured.dispose();
    cost.dispose();
    return created;
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Required' : null;
  String? _number(String? v) =>
      double.tryParse(v ?? '') == null || double.parse(v!) < 0
      ? 'Enter zero or more'
      : null;
  String? _positiveNumber(String? v) =>
      double.tryParse(v ?? '') == null || double.parse(v!) <= 0
      ? 'Enter a quantity above zero'
      : null;
  String? _date(String? v) =>
      v == null || v.trim().isEmpty || DateTime.tryParse(v.trim()) != null
      ? null
      : 'Use YYYY-MM-DD';
  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  bool get _canManageItems => _hospitalRoles.any(
    const {'hospital_admin', 'inventory_manager', 'pharmacist'}.contains,
  );

  bool get _canMoveStock => _hospitalRoles.any(
    const {
      'hospital_admin',
      'inventory_manager',
      'storekeeper',
      'pharmacist',
    }.contains,
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
