import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../constants/api_constants.dart';
import '../datasources/shared_preferences.dart';

class UserService {
  static const String baseUrl = ApiConstants.users;

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

  // Clear session data (Log out)
  Future<void> logout() async {
    await MySharedPreferences().clear();
  }

  Future<UserModel> registerAdmin({
    required String name,
    required String phoneNumber,
    String? password,
    String? shopName,
    String? address,
    String? gstNo,
    String? fssaiNo,
    String? logoUrl,
    String? upiId,
    String? city,
    double? latitude,
    double? longitude,
    String? businessCategory,
    String? businessIcon,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.users}/register-admin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phoneNumber': phoneNumber,
          if (password != null) 'password': password,
          if (shopName != null) 'shopName': shopName,
          if (address != null) 'address': address,
          if (gstNo != null) 'gstNo': gstNo,
          if (fssaiNo != null) 'fssaiNo': fssaiNo,
          if (logoUrl != null) 'logoUrl': logoUrl,
          if (upiId != null) 'upiId': upiId,
          if (city != null) 'city': city,
          if (businessCategory != null) 'businessCategory': businessCategory,
          if (businessIcon != null) 'businessIcon': businessIcon,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final user = UserModel.fromJson(data);
        if (user.token != null) {
          await _saveToken(user.token!);
        }
        return user;
      } else {
        throw Exception(data['message'] ?? 'Failed to register admin');
      }
    } catch (e) {
      throw Exception('Registration error: ${e.toString()}');
    }
  }

  /// Direct login using phone and password
  static Future<Map<String, dynamic>> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.users}/login-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] != false) {
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Exchanges a Firebase ID token for a backend JWT session.
  static Future<Map<String, dynamic>> firebaseLogin(String firebaseToken) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.users}/firebase-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebaseToken': firebaseToken}),
      );

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] != false) {
        return {'success': true, 'token': data['token'], 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Persists user data and JWT token locally after successful authentication.
  static Future<void> saveUserData({required String token, required Map<String, dynamic> user}) async {
    final prefs = await SharedPreferences.getInstance();
    final userModel = UserModel.fromJson(user);

    // 1. Save Token
    await _saveToken(token);

    // 2. Save Session Flags
    await prefs.setBool('isLogged', true);
    final bool clickedTryDemo = prefs.getBool('clickedTryDemo') ?? false;
    final bool isDemo = userModel.phoneNumber == '9999999999' || clickedTryDemo;
    await prefs.setBool('isDemoMode', isDemo);
    if (isDemo) {
      await prefs.setBool('is_first_time_tutorial', true);
      await prefs.setBool('is_first_time_main_tutorial', true);
      await prefs.setBool('is_first_time_drawer_tutorial', true);
      await prefs.setBool('is_first_time_detailed_tutorial', true);
    }
    // Reset the flag so that future logins are treated normally
    await prefs.setBool('clickedTryDemo', false);
    await prefs.setString('myPhone', userModel.phoneNumber);
    await prefs.setString('phoneNumber', userModel.phoneNumber);
    await prefs.setString('role', userModel.role ?? 'admin');
    await prefs.setString('_id', userModel.id ?? '');
    await prefs.setString('adminUid', userModel.id ?? '');
    await prefs.setBool('isAdmin', userModel.role == 'admin' || userModel.role == 'superAdmin');

    // 3. Save User Profile Details
    if (userModel.name.isNotEmpty) await prefs.setString('name', userModel.name);
    if (userModel.shopName != null) await prefs.setString('shopName', userModel.shopName!);
    if (userModel.address != null) await prefs.setString('address', userModel.address!);
    if (userModel.logoUrl != null) await prefs.setString('logoUrl', userModel.logoUrl!);
    if (userModel.gstNo != null) await prefs.setString('gstNumber', userModel.gstNo!);
    if (userModel.fssaiNo != null) await prefs.setString('fssaiNo', userModel.fssaiNo!);
    if (userModel.upiId != null) await prefs.setString('upiId', userModel.upiId!);
    if (userModel.city != null) await prefs.setString('city', userModel.city!);
    if (userModel.location?.latitude != null) await prefs.setDouble('latitude', userModel.location!.latitude!);
    if (userModel.location?.longitude != null) await prefs.setDouble('longitude', userModel.location!.longitude!);
    if (userModel.businessCategory != null) await prefs.setString('businessCategory', userModel.businessCategory!);
    if (userModel.businessIcon != null) await prefs.setString('businessIcon', userModel.businessIcon!);
    await prefs.setString('contact', userModel.phoneNumber); // Save contact for receipt fallback
    await prefs.setBool('isShopOpen', userModel.isShopOpen ?? false);

    if (userModel.subscription != null) {
      await prefs.setString('subscriptionStatus', userModel.subscription?.status ?? 'inactive');
      await prefs.setString('subscriptionPlanType', userModel.subscription?.planType ?? 'free');
      if (userModel.subscription?.planId != null) {
        await prefs.setString('subscriptionPlanId', userModel.subscription!.planId!);
      }
      if (userModel.subscription?.endDate != null) {
        await prefs.setString('subscriptionEndDate', userModel.subscription!.endDate!.toIso8601String());
      }
    }
  }

  Future<List<UserModel>> getShops() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.users}/shop-details'),
        headers: {'Content-Type': 'application/json'},
      );

      print("These Is Response ...........${response.body}");

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['shops'] ?? data['data'] ?? [];
        }
        return list.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to get shops');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserModel>> getShopsByCity(String city) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.users}/shops-by-city?city=$city'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['shops'] ?? data['data'] ?? [];
        }
        return list.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to find shops in this city');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserModel>> getShopsByLocation({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.users}/shops-by-location?lat=$lat&lng=$lng'),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['data'] ?? data['shops'] ?? [];
        }
        return list.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to find shops nearby');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getShopDetails(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.users}/shop-details?adminId=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to get shop details');
      }
    } catch (e) {
      rethrow;
    }
  }

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
        return UserModel.fromJson(data['user'] ?? data);
      } else {
        throw Exception(data['message'] ?? 'Failed to get profile');
      }
    } catch (e) {
      rethrow;
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
        final updatedUser = UserModel.fromJson(data['user'] ?? data);

        // Update SharedPreferences with new data
        final prefs = await SharedPreferences.getInstance();
        if (updates.containsKey('shopName')) await prefs.setString('shopName', updates['shopName']);
        if (updates.containsKey('logoUrl')) await prefs.setString('logoUrl', updates['logoUrl']);
        if (updates.containsKey('address')) await prefs.setString('address', updates['address']);
        if (updates.containsKey('gstNo')) await prefs.setString('gstNo', updates['gstNo']);
        if (updates.containsKey('fssaiNo')) await prefs.setString('fssaiNo', updates['fssaiNo']);
        if (updates.containsKey('upiId')) await prefs.setString('upiId', updates['upiId']);
        if (updates.containsKey('isShopOpen')) await prefs.setBool('isShopOpen', updates['isShopOpen']);
        if (updates.containsKey('phoneNumber')) await prefs.setString('contact', updates['phoneNumber']);
        if (updates.containsKey('businessCategory')) {
          await prefs.setString('businessCategory', updates['businessCategory']);
        }
        if (updates.containsKey('businessIcon')) await prefs.setString('businessIcon', updates['businessIcon']);

        return updatedUser;
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      rethrow;
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

  Future<UserModel> createStaff(Map<String, dynamic> staffData) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/create-staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
        body: jsonEncode(staffData),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception(data['message'] ?? 'Failed to create staff');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<UserModel>> getStaff(String adminId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/staff'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List staffList = data['data'] ?? [];
        return staffList.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to get staff');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel> updateStaff(String id, Map<String, dynamic> updates) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('$baseUrl/staff/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
        body: jsonEncode(updates),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return UserModel.fromJson(data['user']);
      } else {
        throw Exception(data['message'] ?? 'Failed to update staff');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/staff/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token ?? "",
        },
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to delete staff');
      }
    } catch (e) {
      rethrow;
    }
  }
}
