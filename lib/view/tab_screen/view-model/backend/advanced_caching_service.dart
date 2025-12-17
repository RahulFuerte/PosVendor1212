import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'sqlite_helper.dart';
import 'performance_monitor.dart';
import 'image_cache_service.dart';
import 'lazy_loading_service.dart';

/// Advanced multi-level caching service with intelligent cache warming,
/// invalidation policies, and comprehensive performance monitoring
class AdvancedCachingService {
  static final AdvancedCachingService _instance = AdvancedCachingService._internal();
  factory AdvancedCachingService() => _instance;
  AdvancedCachingService._internal();

  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();

  // Memory cache (L1) - fastest access
  final Map<String, CacheEntry> _memoryCache = {};
  
  // Disk cache (L2) - persistent storage
  Database? _diskCacheDb;
  
  // SharedPreferences cache (L3) - for small key-value pairs
  SharedPreferences? _prefsCache;

  // Cache configuration
  static const int _memoryCacheMaxSize = 50 * 1024 * 1024; // 50MB
  static const int _diskCacheMaxSize = 200 * 1024 * 1024; // 200MB
  static const Duration _defaultTtl = Duration(hours: 1);
  static const Duration _criticalDataTtl = Duration(days: 7);
  static const Duration _temporaryDataTtl = Duration(minutes: 15);

  // Cache warming configuration
  final Map<String, CacheWarmingStrategy> _warmingStrategies = {};
  Timer? _warmingTimer;
  
  // Performance monitoring
  final Map<String, CachePerformanceMetrics> _performanceMetrics = {};
  
  // Cache invalidation policies
  final Map<String, CacheInvalidationPolicy> _invalidationPolicies = {};

  /// Initialize the advanced caching service
  Future<void> initialize() async {
    await _performanceMonitor.trackQuery('advanced_cache_init', () async {
      try {
        // Initialize SharedPreferences cache
        _prefsCache = await SharedPreferences.getInstance();
        
        // Initialize disk cache database
        await _initializeDiskCache();
        
        // Set up default cache warming strategies
        _setupDefaultWarmingStrategies();
        
        // Set up default invalidation policies
        _setupDefaultInvalidationPolicies();
        
        // Start cache warming timer
        _startCacheWarming();
        
        // Perform initial cleanup
        await _performInitialCleanup();
        
        developer.log('Advanced caching service initialized', name: 'AdvancedCachingService');
      } catch (e) {
        developer.log('Error initializing advanced caching service: $e', name: 'AdvancedCachingService');
        rethrow;
      }
    });
  }

  /// Store data in multi-level cache with intelligent placement
  Future<void> store(
    String key, 
    dynamic data, {
    Duration? ttl,
    CachePriority priority = CachePriority.normal,
    List<String> tags = const [],
  }) async {
    await _performanceMonitor.trackQuery('advanced_cache_store', () async {
      try {
        final effectiveTtl = ttl ?? _getTtlForPriority(priority);
        final entry = CacheEntry(
          key: key,
          data: data,
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(effectiveTtl),
          priority: priority,
          tags: tags,
          accessCount: 0,
          lastAccessed: DateTime.now(),
        );

        // Store in appropriate cache levels based on priority and size
        await _storeInAppropriateLevel(entry);
        
        // Update performance metrics
        _updateStoreMetrics(key, data);
        
        developer.log('Stored $key in advanced cache with priority ${priority.name}', 
                     name: 'AdvancedCachingService');
      } catch (e) {
        developer.log('Error storing in advanced cache: $e', name: 'AdvancedCachingService');
        rethrow;
      }
    });
  }

