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

class HrmsDashboardData {
  const HrmsDashboardData({
    required this.items,
    required this.lowStockItems,
    required this.stockedItemsCount,
    required this.recentMovements,
    required this.expiringBatchCount,
    required this.expiredBatchCount,
  });

  final List<InventoryItem> items;
  final List<InventoryItem> lowStockItems;
  final int stockedItemsCount;
  final List<Map<String, dynamic>> recentMovements;
  final int expiringBatchCount;
  final int expiredBatchCount;
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

  Future<HrmsDashboardData> dashboard(String hospitalId) async {
    final today = DateTime.now();
    final todayText = _dateString(today);
    final horizonText = _dateString(today.add(const Duration(days: 30)));
    final results = await Future.wait<dynamic>([
      inventory(hospitalId),
      movements(hospitalId),
      _db
          .from('inventory_batches')
          .select('id')
          .eq('hospital_id', hospitalId)
          .eq('is_quarantined', false)
          .gte('expires_on', todayText)
          .lte('expires_on', horizonText),
      _db
          .from('inventory_batches')
          .select('id')
          .eq('hospital_id', hospitalId)
          .eq('is_quarantined', false)
          .lt('expires_on', todayText),
    ]);
    final items = results[0] as List<InventoryItem>;
    return HrmsDashboardData(
      items: items,
      lowStockItems: items.where((item) => item.lowStock).toList(),
      stockedItemsCount: items.where((item) => item.quantity > 0).length,
      recentMovements: results[1] as List<Map<String, dynamic>>,
      expiringBatchCount: (results[2] as List).length,
      expiredBatchCount: (results[3] as List).length,
    );
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

  Future<List<Map<String, dynamic>>> requests(String hospitalId) async {
    final rows = await _db
        .from('resource_requests')
        .select(
          '*,departments(name),resource_request_lines(id,quantity,approved_quantity,inventory_items(name,item_code,unit))',
        )
        .eq('hospital_id', hospitalId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> submitRequest({
    required String hospitalId,
    required String departmentId,
    required String itemId,
    required double quantity,
    required String purpose,
    required String priority,
    String? requiredBy,
  }) async {
    final row = await _db
        .from('resource_requests')
        .insert({
          'hospital_id': hospitalId,
          'department_id': departmentId,
          'requested_by': _db.auth.currentUser!.id,
          'purpose': purpose.trim(),
          'priority': priority,
          'required_by': requiredBy,
        })
        .select('id')
        .single();
    await _db.from('resource_request_lines').insert({
      'hospital_id': hospitalId,
      'request_id': row['id'],
      'item_id': itemId,
      'quantity': quantity,
    });
  }

  Future<void> reviewRequest(String id, String status, {String? note}) async {
    await _db
        .from('resource_requests')
        .update({
          'status': status,
          'reviewed_by': _db.auth.currentUser!.id,
          'review_note': note,
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> transfers(String hospitalId) async {
    final rows = await _db
        .from('stock_transfers')
        .select(
          '*,source:warehouses!stock_transfers_source_warehouse_id_fkey(name),destination:warehouses!stock_transfers_destination_warehouse_id_fkey(name),inventory_items(name,item_code),inventory_batches(batch_number)',
        )
        .eq('hospital_id', hospitalId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> transferStock({
    required String hospitalId,
    required String sourceId,
    required String destinationId,
    required String itemId,
    String? batchId,
    required double quantity,
    required String reason,
    String? reference,
  }) async {
    await _db.rpc(
      'hrms_transfer_stock',
      params: {
        'p_hospital_id': hospitalId,
        'p_source_warehouse_id': sourceId,
        'p_destination_warehouse_id': destinationId,
        'p_item_id': itemId,
        'p_batch_id': batchId,
        'p_quantity': quantity,
        'p_reason': reason,
        'p_reference': reference,
      },
    );
  }

  Future<List<Map<String, dynamic>>> suppliers(String hospitalId) async {
    final rows = await _db
        .from('hrms_suppliers')
        .select()
        .eq('hospital_id', hospitalId)
        .order('name')
        .limit(500);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createSupplier(
    String hospitalId, {
    required String name,
    String? contactName,
    String? email,
    String? phone,
    String? address,
  }) async {
    await _db.from('hrms_suppliers').insert({
      'hospital_id': hospitalId,
      'name': name.trim(),
      'contact_name': contactName,
      'email': email,
      'phone': phone,
      'address': address,
      'created_by': _db.auth.currentUser!.id,
    });
  }

  Future<List<Map<String, dynamic>>> requisitions(String hospitalId) async {
    final rows = await _db
        .from('purchase_requisitions')
        .select('*,departments(name),hrms_suppliers(name)')
        .eq('hospital_id', hospitalId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createRequisition(
    String hospitalId, {
    String? departmentId,
    String? supplierId,
    required String title,
    required String justification,
    double? estimatedCost,
    String? requiredBy,
  }) async {
    await _db.from('purchase_requisitions').insert({
      'hospital_id': hospitalId,
      'department_id': departmentId,
      'supplier_id': supplierId,
      'title': title.trim(),
      'justification': justification.trim(),
      'estimated_cost': estimatedCost,
      'required_by': requiredBy,
      'status': 'submitted',
      'created_by': _db.auth.currentUser!.id,
    });
  }

  Future<void> setRequisitionStatus(String id, String status) async {
    await _db
        .from('purchase_requisitions')
        .update({'status': status})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> assets(String hospitalId) async {
    final rows = await _db
        .from('medical_assets')
        .select('*,departments(name)')
        .eq('hospital_id', hospitalId)
        .order('name')
        .limit(500);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createAsset(
    String hospitalId, {
    String? departmentId,
    required String tag,
    required String name,
    String? serial,
    String? manufacturer,
    String? model,
    String? location,
    String? warrantyUntil,
    String? notes,
  }) async {
    await _db.from('medical_assets').insert({
      'hospital_id': hospitalId,
      'department_id': departmentId,
      'asset_tag': tag.trim(),
      'name': name.trim(),
      'serial_number': serial,
      'manufacturer': manufacturer,
      'model': model,
      'location': location,
      'warranty_until': warrantyUntil,
      'notes': notes,
      'created_by': _db.auth.currentUser!.id,
    });
  }

  Future<List<Map<String, dynamic>>> maintenance(String hospitalId) async {
    final rows = await _db
        .from('maintenance_work_orders')
        .select('*,medical_assets(name,asset_tag)')
        .eq('hospital_id', hospitalId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<void> createMaintenance(
    String hospitalId, {
    required String assetId,
    required String title,
    required String description,
    required String priority,
    String? scheduledFor,
  }) async {
    await _db.from('maintenance_work_orders').insert({
      'hospital_id': hospitalId,
      'asset_id': assetId,
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority,
      'scheduled_for': scheduledFor,
      'reported_by': _db.auth.currentUser!.id,
    });
  }

  Future<void> setMaintenanceStatus(
    String id,
    String status, {
    String? resolution,
  }) async {
    await _db
        .from('maintenance_work_orders')
        .update({'status': status, 'resolution': resolution})
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> hospitalUsers(String hospitalId) async {
    final rows = await _db.rpc(
      'hrms_list_hospital_users',
      params: {'p_hospital_id': hospitalId},
    );
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> addHospitalUser(
    String hospitalId, {
    required String email,
    required String role,
    String? departmentId,
  }) async {
    await _db.rpc(
      'hrms_add_member',
      params: {
        'p_hospital_id': hospitalId,
        'p_email': email.trim(),
        'p_role': role,
        'p_department_id': departmentId,
      },
    );
  }

  Future<void> setMembershipActive(String id, bool active) async {
    await _db.rpc(
      'hrms_set_membership_active',
      params: {'p_membership_id': id, 'p_is_active': active},
    );
  }
}
