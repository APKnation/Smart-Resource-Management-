import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Search filters for the resource browser.
class ResourceQuery {
  final String search;
  final ResourceType? type;
  final String? categoryId;
  final ResourceStatus? status;
  final bool onlyFavorites;
  final bool onlyMine;
  final int limit;

  const ResourceQuery({
    this.search = '',
    this.type,
    this.categoryId,
    this.status,
    this.onlyFavorites = false,
    this.onlyMine = false,
    this.limit = 100,
  });
}

/// CRUD, upload/download, approval, versions, favorites for resources.
class ResourceService {
  final SupabaseClient _db = Supabase.instance.client;
  static const _bucket = 'resources';

  Future<List<Resource>> list(ResourceQuery q) async {
    var query = _db.from('resources').select(
        '*, profiles(full_name,email), resource_categories(categories(id,name,type))');

    final uid = _db.auth.currentUser?.id;
    final text = q.search.trim();
    if (text.isNotEmpty) {
      final like = '%$text%';
      query = query.or('title.ilike.$like,description.ilike.$like,author.ilike.$like');
    }
    if (q.type != null) query = query.eq('resource_type', q.type!.name);
    if (q.status != null) {
      query = query.eq('status', q.status!.name);
    } else if (!q.onlyMine && !q.onlyFavorites) {
      query = query.eq('status', 'approved');
    }
    if (q.categoryId != null) {
      query = query
          .eq('resource_categories.category_id', q.categoryId!);
    }
    if (q.onlyMine && uid != null) query = query.eq('uploaded_by', uid);
    if (q.onlyFavorites && uid != null) {
      query = query.eq('favorites.user_id', uid);
    }

    final rows = await query
        .order('updated_at', ascending: false)
        .limit(q.limit);
    return rows.map(Resource.fromMap).toList();
  }

  Future<Resource> get(String id) async {
    final row = await _db.from('resources').select(
        '*, profiles(full_name,email), resource_categories(categories(id,name,type))')
        .eq('id', id)
        .single();
    return Resource.fromMap(row);
  }

  Future<List<Resource>> listVersionsResources() async =>
      list(const ResourceQuery(limit: 500));

  /// Creates a resource; optionally uploads a file. Returns the new resource id.
  Future<String> create({
    required String title,
    String? description,
    String? author,
    required ResourceType type,
    String? externalUrl,
    PlatformFile? file,
    List<String> categoryIds = const [],
    required bool autoApprove,
  }) async {
    final uid = _db.auth.currentUser!.id;
    String? path;
    int? size;
    String? name;
    String? mime;

    if (file != null) {
      final ext = file.extension ?? 'bin';
      path = 'uploads/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _db.storage.from(_bucket).uploadBinary(
            path,
            await file.readAsBytes(),
            fileOptions: const FileOptions(upsert: false),
          );
      size = await file.length() ?? 0;
      name = file.name;
      mime = _mimeFromExt(ext);
    }

    final row = await _db
        .from('resources')
        .insert({
          'title': title,
          'description': description,
          'author': author,
          'resource_type': type.name,
          'external_url': externalUrl,
          'storage_path': path,
          'file_name': name,
          'file_size': size,
          'mime_type': mime,
          'uploaded_by': uid,
          'status': autoApprove ? 'approved' : 'pending',
        })
        .select('id')
        .single();

