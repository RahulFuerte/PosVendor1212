import 'dart:async';
import 'dart:developer' as developer;
import 'advanced_caching_service.dart';
import 'performance_monitor.dart';
import 'database_service.dart';

/// Manages intelligent cache invalidation policies and strategies
/// Provides automatic and manual cache invalidation based on various triggers
class CacheInvalidationManager {
  static final CacheInvalidationManager _instance = CacheInvalidationManager._internal();
  factory CacheInvalidationManager() => _instance;
  CacheInvalidationManager._internal();

  final AdvancedCachingService _cachingService = AdvancedCachingService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();

  DatabaseService? _databaseService;
  
  // Invalidation tracking
  final Map<String, InvalidationPolicy> _policies = {};
  final Map<String, InvalidationStatistics> _statistics = {};
  final List<InvalidationTrigger> _triggers = [];
  
  Timer? _policyTimer;
  StreamSubscription? _dataChangeSubscription;

  // Configuration
  static const Duration _policyCheckInterval = Duration(minutes: 15);
  static const Duration _statisticsRetentionPeriod = Duration(days: 7);

  /// Initialize the cache invalidation manager
  Future<void> initialize({DatabaseService? databaseService}) async {
    await _performanceMonitor.trackQuery('cache_invalidation_manager_init', () async {
      try {
        _databaseService = databaseService;

        // Register default invalidation policies
        _registerDefaultPolicies();

        // Set up invalidation triggers
        _setupInvalidationTriggers();

        // Start policy execution timer
        _startPolicyTimer();

        // Listen for data changes if database service is available
        _setupDataChangeListener();

        developer.log('Cache invalidation manager initialized', name: 'CacheInvalidationManager');
      } catch (e) {
        developer.log('Error initializing cache invalidation manager: $e', name: 'CacheInvalidationManager');
        rethrow;
      }
    });
  }

  /// Register a custom invalidation policy
  void registerPolicy(InvalidationPolicy policy) {
    _policies[policy.name] = policy;
    _statistics[policy.name] = InvalidationStatistics(policy.name);
    
    developer.log('Registered invalidation policy: ${policy.name}', name: 'CacheInvalidationManager');
  }

  /// Execute invalidation based on data changes
  Future<void> invalidateOnDataChange({
    required String dataType,
    String? specificKey,
    List<String> affectedTags = const [],
  }) async {
    await _performanceMonitor.trackQuery('invalidate_on_data_change', () async {
      try {
        developer.log('Invalidating cache due to data change: $dataType', name: 'CacheInvalidationManager');

        // Find and execute relevant policies
        final relevantPolicies = _findPoliciesForDataType(dataType);
        
        for (final policy in relevantPolicies) {
          await _executePolicy(policy, InvalidationReason.dataChange);
        }

        // Invalidate specific key if provided
        if (specificKey != null) {
          await _cachingService.invalidate(key: specificKey);
        }

        // Invalidate by tags if provided
        if (affectedTags.isNotEmpty) {
          await _cachingService.invalidate(tags: affectedTags);
        }

        developer.log('Data change invalidation completed', name: 'CacheInvalidationManager');
      } catch (e) {
        developer.log('Error during data change invalidation: $e', name: 'CacheInvalidationManager');
        rethrow;
      }
    });
  }

  /// Execute invalidation based on user actions
  Future<void> invalidateOnUserAction({
    required String action,
    String? userId,
    Map<String, dynamic> context = const {},
  }) async {
    await _performanceMonitor.trackQuery('invalidate_on_user_action', () async {
      try {
        developer.log('Invalidating cache due to user action: $action', name: 'CacheInvalidationManager');

        switch (action) {
          case 'logout':
            await _invalidateUserSpecificData(userId);
            break;
          case 'settings_change':
            await _invalidateUserPreferences(userId);
            break;
          case 'department_change':
            await _invalidateDepartmentData(context['department'] as String?);
            break;
          case 'item_update':
            await _invalidateItemData(context['itemId'] as String?);
            break;
          case 'bill_create':
          case 'bill_update':
            await _invalidateBillData(userId);
            break;
          default:
            developer.log('Unknown user action for invalidation: $action', name: 'CacheInvalidationManager');
        }

        developer.log('User action invalidation completed', name: 'CacheInvalidationManager');
      } catch (e) {
        developer.log('Error during user action invalidation: $e', name: 'CacheInvalidationManager');
        rethrow;
      }
    });
  }

