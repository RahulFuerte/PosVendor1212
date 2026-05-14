import 'dart:io';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/performance_monitor.dart';
import 'local/sqlite_helper.dart';


/// Service for database maintenance and optimization operations
/// Handles automatic vacuum, integrity checks, size monitoring, and index maintenance
class DatabaseMaintenanceService {
  SQLiteHelper? _sqliteHelper;
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  /// Initialize the service with a SQLiteHelper instance
  void initialize(SQLiteHelper sqliteHelper) {
    _sqliteHelper = sqliteHelper;
  }
  
  /// Get the database instance
  Future<Database> _getSqliteDatabase() async {
    if (_sqliteHelper == null) {
      throw StateError('DatabaseMaintenanceService not initialized. Call initialize() first.');
    }
    return await _sqliteHelper!.database;
  }
  
  // Configuration constants
  static const int _vacuumThresholdMB = 100; // Vacuum when database exceeds this size
  static const Duration _maintenanceInterval = Duration(hours: 24); // Daily maintenance
  static const Duration _integrityCheckInterval = Duration(days: 7); // Weekly integrity checks
  static const int _maxLogEntries = 1000; // Maximum sync log entries to keep
  static const int _maxImageCacheEntries = 500; // Maximum image cache entries
  static const Duration _imageCacheExpiry = Duration(days: 30); // Image cache expiry
  
  /// Perform comprehensive database maintenance
  /// This is the main entry point for all maintenance operations
  Future<MaintenanceResult> performMaintenance({
    bool forceVacuum = false,
    bool forceIntegrityCheck = false,
    bool cleanupOldData = true,
    bool optimizeIndexes = true,
  }) async {
    return await _performanceMonitor.trackQuery('performMaintenance', () async {
      final result = MaintenanceResult();
      final startTime = DateTime.now();
      
      try {
        
        
        // 1. Check database integrity
        if (forceIntegrityCheck || await _shouldPerformIntegrityCheck()) {
          result.integrityCheckResult = await performIntegrityCheck();
          if (!result.integrityCheckResult!.isHealthy) {
            
            result.warnings.add('Database integrity issues detected');
          }
        }
        
        // 2. Monitor and report database size
        result.sizeInfo = await getDatabaseSizeInfo();
        
        
        // 3. Cleanup old data if requested
        if (cleanupOldData) {
          result.cleanupResult = await performDataCleanup();
          
        }
        
        // 4. Perform vacuum if needed
        if (forceVacuum || await _shouldPerformVacuum()) {
          result.vacuumResult = await performVacuum();
          
        }
        
        // 5. Optimize indexes if requested
        if (optimizeIndexes) {
          result.indexOptimizationResult = await this.optimizeIndexes();
          
        }
        
        // 6. Update maintenance timestamp
        await _updateMaintenanceTimestamp();
        
        result.success = true;
        result.duration = DateTime.now().difference(startTime);
        
        
      } catch (e) {
        result.success = false;
        result.error = e.toString();
        result.duration = DateTime.now().difference(startTime);
        
      }
      
      return result;
    });
  }
  
  /// Perform automatic database vacuum operation
  /// Reclaims unused space and optimizes database file structure
  Future<VacuumResult> performVacuum() async {
    return await _performanceMonitor.trackQuery('performVacuum', () async {
      final result = VacuumResult();
      final startTime = DateTime.now();
      
      try {
        final db = await _getSqliteDatabase();
        
        // Get database size before vacuum
        final sizeBeforeInfo = await getDatabaseSizeInfo();
        result.sizeBefore = sizeBeforeInfo.totalSizeMB;
        
        
        // Perform vacuum operation
        await db.execute('VACUUM');
        
        // Get database size after vacuum
        final sizeAfterInfo = await getDatabaseSizeInfo();
        result.sizeAfter = sizeAfterInfo.totalSizeMB;
        result.spaceReclaimedMB = result.sizeBefore - result.sizeAfter;
        
        result.success = true;
        result.duration = DateTime.now().difference(startTime);
        
        
      } catch (e) {
        result.success = false;
        result.error = e.toString();
        result.duration = DateTime.now().difference(startTime);
        
      }
      
      return result;
    });
  }
  
