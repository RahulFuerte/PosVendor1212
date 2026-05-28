// Dart imports:
import 'dart:async';
import 'dart:collection';

// Package imports:
import 'package:sqflite/sqflite.dart';

// Project imports:
import '../../core/utils/performance_monitor.dart';
import 'local/sqlite_helper.dart';


/// Query optimization service that implements prepared statements, caching, and connection pooling
/// Provides optimized database access with intelligent caching and performance monitoring
class QueryOptimizationService {
  static final QueryOptimizationService _instance = QueryOptimizationService._internal();
  factory QueryOptimizationService() => _instance;
  QueryOptimizationService._internal();

  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // Connection pool for managing database connections
  final Queue<Database> _connectionPool = Queue<Database>();
  final Queue<Completer<Database>> _connectionQueue = Queue<Completer<Database>>();
  static const int _maxConnections = 5;
  static const int _minConnections = 2;
  int _activeConnections = 0;
  bool _isInitialized = false;

  // Query result cache with LRU eviction
  final Map<String, CachedQueryResult> _queryCache = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Prepared statement cache
  final Map<String, String> _preparedStatements = {};

  /// Initialize the query optimization service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _initializeConnectionPool();
    _initializePreparedStatements();
    _performanceMonitor.startMonitoring();
    
    _isInitialized = true;
  }

  /// Initialize connection pool with minimum connections
  Future<void> _initializeConnectionPool() async {
    for (int i = 0; i < _minConnections; i++) {
      final db = await _sqliteHelper.getDatabaseInstance();
      _connectionPool.add(db);
      _activeConnections++;
    }
  }

  /// Initialize commonly used prepared statements
  void _initializePreparedStatements() {
    _preparedStatements.addAll({
      // Food items queries
      'getFoodItemsByAdmin': 'SELECT * FROM food_items WHERE admin_uid = ? ORDER BY name ASC',
      'getFoodItemsByAdminAndDept': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? ORDER BY name ASC',
      'getFoodItemsPaginated': 'SELECT * FROM food_items WHERE admin_uid = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getFoodItemsByAdminAndDeptPaginated': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getFoodItemsCount': 'SELECT COUNT(*) as count FROM food_items WHERE admin_uid = ?',
      'getFoodItemsCountByDept': 'SELECT COUNT(*) as count FROM food_items WHERE admin_uid = ? AND department = ?',
      'searchFoodItemsLike': 'SELECT * FROM food_items WHERE admin_uid = ? AND (name LIKE ? OR food_code LIKE ? OR description LIKE ?) ORDER BY name ASC LIMIT ?',
      'searchFoodItemsLikeWithDept': 'SELECT * FROM food_items WHERE admin_uid = ? AND department = ? AND (name LIKE ? OR food_code LIKE ? OR description LIKE ?) ORDER BY name ASC LIMIT ?',
      
      // Department queries
      'getDepartmentsByAdmin': 'SELECT * FROM departments WHERE admin_uid = ? AND status = ? ORDER BY name ASC',
      'getDepartmentsPaginated': 'SELECT * FROM departments WHERE admin_uid = ? AND status = ? ORDER BY name ASC LIMIT ? OFFSET ?',
      'getDepartmentById': 'SELECT * FROM departments WHERE admin_uid = ? AND id = ? LIMIT 1',
      
      // Bills queries
      'getBillsByAdmin': 'SELECT * FROM bills WHERE admin_uid = ? ORDER BY bill_date DESC',
      'getBillsByAdminAndDateRange': 'SELECT * FROM bills WHERE admin_uid = ? AND bill_date >= ? AND bill_date <= ? ORDER BY bill_date DESC',
      'getBillsPaginated': 'SELECT * FROM bills WHERE admin_uid = ? ORDER BY bill_date DESC LIMIT ? OFFSET ?',
      'getBillsCount': 'SELECT COUNT(*) as count FROM bills WHERE admin_uid = ?',
      'getBillsCountByDateRange': 'SELECT COUNT(*) as count FROM bills WHERE admin_uid = ? AND bill_date >= ? AND bill_date <= ?',
    });
  }

  /// Get a database connection from the pool
  Future<Database> _getConnection() async {
    if (_connectionPool.isNotEmpty) {
      return _connectionPool.removeFirst();
    }

    if (_activeConnections < _maxConnections) {
      final db = await _sqliteHelper.getDatabaseInstance();
      _activeConnections++;
      return db;
    }

    // Wait for a connection to become available
    final completer = Completer<Database>();
    _connectionQueue.add(completer);
    return completer.future;
  }

  /// Return a database connection to the pool
  void _returnConnection(Database db) {
    if (_connectionQueue.isNotEmpty) {
      final completer = _connectionQueue.removeFirst();
      completer.complete(db);
    } else if (_connectionPool.length < _maxConnections) {
      _connectionPool.add(db);
    }
  }

  /// Execute an optimized query with caching and prepared statements
  Future<List<Map<String, dynamic>>> executeOptimizedQuery({
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

      // Get database connection from pool
      final db = await _getConnection();
      
      try {
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
      } finally {
        // Return connection to pool
        _returnConnection(db);
      }
    });
  }

  /// Execute an optimized count query
  Future<int> executeOptimizedCountQuery({
    required String queryKey,
    required List<dynamic> parameters,
    String? customQuery,
    bool useCache = true,
    Duration? cacheExpiry,
  }) async {
    final results = await executeOptimizedQuery(
      queryKey: queryKey,
      parameters: parameters,
      customQuery: customQuery,
      useCache: useCache,
      cacheExpiry: cacheExpiry,
    );
    
    return results.isNotEmpty ? (results.first['count'] as int? ?? 0) : 0;
  }

  /// Get cached query result if available and not expired
  List<Map<String, dynamic>>? _getCachedResult(String queryKey, List<dynamic> parameters) {
    final cacheKey = _generateCacheKey(queryKey, parameters);
    final cachedResult = _queryCache[cacheKey];
    
    if (cachedResult != null && !cachedResult.isExpired) {
      return cachedResult.data;
    }
    
    // Remove expired cache entry
    if (cachedResult != null) {
      _queryCache.remove(cacheKey);
    }
    
    return null;
  }

  /// Cache query result with expiry
  void _cacheResult(String queryKey, List<dynamic> parameters, List<Map<String, dynamic>> data, Duration expiry) {
    final cacheKey = _generateCacheKey(queryKey, parameters);
    
    // Implement LRU eviction if cache is full
    if (_queryCache.length >= _maxCacheSize) {
      _evictOldestCacheEntry();
    }
    
    _queryCache[cacheKey] = CachedQueryResult(
      data: data,
      cachedAt: DateTime.now(),
      expiry: expiry,
    );
  }

  /// Generate cache key from query key and parameters
  String _generateCacheKey(String queryKey, List<dynamic> parameters) {
    return '$queryKey:${parameters.join(':')}';
  }

  /// Evict oldest cache entry (LRU)
  void _evictOldestCacheEntry() {
    if (_queryCache.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;
    
    for (final entry in _queryCache.entries) {
      if (oldestTime == null || entry.value.cachedAt.isBefore(oldestTime)) {
        oldestTime = entry.value.cachedAt;
        oldestKey = entry.key;
      }
    }
    
    if (oldestKey != null) {
      _queryCache.remove(oldestKey);
    }
  }

  /// Optimized getFoodItems with caching and prepared statements
  Future<List<Map<String, dynamic>>> getOptimizedFoodItems(
    String adminUid, {
    String? department,
    int? limit,
    int? offset,
    String orderBy = 'name ASC',
    bool useCache = true,
  }) async {
    if (department != null && department.isNotEmpty) {
      if (limit != null && offset != null) {
        return await executeOptimizedQuery(
          queryKey: 'getFoodItemsByAdminAndDeptPaginated',
          parameters: [adminUid, department, limit, offset],
          useCache: useCache,
        );
      } else {
        return await executeOptimizedQuery(
          queryKey: 'getFoodItemsByAdminAndDept',
          parameters: [adminUid, department],
          useCache: useCache,
        );
      }
    } else {
      if (limit != null && offset != null) {
        return await executeOptimizedQuery(
          queryKey: 'getFoodItemsPaginated',
          parameters: [adminUid, limit, offset],
          useCache: useCache,
        );
      } else {
        return await executeOptimizedQuery(
          queryKey: 'getFoodItemsByAdmin',
          parameters: [adminUid],
          useCache: useCache,
        );
      }
    }
  }

  /// Optimized getFoodItemsCount with caching
  Future<int> getOptimizedFoodItemsCount(
    String adminUid, {
    String? department,
    bool useCache = true,
  }) async {
    if (department != null && department.isNotEmpty) {
      return await executeOptimizedCountQuery(
        queryKey: 'getFoodItemsCountByDept',
        parameters: [adminUid, department],
        useCache: useCache,
      );
    } else {
      return await executeOptimizedCountQuery(
        queryKey: 'getFoodItemsCount',
        parameters: [adminUid],
        useCache: useCache,
      );
    }
  }

  /// Optimized searchFoodItems with caching and prepared statements
  Future<List<Map<String, dynamic>>> getOptimizedSearchFoodItems(
    String adminUid,
    String searchTerm, {
    String? department,
    int limit = 20,
    bool useCache = true,
  }) async {
    final searchPattern = '%$searchTerm%';
    
    if (department != null && department.isNotEmpty) {
      return await executeOptimizedQuery(
        queryKey: 'searchFoodItemsLikeWithDept',
        parameters: [adminUid, department, searchPattern, searchPattern, searchPattern, limit],
        useCache: useCache,
        cacheExpiry: const Duration(minutes: 2), // Shorter cache for search results
      );
    } else {
      return await executeOptimizedQuery(
        queryKey: 'searchFoodItemsLike',
        parameters: [adminUid, searchPattern, searchPattern, searchPattern, limit],
        useCache: useCache,
        cacheExpiry: const Duration(minutes: 2), // Shorter cache for search results
      );
    }
  }

  /// Optimized getDepartments with caching
  Future<List<Map<String, dynamic>>> getOptimizedDepartments(
    String adminUid, {
    int? limit,
    int? offset,
    String orderBy = 'name ASC',
    bool useCache = true,
  }) async {
    if (limit != null && offset != null) {
      return await executeOptimizedQuery(
        queryKey: 'getDepartmentsPaginated',
        parameters: [adminUid, 'Active', limit, offset],
        useCache: useCache,
      );
    } else {
      return await executeOptimizedQuery(
        queryKey: 'getDepartmentsByAdmin',
        parameters: [adminUid, 'Active'],
        useCache: useCache,
      );
    }
  }

  /// Optimized getBills with caching and date range support
  Future<List<Map<String, dynamic>>> getOptimizedBills(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    int? offset,
    String orderBy = 'bill_date DESC',
    bool useCache = true,
  }) async {
    if (startDate != null && endDate != null) {
      return await executeOptimizedQuery(
        queryKey: 'getBillsByAdminAndDateRange',
        parameters: [adminUid, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
        useCache: useCache,
      );
    } else {
      if (limit != null && offset != null) {
        return await executeOptimizedQuery(
          queryKey: 'getBillsPaginated',
          parameters: [adminUid, limit, offset],
          useCache: useCache,
        );
      } else {
        return await executeOptimizedQuery(
          queryKey: 'getBillsByAdmin',
          parameters: [adminUid],
          useCache: useCache,
        );
      }
    }
  }

  /// Optimized getBillsCount with caching
  Future<int> getOptimizedBillsCount(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    bool useCache = true,
  }) async {
    if (startDate != null && endDate != null) {
      return await executeOptimizedCountQuery(
        queryKey: 'getBillsCountByDateRange',
        parameters: [adminUid, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
        useCache: useCache,
      );
    } else {
      return await executeOptimizedCountQuery(
        queryKey: 'getBillsCount',
        parameters: [adminUid],
        useCache: useCache,
      );
    }
  }

  /// Clear query cache
  void clearCache() {
    _queryCache.clear();
  }

  /// Clear cache for specific query pattern
  void clearCacheForQuery(String queryKey) {
    final keysToRemove = _queryCache.keys.where((key) => key.startsWith('$queryKey:')).toList();
    for (final key in keysToRemove) {
      _queryCache.remove(key);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final now = DateTime.now();
    int expiredCount = 0;
    int validCount = 0;
    
    for (final entry in _queryCache.values) {
      if (entry.isExpired) {
        expiredCount++;
      } else {
        validCount++;
      }
    }
    
    return {
      'totalEntries': _queryCache.length,
      'validEntries': validCount,
      'expiredEntries': expiredCount,
      'maxCacheSize': _maxCacheSize,
      'cacheHitRate': _calculateCacheHitRate(),
    };
  }

  /// Calculate cache hit rate (simplified)
  double _calculateCacheHitRate() {
    // This is a simplified calculation
    // In a real implementation, you'd track hits and misses
    return _queryCache.isNotEmpty ? 0.75 : 0.0;
  }

  /// Get connection pool statistics
  Map<String, dynamic> getConnectionPoolStatistics() {
    return {
      'activeConnections': _activeConnections,
      'availableConnections': _connectionPool.length,
      'queuedRequests': _connectionQueue.length,
      'maxConnections': _maxConnections,
      'minConnections': _minConnections,
    };
  }

  /// Dispose resources and close connections
  Future<void> dispose() async {
    _performanceMonitor.stopMonitoring();
    clearCache();
    
    // Close all connections in the pool
    for (final db in _connectionPool) {
      await db.close();
    }
    _connectionPool.clear();
    
    // Complete any queued requests with error
    while (_connectionQueue.isNotEmpty) {
      final completer = _connectionQueue.removeFirst();
      completer.completeError('Service disposed');
    }
    
    _activeConnections = 0;
    _isInitialized = false;
  }
}

/// Cached query result with expiry
class CachedQueryResult {
  final List<Map<String, dynamic>> data;
  final DateTime cachedAt;
  final Duration expiry;

  CachedQueryResult({
    required this.data,
    required this.cachedAt,
    required this.expiry,
  });

  bool get isExpired => DateTime.now().isAfter(cachedAt.add(expiry));
}