  /// Execute invalidation based on time policies
  Future<void> executeTimePolicies() async {
    await _performanceMonitor.trackQuery('execute_time_policies', () async {
      try {
        final timePolicies = _policies.values.where((policy) => 
            policy.trigger == InvalidationTriggerType.time);

        for (final policy in timePolicies) {
          if (_shouldExecuteTimePolicy(policy)) {
            await _executePolicy(policy, InvalidationReason.timeExpired);
          }
        }
      } catch (e) {
        developer.log('Error executing time policies: $e', name: 'CacheInvalidationManager');
        rethrow;
      }
    });
  }

  /// Execute invalidation based on memory pressure
  Future<void> invalidateOnMemoryPressure({
    required MemoryPressureLevel level,
  }) async {
    await _performanceMonitor.trackQuery('invalidate_memory_pressure', () async {
      try {
        developer.log('Invalidating cache due to memory pressure: ${level.name}', name: 'CacheInvalidationManager');

        switch (level) {
          case MemoryPressureLevel.low:
            await _invalidateLowPriorityCache();
            break;
          case MemoryPressureLevel.medium:
            await _invalidateNormalPriorityCache();
            break;
          case MemoryPressureLevel.high:
            await _invalidateHighPriorityCache();
            break;
          case MemoryPressureLevel.critical:
            await _invalidateAllNonCriticalCache();
            break;
        }

        developer.log('Memory pressure invalidation completed', name: 'CacheInvalidationManager');
      } catch (e) {
        developer.log('Error during memory pressure invalidation: $e', name: 'CacheInvalidationManager');
        rethrow;
      }
    });
  }

