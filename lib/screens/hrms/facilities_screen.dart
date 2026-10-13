import 'package:flutter/material.dart';

import '../../services/hrms_service.dart';
import 'hrms_form_widgets.dart';

class FacilitiesScreen extends StatefulWidget {
  const FacilitiesScreen({super.key});
  @override
  State<FacilitiesScreen> createState() => _FacilitiesScreenState();
}

class _FacilitiesScreenState extends State<FacilitiesScreen> {
  final _service = HrmsService();
  late Future<List<HrmsHospital>> _hospitals;
  String? _hospitalId;
  Set<String> _roles = {};
  late Future<_FacilityData> _data;

  @override
  void initState() {
    super.initState();
    _hospitals = _service.hospitals();
    _data = Future.value(const _FacilityData([], []));
  }

  void _select(HrmsHospital? hospital) {
    if (hospital == null) return;
    setState(() {
      _hospitalId = hospital.id;
      _roles = hospital.roles;
      _data = _load(hospital.id);
    });
  }

  Future<_FacilityData> _load(String id) async {
    final values = await Future.wait([
      _service.departments(id),
      _service.warehouses(id, includeInactive: true),
    ]);
    return _FacilityData(
      values[0] as List<Map<String, dynamic>>,
      values[1] as List<HrmsWarehouse>,
    );
  }

  bool get _isAdmin => _roles.contains('hospital_admin');

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: FutureBuilder<List<HrmsHospital>>(
      future: _hospitals,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Text('Could not load hospitals: ${snapshot.error}'),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final hospitals = snapshot.data!;
        if (hospitals.isEmpty)
          return const Center(
            child: Text('No hospital membership is assigned to this account.'),
          );
        if (_hospitalId == null)
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _select(hospitals.first),
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Departments and warehouses',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _hospitalId,
              decoration: const InputDecoration(labelText: 'Hospital'),
              items: [
                for (final hospital in hospitals)
                  DropdownMenuItem(
                    value: hospital.id,
                    child: Text(hospital.name),
                  ),
              ],
              onChanged: (id) =>
                  _select(hospitals.where((h) => h.id == id).firstOrNull),
            ),
            if (!_isAdmin)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Only hospital administrators can change locations.',
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<_FacilityData>(
                future: _data,
                builder: (context, dataSnapshot) {
                  if (dataSnapshot.hasError)
                    return Center(
                      child: Text(
                        'Could not load locations: ${dataSnapshot.error}',
                      ),
                    );
                  if (!dataSnapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final data = dataSnapshot.data!;
                  return ListView(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Departments',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_isAdmin)
                            IconButton.filledTonal(
                              onPressed: () => _addDepartment(),
                              icon: const Icon(Icons.add),
                              tooltip: 'Add department',
                            ),
                        ],
                      ),
                      if (data.departments.isEmpty)
                        const ListTile(title: Text('No departments')),
                      for (final dept in data.departments)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.domain_outlined),
                            title: Text(dept['name'] as String),
                            subtitle: Text(
                              (dept['code'] as String?) ?? 'No department code',
                            ),
                            trailing: _isAdmin
                                ? Switch(
                                    value: dept['is_active'] as bool,
                                    onChanged: (active) async {
                                      try {
                                        await _service.setDepartmentActive(
                                          dept['id'] as String,
                                          active,
                                        );
                                        _reload();
                                      } catch (e) {
                                        if (mounted)
                                          _notify(
                                            'Could not update department: $e',
                                          );
                                      }
                                    },
                                  )
                                : Text(
                                    (dept['is_active'] as bool)
                                        ? 'Active'
                                        : 'Inactive',
                                  ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Warehouses',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          if (_isAdmin)
                            IconButton.filledTonal(
                              onPressed: () => _addWarehouse(data.departments),
                              icon: const Icon(Icons.add),
                              tooltip: 'Add warehouse',
                            ),
                        ],
                      ),
                      if (data.warehouses.isEmpty)
                        const ListTile(title: Text('No warehouses')),
                      for (final warehouse in data.warehouses)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.warehouse_outlined),
                            title: Text(warehouse.name),
                            subtitle: Text(
                              '${warehouse.location ?? 'Location not specified'} · ${warehouse.isActive ? 'Active' : 'Inactive'}',
                            ),
                            trailing: _isAdmin
                                ? Switch(
                                    value: warehouse.isActive,
                                    onChanged: (active) async {
                                      try {
                                        await _service.setWarehouseActive(
                                          warehouse.id,
                                          active,
                                        );
                                        _reload();
                                      } catch (e) {
                                        if (mounted)
                                          _notify(
                                            'Could not update warehouse: $e',
                                          );
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _addDepartment() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add department'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: key,
            child: HrmsFormSection(
              title: 'Department details',
              description:
                  'Create a department, unit, ward, pharmacy, or service.',
              icon: Icons.domain_outlined,
              child: HrmsFormGrid(
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Department name *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: code,
                    decoration: const InputDecoration(
                      labelText: 'Department code',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
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
              if (key.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && _hospitalId != null) {
      try {
        await _service.createDepartment(_hospitalId!, name.text, code.text);
        _reload();
      } catch (e) {
        if (mounted) _notify('Could not add department: $e');
      }
    }
    name.dispose();
    code.dispose();
  }

  Future<void> _addWarehouse(List<Map<String, dynamic>> departments) async {
    final name = TextEditingController();
    final location = TextEditingController();
    String? departmentId;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Add warehouse'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: key,
              child: HrmsFormSection(
                title: 'Warehouse details',
                description: 'Set up a stock location and optionally link it to a department.',
                icon: Icons.warehouse_outlined,
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Warehouse name *',
                        prefixIcon: Icon(Icons.warehouse_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    HrmsFormGrid(
                      children: [
                        TextFormField(
                          controller: location,
                          decoration: const InputDecoration(
                            labelText: 'Location / room',
                            hintText: 'Optional',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                        ),
                        DropdownButtonFormField<String?>(
                          initialValue: departmentId,
                          decoration: const InputDecoration(
                            labelText: 'Department',
                            prefixIcon: Icon(Icons.domain_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Hospital-wide'),
                            ),
                            for (final dept in departments.where(
                              (d) => d['is_active'] == true,
                            ))
                              DropdownMenuItem<String?>(
                                value: dept['id'] as String,
                                child: Text(dept['name'] as String),
                              ),
                          ],
                          onChanged: (v) => update(() => departmentId = v),
                        ),
                      ],
                    ),
                  ],
                ),
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
                if (key.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && _hospitalId != null) {
      try {
        await _service.createWarehouse(
          _hospitalId!,
          name.text,
          location.text,
          departmentId: departmentId,
        );
        _reload();
      } catch (e) {
        if (mounted) _notify('Could not add warehouse: $e');
      }
    }
    name.dispose();
    location.dispose();
  }

  void _reload() {
    if (_hospitalId != null) setState(() => _data = _load(_hospitalId!));
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _FacilityData {
  const _FacilityData(this.departments, this.warehouses);
  final List<Map<String, dynamic>> departments;
  final List<HrmsWarehouse> warehouses;
}
