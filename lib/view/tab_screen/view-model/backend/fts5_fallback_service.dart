import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';

/// FTS5 Fallback Service
/// Handles cases where FTS5 module is not available and provides fallback search functionality
class FTS5FallbackService {
  static final FTS5FallbackService _instance = FTS5FallbackService._internal();
  factory FTS5FallbackService() => _instance;
  FTS5FallbackService._internal();

  bool? _fts5Available;
  bool _fallbackIndexesCreated = false;

  /// Check if FTS5 module is available in the current SQLite installation
  Future<bool> isFTS5Available(Database db) async {
    if (_fts5Available != null) return _fts5Available!;

    try {
      // Try to create a temporary FTS5 table to test availability
      await db.execute('CREATE VIRTUAL TABLE IF NOT EXISTS fts5_test USING fts5(test_column)');
      await db.execute('DROP TABLE IF EXISTS fts5_test');
      
      _fts5Available = true;
      developer.log('FTS5 module is available', name: 'FTS5FallbackService');
      return true;
    } catch (e) {
      _fts5Available = false;
      developer.log('FTS5 module not available: $e', name: 'FTS5FallbackService');
      return false;
    }
  }

  /// Create FTS5 tables if available, otherwise create fallback indexes
  Future<void> setupSearchInfrastructure(Database db) async {
    final fts5Available = await isFTS5Available(db);
    
    if (fts5Available) {
      await _createFTS5Tables(db);
    } else {
      await _createFallbackSearchIndexes(db);
    }
  }

