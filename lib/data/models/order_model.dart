import 'dart:convert';

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final double total;
  final String? variant;
  final double? taxAmount;

  OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.total,
    this.variant,
    this.taxAmount,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      variant: json['variant'] as String?,
      taxAmount: (json['taxAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total': total,
      'variant': variant,
      'taxAmount': taxAmount,
    };
  }
}

class OrderModel {
  final String? id;
  final String adminId;
  final String? shopName;
  final String? employeeId;
  final String billNumber;
  final DateTime? orderDate;
  final String? orderType;
  final String? tableNumber;
  final String? kotNumber;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final double? discount;
  final double? tax;
  final double? roundOff;
  final double finalAmount;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? transactionId;
  final String? status;
  final String? kotStatus;
  final String? cancelReason;
  final String? notes;
  final String? syncStatus;
  final DateTime? billDate;
  final double? netAmount;
  final String? unknownCustomerId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
    this.id,
    required this.adminId,
    this.employeeId,
    required this.billNumber,
    this.orderDate,
    this.orderType,
    this.tableNumber,
    this.kotNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.totalAmount,
    this.discount,
    this.tax,
    this.roundOff,
    required this.finalAmount,
    this.paymentMethod,
    this.paymentStatus,
    this.transactionId,
    this.status,
    this.cancelReason,
    this.notes,
    this.syncStatus,
    this.billDate,
    this.netAmount,
    this.createdAt,
    this.updatedAt,
    this.shopName,
    this.unknownCustomerId,
    this.kotStatus,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String adminId = '';
    String? shopName;

    if (json['adminId'] is Map) {
      adminId = json['adminId']['_id']?.toString() ?? '';
      shopName = json['adminId']['shopName']?.toString();
    } else {
      adminId = json['adminId']?.toString() ?? '';
    }

    return OrderModel(
      id: json['_id']?.toString(),
      adminId: adminId,
      shopName: shopName,
      employeeId: json['employeeId']?.toString(),
      billNumber: json['billNumber']?.toString() ?? '',
      orderDate: json['orderDate'] != null ? DateTime.tryParse(json['orderDate'].toString()) : null,
      orderType: json['orderType']?.toString(),
      tableNumber: json['tableNumber']?.toString(),
      kotNumber: json['kotNumber']?.toString(),
      customerId: json['customerId'] is Map
          ? json['customerId']['_id']?.toString()
          : json['customerId']?.toString(),
      customerName: json['customerName']?.toString(),
      customerPhone: json['customerPhone']?.toString(),
      items:
          (json['items'] as List<dynamic>?)?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? (json['discountAmount'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble() ?? (json['taxAmount'] as num?)?.toDouble(),
      roundOff: (json['roundOff'] as num?)?.toDouble(),
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? (json['netAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString(),
      paymentStatus: json['paymentStatus']?.toString(),
      transactionId: json['transactionId']?.toString(),
      status: json['status']?.toString(),
      cancelReason: json['cancelReason']?.toString(),
      notes: json['notes']?.toString(),
      syncStatus: json['syncStatus']?.toString(),
      billDate: json['billDate'] != null ? DateTime.tryParse(json['billDate'].toString()) : null,
      netAmount: (json['netAmount'] as num?)?.toDouble(),
      kotStatus: json['kotStatus']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      unknownCustomerId: json['unknownCustomerId'] is Map
          ? json['unknownCustomerId']['_id']?.toString()
          : json['unknownCustomerId']?.toString(),
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    List<OrderItem> itemsList = [];
    if (map['items'] != null) {
      try {
        final decoded = map['items'] is String ? jsonDecode(map['items']) : map['items'];
        if (decoded is List) {
          itemsList = decoded.map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        }
      } catch (_) {}
    }
    return OrderModel(
      id: map['id']?.toString(),
      adminId: map['admin_uid'] as String? ?? '',
      billNumber: map['bill_number']?.toString() ?? map['billNumber']?.toString() ?? '',
      orderDate: map['order_date'] != null
          ? (map['order_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['order_date'] as int)
              : DateTime.tryParse(map['order_date'].toString()))
          : null,
      orderType: map['order_type'] as String?,
      tableNumber: map['table_number']?.toString(),
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      customerId: map['customer_id'] as String?,
      items: itemsList,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount_amount'] as num?)?.toDouble(),
      tax: (map['tax_amount'] as num?)?.toDouble(),
      finalAmount: (map['final_total'] as num?)?.toDouble() ?? (map['net_amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['payment_type'] as String? ?? map['payment_method'] as String?,
      notes: map['notes'] as String? ?? map['customer_note'] as String?,
      syncStatus: map['sync_status'] as String?,
      unknownCustomerId: map['unknown_customer_id'] as String?,
      kotStatus: map['kot_status'] as String?,
      billDate: map['bill_date'] != null
          ? (map['bill_date'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['bill_date'] as int)
              : DateTime.tryParse(map['bill_date'].toString()))
          : null,
      createdAt: map['created_at'] != null
          ? (map['created_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int)
              : DateTime.tryParse(map['created_at'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'adminId': adminId,
      'employeeId': employeeId,
      'billNumber': billNumber,
      'orderDate': orderDate?.toIso8601String(),
      'orderType': orderType,
      'tableNumber': tableNumber,
      'kotNumber': kotNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'items': items.map((e) => e.toJson()).toList(),
      'totalAmount': totalAmount,
      'discount': discount,
      'tax': tax,
      'roundOff': roundOff,
      'finalAmount': finalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'transactionId': transactionId,
      'status': status,
      'kotStatus': kotStatus,
      'cancelReason': cancelReason,
      'notes': notes,
      'syncStatus': syncStatus,
      'billDate': billDate?.toIso8601String(),
      'netAmount': netAmount,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'unknownCustomerId': unknownCustomerId,
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'admin_uid': adminId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'items': jsonEncode(items.map((e) => e.toJson()).toList()),
      'total_amount': totalAmount,
      'discount_amount': discount,
      'tax_amount': tax,
      'net_amount': finalAmount,
      'final_total': finalAmount,
      'payment_method': paymentMethod,
      'payment_type': paymentMethod,
      'notes': notes,
      'sync_status': syncStatus ?? 'pending',
      'bill_date': billDate?.millisecondsSinceEpoch ?? orderDate?.millisecondsSinceEpoch,
      'order_date': orderDate?.millisecondsSinceEpoch,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'order_type': orderType,
      'table_number': tableNumber,
      'bill_number': billNumber,
      'unknown_customer_id': unknownCustomerId,
    };
  }
}
