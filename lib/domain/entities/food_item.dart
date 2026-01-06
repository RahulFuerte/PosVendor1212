/// Food Item domain entity
/// Pure business object with no framework dependencies
class FoodItem {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? foodCode;
  final String department;
  final String? imageUrl;
  final int stocks;
  final bool isHot;
  final String adminUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  const FoodItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.foodCode,
    required this.department,
    this.imageUrl,
    this.stocks = 0,
    this.isHot = false,
    required this.adminUid,
    this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.synced,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? foodCode,
    String? department,
    String? imageUrl,
    int? stocks,
    bool? isHot,
    String? adminUid,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      foodCode: foodCode ?? this.foodCode,
      department: department ?? this.department,
      imageUrl: imageUrl ?? this.imageUrl,
      stocks: stocks ?? this.stocks,
      isHot: isHot ?? this.isHot,
      adminUid: adminUid ?? this.adminUid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          adminUid == other.adminUid;

  @override
  int get hashCode => id.hashCode ^ adminUid.hashCode;
}

/// Sync state for offline-first functionality
enum SyncState {
  synced,
  pending,
  conflict,
}
