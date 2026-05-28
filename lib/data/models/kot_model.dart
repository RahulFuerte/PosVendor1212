
class KotItem {
  final String productId;
  final String name;
  final int quantity;
  final String? variant;

  KotItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.variant,
  });

  factory KotItem.fromJson(Map<String, dynamic> json) {
    return KotItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      variant: json['variant']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'variant': variant,
    };
  }
}

class KotModel {
  final String? id;
  final String adminId;
  final String? orderId;
  final String? billNumber;
  final String? customerName;
  final String? orderType;
  final String kotNumber;
  final String? tableNumber;
  final List<KotItem> items;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  KotModel({
    this.id,
    required this.adminId,
    this.orderId,
    this.billNumber,
    this.customerName,
    this.orderType,
    required this.kotNumber,
    this.tableNumber,
    required this.items,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory KotModel.fromJson(Map<String, dynamic> json) {
    // Handle populated orderId
    String? ordId;
    String? billNo;
    String? custName;
    String? ordType;

    if (json['orderId'] is Map) {
      ordId = json['orderId']['_id']?.toString();
      billNo = json['orderId']['billNumber']?.toString();
      custName = json['orderId']['customerName']?.toString();
      ordType = json['orderId']['orderType']?.toString();
    } else {
      ordId = json['orderId']?.toString();
    }

    return KotModel(
      id: json['_id']?.toString(),
      adminId: json['adminId']?.toString() ?? '',
      orderId: ordId,
      billNumber: billNo,
      customerName: custName,
      orderType: ordType,
      kotNumber: json['kotNumber']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString(),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => KotItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'adminId': adminId,
      'orderId': orderId,
      'kotNumber': kotNumber,
      'tableNumber': tableNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
