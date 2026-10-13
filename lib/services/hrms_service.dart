import 'package:supabase_flutter/supabase_flutter.dart';

class HrmsHospital {
  const HrmsHospital({
    required this.id,
    required this.name,
    required this.roles,
  });
  final String id;
  final String name;
  final Set<String> roles;
}

class HrmsWarehouse {
  const HrmsWarehouse({
    required this.id,
    required this.name,
    this.location,
    this.isActive = true,
  });
  final String id;
  final String name;
  final String? location;
  final bool isActive;
  factory HrmsWarehouse.fromMap(Map<String, dynamic> row) => HrmsWarehouse(
    id: row['id'] as String,
    name: row['name'] as String,
    location: row['location'] as String?,
    isActive: (row['is_active'] ?? true) as bool,
  );
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.code,
    required this.name,
    required this.kind,
    required this.unit,
    required this.minimumStock,
    required this.quantity,
    this.reorderLevel = 0,
  });
  final String id;
  final String code;
  final String name;
  final String kind;
  final String unit;
  final double minimumStock;
  final double reorderLevel;
  final double quantity;
  bool get lowStock => quantity <= minimumStock;

  factory InventoryItem.fromMap(Map<String, dynamic> row, double quantity) =>
      InventoryItem(
        id: row['id'] as String,
        code: row['item_code'] as String,
        name: row['name'] as String,
        kind: row['kind'] as String,
        unit: row['unit'] as String,
        minimumStock: (row['minimum_stock'] as num).toDouble(),
        reorderLevel: (row['reorder_level'] as num).toDouble(),
        quantity: quantity,
      );
}

class HrmsService {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<HrmsHospital>> hospitals() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    final memberships = await _db
        .from('hrms_memberships')
        .select('hospital_id,role')
        .eq('user_id', uid)
        .eq('is_active', true);
    if (memberships.isEmpty) return [];
    final rolesByHospital = <String, Set<String>>{};
    for (final row in memberships) {
      rolesByHospital
          .putIfAbsent(row['hospital_id'] as String, () => <String>{})
          .add(row['role'] as String);
    }
    final rows = await _db
        .from('hospitals')
        .select('id,name')
        .inFilter('id', rolesByHospital.keys.toList())
        .eq('is_active', true)
        .order('name');
    return rows
        .map(
          (row) => HrmsHospital(
            id: row['id'] as String,
            name: row['name'] as String,
            roles: rolesByHospital[row['id']]!,
          ),
        )
        .toList();
  }

  Future<List<HrmsWarehouse>> warehouses(
    String hospitalId, {
    bool includeInactive = false,
  }) async {
    var query = _db
        .from('warehouses')
        .select('id,name,location,is_active')
        .eq('hospital_id', hospitalId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('name');
    return rows.map(HrmsWarehouse.fromMap).toList();
  }

  Future<void> setDepartmentActive(String id, bool active) async {
    await _db.from('departments').update({'is_active': active}).eq('id', id);
  }

  Future<void> setWarehouseActive(String id, bool active) async {
    await _db.from('warehouses').update({'is_active': active}).eq('id', id);
  }

  Future<List<Map<String, dynamic>>> departments(String hospitalId) async {
    final rows = await _db
        .from('departments')
        .select('id,name,code,is_active')
        .eq('hospital_id', hospitalId)
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createDepartment(
    String hospitalId,
    String name,
    String code,
  ) async {
    await _db.from('departments').insert({
      'hospital_id': hospitalId,
      'name': name.trim(),
      'code': code.trim().isEmpty ? null : code.trim(),
    });
  }

  Future<void> createWarehouse(
    String hospitalId,
    String name,
    String location, {
    String? departmentId,
  }) async {
    await _db.from('warehouses').insert({
      'hospital_id': hospitalId,
      'department_id': departmentId,
      'name': name.trim(),
      'location': location.trim().isEmpty ? null : location.trim(),
    });
  }

  Future<List<InventoryItem>> inventory(
    String hospitalId, {
    String? warehouseId,
    String search = '',
  }) async {
    var query = _db
        .from('inventory_items')
        .select()
        .eq('hospital_id', hospitalId)
        .eq('is_active', true);
    if (search.trim().isNotEmpty) {
      final term = '%${search.trim()}%';
      query = query.or('name.ilike.$term,item_code.ilike.$term');
    }
    final rows = await query.order('name').limit(500);
    var balanceQuery = _db
        .from('stock_balances')
        .select('item_id,quantity')
        .eq('hospital_id', hospitalId);
    if (warehouseId != null)
      balanceQuery = balanceQuery.eq('warehouse_id', warehouseId);
    final balances = await balanceQuery;
    final quantities = <String, double>{};
    for (final balance in balances) {
      final id = balance['item_id'] as String;
      quantities[id] =
          (quantities[id] ?? 0) + (balance['quantity'] as num).toDouble();
    }
    return rows
        .map((row) => InventoryItem.fromMap(row, quantities[row['id']] ?? 0))
        .toList();
  }

  Future<List<Map<String, dynamic>>> batches(
    String hospitalId,
    String itemId,
  ) async {
    final rows = await _db
        .from('inventory_batches')
        .select('id,batch_number,expires_on,is_quarantined')
        .eq('hospital_id', hospitalId)
        .eq('item_id', itemId)
        .eq('is_quarantined', false)
        .order('expires_on');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createBatch({
    required String hospitalId,
    required String itemId,
    required String number,
    String? expiresOn,
    String? manufacturedOn,
    double? unitCost,
  }) async {
    await _db.from('inventory_batches').insert({
      'hospital_id': hospitalId,
      'item_id': itemId,
      'batch_number': number.trim(),
      'expires_on': expiresOn,
      'manufactured_on': manufacturedOn,
      'unit_cost': unitCost,
    });
  }

  Future<List<Map<String, dynamic>>> movements(String hospitalId) async {
    final rows = await _db
        .from('stock_movements')
        .select(
          'id,kind,quantity,reference,reason,created_at,inventory_items(name,item_code),warehouses(name),inventory_batches(batch_number)',
        )
        .eq('hospital_id', hospitalId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createItem({
    required String hospitalId,
    required String code,
    required String name,
    required String kind,
    required String unit,
    required double minimumStock,
    required double reorderLevel,
  }) async {
    await _db.from('inventory_items').insert({
      'hospital_id': hospitalId,
      'item_code': code.trim(),
      'name': name.trim(),
      'kind': kind,
      'unit': unit.trim(),
      'minimum_stock': minimumStock,
      'reorder_level': reorderLevel,
      'created_by': _db.auth.currentUser!.id,
    });
  }

  Future<void> recordMovement({
    required String hospitalId,
    required String warehouseId,
    required String itemId,
    String? batchId,
    required String kind,
    required double quantity,
    String? reason,
    String? reference,
  }) async {
    await _db.rpc(
      'record_stock_movement',
      params: {
        'p_hospital_id': hospitalId,
        'p_warehouse_id': warehouseId,
        'p_item_id': itemId,
        'p_batch_id': batchId,
        'p_kind': kind,
        'p_quantity': quantity,
        'p_reason': reason,
        'p_reference': reference,
      },
    );
  }
}
