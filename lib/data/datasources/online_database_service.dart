// Dart imports:
import 'dart:typed_data';

// Project imports:
import 'database_service.dart';
import 'remote/node_api_dao.dart';

/// Online-only database service that uses only Node.js API
/// No offline functionality or caching - all operations require internet
class OnlineDatabaseService implements DatabaseService {
  static final OnlineDatabaseService _instance = OnlineDatabaseService._internal();
  factory OnlineDatabaseService() => _instance;
  OnlineDatabaseService._internal();

  final NodeApiDAO _api = NodeApiDAO();

  @override
  Future<void> initialize() async {
    await _api.initialize();
  }

  @override
  Future<void> close() async {
    await _api.close();
  }

  @override
  Future<bool> isOnline() async {
    return await _api.isOnline();
  }

  // ─── Food Items ───────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    return await _api.getFoodItems(adminUid, department: department);
  }

  @override
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId) async {
    return await _api.getFoodItem(adminUid, itemId);
  }

  @override
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    await _api.saveFoodItem(adminUid, foodItem);
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates) async {
    await _api.updateFoodItem(adminUid, itemId, updates);
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    await _api.deleteFoodItem(adminUid, itemId);
  }

  // ─── Departments ──────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    return await _api.getDepartments(adminUid);
  }

  @override
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId) async {
    return await _api.getDepartment(adminUid, departmentId);
  }

  @override
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    await _api.saveDepartment(adminUid, department);
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates) async {
    await _api.updateDepartment(adminUid, departmentId, updates);
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    await _api.deleteDepartment(adminUid, departmentId);
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  @override
  Future<void> saveOrder(String adminUid, Map<String, dynamic> orderData) async {
    await _api.saveOrder(adminUid, orderData);
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(String adminUid) async {
    return await _api.getOrders(adminUid);
  }

  // ─── Bills ────────────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    return await _api.getBills(adminUid, startDate: startDate, endDate: endDate);
  }

  @override
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId) async {
    return await _api.getBill(adminUid, billId);
  }

  @override
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData) async {
    await _api.saveBill(adminUid, billData);
  }

  @override
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates) async {
    await _api.updateBill(adminUid, billId, updates);
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    await _api.deleteBill(adminUid, billId);
  }

  // ─── Sync Operations (no-op for online-only) ──────────────────────────────

  @override
  Future<void> syncPendingData() async {
    // No-op: online-only app doesn't need sync
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    return []; // No offline items
  }

  @override
  Future<void> markAsSynced(String tableName, String recordId) async {
    // No-op: no syncing needed
  }

  @override
  Future<void> markAsPending(String tableName, String recordId) async {
    // No-op: no pending items in online-only mode
  }

  // ─── Image Operations ─────────────────────────────────────────────────────

  @override
  Future<Uint8List?> getImageBlob(String tableName, String recordId) async {
    // No local caching - return null
    return null;
  }

  @override
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData) async {
    // No-op: no local image caching
  }

  @override
  Future<void> clearImageCache() async {
    // No-op: no cache to clear
  }

  @override
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId}) async {
    // No-op: no local caching
    return null;
  }

  // ─── Utility Operations ───────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _api.getCurrentUser();
  }
}