  /// Perform comprehensive database integrity checks
  /// Validates database structure, constraints, and data consistency
  Future<IntegrityCheckResult> performIntegrityCheck() async {
    return await _performanceMonitor.trackQuery('performIntegrityCheck', () async {
      final result = IntegrityCheckResult();
      final startTime = DateTime.now();
      
      try {
        final db = await _getSqliteDatabase();
        
        
        // 1. SQLite integrity check
        final integrityResults = await db.rawQuery('PRAGMA integrity_check');
        result.sqliteIntegrityOk = integrityResults.length == 1 && 
                                   integrityResults.first.values.first == 'ok';
        
        if (!result.sqliteIntegrityOk) {
          result.issues.addAll(integrityResults.map((r) => r.values.first.toString()));
        }
        
        // 2. Foreign key constraint check
        final foreignKeyResults = await db.rawQuery('PRAGMA foreign_key_check');
        result.foreignKeyConstraintsOk = foreignKeyResults.isEmpty;
        
        if (!result.foreignKeyConstraintsOk) {
          result.issues.addAll(foreignKeyResults.map((r) => 'Foreign key violation: ${r.toString()}'));
        }
        
        // 3. Check for orphaned records
        await _checkOrphanedRecords(db, result);
        
        // 4. Check data consistency
        await _checkDataConsistency(db, result);
        
        // 5. Check index consistency
        await _checkIndexConsistency(db, result);
        
        // 6. Check table statistics
        await _checkTableStatistics(db, result);
        
        result.isHealthy = result.sqliteIntegrityOk && 
                          result.foreignKeyConstraintsOk && 
                          result.orphanedRecordsOk && 
                          result.dataConsistencyOk &&
                          result.indexConsistencyOk;
        
        result.success = true;
        result.duration = DateTime.now().difference(startTime);
        
        
      } catch (e) {
        result.success = false;
        result.error = e.toString();
        result.duration = DateTime.now().difference(startTime);
        
      }
      
      return result;
    });
  }
  
  /// Get comprehensive database size information
  /// Monitors database file size and provides breakdown by tables
  Future<DatabaseSizeInfo> getDatabaseSizeInfo() async {
    return await _performanceMonitor.trackQuery('getDatabaseSizeInfo', () async {
      final sizeInfo = DatabaseSizeInfo();
      
      try {
        final db = await _getSqliteDatabase();
        
        // Get database file size
        final dbFile = File(db.path);
        if (await dbFile.exists()) {
          final fileSizeBytes = await dbFile.length();
          sizeInfo.totalSizeMB = fileSizeBytes / (1024 * 1024);
        }
        
        // Get page count and page size
        final pageCountResult = await db.rawQuery('PRAGMA page_count');
        final pageSizeResult = await db.rawQuery('PRAGMA page_size');
        
        sizeInfo.pageCount = pageCountResult.first['page_count'] as int? ?? 0;
        sizeInfo.pageSize = pageSizeResult.first['page_size'] as int? ?? 0;
        
        // Calculate table sizes
        await _calculateTableSizes(db, sizeInfo);
        
        // Get free space information
        final freeListResult = await db.rawQuery('PRAGMA freelist_count');
        sizeInfo.freePages = freeListResult.first['freelist_count'] as int? ?? 0;
        sizeInfo.freeSizeMB = (sizeInfo.freePages * sizeInfo.pageSize) / (1024 * 1024);
        
        sizeInfo.success = true;
        
      } catch (e) {
        sizeInfo.success = false;
        sizeInfo.error = e.toString();
        
      }
      
      return sizeInfo;
    });
  }
  
  /// Perform data cleanup operations
  /// Removes old sync logs, expired image cache, and other temporary data
  Future<DataCleanupResult> performDataCleanup() async {
    return await _performanceMonitor.trackQuery('performDataCleanup', () async {
      final result = DataCleanupResult();
      final startTime = DateTime.now();
      
      try {
        final db = await _getSqliteDatabase();
        
        
        // 1. Clean up old sync log entries
        final oldSyncLogs = await _cleanupOldSyncLogs(db);
        result.syncLogsRemoved = oldSyncLogs;
        
        // 2. Clean up expired image cache
        final expiredImages = await _cleanupExpiredImageCache(db);
        result.imageCacheEntriesRemoved = expiredImages;
        
        // 3. Clean up orphaned image cache entries
        final orphanedImages = await _cleanupOrphanedImageCache(db);
        result.orphanedImagesRemoved = orphanedImages;
        
        // 4. Clean up old migration logs (keep last 10)
        final oldMigrationLogs = await _cleanupOldMigrationLogs(db);
        result.migrationLogsRemoved = oldMigrationLogs;
        
        result.itemsRemoved = result.syncLogsRemoved + 
                             result.imageCacheEntriesRemoved + 
                             result.orphanedImagesRemoved + 
                             result.migrationLogsRemoved;
        
        result.success = true;
        result.duration = DateTime.now().difference(startTime);
        
        
      } catch (e) {
        result.success = false;
        result.error = e.toString();
        result.duration = DateTime.now().difference(startTime);
        
      }
      
      return result;
    });
  }
  