  /// Get invalidation analytics and statistics
  Future<Map<String, dynamic>> getInvalidationAnalytics() async {
    return await _performanceMonitor.trackQuery('invalidation_analytics', () async {
      try {
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'policies': _getPoliciesSnapshot(),
          'statistics': _getStatisticsSnapshot(),
          'triggers': _getTriggersSnapshot(),
          'recommendations': _generateInvalidationRecommendations(),
          'managerStatus': _getManagerStatus(),
        };
      } catch (e) {
        developer.log('Error getting invalidation analytics: $e', name: 'CacheInvalidationManager');
        return {'error': e.toString()};
      }
    });
  }

  /// Register default invalidation policies
  void _registerDefaultPolicies() {
    // Time-based expiration policy
    registerPolicy(InvalidationPolicy(
      name: 'time_expiration',
      trigger: InvalidationTriggerType.time,
      condition: (entry) => entry.isExpired,
      action: InvalidationAction.remove,
      interval: const Duration(hours: 1),
      priority: InvalidationPriority.high,
    ));

    // Memory pressure policy
    registerPolicy(InvalidationPolicy(
      name: 'memory_pressure',
      trigger: InvalidationTriggerType.memoryPressure,
      condition: (entry) => entry.priority == CachePriority.low || 
                           entry.priority == CachePriority.temporary,
      action: InvalidationAction.evictLru,
      priority: InvalidationPriority.high,
    ));

    // Unused data policy
    registerPolicy(InvalidationPolicy(
      name: 'unused_data',
      trigger: InvalidationTriggerType.time,
      condition: (entry) => entry.accessCount == 0 && 
                           DateTime.now().difference(entry.createdAt).inDays > 3,
      action: InvalidationAction.remove,
      interval: const Duration(hours: 6),
      priority: InvalidationPriority.medium,
    ));

    // Large data policy
    registerPolicy(InvalidationPolicy(
      name: 'large_data',
      trigger: InvalidationTriggerType.size,
      condition: (entry) => entry.dataSize > 10 * 1024 * 1024, // 10MB
      action: InvalidationAction.evictLru,
      priority: InvalidationPriority.medium,
    ));

    // Stale data policy
    registerPolicy(InvalidationPolicy(
      name: 'stale_data',
      trigger: InvalidationTriggerType.dataChange,
      condition: (entry) => DateTime.now().difference(entry.createdAt).inHours > 24,
      action: InvalidationAction.refresh,
      priority: InvalidationPriority.low,
    ));

    developer.log('Registered default invalidation policies', name: 'CacheInvalidationManager');
  }

  /// Set up invalidation triggers
  void _setupInvalidationTriggers() {
    // Data change triggers
    _triggers.add(InvalidationTrigger(
      type: InvalidationTriggerType.dataChange,
      dataTypes: ['food_items', 'departments', 'bills', 'users'],
      callback: (dataType, context) async {
        await invalidateOnDataChange(
          dataType: dataType,
          specificKey: context['key'] as String?,
          affectedTags: (context['tags'] as List<String>?) ?? [],
        );
      },
    ));

    // User action triggers
    _triggers.add(InvalidationTrigger(
      type: InvalidationTriggerType.userAction,
      dataTypes: ['user_session', 'preferences'],
      callback: (action, context) async {
        await invalidateOnUserAction(
          action: action,
          userId: context['userId'] as String?,
          context: context,
        );
      },
    ));

    developer.log('Set up invalidation triggers', name: 'CacheInvalidationManager');
  }

  /// Start policy execution timer
  void _startPolicyTimer() {
    _policyTimer = Timer.periodic(_policyCheckInterval, (timer) async {
      try {
        await executeTimePolicies();
        await _cleanupOldStatistics();
      } catch (e) {
        developer.log('Error during scheduled policy execution: $e', name: 'CacheInvalidationManager');
      }
    });
  }

  /// Set up data change listener
  void _setupDataChangeListener() {
    // This would typically listen to database change streams
    // For now, we'll set up a placeholder
    if (_databaseService != null) {
      // _dataChangeSubscription = _databaseService!.dataChangeStream.listen((change) {
      //   invalidateOnDataChange(
      //     dataType: change.dataType,
      //     specificKey: change.key,
      //     affectedTags: change.tags,
      //   );
      // });
    }
  }

  /// Find policies relevant to a specific data type
  List<InvalidationPolicy> _findPoliciesForDataType(String dataType) {
    return _policies.values.where((policy) {
      return policy.trigger == InvalidationTriggerType.dataChange ||
             policy.applicableDataTypes.contains(dataType);
    }).toList();
  }

  /// Execute a specific invalidation policy
  Future<void> _executePolicy(InvalidationPolicy policy, InvalidationReason reason) async {
    final stats = _statistics[policy.name]!;
    stats.startExecution();

    try {
      developer.log('Executing invalidation policy: ${policy.name}', name: 'CacheInvalidationManager');

      switch (policy.action) {
        case InvalidationAction.remove:
          await _executeRemoveAction(policy);
          break;
        case InvalidationAction.evictLru:
          await _executeEvictLruAction(policy);
          break;
        case InvalidationAction.refresh:
          await _executeRefreshAction(policy);
          break;
        case InvalidationAction.selective:
          await _executeSelectiveAction(policy);
          break;
      }

      stats.completeExecution(success: true, reason: reason);
      policy.lastExecuted = DateTime.now();

      developer.log('Policy execution completed: ${policy.name}', name: 'CacheInvalidationManager');
    } catch (e) {
      stats.completeExecution(success: false, reason: reason, error: e.toString());
      developer.log('Error executing policy ${policy.name}: $e', name: 'CacheInvalidationManager');
      rethrow;
    }
  }

  /// Check if a time-based policy should be executed
  bool _shouldExecuteTimePolicy(InvalidationPolicy policy) {
    if (policy.interval == null) return false;
    
    final lastExecution = policy.lastExecuted;
    if (lastExecution == null) return true;
    
    return DateTime.now().difference(lastExecution) >= policy.interval!;
  }

  /// Execute remove action
  Future<void> _executeRemoveAction(InvalidationPolicy policy) async {
    // This would need access to cache entries to evaluate conditions
    // For now, we'll use the caching service's invalidation methods
    if (policy.targetTags.isNotEmpty) {
      await _cachingService.invalidate(tags: policy.targetTags);
    }
  }

  /// Execute evict LRU action
  Future<void> _executeEvictLruAction(InvalidationPolicy policy) async {
    // This would implement LRU eviction logic
    // The caching service should handle this internally
    await _cachingService.performMaintenance();
  }

  /// Execute refresh action
  Future<void> _executeRefreshAction(InvalidationPolicy policy) async {
    // This would trigger a refresh of stale data
    // Implementation depends on specific requirements
    developer.log('Refresh action not yet implemented for policy: ${policy.name}', 
                 name: 'CacheInvalidationManager');
  }

  /// Execute selective action
  Future<void> _executeSelectiveAction(InvalidationPolicy policy) async {
    // This would implement selective invalidation based on complex conditions
    developer.log('Selective action not yet implemented for policy: ${policy.name}', 
                 name: 'CacheInvalidationManager');
  }

  /// Invalidate user-specific data
  Future<void> _invalidateUserSpecificData(String? userId) async {
    if (userId == null) return;

    await _cachingService.invalidate(tags: ['user', 'user_$userId']);
  }

  /// Invalidate user preferences
  Future<void> _invalidateUserPreferences(String? userId) async {
    if (userId == null) return;

    await _cachingService.invalidate(tags: ['preferences', 'user_$userId']);
  }

  /// Invalidate department data
  Future<void> _invalidateDepartmentData(String? department) async {
    if (department == null) return;

    await _cachingService.invalidate(tags: ['department', department]);
  }

  /// Invalidate item data
  Future<void> _invalidateItemData(String? itemId) async {
    if (itemId == null) return;

    await _cachingService.invalidate(key: 'food_item_$itemId');
    await _cachingService.invalidate(tags: ['food_items']);
  }

  /// Invalidate bill data
  Future<void> _invalidateBillData(String? userId) async {
    if (userId == null) return;

    await _cachingService.invalidate(tags: ['bills', 'user_$userId']);
  }

  /// Invalidate low priority cache
  Future<void> _invalidateLowPriorityCache() async {
    await _cachingService.invalidate(tags: ['low_priority', 'temporary']);
  }

  /// Invalidate normal priority cache
  Future<void> _invalidateNormalPriorityCache() async {
    await _cachingService.invalidate(tags: ['normal_priority', 'low_priority', 'temporary']);
  }

  /// Invalidate high priority cache
  Future<void> _invalidateHighPriorityCache() async {
    await _cachingService.invalidate(tags: ['high_priority', 'normal_priority', 'low_priority', 'temporary']);
  }

  /// Invalidate all non-critical cache
  Future<void> _invalidateAllNonCriticalCache() async {
    // Keep only critical data
    await _cachingService.invalidate(tags: ['high_priority', 'normal_priority', 'low_priority', 'temporary']);
  }

  /// Clean up old statistics
  Future<void> _cleanupOldStatistics() async {
    final cutoffTime = DateTime.now().subtract(_statisticsRetentionPeriod);
    
    for (final stats in _statistics.values) {
      stats.cleanupOldEntries(cutoffTime);
    }
  }

  /// Generate invalidation recommendations
  List<String> _generateInvalidationRecommendations() {
    final recommendations = <String>[];
    
    try {
      // Analyze policy execution statistics
      for (final stats in _statistics.values) {
        if (stats.errorRate > 0.1) {
          recommendations.add('Policy "${stats.name}" has high error rate (${(stats.errorRate * 100).toStringAsFixed(1)}%). Review policy conditions.');
        }
        
        if (stats.averageExecutionTime > const Duration(seconds: 30)) {
          recommendations.add('Policy "${stats.name}" takes too long to execute (${stats.averageExecutionTime.inSeconds}s). Consider optimization.');
        }
        
        if (stats.executionCount == 0) {
          recommendations.add('Policy "${stats.name}" has never been executed. Review trigger conditions.');
        }
      }
      
      // Check for missing policies
      if (!_policies.containsKey('memory_pressure')) {
        recommendations.add('Consider adding memory pressure invalidation policy for better resource management.');
      }
      
      if (!_policies.containsKey('user_logout')) {
        recommendations.add('Consider adding user logout invalidation policy for security.');
      }
    } catch (e) {
      recommendations.add('Unable to generate recommendations: $e');
    }
    
    return recommendations;
  }

  /// Get policies snapshot
  Map<String, dynamic> _getPoliciesSnapshot() {
    return _policies.map((key, policy) => MapEntry(key, {
      'name': policy.name,
      'trigger': policy.trigger.name,
      'action': policy.action.name,
      'priority': policy.priority.name,
      'interval': policy.interval?.inMilliseconds,
      'lastExecuted': policy.lastExecuted?.toIso8601String(),
      'targetTags': policy.targetTags,
      'applicableDataTypes': policy.applicableDataTypes,
    }));
  }

  /// Get statistics snapshot
  Map<String, dynamic> _getStatisticsSnapshot() {
    return _statistics.map((key, stats) => MapEntry(key, {
      'name': stats.name,
      'executionCount': stats.executionCount,
      'successCount': stats.successCount,
      'errorCount': stats.errorCount,
      'errorRate': stats.errorRate,
      'averageExecutionTime': stats.averageExecutionTime.inMilliseconds,
      'lastExecution': stats.lastExecution?.toIso8601String(),
      'lastError': stats.lastError,
    }));
  }

  /// Get triggers snapshot
  List<Map<String, dynamic>> _getTriggersSnapshot() {
    return _triggers.map((trigger) => {
      'type': trigger.type.name,
      'dataTypes': trigger.dataTypes,
    }).toList();
  }

  /// Get manager status
  Map<String, dynamic> _getManagerStatus() {
    return {
      'isActive': _policyTimer?.isActive ?? false,
      'policyCheckInterval': _policyCheckInterval.inMilliseconds,
      'registeredPolicies': _policies.length,
      'activeTriggers': _triggers.length,
      'databaseServiceConnected': _databaseService != null,
      'dataChangeListenerActive': _dataChangeSubscription != null,
    };
  }

  /// Dispose the manager and clean up resources
  Future<void> dispose() async {
    _policyTimer?.cancel();
    await _dataChangeSubscription?.cancel();
    
    _policies.clear();
    _statistics.clear();
    _triggers.clear();
    
    developer.log('Cache invalidation manager disposed', name: 'CacheInvalidationManager');
  }
}

