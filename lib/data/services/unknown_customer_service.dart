import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pos/data/constants/api_constants.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnknownCustomerService {
  static const String baseUrl = ApiConstants.unknownCustomers;

  // Helper method to retrieve token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper method to save token
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('authToken', token);
    await prefs.setString('token', token);
  }

  // Register a new Unknown Customer
  Future<UserModel> register({
    required String name,
    required String phoneNumber,
    String address = "",
    String city = "",
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
          'address': address,
          'city': city,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final user = UserModel.fromJson(data['customer']);
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }
        return user;
      } else {
        throw Exception(data['message'] ?? 'Failed to register customer');
      }
    } catch (e) {
      throw Exception('Registration error: ${e.toString()}');
    }
  }

  // Login Unknown Customer using Firebase token
  Future<Map<String, dynamic>> login(String firebaseToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebaseToken': firebaseToken}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }
        return {'success': true, 'token': data['token'], 'customer': data['customer']};
      } else {
        return {
          'success': false, 
          'message': data['message'] ?? 'Login failed',
          'registrationRequired': data['registrationRequired'] ?? false,
          'phoneNumber': data['phoneNumber']
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Get current customer profile
  Future<UserModel> getProfile() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return UserModel.fromJson(data['customer']);
      } else {
        throw Exception(data['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Update customer profile
  Future<UserModel> updateProfile(Map<String, dynamic> updates) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
        body: jsonEncode(updates),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return UserModel.fromJson(data['customer']);
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      rethrow;
    }
  }
}
