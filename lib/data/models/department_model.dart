// Project imports:
import 'package:pos/domain/entities/department.dart';
import 'package:pos/domain/entities/food_item.dart';

/// Department Model - Data layer representation
class DepartmentModel extends Department {
  const DepartmentModel({
    required super.id,
    required super.name,
    super.description,
    super.imageUrl,
    super.status,
    required super.adminUid,
    super.createdAt,
    super.updatedAt,
    super.syncState,
  });

  /// Create from Map (SQLite/Firebase)
  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    return DepartmentModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString(),
      status: map['status']?.toString() ?? 'Active',
      adminUid: map['admin_uid']?.toString() ?? map['adminUid']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
      syncState: _parseSyncState(map['sync_status'] ?? map['syncStatus']),
    );
  }

  /// Create from domain entity
  factory DepartmentModel.fromEntity(Department entity) {
    return DepartmentModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      imageUrl: entity.imageUrl,
      status: entity.status,
      adminUid: entity.adminUid,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      syncState: entity.syncState,
    );
  }

  /// Convert to Map for SQLite
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'status': status,
      'admin_uid': adminUid,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'sync_status': syncState.index,
    };
  }

  /// Convert to Map for Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'status': status,
      'adminUid': adminUid,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  Department toEntity() {
    return Department(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      status: status,
      adminUid: adminUid,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncState: syncState,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static SyncState _parseSyncState(dynamic value) {
    if (value == null) return SyncState.synced;
    if (value is SyncState) return value;
    if (value is int) {
      return SyncState.values[value.clamp(0, SyncState.values.length - 1)];
    }
    return SyncState.synced;
  }
}
