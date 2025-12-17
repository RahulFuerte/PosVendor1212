import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'sqlite_helper.dart';
import 'data_integrity_service.dart';
import 'performance_monitor.dart';
import 'fts5_fallback_service.dart';

/// SQLite Data Access Object for local database operations
class SQLiteDAO implements DatabaseService {
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final DataIntegrityService _integrityService = DataIntegrityService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final FTS5FallbackService _fts5FallbackService = FTS5FallbackService();
  
  // Query result cache for frequently accessed data
  final Map<String, Map<String, dynamic>> _queryCache = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // Prepared statements for repeated queries
  final Map<String, String> _preparedStatements = {};
  
  @override
  Future<void> initialize() async {
    await _sqliteHelper.initializeDatabase();
    await _integrityService.initialize();
    _initializePreparedStatements();
    
    // Setup search infrastructure with FTS5 fallback
    await _setupSearchInfrastructure();
    
    // Ensure database is ready and indexes are created
    await _ensureDatabaseOptimization();
  }

  /// Setup search infrastructure with FTS5 fallback handling
  Future<void> _setupSearchInfrastructure() async {
    try {
      final db = await _sqliteHelper.database;
      await _fts5FallbackService.setupSearchInfrastructure(db);
      developer.log('Search infrastructure setup completed', name: 'SQLiteDAO');
    } catch (e) {
      developer.log('Error setting up search infrastructure: $e', name: 'SQLiteDAO');
      // Continue without search optimization - basic functionality will still work
    }
  }

  /// Ensure database optimization is complete
  Future<void> _ensureDatabaseOptimization() async {
    try {
      final db = await _sqliteHelper.database;
      
      // Verify critical indexes exist
      await _verifyCriticalIndexes(db);
      
      // Warm up FTS if available
      await _warmUpFTS(db);
      
    } catch (e) {
      print('Error during database optimization: $e');
    }
  }