  /// Retrieve data from multi-level cache with intelligent promotion
  Future<T?> retrieve<T>(String key) async {
    return await _performanceMonitor.trackQuery('advanced_cache_retrieve', () async {
      try {
        CacheEntry? entry;
        CacheLevel foundLevel = CacheLevel.none;

        // Check L1 (Memory) first
        if (_memoryCache.containsKey(key)) {
          entry = _memoryCache[key];
          foundLevel = CacheLevel.memory;
        }
        
        // Check L2 (Disk) if not in memory
        if (entry == null) {
          entry = await _retrieveFromDiskCache(key);
          if (entry != null) {
            foundLevel = CacheLevel.disk;
          }
        }
        
        // Check L3 (SharedPreferences) if not in disk
        if (entry == null) {
          entry = await _retrieveFromPrefsCache(key);
          if (entry != null) {
            foundLevel = CacheLevel.preferences;
          }
        }

        if (entry == null || entry.isExpired) {
          _updateRetrieveMetrics(key, false, CacheLevel.none);
          return null;
        }

        // Update access statistics
        entry.accessCount++;
        entry.lastAccessed = DateTime.now();

        // Promote frequently accessed data to higher cache levels
        await _promoteIfNeeded(entry, foundLevel);

        // Update performance metrics
        _updateRetrieveMetrics(key, true, foundLevel);

        developer.log('Retrieved $key from ${foundLevel.name} cache', 
                     name: 'AdvancedCachingService');

        return entry.data as T?;
      } catch (e) {
        developer.log('Error retrieving from advanced cache: $e', name: 'AdvancedCachingService');
        _updateRetrieveMetrics(key, false, CacheLevel.none);
        return null;
      }
    });
  }

  /// Invalidate cache entries by key or tags
  Future<void> invalidate({
    String? key,
    List<String> tags = const [],
    bool invalidateAll = false,
  }) async {
    await _performanceMonitor.trackQuery('advanced_cache_invalidate', () async {
      try {
        if (invalidateAll) {
          await _invalidateAll();
        } else if (key != null) {
          await _invalidateByKey(key);
        } else if (tags.isNotEmpty) {
          await _invalidateByTags(tags);
        }

        developer.log('Cache invalidation completed', name: 'AdvancedCachingService');
      } catch (e) {
        developer.log('Error during cache invalidation: $e', name: 'AdvancedCachingService');
        rethrow;
      }
    });
  }

  /// Warm cache with critical data based on configured strategies
  Future<void> warmCache({List<String> strategies = const []}) async {
    await _performanceMonitor.trackQuery('advanced_cache_warm', () async {
      try {
        final strategiesToExecute = strategies.isEmpty 
            ? _warmingStrategies.keys.toList()
            : strategies;

        for (final strategyName in strategiesToExecute) {
          final strategy = _warmingStrategies[strategyName];
          if (strategy != null) {
            await _executeWarmingStrategy(strategy);
          }
        }

        developer.log('Cache warming completed for ${strategiesToExecute.length} strategies', 
                     name: 'AdvancedCachingService');
      } catch (e) {
        developer.log('Error during cache warming: $e', name: 'AdvancedCachingService');
        rethrow;
      }
    });
  }

  /// Get comprehensive cache performance analytics
  Future<Map<String, dynamic>> getPerformanceAnalytics() async {
    return await _performanceMonitor.trackQuery('advanced_cache_analytics', () async {
      try {
        final memoryStats = _getMemoryCacheStats();
        final diskStats = await _getDiskCacheStats();
        final prefsStats = await _getPrefsCacheStats();
        final overallMetrics = _calculateOverallMetrics();

        return {
          'timestamp': DateTime.now().toIso8601String(),
          'memoryCacheStats': memoryStats,
          'diskCacheStats': diskStats,
          'preferencesCacheStats': prefsStats,
          'overallMetrics': overallMetrics,
          'performanceMetrics': _getPerformanceMetricsSnapshot(),
          'warmingStrategies': _getWarmingStrategiesStatus(),
          'invalidationPolicies': _getInvalidationPoliciesStatus(),
        };
      } catch (e) {
        developer.log('Error getting performance analytics: $e', name: 'AdvancedCachingService');
        return {'error': e.toString()};
      }
    });
  }

