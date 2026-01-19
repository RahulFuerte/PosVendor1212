// Dart imports:
import 'dart:typed_data';

/// Abstract interface for database operations
/// Provides a unified API for both SQLite and Firebase operations
abstract class DatabaseService {
  // Food Items operations
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department});
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId);
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem);
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates);
  Future<void> deleteFoodItem(String adminUid, String itemId);

  // Departments operations
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid);
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId);
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department);
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates);
  Future<void> deleteDepartment(String adminUid, String departmentId);

  // Orders operations
  Future<void> saveOrder(String adminUid, Map<String, dynamic> orderData);
  Future<List<Map<String, dynamic>>> getOrders(String adminUid);

  // Bills operations
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate});
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId);
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData);
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates);
  Future<void> deleteBill(String adminUid, String billId);

  // Sync operations
  Future<void> syncPendingData();
  Future<List<Map<String, dynamic>>> getPendingSyncItems();
  Future<void> markAsSynced(String tableName, String recordId);
  Future<void> markAsPending(String tableName, String recordId);

  // Image operations
  Future<Uint8List?> getImageBlob(String tableName, String recordId);
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData);
  Future<void> clearImageCache();
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId});

  // Utility operations
  Future<bool> isOnline();
  Future<void> initialize();
  Future<void> close();
}

/// Enum for sync status tracking
enum SyncStatus {
  synced(0),
  pending(1),
  conflict(2);

  const SyncStatus(this.value);
  final int value;

  static SyncStatus fromValue(int value) {
    return SyncStatus.values.firstWhere((status) => status.value == value);
  }
}

/// Enum for database operations for sync logging
enum DatabaseOperation {
  insert('INSERT'),
  update('UPDATE'),
  delete('DELETE');

  const DatabaseOperation(this.value);
  final String value;
}