  /// Optimize database indexes for better performance
  /// Rebuilds indexes and updates statistics
  Future<IndexOptimizationResult> optimizeIndexes() async {
    return await _performanceMonitor.trackQuery('optimizeIndexes', () async {
      final result = IndexOptimizationResult();
      final startTime = DateTime.now();
      
      try {
        final db = await _getSqliteDatabase();
        
        
        // 1. Update table statistics for query optimizer
        await db.execute('ANALYZE');
        result.statisticsUpdated = true;
        
        // 2. Get list of all indexes
        final indexes = await db.rawQuery('''
          SELECT name, tbl_name FROM sqlite_master 
          WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
        ''');
        
        result.indexesAnalyzed = indexes.length;
        
        // 3. Check for missing critical indexes
        final missingIndexes = await _checkForMissingIndexes(db);
        result.missingIndexes = missingIndexes;
        
        // 4. Rebuild FTS index if it exists
        final ftsRebuilt = await _rebuildFTSIndex(db);
        result.ftsIndexRebuilt = ftsRebuilt;
        
        // 5. Validate index usage
        result.indexUsageStats = await _getIndexUsageStatistics(db);
        
        result.success = true;
        result.duration = DateTime.now().difference(startTime);
        
        
      } catch (e) {
        result.success = false;
        result.error = e.toString();
        result.duration = DateTime.now().difference(startTime);
        
      }
      
      return result;
    });
  }
  