/// Invalidation policy definition
class InvalidationPolicy {
  final String name;
  final InvalidationTriggerType trigger;
  final bool Function(CacheEntry entry) condition;
  final InvalidationAction action;
  final InvalidationPriority priority;
  final Duration? interval;
  final List<String> targetTags;
  final List<String> applicableDataTypes;
  
  DateTime? lastExecuted;

  InvalidationPolicy({
    required this.name,
    required this.trigger,
    required this.condition,
    required this.action,
    required this.priority,
    this.interval,
    this.targetTags = const [],
    this.applicableDataTypes = const [],
    this.lastExecuted,
  });
}

/// Invalidation trigger definition
class InvalidationTrigger {
  final InvalidationTriggerType type;
  final List<String> dataTypes;
  final Future<void> Function(String dataType, Map<String, dynamic> context) callback;

  InvalidationTrigger({
    required this.type,
    required this.dataTypes,
    required this.callback,
  });
}

/// Invalidation statistics tracking
class InvalidationStatistics {
  final String name;
  
  int executionCount = 0;
  int successCount = 0;
  int errorCount = 0;
  Duration totalExecutionTime = Duration.zero;
  DateTime? lastExecution;
  String? lastError;
  DateTime? _currentExecutionStart;
  
  final List<InvalidationExecution> _executions = [];

