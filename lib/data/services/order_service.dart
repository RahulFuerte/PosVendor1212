import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../constants/api_constants.dart';

class OrderService {
  static const String baseUrl = ApiConstants.orders;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<OrderModel> createOrder({
    required String adminId,
    required String billNumber,
    String? customerId,
    String? customerName,
    String? customerPhone,
    required List<Map<String, dynamic>> items,
    double? discount,
    double? tax,
    String? paymentMethod,
    String? orderType,
    String? tableNumber,
    String? notes,
    String? paymentStatus,
  }) async {
    // Normalization helper
    String normalize(String? value) {
      if (value == null || value.isEmpty) return "";
      if (value.toLowerCase() == 'dinein') return 'DineIn';
      if (value.toLowerCase() == 'pickup') return 'PickUp';
      if (value.toLowerCase() == 'delivery') return 'Delivery';
      if (value.toLowerCase() == 'cash') return 'Cash';
      if (value.toLowerCase() == 'upi') return 'UPI';
      if (value.toLowerCase() == 'card') return 'Card';
      if (value.toLowerCase() == 'complementory') return 'Complementory';
      if (value.toLowerCase() == 'debit') return 'Debit';
      if (value.toLowerCase() == 'paid') return 'Paid';
      if (value.toLowerCase() == 'partial') return 'Partial';
      if (value.toLowerCase() == 'due') return 'Due';
      // Fallback: capitalize first letter
      return value[0].toUpperCase() + value.substring(1);
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      final List<OrderItem> orderItems = items.map((item) {
        return OrderItem(
          productId: item['productId']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          quantity: (item['quantity'] as num?)?.toInt() ?? 0,
          total: ((item['price'] as num?)?.toDouble() ?? 0.0) * ((item['quantity'] as num?)?.toInt() ?? 0),
        );
      }).toList();

      final total = orderItems.fold(0.0, (sum, item) => sum + item.total);

      return OrderModel(
        id: "demo_order_${DateTime.now().millisecondsSinceEpoch}",
        adminId: adminId,
        billNumber: billNumber,
        items: orderItems,
        totalAmount: total,
        finalAmount: total,
        paymentMethod: paymentMethod ?? "Cash",
        orderType: orderType ?? "DineIn",
        createdAt: DateTime.now(),
      );
    }

    final token = await _getToken();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'adminId': adminId,
        'billNumber': billNumber,
        'customerId': (customerId == null || customerId.isEmpty) ? null : customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items,
        'discount': discount,
        'tax': tax,
        'paymentMethod': normalize(paymentMethod),
        'orderType': normalize(orderType),
        'tableNumber': tableNumber,
        'notes': notes,
        'paymentStatus': normalize(paymentStatus),
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return OrderModel.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Failed to create order');
    }
  }

  Future<List<OrderModel>> getOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? orderType,
  }) async {
    final token = await _getToken();

    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate.toIso8601String().split('T')[0];
    if (endDate != null) queryParams['endDate'] = endDate.toIso8601String().split('T')[0];
    if (paymentMethod != null) queryParams['paymentMethod'] = paymentMethod;
    if (orderType != null) queryParams['orderType'] = orderType;

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List ordersList = data['data'];
      return ordersList.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to get orders');
    }
  }
}
