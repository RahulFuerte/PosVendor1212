// Project imports:
import 'food_item.dart';

/// Bill domain entity
class Bill {
  final String id;
  final String adminUid;
  final List<BillItem> items;
  final double totalAmount;
  final double? taxAmount;
  final double? discountAmount;
  final String? customerName;
  final String? customerPhone;
  final String? paymentMethod;
  final DateTime billDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final SyncState syncState;

  const Bill({
    required this.id,
    required this.adminUid,
    required this.items,
    required this.totalAmount,
    this.taxAmount,
    this.discountAmount,
    this.customerName,
    this.customerPhone,
    this.paymentMethod,
    required this.billDate,
    this.createdAt,
    this.updatedAt,
    this.syncState = SyncState.synced,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);
  
  double get finalAmount {
    double amount = subtotal;
    if (taxAmount != null) amount += taxAmount!;
    if (discountAmount != null) amount -= discountAmount!;
    return amount;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Bill copyWith({
    String? id,
    String? adminUid,
    List<BillItem>? items,
    double? totalAmount,
    double? taxAmount,
    double? discountAmount,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    DateTime? billDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
  }) {
    return Bill(
      id: id ?? this.id,
      adminUid: adminUid ?? this.adminUid,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      billDate: billDate ?? this.billDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bill &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          adminUid == other.adminUid;

  @override
  int get hashCode => id.hashCode ^ adminUid.hashCode;
}

/// Bill item (line item in a bill)
class BillItem {
  final String foodItemId;
  final String name;
  final double price;
  final int quantity;
  final String? department;

  const BillItem({
    required this.foodItemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.department,
  });

  double get totalPrice => price * quantity;

  BillItem copyWith({
    String? foodItemId,
    String? name,
    double? price,
    int? quantity,
    String? department,
  }) {
    return BillItem(
      foodItemId: foodItemId ?? this.foodItemId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      department: department ?? this.department,
    );
  }
}