  InvalidationStatistics(this.name);

  double get errorRate => executionCount > 0 ? (errorCount / executionCount) : 0.0;
  
  Duration get averageExecutionTime {
    return executionCount > 0 
        ? Duration(milliseconds: totalExecutionTime.inMilliseconds ~/ executionCount)
        : Duration.zero;
  }

  void startExecution() {
    _currentExecutionStart = DateTime.now();
    executionCount++;
  }

  void completeExecution({
    required bool success,
    required InvalidationReason reason,
    String? error,
  }) {
    lastExecution = DateTime.now();
    
    Duration? executionTime;
    if (_currentExecutionStart != null) {
      executionTime = lastExecution!.difference(_currentExecutionStart!);
      totalExecutionTime += executionTime;
    }
    
    if (success) {
      successCount++;
    } else {
      errorCount++;
      lastError = error;
    }
    
    // Track individual execution
    _executions.add(InvalidationExecution(
      timestamp: lastExecution!,
      success: success,
      reason: reason,
      executionTime: executionTime ?? Duration.zero,
      error: error,
    ));
    
    _currentExecutionStart = null;
  }

  void cleanupOldEntries(DateTime cutoffTime) {
    _executions.removeWhere((execution) => execution.timestamp.isBefore(cutoffTime));
  }
}

/// Individual invalidation execution record
class InvalidationExecution {
  final DateTime timestamp;
  final bool success;
  final InvalidationReason reason;
  final Duration executionTime;
  final String? error;

  InvalidationExecution({
    required this.timestamp,
    required this.success,
    required this.reason,
    required this.executionTime,
    this.error,
  });
}

/// Invalidation trigger types
enum InvalidationTriggerType {
  time,
  dataChange,
  userAction,
  memoryPressure,
  size,
  manual,
}

/// Invalidation actions
enum InvalidationAction {
  remove,
  evictLru,
  refresh,
  selective,
}

/// Invalidation priorities
enum InvalidationPriority {
  low,
  medium,
  high,
  critical,
}

/// Memory pressure levels
enum MemoryPressureLevel {
  low,
  medium,
  high,
  critical,
}

/// Invalidation reasons
enum InvalidationReason {
  timeExpired,
  dataChange,
  userAction,
  memoryPressure,
  sizeLimit,
  manual,
  policy,
}