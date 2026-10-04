import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Admin services: users, roles, categories, settings, audit, reports, notifications.
class AdminService {
  final SupabaseClient _db = Supabase.instance.client;

  // ----- Users -----

  Future<List<Profile>> users({String search = ''}) async {
    var q = _db.from('profiles').select();
    final text = search.trim();
    if (text.isNotEmpty) {
      final like = '%$text%';
      q = q.or('full_name.ilike.$like,email.ilike.$like');
    }
    final rows = await q.order('created_at', ascending: false).limit(500);
    return rows.map(Profile.fromMap).toList();
  }

  Future<Profile> userById(String id) async {
    final row =
        await _db.from('profiles').select().eq('id', id).maybeSingle();
    if (row == null) throw StateError('User not found');
    return Profile.fromMap(row);
  }

  /// Creates an auth user + profile. Requires the service-role edge function
  /// or dashboard; here we use the admin API only if the key permits it.
  /// In practice, admins invite users by email from the dashboard, or the user
  /// self-registers and the admin assigns a role here.
  Future<void> setUserRole(String userId, UserRole role) =>
      _db.from('profiles').update({'role': role.name}).eq('id', userId);

  Future<void> setUserActive(String userId, bool active) =>
      _db.from('profiles').update({'is_active': active}).eq('id', userId);

  // ----- Roles -----

  Future<List<Role>> roles() async {
    final rows = await _db.from('roles').select().order('name');
    return rows.map(Role.fromMap).toList();
  }

  Future<void> upsertRole({
    String? id,
    required String name,
    String? description,
    required List<String> permissions,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'permissions': permissions,
    };
    if (id == null) {
      await _db.from('roles').insert(payload);
    } else {
      await _db.from('roles').update(payload).eq('id', id);
    }
  }

  Future<void> deleteRole(String id) =>
      _db.from('roles').delete().eq('id', id);

  // ----- Categories -----

  Future<void> upsertCategory({
    String? id,
    required String name,
    String? description,
    required String type,
    String? parentId,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'type': type,
      'parent_id': parentId,
    };
    if (id == null) {
      await _db.from('categories').insert(payload);
    } else {
      await _db.from('categories').update(payload).eq('id', id);
    }
  }

  Future<void> deleteCategory(String id) =>
      _db.from('categories').delete().eq('id', id);

  // ----- Settings -----

  Future<Map<String, dynamic>> settings() async {
    final rows = await _db.from('settings').select('key,value');
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  Future<void> saveSetting(String key, dynamic value) =>
      _db.from('settings').upsert({'key': key, 'value': value});

  // ----- Audit -----

  Future<List<AuditLog>> auditLogs({int limit = 300}) async {
    final rows = await _db
        .from('audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AuditLog.fromMap).toList();
  }

  // ----- Reports / analytics -----

  Future<List<AccessLog>> accessLogs({int limit = 1000}) async {
    final rows = await _db
        .from('access_logs')
        .select('*, profiles(full_name,email), resources(title)')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AccessLog.fromMap).toList();
  }

  /// Simple aggregate counts for the dashboard/reports.
  Future<Map<String, int>> counts() async {
    Future<int> count(String table, {String? eqCol, String? eqVal}) async {
      var q = _db.from(table).select('id');
      if (eqCol != null) q = q.eq(eqCol, eqVal!);
      final rows = await q.count();
      return rows;
    }

    final results = <String, int>{};
    results['resources'] = await count('resources');
    results['approved'] = await count('resources', eqCol: 'status', eqVal: 'approved');
    results['pending'] = await count('resources', eqCol: 'status', eqVal: 'pending');
    results['users'] = await count('profiles');
    results['activeUsers'] = await count('profiles', eqCol: 'is_active', eqVal: 'true');
    results['categories'] = await count('categories');
    results['downloads'] = await count('access_logs', eqCol: 'action', eqVal: 'download');
    results['views'] = await count('access_logs', eqCol: 'action', eqVal: 'view');
    return results;
  }

  /// Popular resources by downloads (top [limit]).
  Future<Map<String, int>> popularByDownloads({int limit = 10}) async {
    final rows = await _db
        .from('access_logs')
        .select('resource_id, resources(title)')
        .eq('action', 'download')
        .limit(1000);
    final counts = <String, int>{};
    final titles = <String, String>{};
    for (final r in rows) {
      final rid = r['resource_id'] as String?;
      if (rid == null) continue;
      counts[rid] = (counts[rid] ?? 0) + 1;
      if (r['resources'] is Map) {
        titles[rid] = (r['resources'] as Map)['title'] as String? ?? rid;
      }
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return {
      for (final rid in sorted.take(limit)) titles[rid] ?? rid: counts[rid]!,
    };
  }

  /// Downloads per day for the last [days] days (for the chart).
  Future<Map<DateTime, int>> downloadsPerDay({int days = 14}) async {
    final since =
        DateTime.now().toUtc().subtract(Duration(days: days)).toIso8601String();
    final rows = await _db
        .from('access_logs')
        .select('created_at')
        .eq('action', 'download')
        .gte('created_at', since)
        .limit(5000);
    final map = <DateTime, int>{};
    for (final r in rows) {
      final dt = DateTime.parse(r['created_at'] as String).toLocal();
      final day = DateTime(dt.year, dt.month, dt.day);
      map[day] = (map[day] ?? 0) + 1;
    }
    return map;
  }

  /// Notification for a user (used by admin broadcasts).
  Future<void> broadcast(String title, String body) async {
    final profiles = await _db.from('profiles').select('id').eq('is_active', true);
    final adminId = _db.auth.currentUser!.id;
    final rows = [
      for (final p in profiles)
        {
          'user_id': p['id'],
          'title': title,
          'body': body,
          'type': 'system',
        },
    ];
    await _db.from('notifications').insert(rows);
    await _db.from('audit_logs').insert({
      'actor_id': adminId,
      'action': 'update',
      'entity': 'settings',
      'entity_label': 'Broadcast notification: $title',
    });
  }
}

/// Notification service for the signed-in user.
class NotificationService {
  final SupabaseClient _db = Supabase.instance.client;

  RealtimeChannel subscribe(void Function(AppNotification) onInsert) {
    final uid = _db.auth.currentUser!.id;
    return _db
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: 'user_id=eq.$uid',
          callback: (payload) {
            final row = (payload.newRecord as Map).cast<String, dynamic>();
            onInsert(AppNotification.fromMap(row));
          },
        )
        .subscribe();
  }

  Future<List<AppNotification>> list({int limit = 100}) async {
    final rows = await _db
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> unreadCount() async {
    final res = await _db
        .from('notifications')
        .select('id')
        .eq('read', false)
        .count();
    return res;
  }

  Future<void> markRead(String id) =>
      _db.from('notifications').update({'read': true}).eq('id', id);

  Future<void> markAllRead() async {
    final uid = _db.auth.currentUser!.id;
    await _db
        .from('notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('read', false);
  }
}