    final resourceId = row['id'] as String;
    await _setCategories(resourceId, categoryIds);
    return resourceId;
  }

  /// Updates metadata; a new [file] bumps the version (DB trigger snapshots it).
  Future<void> update(
    String id, {
    required String title,
    String? description,
    String? author,
    required ResourceType type,
    String? externalUrl,
    PlatformFile? file,
    List<String> categoryIds = const [],
    bool replaceFile = false,
  }) async {
    final uid = _db.auth.currentUser!.id;
    final patch = <String, dynamic>{
      'title': title,
      'description': description,
      'author': author,
      'resource_type': type.name,
      'external_url': externalUrl,
    };

    if (replaceFile) {
      if (file != null) {
        final ext = file.extension ?? 'bin';
        final path = 'uploads/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _db.storage.from(_bucket).uploadBinary(path, await file.readAsBytes());
        patch['storage_path'] = path;
        patch['file_name'] = file.name;
        patch['file_size'] = await file.length() ?? 0;
        patch['mime_type'] = _mimeFromExt(ext);
      } else {
        patch['storage_path'] = null;
        patch['file_name'] = null;
        patch['file_size'] = null;
        patch['mime_type'] = null;
      }
    }

    await _db.from('resources').update(patch).eq('id', id);
    await _setCategories(id, categoryIds);
  }

  Future<void> setStatus(String id, ResourceStatus status) =>
      _db.from('resources').update({'status': status.name}).eq('id', id);

  Future<void> setAvailability(String id, ResourceAvailability availability) =>
      _db.from('resources')
          .update({'availability': availability.name})
          .eq('id', id);

  Future<void> delete(String id) async {
    final row = await _db
        .from('resources')
        .select('storage_path')
        .eq('id', id)
        .maybeSingle();
    final path = row?['storage_path'] as String?;
    if (path != null) {
      try {
        await _db.storage.from(_bucket).remove([path]);
      } catch (_) {// best effort
      }
    }
    await _db.from('resources').delete().eq('id', id);
  }

  /// Uploads a new file as the next version (does not change availability).
  Future<void> addVersion(String id, PlatformFile file, String notes) async {
    final uid = _db.auth.currentUser!.id;
    final res = await get(id);
    final nextVer = res.version + 1;
    final ext = file.extension ?? 'bin';
    final path = 'versions/$id/$nextVer.$ext';
    await _db.storage.from(_bucket).uploadBinary(path, await file.readAsBytes());
    await _db.from('resource_versions').insert({
      'resource_id': id,
      'version': nextVer,
      'storage_path': path,
      'file_name': file.name,
      'file_size': await file.length() ?? 0,
      'mime_type': _mimeFromExt(ext),
      'notes': notes,
      'uploaded_by': uid,
    });
    await _db.from('resources').update({'version': nextVer}).eq('id', id);
  }

  Future<List<ResourceVersion>> versions(String resourceId) async {
    final rows = await _db
        .from('resource_versions')
        .select()
        .eq('resource_id', resourceId)
        .order('version', ascending: false);
    return rows.map(ResourceVersion.fromMap).toList();
  }

  Future<void> restoreVersion(ResourceVersion v) async {
    final current = await get(v.resourceId);
    // Snapshot current file into the versions table, then point the resource
    // at the restored version's file.
    if (current.storagePath != null) {
      await _db.from('resource_versions').insert({
        'resource_id': v.resourceId,
        'version': current.version + 1,
        'storage_path': current.storagePath,
        'file_name': current.fileName,
        'file_size': current.fileSize,
        'mime_type': current.mimeType,
        'notes': 'Snapshot before restoring v${v.version}',
        'uploaded_by': _db.auth.currentUser!.id,
      });
    }
    await _db.from('resources').update({
      'storage_path': v.storagePath,
      'file_name': v.fileName,
      'file_size': v.fileSize,
      'mime_type': v.mimeType,
      'version': current.version + 1,
    }).eq('id', v.resourceId);
  }

  // ----- viewing / downloading / access logs -----

  /// Signs a short-lived URL for viewing/downloading and logs the access.
  Future<String> signedUrl(Resource r, {bool download = false}) async {
    if (r.storagePath == null) {
      throw StateError('Resource has no file attached.');
    }
    await _db.rpc('log_access',
        params: {'p_resource_id': r.id, 'p_action': download ? 'download' : 'view'});
    return _db.storage.from(_bucket).createSignedUrl(r.storagePath!, 300);
  }

  // ----- favorites -----

  Future<List<String>> favoriteIds() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _db
        .from('favorites')
        .select('resource_id')
        .eq('user_id', uid);
    return rows.map<String>((r) => r['resource_id'] as String).toList();
  }

  Future<void> toggleFavorite(String resourceId, bool favorite) async {
    final uid = _db.auth.currentUser!.id;
    if (favorite) {
      await _db
          .from('favorites')
          .upsert({'user_id': uid, 'resource_id': resourceId});
    } else {
      await _db
          .from('favorites')
          .delete()
          .match({'user_id': uid, 'resource_id': resourceId});
    }
  }

  Future<void> logView(String resourceId) =>
      _db.rpc('log_access', params: {'p_resource_id': resourceId, 'p_action': 'view'});

  // ----- categories helpers -----

  Future<List<Category>> categories() async {
    final rows = await _db
        .from('categories')
        .select()
        .order('type')
        .order('name');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> _setCategories(String resourceId, List<String> categoryIds) async {
    await _db.from('resource_categories').delete().eq('resource_id', resourceId);
    if (categoryIds.isNotEmpty) {
      await _db.from('resource_categories').insert([
        for (final cid in categoryIds)
          {'resource_id': resourceId, 'category_id': cid},
      ]);
    }
  }

  static String _mimeFromExt(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'mp3' => 'audio/mpeg',
        'mp4' => 'video/mp4',
        'zip' => 'application/zip',
        'txt' => 'text/plain',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'ppt' => 'application/vnd.ms-powerpoint',
        'pptx' =>
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => 'application/octet-stream',
      };
}