  /// Check if vacuum operation should be performed
  Future<bool> _shouldPerformVacuum() async {
    try {
      final sizeInfo = await getDatabaseSizeInfo();
      
      // Perform vacuum if:
      // 1. Database size exceeds threshold
      // 2. Free space is more than 20% of total size
      // 3. Last vacuum was more than a week ago
      
      final exceedsSize = sizeInfo.totalSizeMB > _vacuumThresholdMB;
      final hasSignificantFreeSpace = sizeInfo.freeSizeMB > (sizeInfo.totalSizeMB * 0.2);
      final lastVacuum = await _getLastMaintenanceTimestamp('vacuum');
      final vacuumOverdue = lastVacuum == null || 
                           DateTime.now().difference(lastVacuum) > const Duration(days: 7);
      
      return exceedsSize || hasSignificantFreeSpace || vacuumOverdue;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Check if integrity check should be performed
  Future<bool> _shouldPerformIntegrityCheck() async {
    try {
      final lastCheck = await _getLastMaintenanceTimestamp('integrity_check');
      return lastCheck == null || 
             DateTime.now().difference(lastCheck) > _integrityCheckInterval;
    } catch (e) {
      
      return true; // Default to performing check if unsure
    }
  }
  
  /// Check for orphaned records in the database
  Future<void> _checkOrphanedRecords(Database db, IntegrityCheckResult result) async {
    try {
      // Check for sync log entries without corresponding main table records
      final orphanedSyncLogs = await db.rawQuery('''
        SELECT COUNT(*) as count FROM sync_log s
        WHERE s.table_name = 'food_items' 
        AND NOT EXISTS (SELECT 1 FROM food_items f WHERE f.id = s.record_id)
      ''');
      
      final orphanedCount = orphanedSyncLogs.first['count'] as int;
      result.orphanedRecordsOk = orphanedCount == 0;
      
      if (orphanedCount > 0) {
        result.issues.add('Found $orphanedCount orphaned sync log entries');
      }
      
    } catch (e) {
      result.orphanedRecordsOk = false;
      result.issues.add('Failed to check orphaned records: $e');
    }
  }
  
  /// Check data consistency across tables
  Future<void> _checkDataConsistency(Database db, IntegrityCheckResult result) async {
    try {
      // Check for food items with invalid departments
      final invalidDepartments = await db.rawQuery('''
        SELECT COUNT(*) as count FROM food_items f
        WHERE f.department IS NOT NULL 
        AND f.department != ''
        AND NOT EXISTS (
          SELECT 1 FROM departments d 
          WHERE d.name = f.department AND d.admin_uid = f.admin_uid
        )
      ''');
      
      final invalidCount = invalidDepartments.first['count'] as int;
      result.dataConsistencyOk = invalidCount == 0;
      
      if (invalidCount > 0) {
        result.issues.add('Found $invalidCount food items with invalid departments');
      }
      
    } catch (e) {
      result.dataConsistencyOk = false;
      result.issues.add('Failed to check data consistency: $e');
    }
  }
  
  /// Check index consistency and usage
  Future<void> _checkIndexConsistency(Database db, IntegrityCheckResult result) async {
    try {
      // Check if critical indexes exist
      final criticalIndexes = [
        'idx_food_items_admin_uid',
        'idx_food_items_admin_dept',
        'idx_departments_admin_uid',
        'idx_bills_admin_uid',
      ];
      
      final existingIndexes = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'index' AND name IN (${criticalIndexes.map((_) => '?').join(',')})
      ''', criticalIndexes);
      
      final existingIndexNames = existingIndexes.map((idx) => idx['name'] as String).toSet();
      final missingIndexes = criticalIndexes.where((idx) => !existingIndexNames.contains(idx)).toList();
      
      result.indexConsistencyOk = missingIndexes.isEmpty;
      
      if (missingIndexes.isNotEmpty) {
        result.issues.add('Missing critical indexes: ${missingIndexes.join(', ')}');
      }
      
    } catch (e) {
      result.indexConsistencyOk = false;
      result.issues.add('Failed to check index consistency: $e');
    }
  }
  
  /// Check table statistics and health
  Future<void> _checkTableStatistics(Database db, IntegrityCheckResult result) async {
    try {
      final tables = ['food_items', 'departments', 'bills', 'sync_log', 'image_cache'];
      final tableStats = <String, int>{};
      
      for (final table in tables) {
        final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        tableStats[table] = countResult.first['count'] as int;
      }
      
      result.tableStatistics = tableStats;
      
      // Check for unusually large tables that might need attention
      if (tableStats['sync_log']! > _maxLogEntries) {
        result.issues.add('Sync log table has ${tableStats['sync_log']} entries (max recommended: $_maxLogEntries)');
      }
      
      if (tableStats['image_cache']! > _maxImageCacheEntries) {
        result.issues.add('Image cache has ${tableStats['image_cache']} entries (max recommended: $_maxImageCacheEntries)');
      }
      
    } catch (e) {
      result.issues.add('Failed to check table statistics: $e');
    }
  }
  
  /// Calculate size of individual tables
  Future<void> _calculateTableSizes(Database db, DatabaseSizeInfo sizeInfo) async {
    try {
      final tables = ['food_items', 'departments', 'bills', 'sync_log', 'image_cache'];
      
      for (final table in tables) {
        // Get approximate table size using page count
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        final rowCount = result.first['count'] as int;
        
        // Estimate size (this is approximate)
        final estimatedSizeBytes = rowCount * 1024; // Rough estimate
        sizeInfo.tableSizes[table] = estimatedSizeBytes / (1024 * 1024); // Convert to MB
      }
      
    } catch (e) {
      
    }
  }
  
  /// Clean up old sync log entries
  Future<int> _cleanupOldSyncLogs(Database db) async {
    try {
      // Keep only the most recent entries and successful syncs from last 30 days
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
      
      final result = await db.delete(
        'sync_log',
        where: 'created_at < ? AND sync_status != 1', // Keep successful syncs
        whereArgs: [thirtyDaysAgo],
      );
      
      // Also limit total entries
      final totalCount = await db.rawQuery('SELECT COUNT(*) as count FROM sync_log');
      final count = totalCount.first['count'] as int;
      
      if (count > _maxLogEntries) {
        // Delete oldest entries beyond the limit
        await db.execute('''
          DELETE FROM sync_log 
          WHERE id IN (
            SELECT id FROM sync_log 
            ORDER BY created_at ASC 
            LIMIT ${count - _maxLogEntries}
          )
        ''');
        
        return count - _maxLogEntries + result;
      }
      
      return result;
    } catch (e) {
      
      return 0;
    }
  }
  
  /// Clean up expired image cache entries
  Future<int> _cleanupExpiredImageCache(Database db) async {
    try {
      final expiryTime = DateTime.now().subtract(_imageCacheExpiry).millisecondsSinceEpoch;
      
      return await db.delete(
        'image_cache',
        where: 'cached_at < ?',
        whereArgs: [expiryTime],
      );
    } catch (e) {
      
      return 0;
    }
  }
  
  /// Clean up orphaned image cache entries
  Future<int> _cleanupOrphanedImageCache(Database db) async {
    try {
      // Remove image cache entries that don't have corresponding records
      final result = await db.rawDelete('''
        DELETE FROM image_cache 
        WHERE (table_name = 'food_items' AND record_id NOT IN (SELECT id FROM food_items))
        OR (table_name = 'departments' AND record_id NOT IN (SELECT id FROM departments))
      ''');
      return result;
    } catch (e) {
      
      return 0;
    }
  }
  
  /// Clean up old migration logs
  Future<int> _cleanupOldMigrationLogs(Database db) async {
    try {
      // First check if migration_log table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_log'"
      );
      
      if (tableExists.isEmpty) {
        // Table doesn't exist, nothing to clean up
        return 0;
      }
      
      // Keep only the last 10 migration log entries
      final result = await db.rawDelete('''
        DELETE FROM migration_log 
        WHERE id NOT IN (
          SELECT id FROM migration_log 
          ORDER BY executed_at DESC 
          LIMIT 10
        )
      ''');
      
      return result;
    } catch (e) {
      
      return 0;
    }
  }
  
  /// Check for missing critical indexes
  Future<List<String>> _checkForMissingIndexes(Database db) async {
    try {
      final criticalIndexes = {
        'idx_food_items_admin_uid': 'CREATE INDEX IF NOT EXISTS idx_food_items_admin_uid ON food_items(admin_uid)',
        'idx_food_items_admin_dept': 'CREATE INDEX IF NOT EXISTS idx_food_items_admin_dept ON food_items(admin_uid, department)',
        'idx_food_items_name': 'CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items(name)',
        'idx_departments_admin_uid': 'CREATE INDEX IF NOT EXISTS idx_departments_admin_uid ON departments(admin_uid)',
        'idx_bills_admin_uid': 'CREATE INDEX IF NOT EXISTS idx_bills_admin_uid ON bills(admin_uid)',
        'idx_bills_date': 'CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date)',
        'idx_sync_log_status': 'CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(sync_status)',
      };
      
      final existingIndexes = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'index' AND name IN (${criticalIndexes.keys.map((_) => '?').join(',')})
      ''', criticalIndexes.keys.toList());
      
      final existingIndexNames = existingIndexes.map((idx) => idx['name'] as String).toSet();
      final missingIndexes = <String>[];
      
      for (final indexName in criticalIndexes.keys) {
        if (!existingIndexNames.contains(indexName)) {
          // Create the missing index
          await db.execute(criticalIndexes[indexName]!);
          missingIndexes.add(indexName);
        }
      }
      
      return missingIndexes;
    } catch (e) {
      
      return [];
    }
  }
  
  /// Rebuild FTS index if it exists
  Future<bool> _rebuildFTSIndex(Database db) async {
    try {
      // Check if FTS table exists
      final ftsExists = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'table' AND name = 'food_items_fts'
      ''');
      
      if (ftsExists.isNotEmpty) {
        // Rebuild FTS index
        await db.execute('INSERT INTO food_items_fts(food_items_fts) VALUES("rebuild")');
        return true;
      }
      
      return false;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get index usage statistics
  Future<Map<String, dynamic>> _getIndexUsageStatistics(Database db) async {
    try {
      // Get all indexes
      final indexes = await db.rawQuery('''
        SELECT name, tbl_name FROM sqlite_master 
        WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
      ''');
      
      // Get table row counts for context
      final tableStats = <String, int>{};
      final tables = ['food_items', 'departments', 'bills'];
      
      for (final table in tables) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        tableStats[table] = result.first['count'] as int;
      }
      
      return {
        'totalIndexes': indexes.length,
        'indexesByTable': _groupIndexesByTable(indexes),
        'tableRowCounts': tableStats,
      };
    } catch (e) {
      
      return {};
    }
  }
  
  /// Group indexes by table name
  Map<String, List<String>> _groupIndexesByTable(List<Map<String, dynamic>> indexes) {
    final grouped = <String, List<String>>{};
    
    for (final index in indexes) {
      final tableName = index['tbl_name'] as String;
      final indexName = index['name'] as String;
      
      grouped.putIfAbsent(tableName, () => []).add(indexName);
    }
    
    return grouped;
  }
  
  /// Update maintenance timestamp
  Future<void> _updateMaintenanceTimestamp([String? operation]) async {
    try {
      final db = await _getSqliteDatabase();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Create maintenance_log table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS maintenance_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          executed_at INTEGER NOT NULL,
          success BOOLEAN DEFAULT 1,
          details TEXT
        )
      ''');
      
      await db.insert('maintenance_log', {
        'operation': operation ?? 'full_maintenance',
        'executed_at': now,
        'success': 1,
      });
      
    } catch (e) {
      
    }
  }
  
