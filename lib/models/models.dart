/// Data models for the E-Resources Management System.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum UserRole { admin, librarian, staff, user }

extension UserRoleX on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Administrator',
        UserRole.librarian => 'Librarian',
        UserRole.staff => 'Staff',
        UserRole.user => 'User',
      };

  IconData get icon => switch (this) {
        UserRole.admin => Icons.admin_panel_settings_outlined,
        UserRole.librarian => Icons.local_library_outlined,
        UserRole.staff => Icons.badge_outlined,
        UserRole.user => Icons.person_outline,
      };

  static UserRole fromName(String? name) =>
      UserRole.values.firstWhere((e) => e.name == name,
          orElse: () => UserRole.user);
}

enum ResourceStatus { pending, approved, rejected, archived }

extension ResourceStatusX on ResourceStatus {
  String get label => switch (this) {
        ResourceStatus.pending => 'Pending',
        ResourceStatus.approved => 'Approved',
        ResourceStatus.rejected => 'Rejected',
        ResourceStatus.archived => 'Archived',
      };

  Color get color => switch (this) {
        ResourceStatus.pending => Colors.orange,
        ResourceStatus.approved => Colors.green,
        ResourceStatus.rejected => Colors.red,
        ResourceStatus.archived => Colors.blueGrey,
      };

  static ResourceStatus fromName(String? name) => ResourceStatus.values
      .firstWhere((e) => e.name == name, orElse: () => ResourceStatus.pending);
}

enum ResourceAvailability { active, inactive, restricted, archived }

extension ResourceAvailabilityX on ResourceAvailability {
  String get label => switch (this) {
        ResourceAvailability.active => 'Active',
        ResourceAvailability.inactive => 'Inactive',
        ResourceAvailability.restricted => 'Restricted',
        ResourceAvailability.archived => 'Archived',
      };

  static ResourceAvailability fromName(String? name) =>
      ResourceAvailability.values.firstWhere((e) => e.name == name,
          orElse: () => ResourceAvailability.active);
}

enum ResourceType { pdf, document, presentation, video, audio, image, link, other }

extension ResourceTypeX on ResourceType {
  String get label => switch (this) {
        ResourceType.pdf => 'PDF',
        ResourceType.document => 'Document',
        ResourceType.presentation => 'Presentation',
        ResourceType.video => 'Video',
        ResourceType.audio => 'Audio',
        ResourceType.image => 'Image',
        ResourceType.link => 'Link',
        ResourceType.other => 'Other',
      };

  static ResourceType fromName(String? name) => ResourceType.values
      .firstWhere((e) => e.name == name, orElse: () => ResourceType.other);
}

enum NotificationType { newResource, approved, rejected, updated, system }

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
        NotificationType.newResource => 'New resource',
        NotificationType.approved => 'Approved',
        NotificationType.rejected => 'Rejected',
        NotificationType.updated => 'Updated',
        NotificationType.system => 'System',
      };

  static NotificationType fromName(String? name) => NotificationType.values
      .firstWhere((e) => e.name == name, orElse: () => NotificationType.system);
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class Profile {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? department;
  final String? institution;
  final String? avatarUrl;
  final bool isActive;
  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.institution,
    this.avatarUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        email: (map['email'] ?? '') as String,
        fullName: (map['full_name'] ?? '') as String,
        role: UserRoleX.fromName(map['role'] as String?),
        department: map['department'] as String?,
        institution: map['institution'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        isActive: (map['is_active'] ?? true) as bool,
        createdAt:
            map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'department': department,
        'institution': institution,
        'avatar_url': avatarUrl,
        'is_active': isActive,
      };
}

// ---------------------------------------------------------------------------
// Role
// ---------------------------------------------------------------------------

class Role {
  final String id;
  final String name;
  final String? description;
  final List<String> permissions;
  final bool isSystem;

  const Role({
    required this.id,
    required this.name,
    this.description,
    this.permissions = const [],
    this.isSystem = false,
  });

