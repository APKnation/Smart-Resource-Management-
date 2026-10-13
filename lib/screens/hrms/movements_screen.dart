import 'package:flutter/material.dart';

import '../../services/hrms_service.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});
  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  final _service = HrmsService();
  late Future<List<HrmsHospital>> _hospitals;
  String? _hospitalId;
  Future<List<Map<String, dynamic>>>? _movements;

  @override
  void initState() {
    super.initState();
    _hospitals = _service.hospitals();
  }

  void _select(String? id) {
    if (id == null) return;
    setState(() {
      _hospitalId = id;
      _movements = _service.movements(id);
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: FutureBuilder<List<HrmsHospital>>(
      future: _hospitals,
      builder: (context, hs) {
        if (hs.hasError)
          return Center(child: Text('Could not load hospitals: ${hs.error}'));
        if (!hs.hasData)
          return const Center(child: CircularProgressIndicator());
        if (hs.data!.isEmpty)
          return const Center(
            child: Text('No hospital membership is assigned to this account.'),
          );
        if (_hospitalId == null)
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _select(hs.data!.first.id),
          );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock movement history',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _hospitalId,
              decoration: const InputDecoration(labelText: 'Hospital'),
              items: [
                for (final hospital in hs.data!)
                  DropdownMenuItem(
                    value: hospital.id,
                    child: Text(hospital.name),
                  ),
              ],
              onChanged: _select,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _movements == null
                  ? const Center(child: CircularProgressIndicator())
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _movements,
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return Center(
                            child: Text(
                              'Could not load movement history: ${snapshot.error}',
                            ),
                          );
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final rows = snapshot.data!;
                        if (rows.isEmpty)
                          return const Center(
                            child: Text('No stock movements recorded yet.'),
                          );
                        return RefreshIndicator(
                          onRefresh: () async => setState(
                            () => _movements = _service.movements(_hospitalId!),
                          ),
                          child: ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final row = rows[index];
                              final item =
                                  row['inventory_items']
                                      as Map<String, dynamic>? ??
                                  const {};
                              final warehouse =
                                  row['warehouses'] as Map<String, dynamic>? ??
                                  const {};
                              final batch =
                                  row['inventory_batches']
                                      as Map<String, dynamic>?;
                              final date = DateTime.tryParse(
                                row['created_at'] as String? ?? '',
                              )?.toLocal();
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(
                                      _iconFor(row['kind'] as String? ?? ''),
                                    ),
                                  ),
                                  title: Text(
                                    '${row['kind']} · ${item['name'] ?? 'Inventory item'}',
                                  ),
                                  subtitle: Text(
                                    '${warehouse['name'] ?? 'Warehouse'}${batch == null ? '' : ' · Lot ${batch['batch_number']}'}\n${row['reason'] ?? ''}${row['reference'] == null ? '' : ' · Ref ${row['reference']}'}\n${date == null ? '' : date.toString()}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Text('${row['quantity']}'),
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
  );

  IconData _iconFor(String kind) => switch (kind) {
    'receipt' || 'return' || 'transfer_in' => Icons.south_west,
    'issue' || 'wastage' || 'transfer_out' => Icons.north_east,
    _ => Icons.tune,
  };
}
