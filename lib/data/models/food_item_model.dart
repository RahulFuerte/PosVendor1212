// Project imports:
import 'package:pos/domain/entities/food_item.dart';

/// Food Item Model - Data layer representation
/// Handles serialization/deserialization to/from Map (SQLite/Firebase)
class FoodItemModel extends FoodItem {
  const FoodItemModel({
    required super.id,
    required super.name,
    super.description,
    required super.price,
    super.foodCode,
    required super.department,
    super.imageUrl,
    super.stocks,
    super.isHot,
    required super.adminUid,
    super.createdAt,
    super.updatedAt,
    super.syncState,
  });

  /// Create from Map (SQLite/Firebase)
  factory FoodItemModel.fromMap(Map<String, dynamic> map) {
    return FoodItemModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      price: _parseDouble(map['price']),
      foodCode: map['food_code']?.toString() ?? map['foodCode']?.toString(),
      department: map['department']?.toString() ?? '',
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString(),
      stocks: _parseInt(map['stocks']),
      isHot: _parseBool(map['is_hot'] ?? map['isHot']),
      adminUid: map['admin_uid']?.toString() ?? map['adminUid']?.toString() ?? '',
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
      syncState: _parseSyncState(map['sync_status'] ?? map['syncStatus']),
    );
  }

  /// Create from domain entity
  factory FoodItemModel.fromEntity(FoodItem entity) {
    return FoodItemModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      price: entity.price,
      foodCode: entity.foodCode,
      department: entity.department,
      imageUrl: entity.imageUrl,
      stocks: entity.stocks,
      isHot: entity.isHot,
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
      'price': price,
      'food_code': foodCode,
      'department': department,
      'image_url': imageUrl,
      'stocks': stocks,
      'is_hot': isHot ? 1 : 0,
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
      'price': price,
      'foodCode': foodCode,
      'department': department,
      'imageUrl': imageUrl,
      'stocks': stocks,
      'isHot': isHot,
      'adminUid': adminUid,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  FoodItem toEntity() {
    return FoodItem(
      id: id,
      name: name,
      description: description,
      price: price,
      foodCode: foodCode,
      department: department,
      imageUrl: imageUrl,
      stocks: stocks,
      isHot: isHot,
      adminUid: adminUid,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncState: syncState,
    );
  }

  // Helper parsing methods
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    return false;
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