  /// Create FTS5 virtual tables for full-text search
  Future<void> _createFTS5Tables(Database db) async {
    try {
      // Create FTS5 virtual table for food items
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS food_items_fts USING fts5(
          id, name, description, food_code, department,
          content='food_items',
          content_rowid='rowid'
        )
      ''');

      // Create FTS5 virtual table for departments
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS departments_fts USING fts5(
          id, name,
          content='departments',
          content_rowid='rowid'
        )
      ''');

      // Populate FTS tables with existing data
      await _populateFTS5Tables(db);
      
      developer.log('FTS5 tables created successfully', name: 'FTS5FallbackService');
    } catch (e) {
      developer.log('Failed to create FTS5 tables: $e', name: 'FTS5FallbackService');
      // Fall back to regular indexes
      await _createFallbackSearchIndexes(db);
    }
  }

  /// Populate FTS5 tables with existing data
  Future<void> _populateFTS5Tables(Database db) async {
    try {
      // Check if food_items table exists and has data
      final foodItemsCount = await db.rawQuery('SELECT COUNT(*) as count FROM food_items');
      final count = foodItemsCount.first['count'] as int;
      
      if (count > 0) {
        await db.execute('''
          INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
          SELECT id, name, COALESCE(description, ''), COALESCE(food_code, ''), COALESCE(department, '') 
          FROM food_items
        ''');
        developer.log('Populated food_items_fts with $count items', name: 'FTS5FallbackService');
      }

      // Check if departments table exists and has data
      final departmentsCount = await db.rawQuery('SELECT COUNT(*) as count FROM departments');
      final deptCount = departmentsCount.first['count'] as int;
      
      if (deptCount > 0) {
        await db.execute('''
          INSERT OR REPLACE INTO departments_fts(id, name)
          SELECT id, COALESCE(name, '') FROM departments
        ''');
        developer.log('Populated departments_fts with $deptCount departments', name: 'FTS5FallbackService');
      }
    } catch (e) {
      developer.log('Error populating FTS5 tables: $e', name: 'FTS5FallbackService');
    }
  }

  /// Create fallback search indexes when FTS5 is not available
  Future<void> _createFallbackSearchIndexes(Database db) async {
    if (_fallbackIndexesCreated) return;

    try {
      final fallbackIndexes = [
        // Food items search indexes
        'CREATE INDEX IF NOT EXISTS idx_food_items_name_search ON food_items(name COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_food_items_description_search ON food_items(description COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_food_items_food_code_search ON food_items(food_code COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_food_items_department_search ON food_items(department COLLATE NOCASE)',
        
        // Composite search indexes for better performance
        'CREATE INDEX IF NOT EXISTS idx_food_items_admin_name_search ON food_items(admin_uid, name COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_food_items_admin_dept_search ON food_items(admin_uid, department COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_food_items_dept_name_search ON food_items(department, name COLLATE NOCASE)',
        
        // Department search indexes
        'CREATE INDEX IF NOT EXISTS idx_departments_name_search ON departments(name COLLATE NOCASE)',
        'CREATE INDEX IF NOT EXISTS idx_departments_admin_name_search ON departments(admin_uid, name COLLATE NOCASE)',
        
        // Additional performance indexes
        'CREATE INDEX IF NOT EXISTS idx_food_items_admin_uid ON food_items(admin_uid)',
        'CREATE INDEX IF NOT EXISTS idx_departments_admin_uid ON departments(admin_uid)',
      ];

      for (final indexSql in fallbackIndexes) {
        try {
          await db.execute(indexSql);
        } catch (e) {
          developer.log('Failed to create fallback index: $indexSql - Error: $e', name: 'FTS5FallbackService');
        }
      }

      _fallbackIndexesCreated = true;
      developer.log('Fallback search indexes created successfully', name: 'FTS5FallbackService');
    } catch (e) {
      developer.log('Error creating fallback search indexes: $e', name: 'FTS5FallbackService');
    }
  }

  /// Perform search using FTS5 if available, otherwise use fallback LIKE search
  Future<List<Map<String, dynamic>>> searchFoodItems(
    Database db,
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    final fts5Available = await isFTS5Available(db);
    
    if (fts5Available && await _fts5TablesExist(db)) {
      return await _searchWithFTS5(db, adminUid, searchTerm, department: department, limit: limit);
    } else {
      return await _searchWithFallback(db, adminUid, searchTerm, department: department, limit: limit);
    }
  }

  /// Check if FTS5 tables exist
  Future<bool> _fts5TablesExist(Database db) async {
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

  /// Search using FTS5 full-text search
  Future<List<Map<String, dynamic>>> _searchWithFTS5(
    Database db,
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    try {
      String query = '''
        SELECT f.*, 
               bm25(fts) as rank
        FROM food_items f
        INNER JOIN food_items_fts fts ON f.id = fts.id
        WHERE f.admin_uid = ? AND food_items_fts MATCH ?
      ''';
      
      List<dynamic> args = [adminUid, searchTerm];
      
      if (department != null && department.isNotEmpty) {
        query += ' AND f.department = ?';
        args.add(department);
      }
      
      query += ' ORDER BY rank ASC, f.name ASC LIMIT ?';
      args.add(limit);
      
      final results = await db.rawQuery(query, args);
      developer.log('FTS5 search returned ${results.length} results', name: 'FTS5FallbackService');
      return results;
    } catch (e) {
      developer.log('FTS5 search failed: $e', name: 'FTS5FallbackService');
      // Fall back to LIKE search
      return await _searchWithFallback(db, adminUid, searchTerm, department: department, limit: limit);
    }
  }

  /// Search using fallback LIKE queries with optimized performance
  Future<List<Map<String, dynamic>>> _searchWithFallback(
    Database db,
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
  }) async {
    try {
      // Clean and prepare search term
      final cleanSearchTerm = searchTerm.trim().toLowerCase();
      if (cleanSearchTerm.isEmpty) return [];

      // Split search term into words for better matching
      final searchWords = cleanSearchTerm.split(' ').where((word) => word.isNotEmpty).toList();
      
      // Build search patterns
      final exactPattern = '%$cleanSearchTerm%';
      
      String query = '''
        SELECT *, 
               CASE 
                 WHEN LOWER(name) LIKE ? THEN 1
                 WHEN LOWER(food_code) LIKE ? THEN 2
                 WHEN LOWER(description) LIKE ? THEN 3
                 WHEN LOWER(department) LIKE ? THEN 4
                 ELSE 5
               END as search_priority
        FROM food_items 
        WHERE admin_uid = ? AND (
          LOWER(name) LIKE ? OR 
          LOWER(food_code) LIKE ? OR 
          LOWER(description) LIKE ? OR
          LOWER(department) LIKE ?
        )
      ''';
      
      List<dynamic> args = [
        exactPattern, exactPattern, exactPattern, exactPattern, // For priority calculation
        adminUid, // admin_uid filter
        exactPattern, exactPattern, exactPattern, exactPattern, // For search conditions
      ];
      
      // Add department filter if specified
      if (department != null && department.isNotEmpty) {
        query += ' AND department = ?';
        args.add(department);
      }
      
      // Add multi-word search if applicable
      if (searchWords.length > 1) {
        final wordConditions = searchWords.map((_) => 
          '(LOWER(name) LIKE ? OR LOWER(food_code) LIKE ? OR LOWER(description) LIKE ?)'
        ).join(' AND ');
        
        query += ' OR ($wordConditions)';
        
        for (final word in searchWords) {
          final wordPattern = '%$word%';
          args.addAll([wordPattern, wordPattern, wordPattern]);
        }
      }
      
      query += ' ORDER BY search_priority ASC, name ASC LIMIT ?';
      args.add(limit);
      
      final results = await db.rawQuery(query, args);
      developer.log('Fallback search returned ${results.length} results', name: 'FTS5FallbackService');
      return results;
    } catch (e) {
      developer.log('Fallback search failed: $e', name: 'FTS5FallbackService');
      return [];
    }
  }

  /// Update search indexes when data changes
  Future<void> updateSearchIndexes(Database db, String tableName, Map<String, dynamic> data) async {
    final fts5Available = await isFTS5Available(db);
    
    if (fts5Available && await _fts5TablesExist(db)) {
      await _updateFTS5Indexes(db, tableName, data);
    }
    // Fallback indexes are automatically updated by SQLite
  }

  /// Update FTS5 indexes when data changes
  Future<void> _updateFTS5Indexes(Database db, String tableName, Map<String, dynamic> data) async {
    try {
      if (tableName == 'food_items') {
        await db.execute('''
          INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          data['id'],
          data['name'] ?? '',
          data['description'] ?? '',
          data['food_code'] ?? '',
          data['department'] ?? '',
        ]);
      } else if (tableName == 'departments') {
        await db.execute('''
          INSERT OR REPLACE INTO departments_fts(id, name)
          VALUES (?, ?)
        ''', [
          data['id'],
          data['name'] ?? '',
        ]);
      }
    } catch (e) {
      developer.log('Error updating FTS5 indexes: $e', name: 'FTS5FallbackService');
    }
  }

  /// Remove item from search indexes
  Future<void> removeFromSearchIndexes(Database db, String tableName, String itemId) async {
    final fts5Available = await isFTS5Available(db);
    
    if (fts5Available && await _fts5TablesExist(db)) {
      try {
        if (tableName == 'food_items') {
          await db.execute('DELETE FROM food_items_fts WHERE id = ?', [itemId]);
        } else if (tableName == 'departments') {
          await db.execute('DELETE FROM departments_fts WHERE id = ?', [itemId]);
        }
      } catch (e) {
        developer.log('Error removing from FTS5 indexes: $e', name: 'FTS5FallbackService');
      }
    }
    // Fallback indexes are automatically updated by SQLite
  }

  /// Get search capabilities and status
  Map<String, dynamic> getSearchStatus() {
    return {
      'fts5Available': _fts5Available ?? false,
      'fallbackIndexesCreated': _fallbackIndexesCreated,
      'searchType': _fts5Available == true ? 'FTS5' : 'Fallback',
      'capabilities': {
        'fullTextSearch': _fts5Available == true,
        'basicSearch': true,
        'caseInsensitiveSearch': true,
        'multiWordSearch': true,
        'prioritizedResults': true,
      }
    };
  }

  /// Rebuild search indexes (useful for maintenance)
  Future<void> rebuildSearchIndexes(Database db) async {
    try {
      final fts5Available = await isFTS5Available(db);
      
      if (fts5Available) {
        // Drop and recreate FTS5 tables
        await db.execute('DROP TABLE IF EXISTS food_items_fts');
        await db.execute('DROP TABLE IF EXISTS departments_fts');
        await _createFTS5Tables(db);
      } else {
        // Recreate fallback indexes
        _fallbackIndexesCreated = false;
        await _createFallbackSearchIndexes(db);
      }
      
      developer.log('Search indexes rebuilt successfully', name: 'FTS5FallbackService');
    } catch (e) {
      developer.log('Error rebuilding search indexes: $e', name: 'FTS5FallbackService');
    }
  }
}