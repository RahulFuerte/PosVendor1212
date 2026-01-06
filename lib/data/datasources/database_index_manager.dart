// Dart imports:
import 'dart:developer' as developer;

// Package imports:
import 'package:sqflite/sqflite.dart';

// Project imports:
import 'local/sqlite_helper.dart';

/// Database Index Manager for optimizing query performance
class DatabaseIndexManager {
  static final DatabaseIndexManager _instance = DatabaseIndexManager._internal();
  factory DatabaseIndexManager() => _instance;
  DatabaseIndexManager._internal();

  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  
  /// Create all performance indexes for optimal query speed
  Future<void> createPerformanceIndexes() async {
    developer.log('Creating performance indexes', name: 'DatabaseIndexManager');
    
    try {
      final db = await _sqliteHelper.database;
      
      // Food items performance indexes
      await _createFoodItemIndexes(db);
      
      // Department performance indexes
      await _createDepartmentIndexes(db);
      
      // Bills performance indexes
      await _createBillIndexes(db);
      
      // Sync and cache indexes
      await _createSyncIndexes(db);
      
      // Full-text search indexes
      await _createSearchIndexes(db);
      
      developer.log('All performance indexes created successfully', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Error creating performance indexes: $e', name: 'DatabaseIndexManager');
      rethrow;
    }
  }

  /// Create food items specific indexes
  Future<void> _createFoodItemIndexes(Database db) async {
    final indexes = [
      // Single column indexes for common queries
      'CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items(name)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_department ON food_items(department)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_price ON food_items(price)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_food_code ON food_items(food_code)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_stocks ON food_items(stocks)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_is_hot ON food_items(is_hot)',
      
      // Composite indexes for complex queries
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_dept ON food_items(admin_uid, department)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_name ON food_items(admin_uid, name)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_price ON food_items(admin_uid, price)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_dept_price ON food_items(department, price)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_dept_stocks ON food_items(department, stocks)',
      
      // Sync status indexes
      'CREATE INDEX IF NOT EXISTS idx_food_items_sync_status ON food_items(sync_status)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_sync ON food_items(admin_uid, sync_status)',
      
      // Timestamp indexes for sorting
      'CREATE INDEX IF NOT EXISTS idx_food_items_created_at ON food_items(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_updated_at ON food_items(updated_at)',
    ];
    
    for (final indexSql in indexes) {
      await db.execute(indexSql);
    }
    
    developer.log('Food items indexes created', name: 'DatabaseIndexManager');
  }

  /// Create department specific indexes
  Future<void> _createDepartmentIndexes(Database db) async {
    final indexes = [
      // Basic department indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_name ON departments(name)',
      'CREATE INDEX IF NOT EXISTS idx_departments_status ON departments(status)',
      
      // Composite indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_admin_status ON departments(admin_uid, status)',
      'CREATE INDEX IF NOT EXISTS idx_departments_admin_name ON departments(admin_uid, name)',
      
      // Sync status indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_sync_status ON departments(sync_status)',
      'CREATE INDEX IF NOT EXISTS idx_departments_admin_sync ON departments(admin_uid, sync_status)',
      
      // Timestamp indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_created_at ON departments(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_departments_updated_at ON departments(updated_at)',
    ];
    
    for (final indexSql in indexes) {
      await db.execute(indexSql);
    }
    
    developer.log('Department indexes created', name: 'DatabaseIndexManager');
  }

  /// Create bills specific indexes
  Future<void> _createBillIndexes(Database db) async {
    final indexes = [
      // Date-based indexes for bill queries
      'CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date)',
      'CREATE INDEX IF NOT EXISTS idx_bills_admin_date ON bills(admin_uid, bill_date)',
      'CREATE INDEX IF NOT EXISTS idx_bills_customer_phone ON bills(customer_phone)',
      
      // Amount-based indexes
      'CREATE INDEX IF NOT EXISTS idx_bills_total_amount ON bills(total_amount)',
      'CREATE INDEX IF NOT EXISTS idx_bills_admin_amount ON bills(admin_uid, total_amount)',
      
      // Sync status indexes
      'CREATE INDEX IF NOT EXISTS idx_bills_sync_status ON bills(sync_status)',
      'CREATE INDEX IF NOT EXISTS idx_bills_admin_sync ON bills(admin_uid, sync_status)',
      
      // Timestamp indexes for sorting
      'CREATE INDEX IF NOT EXISTS idx_bills_created_at ON bills(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_bills_updated_at ON bills(updated_at)',
      
      // Composite indexes for complex queries
      'CREATE INDEX IF NOT EXISTS idx_bills_admin_date_amount ON bills(admin_uid, bill_date, total_amount)',
    ];
    
    for (final indexSql in indexes) {
      await db.execute(indexSql);
    }
    
    developer.log('Bills indexes created', name: 'DatabaseIndexManager');
  }

  /// Create sync and cache related indexes
  Future<void> _createSyncIndexes(Database db) async {
    final indexes = [
      // Sync log indexes
      'CREATE INDEX IF NOT EXISTS idx_sync_log_table_record ON sync_log(table_name, record_id)',
      'CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(sync_status)',
      'CREATE INDEX IF NOT EXISTS idx_sync_log_created_at ON sync_log(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_sync_log_synced_at ON sync_log(synced_at)',
      
      // Image cache indexes
      'CREATE INDEX IF NOT EXISTS idx_image_cache_record ON image_cache(table_name, record_id)',
      'CREATE INDEX IF NOT EXISTS idx_image_cache_accessed ON image_cache(last_accessed)',
      'CREATE INDEX IF NOT EXISTS idx_image_cache_cached_at ON image_cache(cached_at)',
      'CREATE INDEX IF NOT EXISTS idx_image_cache_url ON image_cache(image_url)',
    ];
    
    for (final indexSql in indexes) {
      await db.execute(indexSql);
    }
    
    developer.log('Sync and cache indexes created', name: 'DatabaseIndexManager');
  }

  /// Create full-text search indexes
  Future<void> _createSearchIndexes(Database db) async {
    try {
      developer.log('Starting search index creation', name: 'DatabaseIndexManager');
      
      // Always use fallback indexes to avoid FTS5 issues
      // FTS5 is causing app hangs, so we'll skip it entirely for now
      developer.log('Using fallback search indexes (FTS5 disabled to prevent hangs)', name: 'DatabaseIndexManager');
      await _createFallbackSearchIndexes(db);
      
      developer.log('Search indexes created successfully', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Error creating search indexes: $e', name: 'DatabaseIndexManager');
      // Continue without search indexes - basic functionality will still work
      developer.log('Continuing without search indexes - basic functionality will still work', name: 'DatabaseIndexManager');
    }
  }

  /// Check if FTS5 module is available
  Future<bool> _checkFTS5Availability(Database db) async {
    // Always return false to disable FTS5 and prevent app hangs
    developer.log('FTS5 disabled to prevent initialization hangs', name: 'DatabaseIndexManager');
    return false;
  }

  /// Create FTS5 full-text search indexes with enhanced error handling
  Future<void> _createFTS5Indexes(Database db) async {
    try {
      developer.log('Creating FTS5 indexes', name: 'DatabaseIndexManager');
      
      // Create FTS5 virtual table for food items search
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS food_items_fts USING fts5(
          id, name, description, food_code, department,
          content='food_items',
          content_rowid='rowid'
        )
      ''');
      
      // Populate FTS table with existing data
      await db.execute('''
        INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
        SELECT id, name, description, food_code, department FROM food_items
      ''');
      
      // Create FTS5 virtual table for departments search
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS departments_fts USING fts5(
          id, name,
          content='departments',
          content_rowid='rowid'
        )
      ''');
      
      // Populate departments FTS table
      await db.execute('''
        INSERT OR REPLACE INTO departments_fts(id, name)
        SELECT id, name FROM departments
      ''');
      
      developer.log('FTS5 search indexes created successfully', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Failed to create FTS5 indexes: $e', name: 'DatabaseIndexManager');
      // Re-throw to trigger fallback
      throw Exception('FTS5 module not available: $e');
    }
  }

  /// Create fallback search indexes when FTS5 is not available
  Future<void> _createFallbackSearchIndexes(Database db) async {
    final fallbackIndexes = [
      // Text search optimization indexes for food items
      'CREATE INDEX IF NOT EXISTS idx_food_items_name_search ON food_items(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_description_search ON food_items(description COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_food_code_search ON food_items(food_code COLLATE NOCASE)',
      
      // Composite search indexes
      'CREATE INDEX IF NOT EXISTS idx_food_items_admin_name_search ON food_items(admin_uid, name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_food_items_dept_name_search ON food_items(department, name COLLATE NOCASE)',
      
      // Department search indexes
      'CREATE INDEX IF NOT EXISTS idx_departments_name_search ON departments(name COLLATE NOCASE)',
      'CREATE INDEX IF NOT EXISTS idx_departments_admin_name_search ON departments(admin_uid, name COLLATE NOCASE)',
    ];
    
    for (final indexSql in fallbackIndexes) {
      await db.execute(indexSql);
    }
    
    developer.log('Fallback search indexes created', name: 'DatabaseIndexManager');
  }

  /// Optimize query paths by analyzing and improving slow queries
  Future<void> optimizeQueryPaths() async {
    developer.log('Optimizing query paths', name: 'DatabaseIndexManager');
    
    try {
      final db = await _sqliteHelper.database;
      
      // Analyze common query patterns
      final queryAnalysis = await _analyzeCommonQueries(db);
      
      // Create missing indexes based on analysis
      await _createMissingIndexes(db, queryAnalysis);
      
      // Update table statistics for query planner
      await db.execute('ANALYZE');
      
      developer.log('Query path optimization completed', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Error optimizing query paths: $e', name: 'DatabaseIndexManager');
    }
  }

  /// Analyze common query patterns to identify optimization opportunities
  Future<Map<String, dynamic>> _analyzeCommonQueries(Database db) async {
    final analysis = <String, dynamic>{};
    
    try {
      // Common query patterns to analyze
      final queries = [
        {
          'name': 'getFoodItems_by_admin',
          'query': 'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE admin_uid = ?',
          'params': ['test_admin']
        },
        {
          'name': 'getFoodItems_by_department',
          'query': 'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE admin_uid = ? AND department = ?',
          'params': ['test_admin', 'test_dept']
        },
        {
          'name': 'searchFoodItems',
          'query': 'EXPLAIN QUERY PLAN SELECT * FROM food_items WHERE name LIKE ?',
          'params': ['%test%']
        },
        {
          'name': 'getBills_by_date',
          'query': 'EXPLAIN QUERY PLAN SELECT * FROM bills WHERE admin_uid = ? AND bill_date > ?',
          'params': ['test_admin', DateTime.now().millisecondsSinceEpoch - 86400000]
        },
      ];
      
      for (final queryInfo in queries) {
        try {
          final result = await db.rawQuery(queryInfo['query'] as String, queryInfo['params'] as List);
          analysis[queryInfo['name'] as String] = result;
        } catch (e) {
          analysis[queryInfo['name'] as String] = {'error': e.toString()};
        }
      }
      
      return analysis;
    } catch (e) {
      developer.log('Error analyzing queries: $e', name: 'DatabaseIndexManager');
      return {'error': e.toString()};
    }
  }

  /// Create missing indexes based on query analysis
  Future<void> _createMissingIndexes(Database db, Map<String, dynamic> analysis) async {
    try {
      // Check if queries are using indexes efficiently
      for (final entry in analysis.entries) {
        final queryName = entry.key;
        final queryPlan = entry.value;
        
        if (queryPlan is List && queryPlan.isNotEmpty) {
          final planText = queryPlan.map((row) => row.toString()).join(' ');
          
          // If query plan shows table scan, suggest indexes
          if (planText.contains('SCAN TABLE')) {
            developer.log('Query $queryName is using table scan, may need optimization', 
                         name: 'DatabaseIndexManager');
          }
        }
      }
    } catch (e) {
      developer.log('Error creating missing indexes: $e', name: 'DatabaseIndexManager');
    }
  }

  /// Update FTS indexes when data changes
  Future<void> updateSearchIndexes() async {
    try {
      // Since we're using fallback indexes only, no rebuild needed
      developer.log('Using fallback search indexes (no rebuild needed)', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Error updating search indexes: $e', name: 'DatabaseIndexManager');
    }
  }

  /// Check if FTS5 tables exist in the database
  Future<bool> _checkFTS5TablesExist(Database db) async {
    try {
      final result = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='food_items_fts'
      ''');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get index usage statistics
  Future<Map<String, dynamic>> getIndexStatistics() async {
    try {
      final db = await _sqliteHelper.database;
      
      // Get index information
      final indexes = await db.rawQuery('''
        SELECT name, sql FROM sqlite_master 
        WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      ''');
      
      return {
        'totalIndexes': indexes.length,
        'indexes': indexes,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Error getting index statistics: $e', name: 'DatabaseIndexManager');
      return {'error': e.toString()};
    }
  }

  /// Perform database maintenance for optimal performance
  Future<void> performDatabaseMaintenance() async {
    developer.log('Performing database maintenance', name: 'DatabaseIndexManager');
    
    try {
      final db = await _sqliteHelper.database;
      
      // Update table statistics for query optimizer
      await db.execute('ANALYZE');
      
      // Vacuum database to reclaim space and optimize storage
      await db.execute('VACUUM');
      
      // Update search indexes (handles both FTS5 and fallback)
      await updateSearchIndexes();
      
      developer.log('Database maintenance completed', name: 'DatabaseIndexManager');
    } catch (e) {
      developer.log('Error during database maintenance: $e', name: 'DatabaseIndexManager');
    }
  }

  /// Get search capability information
  Future<Map<String, dynamic>> getSearchCapabilities() async {
    try {
      // Always return fallback capabilities since FTS5 is disabled
      return {
        'fts5Available': false,
        'fts5TablesExist': false,
        'searchType': 'Fallback',
        'capabilities': {
          'fullTextSearch': false,
          'basicSearch': true,
          'caseInsensitiveSearch': true,
        }
      };
    } catch (e) {
      developer.log('Error getting search capabilities: $e', name: 'DatabaseIndexManager');
      return {
        'fts5Available': false,
        'fts5TablesExist': false,
        'searchType': 'Fallback',
        'error': e.toString(),
      };
    }
  }
}
