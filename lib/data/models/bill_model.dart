// Dart imports:
import 'dart:convert';

// Project imports:
import 'package:pos/domain/entities/bill.dart';
import 'package:pos/domain/entities/food_item.dart';

/// Bill Model - Data layer representation
class BillModel extends Bill {
  const BillModel({
    required super.id,
    required super.adminUid,
    required super.items,
    required super.totalAmount,
    super.taxAmount,
    super.discountAmount,
    super.customerName,
    super.customerPhone,
    super.paymentMethod,
    required super.billDate,
    super.createdAt,
    super.updatedAt,
    super.syncState,
  });

  /// Create from Map (SQLite/Firebase)
  factory BillModel.fromMap(Map<String, dynamic> map) {
    return BillModel(
      id: map['id']?.toString() ?? '',
      adminUid: map['admin_uid']?.toString() ?? map['adminUid']?.toString() ?? '',
      items: _parseItems(map['items']),
      totalAmount: _parseDouble(map['total_amount'] ?? map['totalAmount']),
      taxAmount: _parseDoubleNullable(map['tax_amount'] ?? map['taxAmount']),
      discountAmount: _parseDoubleNullable(map['discount_amount'] ?? map['discountAmount']),
      customerName: map['customer_name']?.toString() ?? map['customerName']?.toString(),
      customerPhone: map['customer_phone']?.toString() ?? map['customerPhone']?.toString(),
      paymentMethod: map['payment_method']?.toString() ?? map['paymentMethod']?.toString(),
      billDate: _parseDateTime(map['bill_date'] ?? map['billDate']) ?? DateTime.now(),
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
      syncState: _parseSyncState(map['sync_status'] ?? map['syncStatus']),
    );
  }

  /// Create from domain entity
  factory BillModel.fromEntity(Bill entity) {
    return BillModel(
      id: entity.id,
      adminUid: entity.adminUid,
      items: entity.items,
      totalAmount: entity.totalAmount,
      taxAmount: entity.taxAmount,
      discountAmount: entity.discountAmount,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      paymentMethod: entity.paymentMethod,
      billDate: entity.billDate,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      syncState: entity.syncState,
    );
  }

  /// Convert to Map for SQLite
  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'admin_uid': adminUid,
      'items': jsonEncode(items.map((e) => BillItemModel.fromEntity(e).toMap()).toList()),
      'total_amount': totalAmount,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'payment_method': paymentMethod,
      'bill_date': billDate.millisecondsSinceEpoch,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'sync_status': syncState.index,
    };
  }

  /// Convert to Map for Firebase
  Map<String, dynamic> toFirebaseMap() {
    return {
      'id': id,
      'adminUid': adminUid,
      'items': items.map((e) => BillItemModel.fromEntity(e).toMap()).toList(),
      'totalAmount': totalAmount,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'paymentMethod': paymentMethod,
      'billDate': billDate.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Convert to domain entity
  Bill toEntity() {
    return Bill(
      id: id,
      adminUid: adminUid,
      items: items,
      totalAmount: totalAmount,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      customerName: customerName,
      customerPhone: customerPhone,
      paymentMethod: paymentMethod,
      billDate: billDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      syncState: syncState,
    );
  }

  static List<BillItem> _parseItems(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => BillItemModel.fromMap(e as Map<String, dynamic>)).toList();
    }
    if (value is String) {
      try {
        final List<dynamic> decoded = jsonDecode(value);
        return decoded.map((e) => BillItemModel.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    return _parseDouble(value);
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

/// Bill Item Model
class BillItemModel extends BillItem {
  const BillItemModel({
    required super.foodItemId,
    required super.name,
    required super.price,
    required super.quantity,
    super.department,
  });

  factory BillItemModel.fromMap(Map<String, dynamic> map) {
    return BillItemModel(
      foodItemId: map['food_item_id']?.toString() ?? map['foodItemId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      price: BillModel._parseDouble(map['price']),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      department: map['department']?.toString(),
    );
  }

  factory BillItemModel.fromEntity(BillItem entity) {
    return BillItemModel(
      foodItemId: entity.foodItemId,
      name: entity.name,
      price: entity.price,
      quantity: entity.quantity,
      department: entity.department,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'foodItemId': foodItemId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'department': department,
    };
  }
}
