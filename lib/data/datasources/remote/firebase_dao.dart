// Dart imports:
import 'dart:typed_data';

// Project imports:
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../constants/api_constants.dart';
import '../database_service.dart';
import 'package:pos/data/services/user_service.dart';

/// Node.js API Data Access Object — replaces NodeApiDAO.
/// Implements the same DatabaseService interface but calls the REST API.
class NodeApiDAO implements DatabaseService {
  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    // Nothing to initialize for HTTP client
  }

  @override
  Future<void> close() async {
    // Nothing to close for HTTP client
  }

  @override
  Future<bool> isOnline() async {
    try {
      await _get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Food Items ───────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    try {
      String path = '/food-items?adminUid=$adminUid';
      if (department != null && department.isNotEmpty) {
        path += '&department=${Uri.encodeComponent(department)}';
      }
      final data = await _get(path);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch food items: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId) async {
    try {
      final data = await _get('/food-items/$itemId?adminUid=$adminUid');
      return data != null ? Map<String, dynamic>.from(data as Map) : null;
    } catch (e) {
      throw Exception('Failed to fetch food item: $e');
    }
  }

  @override
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    try {
      await _post('/food-items', {'adminUid': adminUid, ...foodItem});
    } catch (e) {
      throw Exception('Failed to save food item: $e');
    }
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates) async {
    try {
      await _put('/food-items/$itemId', {'adminUid': adminUid, ...updates});
    } catch (e) {
      throw Exception('Failed to update food item: $e');
    }
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    try {
      await _delete('/food-items/$itemId?adminUid=$adminUid');
    } catch (e) {
      throw Exception('Failed to delete food item: $e');
    }
  }

  // ─── Departments ─────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    try {
      final data = await _get('/departments?adminUid=$adminUid');
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch departments: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId) async {
    try {
      final data = await _get('/departments/$departmentId?adminUid=$adminUid');
      return data != null ? Map<String, dynamic>.from(data as Map) : null;
    } catch (e) {
      throw Exception('Failed to fetch department: $e');
    }
  }

  @override
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    try {
      await _post('/departments', {'adminUid': adminUid, ...department});
    } catch (e) {
      throw Exception('Failed to save department: $e');
    }
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates) async {
    try {
      await _put('/departments/$departmentId', {'adminUid': adminUid, ...updates});
    } catch (e) {
      throw Exception('Failed to update department: $e');
    }
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    try {
      await _delete('/departments/$departmentId?adminUid=$adminUid');
    } catch (e) {
      throw Exception('Failed to delete department: $e');
    }
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  @override
  Future<void> saveOrder(String adminUid, Map<String, dynamic> orderData) async {
    try {
      await _post('/orders', {'adminUid': adminUid, ...orderData});
    } catch (e) {
      throw Exception('Failed to save order: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(String adminUid) async {
    try {
      final data = await _get('/orders?adminUid=$adminUid');
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch orders: $e');
    }
  }

  // ─── Bills ────────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    try {
      String path = '/orders?adminId=$adminUid';
      if (startDate != null) path += '&startDate=${startDate.millisecondsSinceEpoch}';
      if (endDate != null) path += '&endDate=${endDate.millisecondsSinceEpoch}';
      final data = await _get(path);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch bills: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId) async {
    try {
      final data = await _get('/orders/$billId?adminId=$adminUid');
      return data != null ? Map<String, dynamic>.from(data as Map) : null;
    } catch (e) {
      throw Exception('Failed to fetch bill: $e');
    }
  }

  @override
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData) async {
    try {
      // Create a copy to avoid mutating original
      final Map<String, dynamic> data = {...billData};

      // If items is a string (JSON encoded for SQLite), decode it back to List for API
      if (data['items'] is String) {
        try {
          data['items'] = jsonDecode(data['items']);
        } catch (e) {
          debugPrint('Error decoding bill items for API: $e');
        }
      }

      // Map fields to match backend Order schema if possible
      final Map<String, dynamic> payload = {'adminId': adminUid, 'billNumber': data['id'], ...data};

      await _post('/orders', payload);
    } catch (e) {
      throw Exception('Failed to save bill: $e');
    }
  }

  @override
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates) async {
    try {
      await _put('/bills/$billId', {'adminUid': adminUid, ...updates});
    } catch (e) {
      throw Exception('Failed to update bill: $e');
    }
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    try {
      await _delete('/bills/$billId?adminUid=$adminUid');
    } catch (e) {
      throw Exception('Failed to delete bill: $e');
    }
  }

  // ─── Sync operations (handled by SQLite DAO) ─────────────────────────────

  @override
  Future<void> syncPendingData() async {}

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async => [];

  @override
  Future<void> markAsSynced(String tableName, String recordId) async {}

  @override
  Future<void> markAsPending(String tableName, String recordId) async {}

  // ─── Image operations (handled by SQLite DAO) ────────────────────────────

  @override
  Future<Uint8List?> getImageBlob(String tableName, String recordId) async => null;

  @override
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData) async {}

  @override
  Future<void> clearImageCache() async {}

  @override
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId}) async => null;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = await UserService().getProfile();
      final map = user.toJson();
      // Map 'id' (which is '_id' in toJson) to 'uid' for SQLiteHelper compatibility
      map['uid'] = user.id;
      return map;
    } catch (e) {
      debugPrint('Error getting current user in NodeApiDAO: $e');
      return null;
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  static const String _baseUrl = ApiConstants.baseUrl;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': token ?? "",
    };
  }

  Future<dynamic> _get(String path) async {
    final response = await http.get(Uri.parse('$_baseUrl$path'), headers: await _getHeaders());
    return _handleResponse(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(Uri.parse('$_baseUrl$path'), headers: await _getHeaders(), body: jsonEncode(body));
    return _handleResponse(response);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(Uri.parse('$_baseUrl$path'), headers: await _getHeaders(), body: jsonEncode(body));
    return _handleResponse(response);
  }

  Future<dynamic> _delete(String path) async {
    final response = await http.delete(Uri.parse('$_baseUrl$path'), headers: await _getHeaders());
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'API error: ${response.statusCode}');
      }
    } catch (e) {
      // Handle non-JSON responses (like HTML error pages)
      if (response.statusCode >= 400) {
        throw Exception(
            'Server error (${response.statusCode}): The server returned an unexpected response. Please check your connection or try again later.');
      }
      rethrow;
    }
  }
}
