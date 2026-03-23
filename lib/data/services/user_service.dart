import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../constants/api_constants.dart';
import 'demo_data.dart';

class UserService {
  static const String baseUrl = ApiConstants.users;

  // Helper method to retrieve token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Helper method to save token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    await prefs.setString('authToken', token);
  }

  // Clear token and session data (Log out)
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('authToken');
    await prefs.remove('myPhone');
    await prefs.remove('isLogged');
    await prefs.remove('isAdmin');
    await prefs.remove('adminUid');
    await prefs.remove('role');
    await prefs.remove('shopName');
    await prefs.remove('isDemoMode');
  }

  Future<UserModel> registerAdmin({
    required String name,
    required String phoneNumber,
    required String password,
    String? shopName,
    String? address,
    String? gstNo,
    String? fssaiNo,
    String? logoUrl,
    String? upiId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register-admin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
          'password': password,
          if (shopName != null) 'shopName': shopName,
          if (address != null) 'address': address,
          if (gstNo != null) 'gstNo': gstNo,
          if (fssaiNo != null) 'fssaiNo': fssaiNo,
          if (logoUrl != null) 'logoUrl': logoUrl,
          if (upiId != null) 'upiId': upiId,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final user = UserModel.fromJson(data);
        if (user.token != null) {
          await saveToken(user.token!);
        }
        return user;
      } else {
        throw Exception(data['message'] ?? 'Failed to register admin');
      }
    } catch (e) {
      throw Exception('Registration error: ${e.toString()}');
    }
  }

  Future<UserModel> loginUser({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(data);
        if (user.token != null) {
          await saveToken(user.token!);
        }
        return user;
      } else {
        throw Exception(data['message'] ?? 'Failed to login');
      }
    } catch (e) {
      throw Exception('Login error: ${e.toString()}');
    }
  }

  Future<UserModel> createEmployee({
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/create-employee'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to create employee');
      }
    } catch (e) {
      throw Exception('Create employee error: ${e.toString()}');
    }
  }

  Future<List<UserModel>> getMyEmployees() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/employees'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return (data as List).map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to get employees');
      }
    } catch (e) {
      throw Exception('Fetch employees error: ${e.toString()}');
    }
  }

  Future<UserModel> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final isDemoMode = prefs.getBool('isDemoMode') ?? false;

    if (isDemoMode) {
      return DemoData.profile;
    }

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
        return UserModel.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      throw Exception('Fetch profile error: ${e.toString()}');
    }
  }

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
        final updatedUser = UserModel.fromJson(data);

        // Update SharedPreferences with new data
        final prefs = await SharedPreferences.getInstance();
        if (updates.containsKey('shopName')) await prefs.setString('shopName', updates['shopName']);
        if (updates.containsKey('logoUrl')) await prefs.setString('logoUrl', updates['logoUrl']);
        if (updates.containsKey('address')) await prefs.setString('address', updates['address']);
        if (updates.containsKey('gstNo')) await prefs.setString('gstNo', updates['gstNo']);
        if (updates.containsKey('fssaiNo')) await prefs.setString('fssaiNo', updates['fssaiNo']);
        if (updates.containsKey('upiId')) await prefs.setString('upiId', updates['upiId']);

        return updatedUser;
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Update profile error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phoneNumber, {String? adminUid}) async {
    try {
      final token = await _getToken();
      String url = '$baseUrl/$phoneNumber';
      if (adminUid != null) {
        url += '?adminUid=$adminUid';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null; // Return null if user not found or error
      }
    } catch (e) {
      debugPrint('getUserByPhone error: $e');
      return null;
    }
  }
}
