// Project imports:
import 'food_item.dart';

/// Customer domain entity
class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String adminUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.adminUid,
    this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.synced,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? adminUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      adminUid: adminUid ?? this.adminUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          adminUid == other.adminUid;

  @override
  int get hashCode => id.hashCode ^ adminUid.hashCode;
}
