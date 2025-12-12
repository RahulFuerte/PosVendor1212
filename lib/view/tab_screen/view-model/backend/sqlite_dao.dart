import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'sqlite_helper.dart';
import 'data_integrity_service.dart';
import 'performance_monitor.dart';

/// SQLite Data Access Object for local database operations
class SQLiteDAO implements DatabaseService {
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final DataIntegrityService _integrityService = DataIntegrityService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  @override
  Future<void> initialize() async {
    await _sqliteHelper.initializeDatabase();
    await _integrityService.initialize();
  }

  @override
  Future<void> close() async {
    await _sqliteHelper.closeDatabase();
  }

  @override
  Future<bool> isOnline() async {
    // SQLite is always available locally
    return true;
  }

  // Food Items operations
  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    return await _performanceMonitor.trackQuery('getFoodItems', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (department != null && department.isNotEmpty) {
        whereClause += ' AND department = ?';
        whereArgs.add(department);
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        'food_items',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );
      
      return results;
    });
  }

  /// Get food items with pagination for large datasets
  Future<List<Map<String, dynamic>>> getFoodItemsPaginated(
    String adminUid, {
    String? department,
    int offset = 0,
    int limit = 20,
    String orderBy = 'name ASC',
  }) async {
    return await _performanceMonitor.trackQuery('getFoodItemsPaginated', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (department != null && department.isNotEmpty) {
        whereClause += ' AND department = ?';
        whereArgs.add(department);
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        'food_items',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      
      return results;
    });
  }

  /// Get total count of food items for pagination
  Future<int> getFoodItemsCount(String adminUid, {String? department}) async {
    return await _performanceMonitor.trackQuery('getFoodItemsCount', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (department != null && department.isNotEmpty) {
        whereClause += ' AND department = ?';
        whereArgs.add(department);
      }
      
      final List<Map<String, dynamic>> results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM food_items WHERE $whereClause',
        whereArgs,
      );
      
      return results.first['count'] as int;
    });
  }

  /// Search food items with optimized query
  Future<List<Map<String, dynamic>>> searchFoodItems(
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    return await _performanceMonitor.trackQuery('searchFoodItems', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ? AND (name LIKE ? OR food_code LIKE ? OR description LIKE ?)';
      List<dynamic> whereArgs = [adminUid, '%$searchTerm%', '%$searchTerm%', '%$searchTerm%'];
      
      if (department != null && department.isNotEmpty) {
        whereClause += ' AND department = ?';
        whereArgs.add(department);
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        'food_items',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
        limit: limit,
      );
      
      return results;
    });
  }

  @override
  Future<Map<String, dynamic>?> getFoodItem(String adminUid, String itemId) async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      'food_items',
      where: 'admin_uid = ? AND id = ?',
      whereArgs: [adminUid, itemId],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<void> saveFoodItem(String adminUid, Map<String, dynamic> foodItem) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> itemData = {
        ...foodItem,
        'admin_uid': adminUid,
        'created_at': now,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      // Convert boolean values to integers for SQLite compatibility
      if (itemData['is_hot'] is bool) {
        itemData['is_hot'] = itemData['is_hot'] ? 1 : 0;
      }
      
      await txn.insert(
        'food_items',
        itemData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'food_items', foodItem['id'], DatabaseOperation.insert);
    });
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, Map<String, dynamic> updates) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> updateData = {
        ...updates,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      // Convert boolean values to integers for SQLite compatibility
      if (updateData['is_hot'] is bool) {
        updateData['is_hot'] = updateData['is_hot'] ? 1 : 0;
      }
      
      await txn.update(
        'food_items',
        updateData,
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, itemId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'food_items', itemId, DatabaseOperation.update);
    });
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    await _integrityService.executeInTransaction((txn) async {
      await txn.delete(
        'food_items',
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, itemId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'food_items', itemId, DatabaseOperation.delete);
    });
  }

  // Departments operations
  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    return await _performanceMonitor.trackQuery('getDepartments', () async {
      final db = await _sqliteHelper.database;
      
      final List<Map<String, dynamic>> results = await db.query(
        'departments',
        where: 'admin_uid = ? AND status = ?',
        whereArgs: [adminUid, 'Active'],
        orderBy: 'name ASC',
      );
      
      return results;
    });
  }

  /// Get departments with pagination
  Future<List<Map<String, dynamic>>> getDepartmentsPaginated(
    String adminUid, {
    int offset = 0,
    int limit = 20,
    String orderBy = 'name ASC',
  }) async {
    return await _performanceMonitor.trackQuery('getDepartmentsPaginated', () async {
      final db = await _sqliteHelper.database;
      
      final List<Map<String, dynamic>> results = await db.query(
        'departments',
        where: 'admin_uid = ? AND status = ?',
        whereArgs: [adminUid, 'Active'],
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      
      return results;
    });
  }

  @override
  Future<Map<String, dynamic>?> getDepartment(String adminUid, String departmentId) async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      'departments',
      where: 'admin_uid = ? AND id = ?',
      whereArgs: [adminUid, departmentId],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<void> saveDepartment(String adminUid, Map<String, dynamic> department) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> departmentData = {
        ...department,
        'admin_uid': adminUid,
        'created_at': now,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      await txn.insert(
        'departments',
        departmentData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'departments', department['id'], DatabaseOperation.insert);
    });
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, Map<String, dynamic> updates) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> updateData = {
        ...updates,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      await txn.update(
        'departments',
        updateData,
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, departmentId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'departments', departmentId, DatabaseOperation.update);
    });
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    await _integrityService.executeInTransaction((txn) async {
      await txn.delete(
        'departments',
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, departmentId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'departments', departmentId, DatabaseOperation.delete);
    });
  }

  // Bills operations
  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    return await _performanceMonitor.trackQuery('getBills', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (startDate != null) {
        whereClause += ' AND bill_date >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }
      
      if (endDate != null) {
        whereClause += ' AND bill_date <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        'bills',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'bill_date DESC',
      );
      
      return results;
    });
  }

  /// Get bills with pagination for large datasets
  Future<List<Map<String, dynamic>>> getBillsPaginated(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = 20,
    String orderBy = 'bill_date DESC',
  }) async {
    return await _performanceMonitor.trackQuery('getBillsPaginated', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (startDate != null) {
        whereClause += ' AND bill_date >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }
      
      if (endDate != null) {
        whereClause += ' AND bill_date <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }
      
      final List<Map<String, dynamic>> results = await db.query(
        'bills',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
      
      return results;
    });
  }

  /// Get total count of bills for pagination
  Future<int> getBillsCount(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    return await _performanceMonitor.trackQuery('getBillsCount', () async {
      final db = await _sqliteHelper.database;
      
      String whereClause = 'admin_uid = ?';
      List<dynamic> whereArgs = [adminUid];
      
      if (startDate != null) {
        whereClause += ' AND bill_date >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }
      
      if (endDate != null) {
        whereClause += ' AND bill_date <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }
      
      final List<Map<String, dynamic>> results = await db.rawQuery(
        'SELECT COUNT(*) as count FROM bills WHERE $whereClause',
        whereArgs,
      );
      
      return results.first['count'] as int;
    });
  }

  @override
  Future<Map<String, dynamic>?> getBill(String adminUid, String billId) async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      'bills',
      where: 'admin_uid = ? AND id = ?',
      whereArgs: [adminUid, billId],
      limit: 1,
    );
    
    return results.isNotEmpty ? results.first : null;
  }

  @override
  Future<void> saveBill(String adminUid, Map<String, dynamic> billData) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> bill = {
        ...billData,
        'admin_uid': adminUid,
        'created_at': now,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      await txn.insert(
        'bills',
        bill,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'bills', billData['id'], DatabaseOperation.insert);
    });
  }

  @override
  Future<void> updateBill(String adminUid, String billId, Map<String, dynamic> updates) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> updateData = {
        ...updates,
        'updated_at': now,
        'sync_status': SyncStatus.pending.value,
      };
      
      await txn.update(
        'bills',
        updateData,
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, billId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'bills', billId, DatabaseOperation.update);
    });
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    await _integrityService.executeInTransaction((txn) async {
      await txn.delete(
        'bills',
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, billId],
      );
      
      // Log the operation for sync tracking within the same transaction
      await _logSyncOperationInTransaction(txn, 'bills', billId, DatabaseOperation.delete);
    });
  }

  // Sync operations
  @override
  Future<void> syncPendingData() async {
    // This will be implemented by the SyncManager
    // For now, just mark as placeholder
    throw UnimplementedError('Sync operations are handled by SyncManager');
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      'sync_log',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
      orderBy: 'created_at ASC',
    );
    
    return results;
  }

  @override
  Future<void> markAsSynced(String tableName, String recordId) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Update the main table sync status
      await txn.update(
        tableName,
        {'sync_status': SyncStatus.synced.value},
        where: 'id = ?',
        whereArgs: [recordId],
      );
      
      // Update sync log
      await txn.update(
        'sync_log',
        {
          'sync_status': SyncStatus.synced.value,
          'synced_at': now,
        },
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );
    });
  }

  @override
  Future<void> markAsPending(String tableName, String recordId) async {
    await _integrityService.executeInTransaction((txn) async {
      // Update the main table sync status
      await txn.update(
        tableName,
        {'sync_status': SyncStatus.pending.value},
        where: 'id = ?',
        whereArgs: [recordId],
      );
      
      // Update sync log
      await txn.update(
        'sync_log',
        {'sync_status': SyncStatus.pending.value},
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );
    });
  }

  // Image operations
  @override
  Future<Uint8List?> getImageBlob(String tableName, String recordId) async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      'image_cache',
      columns: ['image_blob'],
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [tableName, recordId],
      limit: 1,
    );
    
    if (results.isNotEmpty && results.first['image_blob'] != null) {
      // Update last accessed time
      await db.update(
        'image_cache',
        {'last_accessed': DateTime.now().millisecondsSinceEpoch},
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );
      
      return results.first['image_blob'] as Uint8List;
    }
    
    return null;
  }

  @override
  Future<void> saveImageBlob(String tableName, String recordId, String imageUrl, Uint8List imageData) async {
    await _integrityService.executeInTransaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final Map<String, dynamic> imageCache = {
        'id': '${tableName}_$recordId',
        'table_name': tableName,
        'record_id': recordId,
        'image_url': imageUrl,
        'image_blob': imageData,
        'file_size': imageData.length,
        'cached_at': now,
        'last_accessed': now,
      };
      
      await txn.insert(
        'image_cache',
        imageCache,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      // Also update the main table with the BLOB data
      await txn.update(
        tableName,
        {'image_blob': imageData},
        where: 'id = ?',
        whereArgs: [recordId],
      );
    });
  }

  @override
  Future<void> clearImageCache() async {
    final db = await _sqliteHelper.database;
    
    await db.delete('image_cache');
    
    // Also clear BLOB data from main tables
    await db.update('food_items', {'image_blob': null});
    await db.update('departments', {'image_blob': null});
  }

  @override
  Future<Uint8List?> downloadAndCacheImage(String imageUrl, {String? tableName, String? recordId}) async {
    // SQLiteDAO doesn't handle image downloading - this is handled by ImageCacheService
    // This method is implemented here for interface compliance but delegates to ImageCacheService
    throw UnimplementedError('Image download and caching operations are handled by ImageCacheService');
  }

  // Helper method to log sync operations within a transaction
  Future<void> _logSyncOperationInTransaction(Transaction txn, String tableName, String recordId, DatabaseOperation operation) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final Map<String, dynamic> logEntry = {
      'table_name': tableName,
      'record_id': recordId,
      'operation': operation.value,
      'sync_status': SyncStatus.pending.value,
      'created_at': now,
    };
    
    await txn.insert(
      'sync_log',
      logEntry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }



  // Additional helper methods for sync status management
  Future<List<Map<String, dynamic>>> getPendingItemsByTable(String tableName) async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.query(
      tableName,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.value],
    );
    
    return results;
  }

  Future<int> getPendingItemsCount() async {
    final db = await _sqliteHelper.database;
    
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sync_log WHERE sync_status = ?',
      [SyncStatus.pending.value],
    );
    
    return results.first['count'] as int;
  }

  /// Validate data integrity for all tables
  Future<DataIntegrityResult> validateDataIntegrity({String? adminUid}) async {
    return await _integrityService.validateDataIntegrity(adminUid: adminUid);
  }

  /// Create a backup of the database
  Future<BackupResult> createBackup({String? backupName}) async {
    return await _integrityService.createDatabaseBackup(backupName: backupName);
  }

  /// Restore database from backup or Firebase
  Future<RestoreResult> restoreDatabase({
    String? backupPath,
    String? adminUid,
    bool fromFirebase = false,
  }) async {
    return await _integrityService.restoreDatabase(
      backupPath: backupPath,
      adminUid: adminUid,
      fromFirebase: fromFirebase,
    );
  }

  /// Detect and recover from database corruption
  Future<CorruptionRecoveryResult> detectAndRecoverCorruption(String adminUid) async {
    return await _integrityService.detectAndRecoverCorruption(adminUid);
  }

  /// Get list of available backups
  Future<List<BackupInfo>> getAvailableBackups() async {
    return await _integrityService.getAvailableBackups();
  }

  /// Delete a specific backup
  Future<bool> deleteBackup(String backupPath) async {
    return await _integrityService.deleteBackup(backupPath);
  }

  /// Execute multiple operations as a batch transaction
  Future<void> executeBatchOperations(List<Future<void> Function(Transaction txn)> operations) async {
    await _integrityService.executeBatchTransaction(operations);
  }
}