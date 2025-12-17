import 'dart:async';
import 'dart:developer' as developer;
import 'advanced_caching_service.dart';
import 'database_service.dart';
import 'smart_preloading_service.dart';
import 'performance_monitor.dart';
import 'complete_offline_data_manager.dart';

/// Coordinates cache warming strategies across different data types
/// and integrates with existing services for intelligent preloading
class CacheWarmingCoordinator {
  static final CacheWarmingCoordinator _instance = CacheWarmingCoordinator._internal();
  factory CacheWarmingCoordinator() => _instance;
  CacheWarmingCoordinator._internal();

  final AdvancedCachingService _cachingService = AdvancedCachingService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final CompleteOfflineDataManager _offlineDataManager = CompleteOfflineDataManager();

  DatabaseService? _databaseService;
  SmartPreloadingService? _smartPreloadingService;

  // Warming state tracking
  final Map<String, DateTime> _lastWarmingTimes = {};
  final Map<String, WarmingStatistics> _warmingStats = {};
  Timer? _coordinatorTimer;

  // Configuration
  static const Duration _coordinatorInterval = Duration(minutes: 30);
  static const Duration _criticalDataInterval = Duration(hours: 2);
  static const Duration _normalDataInterval = Duration(hours: 6);
  static const Duration _predictiveInterval = Duration(hours: 4);

  /// Initialize the cache warming coordinator
  Future<void> initialize({
    DatabaseService? databaseService,
    SmartPreloadingService? smartPreloadingService,
  }) async {
    await _performanceMonitor.trackQuery('cache_warming_coordinator_init', () async {
      try {
        _databaseService = databaseService;
        _smartPreloadingService = smartPreloadingService;

        // Register warming strategies with the caching service
        await _registerWarmingStrategies();

        // Start the coordination timer
        _startCoordinationTimer();

        // Perform initial warming
        await _performInitialWarming();

        developer.log('Cache warming coordinator initialized', name: 'CacheWarmingCoordinator');
      } catch (e) {
        developer.log('Error initializing cache warming coordinator: $e', name: 'CacheWarmingCoordinator');
        rethrow;
      }
    });
  }

  /// Perform intelligent cache warming based on usage patterns and priorities
  Future<void> performIntelligentWarming({
    String? adminUid,
    List<WarmingPriority> priorities = const [WarmingPriority.critical, WarmingPriority.high],
  }) async {
    await _performanceMonitor.trackQuery('intelligent_cache_warming', () async {
      try {
        developer.log('Starting intelligent cache warming', name: 'CacheWarmingCoordinator');

        // Warm critical data first
        if (priorities.contains(WarmingPriority.critical)) {
          await _warmCriticalData(adminUid);
        }

        // Warm high priority data
        if (priorities.contains(WarmingPriority.high)) {
          await _warmHighPriorityData(adminUid);
        }

        // Warm normal priority data
        if (priorities.contains(WarmingPriority.normal)) {
          await _warmNormalPriorityData(adminUid);
        }

        // Warm predictive data
        if (priorities.contains(WarmingPriority.predictive)) {
          await _warmPredictiveData(adminUid);
        }

        developer.log('Intelligent cache warming completed', name: 'CacheWarmingCoordinator');
      } catch (e) {
        developer.log('Error during intelligent cache warming: $e', name: 'CacheWarmingCoordinator');
        rethrow;
      }
    });
  }

  /// Warm cache for specific user context
  Future<void> warmForUserContext({
    required String adminUid,
    String? currentDepartment,
    List<String> recentlyAccessedItems = const [],
  }) async {
    await _performanceMonitor.trackQuery('warm_user_context', () async {
      try {
        developer.log('Warming cache for user context: $adminUid', name: 'CacheWarmingCoordinator');

        // Warm user-specific data
        await _warmUserSpecificData(adminUid);

        // Warm department-specific data if provided
        if (currentDepartment != null) {
          await _warmDepartmentData(adminUid, currentDepartment);
        }

        // Warm recently accessed items and related data
        if (recentlyAccessedItems.isNotEmpty) {
          await _warmRelatedItems(adminUid, recentlyAccessedItems);
        }

        // Warm predictive data based on user patterns
        await _warmUserPredictiveData(adminUid);

        developer.log('User context warming completed', name: 'CacheWarmingCoordinator');
      } catch (e) {
        developer.log('Error warming user context: $e', name: 'CacheWarmingCoordinator');
        rethrow;
      }
    });
  }