  /// Get last maintenance timestamp for specific operation
  Future<DateTime?> _getLastMaintenanceTimestamp(String operation) async {
    try {
      final db = await _getSqliteDatabase();
      
      final result = await db.query(
        'maintenance_log',
        columns: ['executed_at'],
        where: 'operation = ? AND success = 1',
        whereArgs: [operation],
        orderBy: 'executed_at DESC',
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final timestamp = result.first['executed_at'] as int;
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get maintenance history
  Future<List<Map<String, dynamic>>> getMaintenanceHistory({int limit = 50}) async {
    try {
      final db = await _getSqliteDatabase();
      
      return await db.query(
        'maintenance_log',
        orderBy: 'executed_at DESC',
        limit: limit,
      );
    } catch (e) {
      
      return [];
    }
  }
  
  /// Schedule automatic maintenance
  Future<void> scheduleAutomaticMaintenance() async {
    // This would typically integrate with a background task scheduler
    // For now, we'll just check if maintenance is due
    try {
      final lastMaintenance = await _getLastMaintenanceTimestamp('full_maintenance');
      
      if (lastMaintenance == null || 
          DateTime.now().difference(lastMaintenance) > _maintenanceInterval) {
        
        
        
        // Perform lightweight maintenance
        await performMaintenance(
          forceVacuum: false,
          forceIntegrityCheck: false,
          cleanupOldData: true,
          optimizeIndexes: true,
        );
      }
    } catch (e) {
      
    }
  }
}

/// Result classes for maintenance operations

class MaintenanceResult {
  bool success = false;
  String? error;
  Duration? duration;
  List<String> warnings = [];
  
  DatabaseSizeInfo? sizeInfo;
  VacuumResult? vacuumResult;
  IntegrityCheckResult? integrityCheckResult;
  DataCleanupResult? cleanupResult;
  IndexOptimizationResult? indexOptimizationResult;
}

class VacuumResult {
  bool success = false;
  String? error;
  Duration? duration;
  double sizeBefore = 0.0;
  double sizeAfter = 0.0;
  double spaceReclaimedMB = 0.0;
}

class IntegrityCheckResult {
  bool success = false;
  String? error;
  Duration? duration;
  bool isHealthy = false;
  
  bool sqliteIntegrityOk = false;
  bool foreignKeyConstraintsOk = false;
  bool orphanedRecordsOk = false;
  bool dataConsistencyOk = false;
  bool indexConsistencyOk = false;
  
  List<String> issues = [];
  Map<String, int> tableStatistics = {};
}

class DatabaseSizeInfo {
  bool success = false;
  String? error;
  
  double totalSizeMB = 0.0;
  double freeSizeMB = 0.0;
  int pageCount = 0;
  int pageSize = 0;
  int freePages = 0;
  
  Map<String, double> tableSizes = {};
}

class DataCleanupResult {
  bool success = false;
  String? error;
  Duration? duration;
  
  int syncLogsRemoved = 0;
  int imageCacheEntriesRemoved = 0;
  int orphanedImagesRemoved = 0;
  int migrationLogsRemoved = 0;
  int itemsRemoved = 0;
}

class IndexOptimizationResult {
  bool success = false;
  String? error;
  Duration? duration;
  
  bool statisticsUpdated = false;
  int indexesAnalyzed = 0;
  List<String> missingIndexes = [];
  bool ftsIndexRebuilt = false;
  Map<String, dynamic> indexUsageStats = {};
}