import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer_model.dart';
import '../constants/api_constants.dart';

class CustomerService {
  static const String baseUrl = ApiConstants.customers;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<CustomerModel> createCustomer({
    required String name,
    required String phoneNumber,
    String? address,
    String? gstNo,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'name': name,
        'phoneNumber': phoneNumber,
        'address': address,
        'gstNo': gstNo,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return CustomerModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create customer');
    }
  }

  Future<List<CustomerModel>> getCustomers() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => CustomerModel.fromJson(e)).toList();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to get customers');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<CustomerModel> updateCustomer({
    required String id,
    String? name,
    String? phoneNumber,
    String? address,
    String? gstNo,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        if (name != null) 'name': name,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (address != null) 'address': address,
        if (gstNo != null) 'gstNo': gstNo,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return CustomerModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update customer');
    }
  }

  Future<void> deleteCustomer(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete customer');
    }
  }
}