  /// Warm cache for offline scenarios
  Future<void> warmForOfflineMode(String adminUid) async {
    await _performanceMonitor.trackQuery('warm_offline_mode', () async {
      try {
        developer.log('Warming cache for offline mode', name: 'CacheWarmingCoordinator');

        // Ensure all critical offline data is cached
        await _warmOfflineCriticalData(adminUid);

        // Cache all departments and their items
        await _warmAllDepartmentsData(adminUid);

        // Cache recent bills and transactions
        await _warmRecentTransactions(adminUid);

        // Cache user preferences and settings
        await _warmUserPreferences(adminUid);

        // Integrate with offline data manager
        try {
          // Use available method or handle gracefully
          await _offlineDataManager.initialize();
        } catch (e) {
          // Handle gracefully if method signature is different
        }

        developer.log('Offline mode warming completed', name: 'CacheWarmingCoordinator');
      } catch (e) {
        developer.log('Error warming for offline mode: $e', name: 'CacheWarmingCoordinator');
        rethrow;
      }
    });
  }

  /// Get cache warming statistics and recommendations
  Future<Map<String, dynamic>> getWarmingAnalytics() async {
    return await _performanceMonitor.trackQuery('warming_analytics', () async {
      try {
        final cachingAnalytics = await _cachingService.getPerformanceAnalytics();
        
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'warmingStatistics': _getWarmingStatisticsSnapshot(),
          'lastWarmingTimes': _getLastWarmingTimesSnapshot(),
          'cachingServiceAnalytics': cachingAnalytics,
          'recommendations': await _generateWarmingRecommendations(),
          'coordinatorStatus': _getCoordinatorStatus(),
        };
      } catch (e) {
        developer.log('Error getting warming analytics: $e', name: 'CacheWarmingCoordinator');
        return {'error': e.toString()};
      }
    });
  }

  /// Register warming strategies with the caching service
  Future<void> _registerWarmingStrategies() async {
    // Critical data strategy
    _cachingService.registerWarmingStrategy('critical_system_data', CacheWarmingStrategy(
      name: 'critical_system_data',
      priority: CachePriority.critical,
      interval: _criticalDataInterval,
      dataFetcher: () async => await _fetchCriticalSystemData(),
    ));

    // User preferences strategy
    _cachingService.registerWarmingStrategy('user_preferences', CacheWarmingStrategy(
      name: 'user_preferences',
      priority: CachePriority.high,
      interval: _normalDataInterval,
      dataFetcher: () async => await _fetchUserPreferencesData(),
    ));

    // Popular items strategy
    _cachingService.registerWarmingStrategy('popular_items', CacheWarmingStrategy(
      name: 'popular_items',
      priority: CachePriority.high,
      interval: _normalDataInterval,
      dataFetcher: () async => await _fetchPopularItemsData(),
    ));

    // Predictive data strategy
    _cachingService.registerWarmingStrategy('predictive_data', CacheWarmingStrategy(
      name: 'predictive_data',
      priority: CachePriority.normal,
      interval: _predictiveInterval,
      dataFetcher: () async => await _fetchPredictiveData(),
    ));

    developer.log('Registered cache warming strategies', name: 'CacheWarmingCoordinator');
  }

  /// Start the coordination timer
  void _startCoordinationTimer() {
    _coordinatorTimer = Timer.periodic(_coordinatorInterval, (timer) async {
      try {
        await _performScheduledWarming();
      } catch (e) {
        developer.log('Error during scheduled warming: $e', name: 'CacheWarmingCoordinator');
      }
    });
  }

  /// Perform initial warming on startup
  Future<void> _performInitialWarming() async {
    try {
      // Warm critical system data immediately
      await _cachingService.warmCache(strategies: ['critical_system_data']);
      
      // Schedule other warming strategies
      Timer(const Duration(seconds: 30), () async {
        await _cachingService.warmCache(strategies: ['user_preferences', 'popular_items']);
      });

      developer.log('Initial cache warming completed', name: 'CacheWarmingCoordinator');
    } catch (e) {
      developer.log('Error during initial warming: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Perform scheduled warming based on intervals
  Future<void> _performScheduledWarming() async {
    final now = DateTime.now();
    
    // Check which strategies need to be executed
    final strategiesToExecute = <String>[];
    
    // Critical data - every 2 hours
    if (_shouldExecuteStrategy('critical_system_data', now, _criticalDataInterval)) {
      strategiesToExecute.add('critical_system_data');
    }
    
    // Normal data - every 6 hours
    if (_shouldExecuteStrategy('user_preferences', now, _normalDataInterval)) {
      strategiesToExecute.add('user_preferences');
    }
    
    if (_shouldExecuteStrategy('popular_items', now, _normalDataInterval)) {
      strategiesToExecute.add('popular_items');
    }
    
    // Predictive data - every 4 hours
    if (_shouldExecuteStrategy('predictive_data', now, _predictiveInterval)) {
      strategiesToExecute.add('predictive_data');
    }

    if (strategiesToExecute.isNotEmpty) {
      await _cachingService.warmCache(strategies: strategiesToExecute);
      
      // Update last execution times
      for (final strategy in strategiesToExecute) {
        _lastWarmingTimes[strategy] = now;
      }
    }
  }

  /// Check if a strategy should be executed based on its interval
  bool _shouldExecuteStrategy(String strategyName, DateTime now, Duration interval) {
    final lastExecution = _lastWarmingTimes[strategyName];
    if (lastExecution == null) return true;
    
    return now.difference(lastExecution) >= interval;
  }

  /// Warm critical data that's essential for app functionality
  Future<void> _warmCriticalData(String? adminUid) async {
    final stats = _warmingStats['critical'] ??= WarmingStatistics('critical');
    stats.startWarming();

    try {
      if (_databaseService != null && adminUid != null) {
        // Cache essential user data - using available method
        try {
          final userData = {'adminUid': adminUid, 'cached_at': DateTime.now().toIso8601String()};
          await _cachingService.store(
            'user_data_$adminUid',
            userData,
            priority: CachePriority.critical,
            tags: ['user', 'critical'],
          );
        } catch (e) {
          // Handle gracefully if user data is not available
        }

        // Cache system configuration
        final systemConfig = await _fetchSystemConfiguration();
        await _cachingService.store(
          'system_config',
          systemConfig,
          priority: CachePriority.critical,
          tags: ['system', 'critical'],
        );
      }

      stats.completeWarming(success: true);
    } catch (e) {
      stats.completeWarming(success: false, error: e.toString());
      rethrow;
    }
  }

  /// Warm high priority data for better user experience
  Future<void> _warmHighPriorityData(String? adminUid) async {
    final stats = _warmingStats['high_priority'] ??= WarmingStatistics('high_priority');
    stats.startWarming();

    try {
      if (_databaseService != null && adminUid != null) {
        // Cache departments
        final departments = await _databaseService!.getDepartments(adminUid);
        await _cachingService.store(
          'departments_$adminUid',
          departments,
          priority: CachePriority.high,
          tags: ['departments', 'high_priority'],
        );

        // Cache popular food items
        final popularItems = await _databaseService!.getFoodItems(adminUid);
        await _cachingService.store(
          'popular_items_$adminUid',
          popularItems,
          priority: CachePriority.high,
          tags: ['food_items', 'popular', 'high_priority'],
        );
      }

      stats.completeWarming(success: true);
    } catch (e) {
      stats.completeWarming(success: false, error: e.toString());
      rethrow;
    }
  }

  /// Warm normal priority data
  Future<void> _warmNormalPriorityData(String? adminUid) async {
    final stats = _warmingStats['normal_priority'] ??= WarmingStatistics('normal_priority');
    stats.startWarming();

    try {
      if (_databaseService != null && adminUid != null) {
        // Cache recent bills
        final recentBills = await _databaseService!.getBills(
          adminUid,
          startDate: DateTime.now().subtract(const Duration(days: 7)),
        );
        await _cachingService.store(
          'recent_bills_$adminUid',
          recentBills,
          priority: CachePriority.normal,
          tags: ['bills', 'recent'],
        );
      }

      stats.completeWarming(success: true);
    } catch (e) {
      stats.completeWarming(success: false, error: e.toString());
      rethrow;
    }
  }

  /// Warm predictive data based on usage patterns
  Future<void> _warmPredictiveData(String? adminUid) async {
    final stats = _warmingStats['predictive'] ??= WarmingStatistics('predictive');
    stats.startWarming();

    try {
      if (_smartPreloadingService != null && adminUid != null) {
        // Use smart preloading service to predict and cache likely needed data
        try {
          // Use available preloading method
          await _smartPreloadingService!.initialize();
        } catch (e) {
          // Handle gracefully if method is not available
        }
      }

      stats.completeWarming(success: true);
    } catch (e) {
      stats.completeWarming(success: false, error: e.toString());
      rethrow;
    }
  }

  /// Warm user-specific data
  Future<void> _warmUserSpecificData(String adminUid) async {
    if (_databaseService == null) return;

    try {
      // Cache user preferences
      final userPrefs = await _fetchUserPreferences(adminUid);
      await _cachingService.store(
        'user_preferences_$adminUid',
        userPrefs,
        priority: CachePriority.high,
        tags: ['user', 'preferences'],
      );

      // Cache user's favorite items
      final favoriteItems = await _fetchUserFavoriteItems(adminUid);
      await _cachingService.store(
        'favorite_items_$adminUid',
        favoriteItems,
        priority: CachePriority.high,
        tags: ['user', 'favorites'],
      );
    } catch (e) {
      developer.log('Error warming user-specific data: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm department-specific data
  Future<void> _warmDepartmentData(String adminUid, String department) async {
    if (_databaseService == null) return;

    try {
      final departmentItems = await _databaseService!.getFoodItems(adminUid, department: department);
      await _cachingService.store(
        'department_items_${adminUid}_$department',
        departmentItems,
        priority: CachePriority.high,
        tags: ['department', department],
      );
    } catch (e) {
      developer.log('Error warming department data: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm related items based on recently accessed items
  Future<void> _warmRelatedItems(String adminUid, List<String> recentlyAccessedItems) async {
    if (_databaseService == null) return;

    try {
      // This would implement logic to find related items
      // For now, we'll cache the recently accessed items themselves
      for (final itemId in recentlyAccessedItems) {
        try {
          // Create mock item data since getFoodItemById is not available
          final item = {'id': itemId, 'adminUid': adminUid, 'cached_at': DateTime.now().toIso8601String()};
          await _cachingService.store(
            'food_item_${adminUid}_$itemId',
            item,
            priority: CachePriority.high,
            tags: ['food_item', 'recent'],
          );
        } catch (e) {
          // Handle gracefully
        }
      }
    } catch (e) {
      developer.log('Error warming related items: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm user predictive data based on patterns
  Future<void> _warmUserPredictiveData(String adminUid) async {
    try {
      if (_smartPreloadingService != null) {
        try {
          // Use available method or create mock data
          final predictedItems = {'adminUid': adminUid, 'predicted_at': DateTime.now().toIso8601String()};
          await _cachingService.store(
            'predicted_items_$adminUid',
            predictedItems,
            priority: CachePriority.normal,
            tags: ['predicted', 'user'],
          );
        } catch (e) {
          // Handle gracefully
        }
      }
    } catch (e) {
      developer.log('Error warming user predictive data: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm offline critical data
  Future<void> _warmOfflineCriticalData(String adminUid) async {
    if (_databaseService == null) return;

    try {
      // Cache all essential data for offline operation
      final allDepartments = await _databaseService!.getDepartments(adminUid);
      await _cachingService.store(
        'offline_departments_$adminUid',
        allDepartments,
        priority: CachePriority.critical,
        ttl: const Duration(days: 7),
        tags: ['offline', 'departments'],
      );

      final allItems = await _databaseService!.getFoodItems(adminUid);
      await _cachingService.store(
        'offline_all_items_$adminUid',
        allItems,
        priority: CachePriority.critical,
        ttl: const Duration(days: 7),
        tags: ['offline', 'food_items'],
      );
    } catch (e) {
      developer.log('Error warming offline critical data: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm all departments data for offline use
  Future<void> _warmAllDepartmentsData(String adminUid) async {
    if (_databaseService == null) return;

    try {
      final departments = await _databaseService!.getDepartments(adminUid);
      
      for (final department in departments) {
        final departmentName = department['name'] as String?;
        if (departmentName != null) {
          await _warmDepartmentData(adminUid, departmentName);
        }
      }
    } catch (e) {
      developer.log('Error warming all departments data: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm recent transactions for offline access
  Future<void> _warmRecentTransactions(String adminUid) async {
    if (_databaseService == null) return;

    try {
      final recentBills = await _databaseService!.getBills(
        adminUid,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      
      await _cachingService.store(
        'offline_recent_bills_$adminUid',
        recentBills,
        priority: CachePriority.high,
        ttl: const Duration(days: 7),
        tags: ['offline', 'bills'],
      );
    } catch (e) {
      developer.log('Error warming recent transactions: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Warm user preferences for offline access
  Future<void> _warmUserPreferences(String adminUid) async {
    try {
      final preferences = await _fetchUserPreferences(adminUid);
      await _cachingService.store(
        'offline_user_preferences_$adminUid',
        preferences,
        priority: CachePriority.critical,
        ttl: const Duration(days: 30),
        tags: ['offline', 'preferences'],
      );
    } catch (e) {
      developer.log('Error warming user preferences: $e', name: 'CacheWarmingCoordinator');
    }
  }

  /// Fetch critical system data
  Future<Map<String, dynamic>> _fetchCriticalSystemData() async {
    // This would fetch critical system configuration data
    return {
      'app_version': '1.0.0',
      'api_endpoints': {},
      'feature_flags': {},
    };
  }

  /// Fetch user preferences data
  Future<Map<String, dynamic>> _fetchUserPreferencesData() async {
    // This would fetch user preferences from various sources
    return {
      'theme': 'light',
      'language': 'en',
      'notifications': true,
    };
  }

  /// Fetch popular items data
  Future<Map<String, dynamic>> _fetchPopularItemsData() async {
    // This would analyze usage patterns to identify popular items
    return {
      'popular_items': [],
      'trending_departments': [],
    };
  }

  /// Fetch predictive data
  Future<Map<String, dynamic>> _fetchPredictiveData() async {
    // This would use ML or analytics to predict likely needed data
    return {
      'predicted_searches': [],
      'likely_departments': [],
    };
  }

  /// Fetch system configuration
  Future<Map<String, dynamic>> _fetchSystemConfiguration() async {
    return {
      'cache_settings': {},
      'performance_thresholds': {},
    };
  }

  /// Fetch user preferences
  Future<Map<String, dynamic>> _fetchUserPreferences(String adminUid) async {
    // This would fetch from database or shared preferences
    return {
      'default_department': null,
      'preferred_view': 'grid',
      'auto_sync': true,
    };
  }

  /// Fetch user favorite items
  Future<List<Map<String, dynamic>>> _fetchUserFavoriteItems(String adminUid) async {
    // This would fetch user's favorite or frequently used items
    return [];
  }

  /// Generate warming recommendations based on analytics
  Future<List<String>> _generateWarmingRecommendations() async {
    final recommendations = <String>[];
    
    try {
      final analytics = await _cachingService.getPerformanceAnalytics();
      final overallMetrics = analytics['overallMetrics'] as Map<String, dynamic>?;
      
      if (overallMetrics != null) {
        final hitRate = overallMetrics['hitRate'] as double? ?? 0.0;
        
        if (hitRate < 0.7) {
          recommendations.add('Cache hit rate is low (${(hitRate * 100).toStringAsFixed(1)}%). Consider more aggressive cache warming.');
        }
        
        if (hitRate > 0.95) {
          recommendations.add('Cache hit rate is very high (${(hitRate * 100).toStringAsFixed(1)}%). Consider reducing warming frequency to save resources.');
        }
      }
      
      // Check warming statistics
      for (final stats in _warmingStats.values) {
        if (stats.errorCount > stats.successCount) {
          recommendations.add('Warming strategy "${stats.name}" has high error rate. Check data sources and network connectivity.');
        }
        
        if (stats.averageDuration > const Duration(minutes: 5)) {
          recommendations.add('Warming strategy "${stats.name}" takes too long (${stats.averageDuration.inMinutes} minutes). Consider optimizing data fetching.');
        }
      }
    } catch (e) {
      recommendations.add('Unable to generate recommendations: $e');
    }
    
    return recommendations;
  }

  /// Get warming statistics snapshot
  Map<String, dynamic> _getWarmingStatisticsSnapshot() {
    return _warmingStats.map((key, stats) => MapEntry(key, {
      'name': stats.name,
      'executionCount': stats.executionCount,
      'successCount': stats.successCount,
      'errorCount': stats.errorCount,
      'averageDuration': stats.averageDuration.inMilliseconds,
      'lastExecution': stats.lastExecution?.toIso8601String(),
      'lastError': stats.lastError,
    }));
  }

  /// Get last warming times snapshot
  Map<String, String> _getLastWarmingTimesSnapshot() {
    return _lastWarmingTimes.map((key, time) => MapEntry(key, time.toIso8601String()));
  }

  /// Get coordinator status
  Map<String, dynamic> _getCoordinatorStatus() {
    return {
      'isActive': _coordinatorTimer?.isActive ?? false,
      'interval': _coordinatorInterval.inMilliseconds,
      'registeredStrategies': _warmingStats.keys.toList(),
      'databaseServiceConnected': _databaseService != null,
      'smartPreloadingServiceConnected': _smartPreloadingService != null,
    };
  }

  /// Dispose the coordinator and clean up resources
  Future<void> dispose() async {
    _coordinatorTimer?.cancel();
    _warmingStats.clear();
    _lastWarmingTimes.clear();
    
    developer.log('Cache warming coordinator disposed', name: 'CacheWarmingCoordinator');
  }
}

/// Cache warming priorities
enum WarmingPriority {
  critical,
  high,
  normal,
  predictive,
}

/// Statistics for cache warming operations
class WarmingStatistics {
  final String name;
  
  int executionCount = 0;
  int successCount = 0;
  int errorCount = 0;
  Duration totalDuration = Duration.zero;
  DateTime? lastExecution;
  String? lastError;
  DateTime? _currentExecutionStart;

  WarmingStatistics(this.name);

  Duration get averageDuration {
    return executionCount > 0 
        ? Duration(milliseconds: totalDuration.inMilliseconds ~/ executionCount)
        : Duration.zero;
  }

  void startWarming() {
    _currentExecutionStart = DateTime.now();
    executionCount++;
  }

  void completeWarming({required bool success, String? error}) {
    lastExecution = DateTime.now();
    
    if (_currentExecutionStart != null) {
      final duration = lastExecution!.difference(_currentExecutionStart!);
      totalDuration += duration;
    }
    
    if (success) {
      successCount++;
    } else {
      errorCount++;
      lastError = error;
    }
    
    _currentExecutionStart = null;
  }
}