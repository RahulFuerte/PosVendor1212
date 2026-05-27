import 'dart:convert';

class TableModel {
  final String id;
  final String tableNumber;
  List<Map<String, dynamic>> items;
  double subtotal;
  String? customerName;
  String? customerPhone;
  bool isOccupied;
  String? lastOrderId;
  String? currentOrderId;

  TableModel({
    required this.id,
    required this.tableNumber,
    this.items = const [],
    this.subtotal = 0.0,
    this.customerName,
    this.customerPhone,
    this.isOccupied = false,
    this.lastOrderId,
    this.currentOrderId,
  });

  TableModel copyWith({
    String? id,
    String? tableNumber,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    String? customerName,
    String? customerPhone,
    bool? isOccupied,
    String? lastOrderId,
    String? currentOrderId,
  }) {
    return TableModel(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      isOccupied: isOccupied ?? this.isOccupied,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      currentOrderId: currentOrderId ?? this.currentOrderId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tableNumber': tableNumber,
      'items': jsonEncode(items),
      'subtotal': subtotal,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'isOccupied': isOccupied ? 1 : 0,
      'lastOrderId': lastOrderId,
      'currentOrderId': currentOrderId,
    };
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id']?.toString() ?? map['_id']?.toString() ?? '',
      tableNumber: map['tableNumber']?.toString() ?? '',
      items: map['items'] is String
          ? List<Map<String, dynamic>>.from(jsonDecode(map['items']))
          : List<Map<String, dynamic>>.from(map['items'] ?? []),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      customerName: map['customerName'],
      customerPhone: map['customerPhone'],
      isOccupied: map['isOccupied'] == 1 || map['status'] == 'Occupied' || (map['isOccupied'] is bool && map['isOccupied'] == true),
      lastOrderId: map['lastOrderId']?.toString(),
      currentOrderId: map['currentOrderId']?.toString(),
    );
  }

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel.fromMap(json);
  }
}
