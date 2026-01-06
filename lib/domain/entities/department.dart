// Project imports:
import 'food_item.dart';

/// Department domain entity
class Department {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String status;
  final String adminUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  const Department({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.status = 'Active',
    required this.adminUid,
    this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.synced,
  });

  Department copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? status,
    String? adminUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return Department(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      adminUid: adminUid ?? this.adminUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }

  bool get isActive => status == 'Active';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Department &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          adminUid == other.adminUid;

  @override
  int get hashCode => id.hashCode ^ adminUid.hashCode;
}
