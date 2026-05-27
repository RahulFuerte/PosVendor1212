import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';
import '../constants/api_constants.dart';

class OrderService {
  static const String baseUrl = ApiConstants.orders;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  String _normalize(String? value) {
    if (value == null || value.isEmpty) return "";
    String lower = value.toLowerCase();
    if (lower == 'dinein') return 'DineIn';
    if (lower == 'pickup') return 'PickUp';
    if (lower == 'delivery') return 'Delivery';
    if (lower == 'cash') return 'Cash';
    if (lower == 'upi') return 'UPI';
    if (lower == 'card') return 'Card';
    if (lower == 'complementory') return 'Complementory';
    if (lower == 'debit') return 'Debit';
    if (lower == 'paid') return 'Paid';
    if (lower == 'partial') return 'Partial';
    if (lower == 'due') return 'Due';
    // Fallback: capitalize first letter
    return value[0].toUpperCase() + value.substring(1);
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
    String? employeeId, // Added
    bool createKot = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _getToken();
    final double total = items.fold(
        0.0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));

    final businessCategory = prefs.getString('businessCategory') ?? 'Food';
    final bool effectiveCreateKot = businessCategory == 'Food' && createKot;

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
        'totalAmount': total,
        'finalAmount': total - (discount ?? 0) + (tax ?? 0),
        'discount': discount,
        'tax': tax,
        'paymentMethod': _normalize(paymentMethod),
        'orderType': _normalize(orderType),
        'tableNumber': tableNumber,
        'notes': notes,
        'paymentStatus': _normalize(paymentStatus),
        'employeeId': employeeId, // Included
        'createKot': effectiveCreateKot,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return OrderModel.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Failed to create order');
    }
  }

  Future<List<OrderModel>> getGuestHistory(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/guest/history/$id'),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List ordersList = data['data'] ?? data;
      return ordersList.map((e) => OrderModel.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to get order history');
    }
  }

  Future<OrderModel> createGuestOrder({
    required String adminId,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    String? customerId,
    String? billNumber,
    double? totalAmount,
    double? finalAmount,
    double? discount,
    double? tax,
    String? orderType,
    String? paymentMethod,
    String? paymentStatus,
    String? tableNumber,
    String? notes,
    String? unknownCustomerId,
    bool createKot = true,
  }) async {
    final double calculatedTotal = items.fold(
        0.0, (sum, item) => sum + ((item['price'] as num).toDouble() * (item['quantity'] as num).toDouble()));

    final double effectiveTotal = totalAmount ?? calculatedTotal;
    final double effectiveFinal = finalAmount ?? (effectiveTotal - (discount ?? 0) + (tax ?? 0));

    final prefs = await SharedPreferences.getInstance();
    final businessCategory = prefs.getString('businessCategory') ?? 'Food';
    final bool effectiveCreateKot = businessCategory == 'Food' && createKot;

    final response = await http.post(
      Uri.parse('$baseUrl/guest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'adminId': adminId,
        'billNumber': billNumber,
        'customerId': customerId,
        'unknownCustomerId': unknownCustomerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items,
        'totalAmount': effectiveTotal,
        'finalAmount': effectiveFinal,
        'discount': discount ?? 0,
        'tax': tax ?? 0,
        'orderType': _normalize(orderType ?? "PickUp"),
        'paymentMethod': _normalize(paymentMethod ?? "Cash"),
        'paymentStatus': _normalize(paymentStatus ?? "Paid"),
        'tableNumber': tableNumber ?? "",
        'notes': notes ?? "",
        'createKot': effectiveCreateKot,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      // In guest order, data might be directly the order or wrapped in 'data'
      return OrderModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create guest order');
    }
  }

  Future<List<OrderModel>> getOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? orderType,
    String? status,
    String? orderSource,
    String? unknownCustomerId,
  }) async {
    final token = await _getToken();

    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = DateFormat('yyyy-MM-dd').format(startDate);
    if (endDate != null) queryParams['endDate'] = DateFormat('yyyy-MM-dd').format(endDate);
    if (paymentMethod != null) queryParams['paymentMethod'] = paymentMethod;
    if (orderType != null) queryParams['orderType'] = orderType;
    if (status != null) queryParams['status'] = status;
    if (orderSource != null) queryParams['orderSource'] = orderSource;
    if (unknownCustomerId != null) queryParams['unknownCustomerId'] = unknownCustomerId;

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

  Future<OrderModel> updateOrderStatus(
    String id, {
    String? status,
    String? paymentStatus,
    String? paymentMethod,
  }) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        if (status != null) 'status': status,
        if (paymentStatus != null) 'paymentStatus': paymentStatus,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return OrderModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update order status');
    }
  }

  Future<List<OrderModel>> getKitchenOrders() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/kitchen'),
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
      throw Exception(data['message'] ?? 'Failed to get kitchen orders');
    }
  }

  Future<OrderModel> updateKotStatus(String id, String kotStatus) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/kot-status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'kotStatus': kotStatus}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return OrderModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update KOT status');
    }
  }

  Future<OrderModel> cancelOrder(String id, String reason) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/cancel'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'cancelReason': reason}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return OrderModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(data['message'] ?? 'Failed to cancel order');
    }
  }
}