  /// Verify that critical indexes exist for performance
  Future<void> _verifyCriticalIndexes(Database db) async {
    try {
      final indexes = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'index' AND tbl_name = 'food_items'
      ''');
      
      final indexNames = indexes.map((idx) => idx['name'] as String).toSet();
      
      // Check for critical indexes
      final criticalIndexes = [
        'idx_food_items_admin_uid',
        'idx_food_items_admin_dept',
        'idx_food_items_name',
      ];
      
      for (final indexName in criticalIndexes) {
        if (!indexNames.contains(indexName)) {
          print('Warning: Critical index $indexName is missing');
        }
      }
    } catch (e) {
      print('Error verifying indexes: $e');
    }
  }

  /// Warm up FTS for better initial search performance
  Future<void> _warmUpFTS(Database db) async {
    try {
      // Check if FTS table exists and warm it up
      final ftsExists = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'table' AND name = 'food_items_fts'
      ''');
      
      if (ftsExists.isNotEmpty) {
        // Perform a simple FTS query to warm up the index
        await db.rawQuery('''
          SELECT COUNT(*) FROM food_items_fts WHERE food_items_fts MATCH 'test'
        ''');
      }
    } catch (e) {
      // FTS warmup failure is not critical
      print('FTS warmup failed (expected if no data): $e');
    }
  }

  @override
  Future<void> close() async {
    _queryCache.clear();
    await _sqliteHelper.closeDatabase();
  }

  @override
  Future<bool> isOnline() async {
    // SQLite is always available locally
    return true;
  }

  /// Initialize optimized prepared statements for frequently used queries
  void _initializePreparedStatements() {
    _preparedStatements.addAll({
      // Enhanced food items queries with better indexing
      'getFoodItemsByAdmin': 'SELECT * FROM food_items WHERE admin_uid = ? ORDER BY name ASC',
      'getFoodItemsByAdminAndDept': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? ORDER BY name ASC',
      'getFoodItemsPaginated': 'SELECT * FROM food_items WHERE admin_uid = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getFoodItemsByAdminAndDeptPaginated': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getFoodItemsCount': 'SELECT COUNT(*) as count FROM food_items WHERE admin_uid = ?',
      'getFoodItemsCountByDept': 'SELECT COUNT(*) as count FROM food_items WHERE admin_uid = ? AND department = ?',
      
      // Optimized search queries
      'searchFoodItemsLike': 'SELECT * FROM food_items WHERE admin_uid = ? AND (name LIKE ? OR food_code LIKE ? OR description LIKE ?) ORDER BY name ASC LIMIT ?',
      'searchFoodItemsLikeWithDept': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? AND (name LIKE ? OR food_code LIKE ? OR description LIKE ?) ORDER BY name ASC LIMIT ?',
      
      // Price range queries for better performance
      'getFoodItemsByPriceRange': 'SELECT * FROM food_items WHERE admin_uid = ? AND price BETWEEN ? AND ? ORDER BY price ASC LIMIT ?',
      'getFoodItemsByDeptAndPriceRange': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? AND price BETWEEN ? AND ? ORDER BY price ASC LIMIT ?',
      
      // Stock level queries
      'getFoodItemsByStockLevel': 'SELECT * FROM food_items WHERE admin_uid = ? AND stocks >= ? ORDER BY stocks ASC LIMIT ?',
      'getLowStockItems': 'SELECT * FROM food_items WHERE admin_uid = ? AND stocks < ? ORDER BY stocks ASC LIMIT ?',
      
      // Department queries with enhanced performance
      'getDepartmentsByAdmin': 'SELECT * FROM departments WHERE admin_uid = ? AND status = ? ORDER BY name ASC',
      'getDepartmentsPaginated': 'SELECT * FROM departments WHERE admin_uid = ? AND status = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getDepartmentsCount': 'SELECT COUNT(*) as count FROM departments WHERE admin_uid = ? AND status = ?',
      
      // Enhanced bills queries with date indexing
      'getBillsByAdmin': 'SELECT * FROM bills WHERE admin_uid = ? ORDER BY bill_date DESC',
      'getBillsByAdminAndDateRange': 'SELECT * FROM bills WHERE admin_uid = ? AND bill_date >= ? AND bill_date <= ? ORDER BY bill_date DESC',
      'getBillsPaginated': 'SELECT * FROM bills WHERE admin_uid = ? ORDER BY bill_date DESC LIMIT ? OFFSET ?',
      'getBillsCount': 'SELECT COUNT(*) as count FROM bills WHERE admin_uid = ?',
      'getBillsCountByDateRange': 'SELECT COUNT(*) as count FROM bills WHERE admin_uid = ? AND bill_date >= ? AND bill_date <= ?',
      'getBillsByAmountRange': 'SELECT * FROM bills WHERE admin_uid = ? AND total_amount BETWEEN ? AND ? ORDER BY bill_date DESC LIMIT ?',
      
      // Sync status queries for better performance
      'getPendingFoodItems': 'SELECT * FROM food_items WHERE admin_uid = ? AND sync_status = ? ORDER BY updated_at ASC',
      'getPendingDepartments': 'SELECT * FROM departments WHERE admin_uid = ? AND sync_status = ? ORDER BY updated_at ASC',
      'getPendingBills': 'SELECT * FROM bills WHERE admin_uid = ? AND sync_status = ? ORDER BY updated_at ASC',
    });
  }

  /// Execute an optimized query with caching and prepared statements
  Future<List<Map<String, dynamic>>> _executeOptimizedQuery({
    required String queryKey,
    required List<dynamic> parameters,
    String? customQuery,
    bool useCache = true,
    Duration? cacheExpiry,
  }) async {
    return await _performanceMonitor.trackQuery('optimized_$queryKey', () async {
      // Check cache first if enabled
      if (useCache) {
        final cachedResult = _getCachedResult(queryKey, parameters);
        if (cachedResult != null) {
          return cachedResult;
        }
      }

      final db = await _sqliteHelper.database;
      
      // Use prepared statement or custom query
      final query = customQuery ?? _preparedStatements[queryKey];
      if (query == null) {
        throw ArgumentError('No prepared statement found for key: $queryKey');
      }

      // Execute the query
      final result = await db.rawQuery(query, parameters);

      // Cache the result if caching is enabled
      if (useCache) {
        _cacheResult(queryKey, parameters, result, cacheExpiry ?? _cacheExpiry);
      }

      return result;
    });
  }

  /// Execute an optimized count query
  Future<int> _executeOptimizedCountQuery({
    required String queryKey,
    required List<dynamic> parameters,
    String? customQuery,
    bool useCache = true,
    Duration? cacheExpiry,
  }) async {
    final results = await _executeOptimizedQuery(
      queryKey: queryKey,
      parameters: parameters,
      customQuery: customQuery,
      useCache: useCache,
      cacheExpiry: cacheExpiry,
    );
    
    return results.isNotEmpty ? (results.first['count'] as int? ?? 0) : 0;
  }

  /// Get cached query result if available and not expired with hit tracking
  List<Map<String, dynamic>>? _getCachedResult(String queryKey, List<dynamic> parameters) {
    final cacheKey = _generateCacheKey(queryKey, parameters);
    final cachedResult = _queryCache[cacheKey];
    
    if (cachedResult != null) {
      final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedResult['cachedAt'] as int);
      final expiryDuration = Duration(milliseconds: cachedResult['expiryMs'] as int);
      
      if (DateTime.now().isBefore(cachedAt.add(expiryDuration))) {
        // Increment hit count
        cachedResult['hits'] = (cachedResult['hits'] as int? ?? 0) + 1;
        cachedResult['lastAccessed'] = DateTime.now().millisecondsSinceEpoch;
        
        return List<Map<String, dynamic>>.from(cachedResult['data'] as List);
      } else {
        // Remove expired cache entry
        _queryCache.remove(cacheKey);
      }
    }
    
    return null;
  }

  /// Cache query result with expiry and hit tracking
  void _cacheResult(String queryKey, List<dynamic> parameters, List<Map<String, dynamic>> data, Duration expiry) {
    final cacheKey = _generateCacheKey(queryKey, parameters);
    
    // Implement LRU eviction if cache is full
    if (_queryCache.length >= _maxCacheSize) {
      _evictLRUCacheEntry();
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    _queryCache[cacheKey] = {
      'data': data,
      'cachedAt': now,
      'lastAccessed': now,
      'expiryMs': expiry.inMilliseconds,
      'hits': 0,
      'size': data.length,
    };
  }

  /// Generate cache key from query key and parameters
  String _generateCacheKey(String queryKey, List<dynamic> parameters) {
    return '$queryKey:${parameters.join(':')}';
  }

  /// Evict least recently used cache entry (LRU)
  void _evictLRUCacheEntry() {
    if (_queryCache.isEmpty) return;
    
    String? lruKey;
    int? lruTime;
    
    for (final entry in _queryCache.entries) {
      final lastAccessed = entry.value['lastAccessed'] as int;
      if (lruTime == null || lastAccessed < lruTime) {
        lruTime = lastAccessed;
        lruKey = entry.key;
      }
    }
    
    if (lruKey != null) {
      _queryCache.remove(lruKey);
    }
  }

  /// Evict cache entries by size (remove largest entries first)
  void _evictCacheBySize() {
    if (_queryCache.isEmpty) return;
    
    // Sort entries by size (descending) and remove the largest ones
    final sortedEntries = _queryCache.entries.toList()
      ..sort((a, b) => (b.value['size'] as int).compareTo(a.value['size'] as int));
    
    // Remove the largest entry
    if (sortedEntries.isNotEmpty) {
      _queryCache.remove(sortedEntries.first.key);
    }
  }

  /// Smart cache eviction based on multiple factors
  void _smartCacheEviction() {
    if (_queryCache.isEmpty) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    String? evictKey;
    double lowestScore = double.infinity;
    
    for (final entry in _queryCache.entries) {
      final lastAccessed = entry.value['lastAccessed'] as int;
      final hits = entry.value['hits'] as int;
      final size = entry.value['size'] as int;
      
      // Calculate eviction score (lower is more likely to be evicted)
      final timeSinceAccess = now - lastAccessed;
      final score = (hits + 1) / (timeSinceAccess / 1000.0 + size / 100.0);
      
      if (score < lowestScore) {
        lowestScore = score;
        evictKey = entry.key;
      }
    }
    
    if (evictKey != null) {
      _queryCache.remove(evictKey);
    }
  }

  // Food Items operations with enhanced indexing strategy
  @override
  Future<List<Map<String, dynamic>>> getFoodItems(String adminUid, {String? department}) async {
    return await _performanceMonitor.trackQuery('getFoodItems', () async {
      if (department != null && department.isNotEmpty) {
        return await _executeOptimizedQuery(
          queryKey: 'getFoodItemsByAdminAndDept',
          parameters: [adminUid, department],
          useCache: true,
        );
      } else {
        return await _executeOptimizedQuery(
          queryKey: 'getFoodItemsByAdmin',
          parameters: [adminUid],
          useCache: true,
        );
      }
    });
  }

  /// Enhanced getFoodItems with advanced filtering and sorting options
  Future<List<Map<String, dynamic>>> getFoodItemsAdvanced(
    String adminUid, {
    String? department,
    String? sortBy = 'name',
    String sortOrder = 'ASC',
    double? minPrice,
    double? maxPrice,
    bool? isHot,
    int? minStocks,
    int offset = 0,
    int limit = 50,
  }) async {
    return await _performanceMonitor.trackQuery('getFoodItemsAdvanced', () async {
      final db = await _sqliteHelper.database;
      
      // Build dynamic query with proper indexing
      final List<String> whereConditions = ['admin_uid = ?'];
      final List<dynamic> whereArgs = [adminUid];
      
      if (department != null && department.isNotEmpty) {
        whereConditions.add('department = ?');
        whereArgs.add(department);
      }
      
      if (minPrice != null) {
        whereConditions.add('price >= ?');
        whereArgs.add(minPrice);
      }
      
      if (maxPrice != null) {
        whereConditions.add('price <= ?');
        whereArgs.add(maxPrice);
      }
      
      if (isHot != null) {
        whereConditions.add('is_hot = ?');
        whereArgs.add(isHot ? 1 : 0);
      }
      
      if (minStocks != null) {
        whereConditions.add('stocks >= ?');
        whereArgs.add(minStocks);
      }
      
      // Validate sort column to prevent SQL injection
      final validSortColumns = ['name', 'price', 'department', 'stocks', 'created_at', 'updated_at'];
      final safeSortBy = validSortColumns.contains(sortBy) ? sortBy : 'name';
      final safeSortOrder = sortOrder.toUpperCase() == 'DESC' ? 'DESC' : 'ASC';
      
      final query = '''
        SELECT * FROM food_items 
        WHERE ${whereConditions.join(' AND ')} 
        ORDER BY $safeSortBy $safeSortOrder 
        LIMIT ? OFFSET ?
      ''';
      
      whereArgs.addAll([limit, offset]);
      
      final result = await db.rawQuery(query, whereArgs);
      
      // Cache the result for frequently used queries
      if (department == null && minPrice == null && maxPrice == null && isHot == null && minStocks == null) {
        _cacheResult('getFoodItemsAdvanced', whereArgs, result, _cacheExpiry);
      }
      
      return result;
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
    if (department != null && department.isNotEmpty) {
      return await _executeOptimizedQuery(
        queryKey: 'getFoodItemsByAdminAndDeptPaginated',
        parameters: [adminUid, department, limit, offset],
        useCache: true,
      );
    } else {
      return await _executeOptimizedQuery(
        queryKey: 'getFoodItemsPaginated',
        parameters: [adminUid, limit, offset],
        useCache: true,
      );
    }
  }

  /// Get total count of food items for pagination
  Future<int> getFoodItemsCount(String adminUid, {String? department}) async {
    if (department != null && department.isNotEmpty) {
      return await _executeOptimizedCountQuery(
        queryKey: 'getFoodItemsCountByDept',
        parameters: [adminUid, department],
        useCache: true,
      );
    } else {
      return await _executeOptimizedCountQuery(
        queryKey: 'getFoodItemsCount',
        parameters: [adminUid],
        useCache: true,
      );
    }
  }

  /// Enhanced search food items with optimized FTS (Full-Text Search) and ranking
  Future<List<Map<String, dynamic>>> searchFoodItems(
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
    bool enableRanking = true,
  }) async {
    return await _performanceMonitor.trackQuery('searchFoodItems', () async {
      try {
        final db = await _sqliteHelper.database;
        
        // Use FTS5 fallback service for robust search handling
        final results = await _fts5FallbackService.searchFoodItems(
          db,
          adminUid,
          searchTerm,
          department: department,
          limit: limit,
        );
        
        developer.log('Search completed: ${results.length} results for "$searchTerm"', name: 'SQLiteDAO');
        return results;
      } catch (e) {
        developer.log('Search failed: $e', name: 'SQLiteDAO');
        
        // Final fallback to basic query
        try {
          return await _performBasicSearch(adminUid, searchTerm, department, limit);
        } catch (fallbackError) {
          developer.log('Basic search fallback also failed: $fallbackError', name: 'SQLiteDAO');
          return [];
        }
      }
    });
  }

  /// Basic search fallback when all other methods fail
  Future<List<Map<String, dynamic>>> _performBasicSearch(
    String adminUid,
    String searchTerm,
    String? department,
    int limit,
  ) async {
    final db = await _sqliteHelper.database;
    
    final searchPattern = '%${searchTerm.toLowerCase()}%';
    
    String query = '''
      SELECT * FROM food_items 
      WHERE admin_uid = ? AND LOWER(name) LIKE ?
    ''';
    
    List<dynamic> args = [adminUid, searchPattern];
    
    if (department != null && department.isNotEmpty) {
      query += ' AND department = ?';
      args.add(department);
    }
    
    query += ' ORDER BY name ASC LIMIT ?';
    args.add(limit);
    
    return await db.rawQuery(query, args);
  }

  /// Advanced LIKE search with multiple search strategies for better results
  Future<List<Map<String, dynamic>>> _performAdvancedLikeSearch(
    String adminUid,
    String searchTerm,
    String? department,
    int limit,
  ) async {
    final db = await _sqliteHelper.database;
    
    // Split search term into words for better matching
    final searchWords = searchTerm.toLowerCase().split(' ').where((word) => word.isNotEmpty).toList();
    
    if (searchWords.isEmpty) {
      return [];
    }
    
    // Build dynamic search query with multiple strategies
    final List<String> searchConditions = [];
    final List<dynamic> searchArgs = [adminUid];
    
    // Strategy 1: Exact phrase match (highest priority)
    final exactPattern = '%${searchTerm.toLowerCase()}%';
    searchConditions.add('(LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(food_code) LIKE ?)');
    searchArgs.addAll([exactPattern, exactPattern, exactPattern]);
    
    // Strategy 2: All words match (medium priority)
    if (searchWords.length > 1) {
      final allWordsConditions = <String>[];
      for (final word in searchWords) {
        final wordPattern = '%$word%';
        allWordsConditions.add('(LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(food_code) LIKE ?)');
        searchArgs.addAll([wordPattern, wordPattern, wordPattern]);
      }
      searchConditions.add('(${allWordsConditions.join(' AND ')})');
    }
    
    // Strategy 3: Any word match (lowest priority)
    if (searchWords.length > 1) {
      final anyWordConditions = <String>[];
      for (final word in searchWords) {
        final wordPattern = '%$word%';
        anyWordConditions.add('(LOWER(name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(food_code) LIKE ?)');
        searchArgs.addAll([wordPattern, wordPattern, wordPattern]);
      }
      searchConditions.add('(${anyWordConditions.join(' OR ')})');
    }
    
    String query = '''
      SELECT *, 
             CASE 
               WHEN LOWER(name) LIKE ? THEN 1
               WHEN LOWER(food_code) LIKE ? THEN 2
               WHEN LOWER(description) LIKE ? THEN 3
               ELSE 4
             END as search_priority
      FROM food_items 
      WHERE admin_uid = ? AND (${searchConditions.join(' OR ')})
    ''';
    
    // Add exact pattern args for priority calculation
    final priorityArgs = [exactPattern, exactPattern, exactPattern];
    final allArgs = [...priorityArgs, ...searchArgs];
    
    if (department != null && department.isNotEmpty) {
      query += ' AND department = ?';
      allArgs.add(department);
    }
    
    query += ' ORDER BY search_priority ASC, name ASC LIMIT ?';
    allArgs.add(limit);
    
    return await db.rawQuery(query, allArgs);
  }

  /// Search food items with auto-complete suggestions
  Future<List<Map<String, dynamic>>> searchFoodItemsAutoComplete(
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 10,
  }) async {
    return await _performanceMonitor.trackQuery('searchFoodItemsAutoComplete', () async {
      final db = await _sqliteHelper.database;
      
      if (searchTerm.length < 2) {
        return [];
      }
      
      // Use prefix matching for auto-complete
      final prefixPattern = '${searchTerm.toLowerCase()}%';
      
      String query = '''
        SELECT DISTINCT name, food_code, department
        FROM food_items 
        WHERE admin_uid = ? AND (
          LOWER(name) LIKE ? OR 
          LOWER(food_code) LIKE ?
        )
      ''';
      
      List<dynamic> args = [adminUid, prefixPattern, prefixPattern];
      
      if (department != null && department.isNotEmpty) {
        query += ' AND department = ?';
        args.add(department);
      }
      
      query += ' ORDER BY name ASC LIMIT ?';
      args.add(limit);
      
      return await db.rawQuery(query, args);
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
      
      // Update FTS index for search optimization
      await _updateFTSIndex(txn, itemData);
      
      // Clear relevant cache entries
      _clearCacheForQuery('getFoodItems');
      _clearCacheForQuery('searchFoodItems');
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
      
      // Update FTS index with the updated data
      final updatedItem = await txn.query(
        'food_items',
        where: 'admin_uid = ? AND id = ?',
        whereArgs: [adminUid, itemId],
        limit: 1,
      );
      if (updatedItem.isNotEmpty) {
        await _updateFTSIndex(txn, updatedItem.first);
      }
      
      // Clear relevant cache entries
      _clearCacheForQuery('getFoodItems');
      _clearCacheForQuery('searchFoodItems');
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
      
      // Remove from FTS index
      await _removeFTSIndex(txn, itemId);
      
      // Clear relevant cache entries
      _clearCacheForQuery('getFoodItems');
      _clearCacheForQuery('searchFoodItems');
    });
  }

  // Departments operations
  @override
  Future<List<Map<String, dynamic>>> getDepartments(String adminUid) async {
    return await _executeOptimizedQuery(
      queryKey: 'getDepartmentsByAdmin',
      parameters: [adminUid, 'Active'],
      useCache: true,
    );
  }

  /// Get departments with pagination
  Future<List<Map<String, dynamic>>> getDepartmentsPaginated(
    String adminUid, {
    int offset = 0,
    int limit = 20,
    String orderBy = 'name ASC',
  }) async {
    return await _executeOptimizedQuery(
      queryKey: 'getDepartmentsPaginated',
      parameters: [adminUid, 'Active', limit, offset],
      useCache: true,
    );
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getDepartments');
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getDepartments');
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getDepartments');
    });
  }

  // Bills operations
  @override
  Future<List<Map<String, dynamic>>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    if (startDate != null && endDate != null) {
      return await _executeOptimizedQuery(
        queryKey: 'getBillsByAdminAndDateRange',
        parameters: [adminUid, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
        useCache: true,
      );
    } else {
      return await _executeOptimizedQuery(
        queryKey: 'getBillsByAdmin',
        parameters: [adminUid],
        useCache: true,
      );
    }
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
    if (startDate != null && endDate != null) {
      return await _executeOptimizedQuery(
        queryKey: 'getBillsByAdminAndDateRange',
        parameters: [adminUid, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
        useCache: true,
      );
    } else {
      return await _executeOptimizedQuery(
        queryKey: 'getBillsPaginated',
        parameters: [adminUid, limit, offset],
        useCache: true,
      );
    }
  }

  /// Get total count of bills for pagination
  Future<int> getBillsCount(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    if (startDate != null && endDate != null) {
      return await _executeOptimizedCountQuery(
        queryKey: 'getBillsCountByDateRange',
        parameters: [adminUid, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
        useCache: true,
      );
    } else {
      return await _executeOptimizedCountQuery(
        queryKey: 'getBillsCount',
        parameters: [adminUid],
        useCache: true,
      );
    }
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getBills');
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getBills');
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
      
      // Clear relevant cache entries
      _clearCacheForQuery('getBills');
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

  /// Execute multiple operations as a batch transaction for bulk data operations
  Future<void> executeBatchOperations(List<Future<void> Function(Transaction txn)> operations) async {
    await _integrityService.executeBatchTransaction(operations);
  }

  /// Batch insert food items for bulk operations
  Future<void> batchInsertFoodItems(String adminUid, List<Map<String, dynamic>> foodItems) async {
    return await _performanceMonitor.trackQuery('batchInsertFoodItems', () async {
      await _integrityService.executeInTransaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final foodItem in foodItems) {
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
          
          // Update FTS index for search optimization
          await _updateFTSIndex(txn, itemData);
        }
        
        // Clear relevant cache entries
        _clearCacheForQuery('getFoodItems');
        _clearCacheForQuery('searchFoodItems');
      });
    });
  }

  /// Batch update food items for bulk operations
  Future<void> batchUpdateFoodItems(String adminUid, List<Map<String, dynamic>> updates) async {
    return await _performanceMonitor.trackQuery('batchUpdateFoodItems', () async {
      await _integrityService.executeInTransaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final update in updates) {
          final itemId = update['id'];
          if (itemId == null) continue;
          
          final Map<String, dynamic> updateData = {
            ...update,
            'updated_at': now,
            'sync_status': SyncStatus.pending.value,
          };
          updateData.remove('id'); // Remove ID from update data
          
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
          
          // Update FTS index with the updated data
          final updatedItem = await txn.query(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [adminUid, itemId],
            limit: 1,
          );
          if (updatedItem.isNotEmpty) {
            await _updateFTSIndex(txn, updatedItem.first);
          }
        }
        
        // Clear relevant cache entries
        _clearCacheForQuery('getFoodItems');
        _clearCacheForQuery('searchFoodItems');
      });
    });
  }

  /// Batch delete food items for bulk operations
  Future<void> batchDeleteFoodItems(String adminUid, List<String> itemIds) async {
    return await _performanceMonitor.trackQuery('batchDeleteFoodItems', () async {
      await _integrityService.executeInTransaction((txn) async {
        for (final itemId in itemIds) {
          await txn.delete(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [adminUid, itemId],
          );
          
          // Log the operation for sync tracking within the same transaction
          await _logSyncOperationInTransaction(txn, 'food_items', itemId, DatabaseOperation.delete);
          
          // Remove from FTS index
          await _removeFTSIndex(txn, itemId);
        }
        
        // Clear relevant cache entries
        _clearCacheForQuery('getFoodItems');
        _clearCacheForQuery('searchFoodItems');
      });
    });
  }

  /// Batch insert departments for bulk operations
  Future<void> batchInsertDepartments(String adminUid, List<Map<String, dynamic>> departments) async {
    return await _performanceMonitor.trackQuery('batchInsertDepartments', () async {
      await _integrityService.executeInTransaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final department in departments) {
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
        }
        
        // Clear relevant cache entries
        _clearCacheForQuery('getDepartments');
      });
    });
  }

  /// Batch insert bills for bulk operations
  Future<void> batchInsertBills(String adminUid, List<Map<String, dynamic>> bills) async {
    return await _performanceMonitor.trackQuery('batchInsertBills', () async {
      await _integrityService.executeInTransaction((txn) async {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        for (final billData in bills) {
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
        }
        
        // Clear relevant cache entries
        _clearCacheForQuery('getBills');
      });
    });
  }

  /// Update FTS index when food items are modified for optimal search performance
  Future<void> _updateFTSIndex(DatabaseExecutor db, Map<String, dynamic> itemData) async {
    try {
      // Check if FTS table exists before updating
      final ftsExists = await _checkFTSAvailability(db);
      if (!ftsExists) return;
      
      // Update the FTS table with the new/updated item data
      await db.execute('''
        INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
        VALUES (?, ?, ?, ?, ?)
      ''', [
        itemData['id'],
        itemData['name'] ?? '',
        itemData['description'] ?? '',
        itemData['food_code'] ?? '',
        itemData['department'] ?? '',
      ]);
    } catch (e) {
      // FTS update failure shouldn't break the main operation
      print('Failed to update FTS index: $e');
    }
  }

  /// Remove item from FTS index when deleted
  Future<void> _removeFTSIndex(DatabaseExecutor db, String itemId) async {
    try {
      // Check if FTS table exists before removing
      final ftsExists = await _checkFTSAvailability(db);
      if (!ftsExists) return;
      
      await db.execute('DELETE FROM food_items_fts WHERE id = ?', [itemId]);
    } catch (e) {
      // FTS update failure shouldn't break the main operation
      print('Failed to remove from FTS index: $e');
    }
  }

  /// Clear cache for specific query pattern
  void _clearCacheForQuery(String queryKey) {
    final keysToRemove = _queryCache.keys.where((key) => key.startsWith('$queryKey:')).toList();
    for (final key in keysToRemove) {
      _queryCache.remove(key);
    }
  }

  /// Enhanced pagination with cursor-based navigation for better performance
  Future<Map<String, dynamic>> getFoodItemsPaginatedWithCursor(
    String adminUid, {
    String? department,
    String? cursor, // Last item ID from previous page
    int limit = 20,
    String sortBy = 'name',
    String sortOrder = 'ASC',
  }) async {
    return await _performanceMonitor.trackQuery('getFoodItemsPaginatedWithCursor', () async {
      final db = await _sqliteHelper.database;
      
      // Validate sort parameters
      final validSortColumns = ['name', 'price', 'department', 'stocks', 'created_at', 'updated_at'];
      final safeSortBy = validSortColumns.contains(sortBy) ? sortBy : 'name';
      final safeSortOrder = sortOrder.toUpperCase() == 'DESC' ? 'DESC' : 'ASC';
      
      String query = 'SELECT * FROM food_items WHERE admin_uid = ?';
      List<dynamic> args = [adminUid];
      
      if (department != null && department.isNotEmpty) {
        query += ' AND department = ?';
        args.add(department);
      }
      
      // Add cursor condition for pagination
      if (cursor != null && cursor.isNotEmpty) {
        if (safeSortOrder == 'ASC') {
          query += ' AND $safeSortBy > (SELECT $safeSortBy FROM food_items WHERE id = ?)';
        } else {
          query += ' AND $safeSortBy < (SELECT $safeSortBy FROM food_items WHERE id = ?)';
        }
        args.add(cursor);
      }
      
      query += ' ORDER BY $safeSortBy $safeSortOrder LIMIT ?';
      args.add(limit + 1); // Get one extra to check if there's a next page
      
      final results = await db.rawQuery(query, args);
      
      // Check if there's a next page
      final hasNextPage = results.length > limit;
      if (hasNextPage) {
        results.removeLast(); // Remove the extra item
      }
      
      // Get next cursor
      String? nextCursor;
      if (hasNextPage && results.isNotEmpty) {
        nextCursor = results.last['id'] as String;
      }
      
      return {
        'items': results,
        'hasNextPage': hasNextPage,
        'nextCursor': nextCursor,
        'totalCount': await getFoodItemsCount(adminUid, department: department),
      };
    });
  }

  /// Get paginated search results with enhanced performance
  Future<Map<String, dynamic>> searchFoodItemsPaginated(
    String adminUid,
    String searchTerm, {
    String? department,
    int offset = 0,
    int limit = 20,
    bool enableRanking = true,
  }) async {
    return await _performanceMonitor.trackQuery('searchFoodItemsPaginated', () async {
      // Get search results
      final items = await searchFoodItems(
        adminUid,
        searchTerm,
        department: department,
        limit: limit,
        enableRanking: enableRanking,
      );
      
      // Get total count for pagination info
      final totalCount = await _getSearchResultsCount(adminUid, searchTerm, department);
      
      return {
        'items': items,
        'totalCount': totalCount,
        'hasNextPage': (offset + limit) < totalCount,
        'currentPage': (offset / limit).floor() + 1,
        'totalPages': (totalCount / limit).ceil(),
      };
    });
  }

  /// Get total count of search results
  Future<int> _getSearchResultsCount(String adminUid, String searchTerm, String? department) async {
    final db = await _sqliteHelper.database;
    
    // Check if FTS is available first
    final ftsExists = await _checkFTSAvailability(db);
    
    if (ftsExists) {
      try {
        // Try FTS count first
        String ftsQuery = '''
          SELECT COUNT(*) as count FROM food_items f
          INNER JOIN food_items_fts fts ON f.id = fts.id
          WHERE f.admin_uid = ? AND food_items_fts MATCH ?
        ''';
        
        List<dynamic> args = [adminUid, searchTerm];
        
        if (department != null && department.isNotEmpty) {
          ftsQuery += ' AND f.department = ?';
          args.add(department);
        }
        
        final ftsResult = await db.rawQuery(ftsQuery, args);
        return ftsResult.first['count'] as int;
      } catch (e) {
        // Fallback to LIKE search count
        print('FTS count failed, using fallback: $e');
      }
    }
    
    // Fallback to LIKE search count
      final searchPattern = '%$searchTerm%';
      String query = '''
        SELECT COUNT(*) as count FROM food_items 
        WHERE admin_uid = ? AND (
          name LIKE ? OR 
          description LIKE ? OR 
          food_code LIKE ?
        )
      ''';
      
      List<dynamic> args = [adminUid, searchPattern, searchPattern, searchPattern];
      
      if (department != null && department.isNotEmpty) {
        query += ' AND department = ?';
        args.add(department);
      }
      
      final result = await db.rawQuery(query, args);
      return result.first['count'] as int;
    }

  /// Get comprehensive query optimization statistics
  Map<String, dynamic> getQueryOptimizationStatistics() {
    final now = DateTime.now().millisecondsSinceEpoch;
    int expiredCount = 0;
    int validCount = 0;
    int cacheHits = 0;
    int cacheMisses = 0;
    
    for (final entry in _queryCache.values) {
      final cachedAt = entry['cachedAt'] as int;
      final expiryMs = entry['expiryMs'] as int;
      final hits = entry['hits'] as int? ?? 0;
      
      if (now > cachedAt + expiryMs) {
        expiredCount++;
      } else {
        validCount++;
        cacheHits += hits;
      }
    }
    
    // Calculate cache hit rate
    final totalRequests = cacheHits + cacheMisses;
    final cacheHitRate = totalRequests > 0 ? cacheHits / totalRequests : 0.0;
    
    return {
      'cacheStatistics': {
        'totalEntries': _queryCache.length,
        'validEntries': validCount,
        'expiredEntries': expiredCount,
        'maxCacheSize': _maxCacheSize,
        'cacheHitRate': cacheHitRate,
        'cacheHits': cacheHits,
        'cacheMisses': cacheMisses,
      },
      'preparedStatements': _preparedStatements.length,
      'performanceReport': _performanceMonitor.getPerformanceReport(),
      'indexUsage': _getIndexUsageStatistics(),
    };
  }

  /// Get index usage statistics for query optimization
  Future<Map<String, dynamic>> _getIndexUsageStatistics() async {
    try {
      final db = await _sqliteHelper.database;
      
      // Get index usage statistics
      final indexStats = await db.rawQuery('''
        SELECT name, tbl_name FROM sqlite_master 
        WHERE type = 'index' AND tbl_name IN ('food_items', 'departments', 'bills')
        ORDER BY tbl_name, name
      ''');
      
      // Get table statistics
      final tableStats = <String, dynamic>{};
      for (final table in ['food_items', 'departments', 'bills']) {
        final count = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        tableStats[table] = count.first['count'];
      }
      
      return {
        'indexes': indexStats,
        'tableCounts': tableStats,
        'ftsEnabled': await _isFTSEnabled(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Check if FTS is enabled and working
  Future<bool> _isFTSEnabled() async {
    try {
      final db = await _sqliteHelper.database;
      final result = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'table' AND name = 'food_items_fts'
      ''');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear query cache
  void clearQueryCache() {
    _queryCache.clear();
  }

  /// Clear cache for specific query type
  void clearCacheForQueryType(String queryType) {
    _clearCacheForQuery(queryType);
  }

  /// Optimize database performance by running ANALYZE and VACUUM
  Future<void> optimizeDatabasePerformance() async {
    return await _performanceMonitor.trackQuery('optimizeDatabasePerformance', () async {
      final db = await _sqliteHelper.database;
      
      try {
        // Update table statistics for query optimizer
        await db.execute('ANALYZE');
        
        // Rebuild FTS index if it exists
        await _rebuildFTSIndex(db);
        
        print('Database performance optimization completed');
      } catch (e) {
        print('Error during database optimization: $e');
      }
    });
  }

  /// Rebuild FTS index for better search performance
  Future<void> _rebuildFTSIndex(Database db) async {
    try {
      // Check if FTS table exists
      final ftsExists = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'table' AND name = 'food_items_fts'
      ''');
      
      if (ftsExists.isNotEmpty) {
        // Rebuild FTS index
        await db.execute('INSERT INTO food_items_fts(food_items_fts) VALUES("rebuild")');
        print('FTS index rebuilt successfully');
      }
    } catch (e) {
      print('Error rebuilding FTS index: $e');
    }
  }

  /// Get database size and performance metrics
  Future<Map<String, dynamic>> getDatabaseMetrics() async {
    return await _performanceMonitor.trackQuery('getDatabaseMetrics', () async {
      final db = await _sqliteHelper.database;
      
      try {
        // Get database file size
        final dbPath = db.path;
        
        // Get table row counts
        final foodItemsCount = await db.rawQuery('SELECT COUNT(*) as count FROM food_items');
        final departmentsCount = await db.rawQuery('SELECT COUNT(*) as count FROM departments');
        final billsCount = await db.rawQuery('SELECT COUNT(*) as count FROM bills');
        final syncLogCount = await db.rawQuery('SELECT COUNT(*) as count FROM sync_log');
        
        // Get index information
        final indexes = await db.rawQuery('''
          SELECT name, tbl_name FROM sqlite_master 
          WHERE type = 'index' AND tbl_name IN ('food_items', 'departments', 'bills')
        ''');
        
        return {
          'databasePath': dbPath,
          'tableCounts': {
            'food_items': foodItemsCount.first['count'],
            'departments': departmentsCount.first['count'],
            'bills': billsCount.first['count'],
            'sync_log': syncLogCount.first['count'],
          },
          'indexes': indexes,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } catch (e) {
        return {'error': e.toString()};
      }
    });
  }

  /// Check if FTS is available and working
  Future<bool> _checkFTSAvailability(DatabaseExecutor db) async {
    try {
      final result = await db.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'table' AND name = 'food_items_fts'
      ''');
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }





  /// Warm up cache with frequently accessed data
  Future<void> warmUpCache(String adminUid) async {
    return await _performanceMonitor.trackQuery('warmUpCache', () async {
      try {
        // Pre-load frequently accessed data
        await getFoodItems(adminUid);
        await getDepartments(adminUid);
        
        // Pre-load recent bills (last 7 days)
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        await getBills(adminUid, startDate: weekAgo);
        
        print('Cache warmed up successfully');
      } catch (e) {
        print('Error warming up cache: $e');
      }
    });
  }

  /// Get query execution plan for optimization analysis
  Future<List<Map<String, dynamic>>> getQueryExecutionPlan(String query, List<dynamic> args) async {
    try {
      final db = await _sqliteHelper.database;
      final explainQuery = 'EXPLAIN QUERY PLAN $query';
      return await db.rawQuery(explainQuery, args);
    } catch (e) {
      return [{'error': e.toString()}];
    }
  }

  /// Suggest query optimizations based on usage patterns
  Future<List<String>> suggestQueryOptimizations() async {
    final suggestions = <String>[];
    
    try {
      final metrics = await getDatabaseMetrics();
      final cacheStats = metrics['cacheStatistics'] as Map<String, dynamic>;
      
      // Analyze cache hit rate
      final cacheHitRate = cacheStats['cacheHitRate'] as double;
      if (cacheHitRate < 0.5) {
        suggestions.add('Consider increasing cache size or adjusting cache expiry times');
      }
      
      // Analyze table sizes
      final tableCounts = metrics['tableCounts'] as Map<String, dynamic>;
      final foodItemsCount = tableCounts['food_items'] as int;
      
      if (foodItemsCount > 1000) {
        suggestions.add('Consider implementing more aggressive pagination for food items');
      }
      
      if (foodItemsCount > 5000 && !await _isFTSEnabled()) {
        suggestions.add('Enable Full-Text Search (FTS) for better search performance with large datasets');
      }
      
      // Check for missing indexes
      final performanceReport = _performanceMonitor.getPerformanceReport();
      if (performanceReport['slowQueries'] != null) {
        suggestions.add('Review slow queries and consider adding appropriate indexes');
      }
      
      return suggestions;
    } catch (e) {
      return ['Error analyzing query patterns: $e'];
    }
  }


}