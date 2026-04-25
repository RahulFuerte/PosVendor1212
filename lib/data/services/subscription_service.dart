import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_plan_model.dart';
import '../models/user_model.dart';
import '../models/subscription_history_model.dart';
import '../constants/api_constants.dart';

class SubscriptionService {
  static const String baseUrl = ApiConstants.subscriptions;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<SubscriptionPlanModel> createPlan({
    required String name,
    required double price,
    required int durationInDays,
    List<String>? features,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/plans'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'name': name,
        'price': price,
        'durationInDays': durationInDays,
        'features': features,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return SubscriptionPlanModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create plan');
    }
  }

  Future<List<SubscriptionPlanModel>> getPlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/plans'),
      headers: {'Content-Type': 'application/json'},
    );
    print("Call Normal");
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => SubscriptionPlanModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get plans');
    }
  }

  Future<SubscriptionPlanModel> getPlanById(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/plans/$id'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return SubscriptionPlanModel.fromJson(data);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get plan');
    }
  }

  Future<Map<String, dynamic>> subscribeUser(String planId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/subscribe'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'planId': planId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to subscribe');
    }
  }

  Future<SubscriptionDetails?> getMySubscription() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/my-subscription'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return SubscriptionDetails.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to get subscription info');
    }
  }

  Future<Map<String, dynamic>> purchaseSubscription(String planId, {String paymentId = "MANUAL"}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/purchase'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'planId': planId,
        'paymentId': paymentId,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to purchase subscription');
    }
  }

  Future<List<SubscriptionHistoryModel>> getSubscriptionHistory() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => SubscriptionHistoryModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to fetch subscription history');
    }
  }
}