  factory Role.fromMap(Map<String, dynamic> map) => Role(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        permissions:
            ((map['permissions'] as List?) ?? const []).cast<String>().toList(),
        isSystem: (map['is_system'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// Category
// ---------------------------------------------------------------------------

class Category {
  final String id;
  final String name;
  final String? description;
  final String type;
  final String? parentId;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.type = 'subject',
    this.parentId,
  });

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String?,
        type: (map['type'] ?? 'subject') as String,
        parentId: map['parent_id'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Resource + Version
// ---------------------------------------------------------------------------

class Resource {
  final String id;
  final String title;
  final String? description;
  final String? author;
  final ResourceType resourceType;
  final ResourceStatus status;
  final ResourceAvailability availability;
  final String? storagePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? externalUrl;
  final int version;
  final String uploadedBy;
  final Profile? uploader;
  final List<Category> categories;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Resource({
    required this.id,
    required this.title,
    this.description,
    this.author,
    this.resourceType = ResourceType.other,
    this.status = ResourceStatus.pending,
    this.availability = ResourceAvailability.active,
    this.storagePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.externalUrl,
    this.version = 1,
    required this.uploadedBy,
    this.uploader,
    this.categories = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isDownloadable =>
      storagePath != null &&
      status == ResourceStatus.approved &&
      (availability == ResourceAvailability.active ||
          availability == ResourceAvailability.restricted);

  factory Resource.fromMap(Map<String, dynamic> map) {
    final uploader = map['profiles'] is Map
        ? Profile.fromMap((map['profiles'] as Map).cast<String, dynamic>())
        : null;
    final cats = <Category>[];
    if (map['resource_categories'] is List) {
      for (final rc in (map['resource_categories'] as List)) {
        if (rc is Map && rc['categories'] is Map) {
          cats.add(
              Category.fromMap((rc['categories'] as Map).cast<String, dynamic>()));
        }
      }
    }
    return Resource(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      author: map['author'] as String?,
      resourceType: ResourceTypeX.fromName(map['resource_type'] as String?),
      status: ResourceStatusX.fromName(map['status'] as String?),
      availability:
          ResourceAvailabilityX.fromName(map['availability'] as String?),
      storagePath: map['storage_path'] as String?,
      fileName: map['file_name'] as String?,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
      externalUrl: map['external_url'] as String?,
      version: (map['version'] ?? 1) as int,
      uploadedBy: (map['uploaded_by'] ?? '') as String,
      uploader: uploader,
      categories: cats,
      createdAt:
          map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      updatedAt:
          map['updated_at'] == null ? null : DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'author': author,
        'resource_type': resourceType.name,
        'status': status.name,
        'availability': availability.name,
        'storage_path': storagePath,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'external_url': externalUrl,
        'uploaded_by': uploadedBy,
      };
}

class ResourceVersion {
  final String id;
  final String resourceId;
  final int version;
  final String? storagePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? notes;
  final DateTime? createdAt;

  const ResourceVersion({
    required this.id,
    required this.resourceId,
    required this.version,
    this.storagePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.notes,
    this.createdAt,
  });

  factory ResourceVersion.fromMap(Map<String, dynamic> map) =>
      ResourceVersion(
        id: map['id'] as String,
        resourceId: map['resource_id'] as String,
        version: (map['version'] ?? 1) as int,
        storagePath: map['storage_path'] as String?,
        fileName: map['file_name'] as String?,
        fileSize: map['file_size'] as int?,
        mimeType: map['mime_type'] as String?,
        notes: map['notes'] as String?,
        createdAt:
            map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      );
}

// ---------------------------------------------------------------------------
// Notifications / Audit / Access
// ---------------------------------------------------------------------------

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final NotificationType type;
  final String? link;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.type = NotificationType.system,
    this.link,
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) =>
      AppNotification(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        title: map['title'] as String,
        body: map['body'] as String?,
        type: NotificationTypeX.fromName(map['type'] as String?),
        link: map['link'] as String?,
        read: (map['read'] ?? false) as bool,
        createdAt:
            map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      );
}

class AuditLog {
  final String id;
  final String? actorId;
  final String? actorEmail;
  final String action;
  final String entity;
  final String? entityId;
  final String? entityLabel;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;

  const AuditLog({
    required this.id,
    this.actorId,
    this.actorEmail,
    required this.action,
    required this.entity,
    this.entityId,
    this.entityLabel,
    this.details,
    this.createdAt,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) => AuditLog(
        id: map['id'] as String,
        actorId: map['actor_id'] as String?,
        actorEmail: map['actor_email'] as String?,
        action: (map['action'] ?? '') as String,
        entity: (map['entity'] ?? '') as String,
        entityId: map['entity_id'] as String?,
        entityLabel: map['entity_label'] as String?,
        details: map['details'] as Map<String, dynamic>?,
        createdAt:
            map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      );
}

class AccessLog {
  final String id;
  final String? userId;
  final String? resourceId;
  final String action;
  final DateTime? createdAt;
  final Profile? user;
  final Resource? resource;

  const AccessLog({
    required this.id,
    this.userId,
    this.resourceId,
    required this.action,
    this.createdAt,
    this.user,
    this.resource,
  });

  factory AccessLog.fromMap(Map<String, dynamic> map) {
    final user = map['profiles'] is Map
        ? Profile.fromMap((map['profiles'] as Map).cast<String, dynamic>())
        : null;
    final resource = map['resources'] is Map
        ? Resource.fromMap((map['resources'] as Map).cast<String, dynamic>())
        : null;
    return AccessLog(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      resourceId: map['resource_id'] as String?,
      action: (map['action'] ?? '') as String,
      createdAt:
          map['created_at'] == null ? null : DateTime.parse(map['created_at']),
      user: user,
      resource: resource,
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class Setting {
  final String key;
  final dynamic value;

  const Setting({required this.key, this.value});

  factory Setting.fromMap(Map<String, dynamic> map) =>
      Setting(key: map['key'] as String, value: map['value']);
}