  /// Register a cache warming strategy
  void registerWarmingStrategy(String name, CacheWarmingStrategy strategy) {
    _warmingStrategies[name] = strategy;
    developer.log('Registered cache warming strategy: $name', name: 'AdvancedCachingService');
  }

  /// Register a cache invalidation policy
  void registerInvalidationPolicy(String name, CacheInvalidationPolicy policy) {
    _invalidationPolicies[name] = policy;
    developer.log('Registered cache invalidation policy: $name', name: 'AdvancedCachingService');
  }

  /// Perform cache maintenance and optimization
  Future<void> performMaintenance() async {
    await _performanceMonitor.trackQuery('advanced_cache_maintenance', () async {
      try {
        // Clean expired entries
        await _cleanExpiredEntries();
        
        // Optimize cache levels
        await _optimizeCacheLevels();
        
        // Execute invalidation policies
        await _executeInvalidationPolicies();
        
        // Compact disk cache
        await _compactDiskCache();
        
        // Update performance metrics
        _updateMaintenanceMetrics();

        developer.log('Cache maintenance completed', name: 'AdvancedCachingService');
      } catch (e) {
        developer.log('Error during cache maintenance: $e', name: 'AdvancedCachingService');
        rethrow;
      }
    });
  }

  /// Initialize disk cache database
  Future<void> _initializeDiskCache() async {
    final dbPath = 'advanced_cache.db';
    _diskCacheDb = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache_entries (
            key TEXT PRIMARY KEY,
            data BLOB,
            created_at INTEGER,
            expires_at INTEGER,
            priority INTEGER,
            tags TEXT,
            access_count INTEGER,
            last_accessed INTEGER,
            data_size INTEGER
          )
        ''');
        
        await db.execute('CREATE INDEX idx_expires_at ON cache_entries(expires_at)');
        await db.execute('CREATE INDEX idx_priority ON cache_entries(priority)');
        await db.execute('CREATE INDEX idx_last_accessed ON cache_entries(last_accessed)');
      },
    );
  }

  /// Store entry in appropriate cache level based on size and priority
  Future<void> _storeInAppropriateLevel(CacheEntry entry) async {
    final dataSize = _calculateDataSize(entry.data);
    entry.dataSize = dataSize;

    // Always try to store in memory for high priority or small data
    if (entry.priority == CachePriority.critical || 
        entry.priority == CachePriority.high ||
        dataSize < 1024 * 1024) { // Less than 1MB
      
      // Check if memory cache has space
      if (_getMemoryCacheSize() + dataSize <= _memoryCacheMaxSize) {
        _memoryCache[entry.key] = entry;
      } else {
        // Evict least recently used entries to make space
        await _evictFromMemoryCache(dataSize);
        _memoryCache[entry.key] = entry;
      }
    }

    // Store in disk cache for persistence
    if (entry.priority != CachePriority.temporary) {
      await _storeToDiskCache(entry);
    }

    // Store small key-value pairs in SharedPreferences
    if (dataSize < 1024 && entry.data is String) { // Less than 1KB and string data
      await _storeToPrefsCache(entry);
    }
  }

  /// Retrieve entry from disk cache
  Future<CacheEntry?> _retrieveFromDiskCache(String key) async {
    if (_diskCacheDb == null) return null;

    try {
      final result = await _diskCacheDb!.query(
        'cache_entries',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final row = result.first;
      final data = _deserializeData(row['data'] as Uint8List);
      
      return CacheEntry(
        key: key,
        data: data,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(row['expires_at'] as int),
        priority: CachePriority.values[row['priority'] as int],
        tags: (row['tags'] as String).split(',').where((tag) => tag.isNotEmpty).toList(),
        accessCount: row['access_count'] as int,
        lastAccessed: DateTime.fromMillisecondsSinceEpoch(row['last_accessed'] as int),
        dataSize: row['data_size'] as int,
      );
    } catch (e) {
      developer.log('Error retrieving from disk cache: $e', name: 'AdvancedCachingService');
      return null;
    }
  }

  /// Store entry to disk cache
  Future<void> _storeToDiskCache(CacheEntry entry) async {
    if (_diskCacheDb == null) return;

    try {
      final serializedData = _serializeData(entry.data);
      
      await _diskCacheDb!.insert(
        'cache_entries',
        {
          'key': entry.key,
          'data': serializedData,
          'created_at': entry.createdAt.millisecondsSinceEpoch,
          'expires_at': entry.expiresAt.millisecondsSinceEpoch,
          'priority': entry.priority.index,
          'tags': entry.tags.join(','),
          'access_count': entry.accessCount,
          'last_accessed': entry.lastAccessed.millisecondsSinceEpoch,
          'data_size': entry.dataSize,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      developer.log('Error storing to disk cache: $e', name: 'AdvancedCachingService');
    }
  }

  /// Retrieve entry from SharedPreferences cache
  Future<CacheEntry?> _retrieveFromPrefsCache(String key) async {
    if (_prefsCache == null) return null;

    try {
      final entryJson = _prefsCache!.getString('cache_$key');
      if (entryJson == null) return null;

      final entryMap = jsonDecode(entryJson) as Map<String, dynamic>;
      
      return CacheEntry(
        key: key,
        data: entryMap['data'],
        createdAt: DateTime.fromMillisecondsSinceEpoch(entryMap['created_at'] as int),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(entryMap['expires_at'] as int),
        priority: CachePriority.values[entryMap['priority'] as int],
        tags: (entryMap['tags'] as List).cast<String>(),
        accessCount: entryMap['access_count'] as int,
        lastAccessed: DateTime.fromMillisecondsSinceEpoch(entryMap['last_accessed'] as int),
        dataSize: entryMap['data_size'] as int,
      );
    } catch (e) {
      developer.log('Error retrieving from prefs cache: $e', name: 'AdvancedCachingService');
      return null;
    }
  }

  /// Store entry to SharedPreferences cache
  Future<void> _storeToPrefsCache(CacheEntry entry) async {
    if (_prefsCache == null) return;

    try {
      final entryMap = {
        'data': entry.data,
        'created_at': entry.createdAt.millisecondsSinceEpoch,
        'expires_at': entry.expiresAt.millisecondsSinceEpoch,
        'priority': entry.priority.index,
        'tags': entry.tags,
        'access_count': entry.accessCount,
        'last_accessed': entry.lastAccessed.millisecondsSinceEpoch,
        'data_size': entry.dataSize,
      };

      await _prefsCache!.setString('cache_${entry.key}', jsonEncode(entryMap));
    } catch (e) {
      developer.log('Error storing to prefs cache: $e', name: 'AdvancedCachingService');
    }
  }

  /// Promote frequently accessed data to higher cache levels
  Future<void> _promoteIfNeeded(CacheEntry entry, CacheLevel currentLevel) async {
    // Promote to memory cache if accessed frequently and not already there
    if (currentLevel != CacheLevel.memory && 
        entry.accessCount > 5 && 
        entry.dataSize < 5 * 1024 * 1024) { // Less than 5MB
      
      if (_getMemoryCacheSize() + entry.dataSize <= _memoryCacheMaxSize) {
        _memoryCache[entry.key] = entry;
      }
    }
  }

  /// Setup default cache warming strategies
  void _setupDefaultWarmingStrategies() {
    // Critical data warming strategy
    registerWarmingStrategy('critical_data', CacheWarmingStrategy(
      name: 'critical_data',
      priority: CachePriority.critical,
      interval: const Duration(hours: 6),
      dataFetcher: () async {
        // This would be implemented to fetch critical data like user preferences,
        // frequently accessed food items, etc.
        return <String, dynamic>{
          'user_preferences': 'mock_data',
          'popular_items': 'mock_data',
        };
      },
    ));

    // Predictive warming strategy
    registerWarmingStrategy('predictive', CacheWarmingStrategy(
      name: 'predictive',
      priority: CachePriority.high,
      interval: const Duration(hours: 2),
      dataFetcher: () async {
        // This would analyze user patterns and preload likely needed data
        return <String, dynamic>{
          'predicted_items': 'mock_data',
        };
      },
    ));
  }

  /// Setup default invalidation policies
  void _setupDefaultInvalidationPolicies() {
    // Time-based invalidation
    registerInvalidationPolicy('time_based', CacheInvalidationPolicy(
      name: 'time_based',
      condition: (entry) => entry.isExpired,
      action: CacheInvalidationAction.remove,
    ));

    // Size-based invalidation
    registerInvalidationPolicy('size_based', CacheInvalidationPolicy(
      name: 'size_based',
      condition: (entry) => _getMemoryCacheSize() > _memoryCacheMaxSize * 0.9,
      action: CacheInvalidationAction.evictLru,
    ));

    // Access-based invalidation
    registerInvalidationPolicy('access_based', CacheInvalidationPolicy(
      name: 'access_based',
      condition: (entry) => entry.accessCount == 0 && 
          DateTime.now().difference(entry.createdAt).inDays > 7,
      action: CacheInvalidationAction.remove,
    ));
  }

  /// Start cache warming timer
  void _startCacheWarming() {
    _warmingTimer = Timer.periodic(const Duration(hours: 1), (timer) async {
      try {
        await warmCache();
      } catch (e) {
        developer.log('Error during scheduled cache warming: $e', name: 'AdvancedCachingService');
      }
    });
  }

  /// Execute a cache warming strategy
  Future<void> _executeWarmingStrategy(CacheWarmingStrategy strategy) async {
    try {
      final data = await strategy.dataFetcher();
      
      for (final entry in data.entries) {
        await store(
          entry.key,
          entry.value,
          priority: strategy.priority,
          ttl: _getTtlForPriority(strategy.priority),
        );
      }

      strategy.lastExecuted = DateTime.now();
      developer.log('Executed warming strategy: ${strategy.name}', name: 'AdvancedCachingService');
    } catch (e) {
      developer.log('Error executing warming strategy ${strategy.name}: $e', name: 'AdvancedCachingService');
    }
  }

  /// Get TTL based on cache priority
  Duration _getTtlForPriority(CachePriority priority) {
    switch (priority) {
      case CachePriority.critical:
        return _criticalDataTtl;
      case CachePriority.high:
        return _defaultTtl;
      case CachePriority.normal:
        return _defaultTtl;
      case CachePriority.low:
        return const Duration(minutes: 30);
      case CachePriority.temporary:
        return _temporaryDataTtl;
    }
  }

  /// Calculate data size in bytes
  int _calculateDataSize(dynamic data) {
    if (data is String) {
      return utf8.encode(data).length;
    } else if (data is Uint8List) {
      return data.length;
    } else if (data is List || data is Map) {
      return utf8.encode(jsonEncode(data)).length;
    } else {
      return utf8.encode(data.toString()).length;
    }
  }

  /// Get current memory cache size
  int _getMemoryCacheSize() {
    return _memoryCache.values.fold(0, (sum, entry) => sum + entry.dataSize);
  }

  /// Serialize data for disk storage
  Uint8List _serializeData(dynamic data) {
    if (data is Uint8List) {
      return data;
    } else {
      return Uint8List.fromList(utf8.encode(jsonEncode(data)));
    }
  }

  /// Deserialize data from disk storage
  dynamic _deserializeData(Uint8List data) {
    try {
      final jsonString = utf8.decode(data);
      return jsonDecode(jsonString);
    } catch (e) {
      // If JSON decode fails, return as raw bytes
      return data;
    }
  }

  /// Evict entries from memory cache to make space
  Future<void> _evictFromMemoryCache(int spaceNeeded) async {
    final entries = _memoryCache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    int freedSpace = 0;
    final keysToRemove = <String>[];

    for (final entry in entries) {
      if (freedSpace >= spaceNeeded) break;
      
      keysToRemove.add(entry.key);
      freedSpace += entry.dataSize;
    }

    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    developer.log('Evicted ${keysToRemove.length} entries from memory cache', 
                 name: 'AdvancedCachingService');
  }

  /// Invalidate all cache entries
  Future<void> _invalidateAll() async {
    _memoryCache.clear();
    
    if (_diskCacheDb != null) {
      await _diskCacheDb!.delete('cache_entries');
    }
    
    if (_prefsCache != null) {
      final keys = _prefsCache!.getKeys().where((key) => key.startsWith('cache_'));
      for (final key in keys) {
        await _prefsCache!.remove(key);
      }
    }
  }

  /// Invalidate cache entry by key
  Future<void> _invalidateByKey(String key) async {
    _memoryCache.remove(key);
    
    if (_diskCacheDb != null) {
      await _diskCacheDb!.delete('cache_entries', where: 'key = ?', whereArgs: [key]);
    }
    
    if (_prefsCache != null) {
      await _prefsCache!.remove('cache_$key');
    }
  }

  /// Invalidate cache entries by tags
  Future<void> _invalidateByTags(List<String> tags) async {
    // Memory cache
    final keysToRemove = <String>[];
    for (final entry in _memoryCache.entries) {
      if (entry.value.tags.any((tag) => tags.contains(tag))) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }

    // Disk cache
    if (_diskCacheDb != null) {
      for (final tag in tags) {
        await _diskCacheDb!.delete(
          'cache_entries',
          where: 'tags LIKE ?',
          whereArgs: ['%$tag%'],
        );
      }
    }
  }

  /// Clean expired entries from all cache levels
  Future<void> _cleanExpiredEntries() async {
    final now = DateTime.now();

    // Memory cache
    final expiredKeys = _memoryCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
    }

    // Disk cache
    if (_diskCacheDb != null) {
      await _diskCacheDb!.delete(
        'cache_entries',
        where: 'expires_at < ?',
        whereArgs: [now.millisecondsSinceEpoch],
      );
    }

    developer.log('Cleaned ${expiredKeys.length} expired entries', name: 'AdvancedCachingService');
  }

  /// Execute invalidation policies
  Future<void> _executeInvalidationPolicies() async {
    for (final policy in _invalidationPolicies.values) {
      await _executeInvalidationPolicy(policy);
    }
  }

  /// Execute a specific invalidation policy
  Future<void> _executeInvalidationPolicy(CacheInvalidationPolicy policy) async {
    try {
      final entriesToProcess = <CacheEntry>[];
      
      // Check memory cache entries
      for (final entry in _memoryCache.values) {
        if (policy.condition(entry)) {
          entriesToProcess.add(entry);
        }
      }

      // Execute action based on policy
      switch (policy.action) {
        case CacheInvalidationAction.remove:
          for (final entry in entriesToProcess) {
            await _invalidateByKey(entry.key);
          }
          break;
        case CacheInvalidationAction.evictLru:
          await _evictLeastRecentlyUsed(entriesToProcess.length);
          break;
        case CacheInvalidationAction.refresh:
          // This would trigger a refresh of the data
          // Implementation depends on specific requirements
          break;
      }

      policy.lastExecuted = DateTime.now();
    } catch (e) {
      developer.log('Error executing invalidation policy ${policy.name}: $e', 
                   name: 'AdvancedCachingService');
    }
  }

  /// Evict least recently used entries
  Future<void> _evictLeastRecentlyUsed(int count) async {
    final entries = _memoryCache.values.toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

    final keysToRemove = entries.take(count).map((entry) => entry.key).toList();
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
    }
  }

  /// Optimize cache levels by moving data appropriately
  Future<void> _optimizeCacheLevels() async {
    // Move frequently accessed data to memory cache
    // Move rarely accessed data to lower levels
    // This is a simplified implementation
  }

  /// Compact disk cache database
  Future<void> _compactDiskCache() async {
    if (_diskCacheDb != null) {
      try {
        await _diskCacheDb!.execute('VACUUM');
      } catch (e) {
        developer.log('Error compacting disk cache: $e', name: 'AdvancedCachingService');
      }
    }
  }

  /// Perform initial cleanup on service start
  Future<void> _performInitialCleanup() async {
    await _cleanExpiredEntries();
    await _compactDiskCache();
  }

  /// Update store performance metrics
  void _updateStoreMetrics(String key, dynamic data) {
    final metrics = _performanceMetrics[key] ??= CachePerformanceMetrics(key);
    metrics.storeCount++;
    metrics.lastStoreTime = DateTime.now();
  }

  /// Update retrieve performance metrics
  void _updateRetrieveMetrics(String key, bool hit, CacheLevel level) {
    final metrics = _performanceMetrics[key] ??= CachePerformanceMetrics(key);
    metrics.retrieveCount++;
    metrics.lastRetrieveTime = DateTime.now();
    
    if (hit) {
      metrics.hitCount++;
      metrics.lastHitLevel = level;
    } else {
      metrics.missCount++;
    }
  }

  /// Update maintenance metrics
  void _updateMaintenanceMetrics() {
    // Update overall maintenance statistics
  }

  /// Get memory cache statistics
  Map<String, dynamic> _getMemoryCacheStats() {
    return {
      'entryCount': _memoryCache.length,
      'totalSize': _getMemoryCacheSize(),
      'maxSize': _memoryCacheMaxSize,
      'utilization': _getMemoryCacheSize() / _memoryCacheMaxSize,
    };
  }

  /// Get disk cache statistics
  Future<Map<String, dynamic>> _getDiskCacheStats() async {
    if (_diskCacheDb == null) {
      return {'entryCount': 0, 'totalSize': 0};
    }

    try {
      final result = await _diskCacheDb!.rawQuery('''
        SELECT COUNT(*) as entry_count, SUM(data_size) as total_size
        FROM cache_entries
      ''');

      if (result.isNotEmpty) {
        return {
          'entryCount': result.first['entry_count'] ?? 0,
          'totalSize': result.first['total_size'] ?? 0,
          'maxSize': _diskCacheMaxSize,
        };
      }
    } catch (e) {
      developer.log('Error getting disk cache stats: $e', name: 'AdvancedCachingService');
    }

    return {'entryCount': 0, 'totalSize': 0};
  }

  /// Get SharedPreferences cache statistics
  Future<Map<String, dynamic>> _getPrefsCacheStats() async {
    if (_prefsCache == null) {
      return {'entryCount': 0};
    }

    final cacheKeys = _prefsCache!.getKeys().where((key) => key.startsWith('cache_'));
    return {
      'entryCount': cacheKeys.length,
    };
  }

  /// Calculate overall performance metrics
  Map<String, dynamic> _calculateOverallMetrics() {
    int totalHits = 0;
    int totalMisses = 0;
    int totalStores = 0;
    int totalRetrieves = 0;

    for (final metrics in _performanceMetrics.values) {
      totalHits += metrics.hitCount;
      totalMisses += metrics.missCount;
      totalStores += metrics.storeCount;
      totalRetrieves += metrics.retrieveCount;
    }

    final hitRate = totalRetrieves > 0 ? (totalHits / totalRetrieves) : 0.0;

    return {
      'totalHits': totalHits,
      'totalMisses': totalMisses,
      'totalStores': totalStores,
      'totalRetrieves': totalRetrieves,
      'hitRate': hitRate,
      'missRate': 1.0 - hitRate,
    };
  }

  /// Get performance metrics snapshot
  Map<String, dynamic> _getPerformanceMetricsSnapshot() {
    return _performanceMetrics.map((key, metrics) => MapEntry(key, {
      'key': metrics.key,
      'hitCount': metrics.hitCount,
      'missCount': metrics.missCount,
      'storeCount': metrics.storeCount,
      'retrieveCount': metrics.retrieveCount,
      'hitRate': metrics.retrieveCount > 0 ? (metrics.hitCount / metrics.retrieveCount) : 0.0,
      'lastHitLevel': metrics.lastHitLevel?.name,
      'lastStoreTime': metrics.lastStoreTime?.toIso8601String(),
      'lastRetrieveTime': metrics.lastRetrieveTime?.toIso8601String(),
    }));
  }

  /// Get warming strategies status
  Map<String, dynamic> _getWarmingStrategiesStatus() {
    return _warmingStrategies.map((key, strategy) => MapEntry(key, {
      'name': strategy.name,
      'priority': strategy.priority.name,
      'interval': strategy.interval.inMilliseconds,
      'lastExecuted': strategy.lastExecuted?.toIso8601String(),
    }));
  }

  /// Get invalidation policies status
  Map<String, dynamic> _getInvalidationPoliciesStatus() {
    return _invalidationPolicies.map((key, policy) => MapEntry(key, {
      'name': policy.name,
      'action': policy.action.name,
      'lastExecuted': policy.lastExecuted?.toIso8601String(),
    }));
  }

  /// Dispose the service and clean up resources
  Future<void> dispose() async {
    _warmingTimer?.cancel();
    await _diskCacheDb?.close();
    _memoryCache.clear();
    _performanceMetrics.clear();
    _warmingStrategies.clear();
    _invalidationPolicies.clear();
    
    developer.log('Advanced caching service disposed', name: 'AdvancedCachingService');
  }
}

/// Cache entry with metadata
class CacheEntry {
  final String key;
  final dynamic data;
  final DateTime createdAt;
  final DateTime expiresAt;
  final CachePriority priority;
  final List<String> tags;
  
  int accessCount;
  DateTime lastAccessed;
  int dataSize;

  CacheEntry({
    required this.key,
    required this.data,
    required this.createdAt,
    required this.expiresAt,
    required this.priority,
    required this.tags,
    required this.accessCount,
    required this.lastAccessed,
    this.dataSize = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Cache priority levels
enum CachePriority {
  critical,   // Never evict, long TTL
  high,       // Rarely evict, medium TTL
  normal,     // Standard eviction, standard TTL
  low,        // Evict when needed, short TTL
  temporary,  // Evict aggressively, very short TTL
}

/// Cache levels in the multi-level hierarchy
enum CacheLevel {
  none,
  memory,
  disk,
  preferences,
}

/// Cache warming strategy
class CacheWarmingStrategy {
  final String name;
  final CachePriority priority;
  final Duration interval;
  final Future<Map<String, dynamic>> Function() dataFetcher;
  
  DateTime? lastExecuted;

  CacheWarmingStrategy({
    required this.name,
    required this.priority,
    required this.interval,
    required this.dataFetcher,
    this.lastExecuted,
  });
}

/// Cache invalidation policy
class CacheInvalidationPolicy {
  final String name;
  final bool Function(CacheEntry entry) condition;
  final CacheInvalidationAction action;
  
  DateTime? lastExecuted;

  CacheInvalidationPolicy({
    required this.name,
    required this.condition,
    required this.action,
    this.lastExecuted,
  });
}

/// Cache invalidation actions
enum CacheInvalidationAction {
  remove,     // Remove the entry
  evictLru,   // Evict least recently used entries
  refresh,    // Refresh the entry data
}

/// Performance metrics for cache operations
class CachePerformanceMetrics {
  final String key;
  
  int hitCount = 0;
  int missCount = 0;
  int storeCount = 0;
  int retrieveCount = 0;
  
  CacheLevel? lastHitLevel;
  DateTime? lastStoreTime;
  DateTime? lastRetrieveTime;

  CachePerformanceMetrics(this.key);
}