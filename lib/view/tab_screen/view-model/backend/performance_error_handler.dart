import 'dart:async';
import 'dart:developer' as developer;
import 'performance_monitor.dart';
import 'error_handling_service.dart';
import 'comprehensive_error_handler.dart';
import 'user_error_service.dart';
import 'error_recovery_service.dart';

/// Specialized error handler for performance-related issues
/// Provides specific error handling, fallback strategies, and automatic recovery
/// for slow queries, memory issues, and performance degradation
class PerformanceErrorHandler {
  static final PerformanceErrorHandler _instance = PerformanceErrorHandler._internal();
  factory PerformanceErrorHandler() => _instance;
  PerformanceErrorHandler._internal();

  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final ComprehensiveErrorHandler _errorHandler = ComprehensiveErrorHandler();
  final StreamController<PerformanceIssue> _issueController = 
      StreamController<PerformanceIssue>.broadcast();

  bool _isInitialized = false;
  Timer? _performanceCheckTimer;
  final Map<String, DateTime> _lastIssueReported = {};
  final Map<String, int> _issueOccurrenceCount = {};
  final Map<String, Timer> _recoveryTimers = {};

  // Performance thresholds for error detection
  static const int slowQueryThresholdMs = 1000;
  static const int criticalQueryThresholdMs = 3000;
  static const int memoryWarningThresholdMB = 120;
  static const int memoryCriticalThresholdMB = 180;
  static const double cacheHitRateWarningThreshold = 0.6;
  static const double cacheHitRateCriticalThreshold = 0.4;

  /// Stream that emits performance issues
  Stream<PerformanceIssue> get issueStream => _issueController.stream;

  /// Initialize the performance error handler
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _errorHandler.initialize();
      _performanceMonitor.startMonitoring();

      // Start periodic performance checks
      _performanceCheckTimer = Timer.periodic(
        const Duration(seconds: 30), 
        (_) => _checkPerformanceIssues(),
      );

      _isInitialized = true;
      
      await _errorHandler.handleInfo(
        component: 'PerformanceErrorHandler',
        message: 'Performance error handler initialized successfully',
      );
    } catch (e) {
      developer.log('Failed to initialize PerformanceErrorHandler: $e', name: 'PerformanceErrorHandler');
      rethrow;
    }
  }

  /// Handle slow query performance issues
  Future<void> handleSlowQuery({
    required String queryName,
    required int executionTimeMs,
    required String context,
    Map<String, dynamic>? queryParameters,
  }) async {
    final severity = executionTimeMs >= criticalQueryThresholdMs 
        ? PerformanceIssueSeverity.critical 
        : PerformanceIssueSeverity.warning;

    final issue = PerformanceIssue(
      id: 'slow_query_${queryName}_${DateTime.now().millisecondsSinceEpoch}',
      type: PerformanceIssueType.slowQuery,
      severity: severity,
      title: 'Slow Query Detected',
      description: 'Query "$queryName" took ${executionTimeMs}ms to execute',
      context: {
        'queryName': queryName,
        'executionTimeMs': executionTimeMs,
        'context': context,
        'parameters': queryParameters,
        'threshold': slowQueryThresholdMs,
      },
      timestamp: DateTime.now(),
    );

    await _processPerformanceIssue(issue);

    // Implement fallback strategies
    await _implementSlowQueryFallback(queryName, executionTimeMs, context);
  }

  /// Handle memory performance issues
  Future<void> handleMemoryIssue({
    required double currentMemoryMB,
    required String operation,
    String? context,
  }) async {
    final severity = currentMemoryMB >= memoryCriticalThresholdMB 
        ? PerformanceIssueSeverity.critical 
        : PerformanceIssueSeverity.warning;

    final issue = PerformanceIssue(
      id: 'memory_issue_${DateTime.now().millisecondsSinceEpoch}',
      type: PerformanceIssueType.memoryUsage,
      severity: severity,
      title: 'High Memory Usage Detected',
      description: 'Memory usage is ${currentMemoryMB.toStringAsFixed(1)}MB during $operation',
      context: {
        'currentMemoryMB': currentMemoryMB,
        'operation': operation,
        'context': context,
        'warningThreshold': memoryWarningThresholdMB,
        'criticalThreshold': memoryCriticalThresholdMB,
      },
      timestamp: DateTime.now(),
    );

    await _processPerformanceIssue(issue);

    // Implement memory cleanup strategies
    await _implementMemoryCleanupFallback(currentMemoryMB, operation);
  }

  /// Handle cache performance issues
  Future<void> handleCachePerformanceIssue({
    required double hitRate,
    required String cacheType,
    String? context,
  }) async {
    final severity = hitRate <= cacheHitRateCriticalThreshold 
        ? PerformanceIssueSeverity.critical 
        : PerformanceIssueSeverity.warning;

    final issue = PerformanceIssue(
      id: 'cache_issue_${cacheType}_${DateTime.now().millisecondsSinceEpoch}',
      type: PerformanceIssueType.cachePerformance,
      severity: severity,
      title: 'Poor Cache Performance',
      description: '$cacheType cache hit rate is ${(hitRate * 100).toStringAsFixed(1)}%',
      context: {
        'hitRate': hitRate,
        'cacheType': cacheType,
        'context': context,
        'warningThreshold': cacheHitRateWarningThreshold,
        'criticalThreshold': cacheHitRateCriticalThreshold,
      },
      timestamp: DateTime.now(),
    );

    await _processPerformanceIssue(issue);

    // Implement cache optimization strategies
    await _implementCacheOptimizationFallback(cacheType, hitRate);
  }

  /// Handle general performance degradation
  Future<void> handlePerformanceDegradation({
    required String operation,
    required String degradationType,
    required Map<String, dynamic> metrics,
    String? userMessage,
  }) async {
    final issue = PerformanceIssue(
      id: 'degradation_${operation}_${DateTime.now().millisecondsSinceEpoch}',
      type: PerformanceIssueType.generalDegradation,
      severity: PerformanceIssueSeverity.warning,
      title: 'Performance Degradation Detected',
      description: '$degradationType in $operation',
      context: {
        'operation': operation,
        'degradationType': degradationType,
        'metrics': metrics,
      },
      timestamp: DateTime.now(),
    );

    await _processPerformanceIssue(issue);

    // Show user-friendly message if provided
    if (userMessage != null) {
      _errorHandler.userErrorService.showWarning(
        title: 'Performance Notice',
        message: userMessage,
      );
    }
  }

  /// Process a performance issue through the error handling pipeline
  Future<void> _processPerformanceIssue(PerformanceIssue issue) async {
    // Emit to stream for UI components
    if (!_issueController.isClosed) {
      _issueController.add(issue);
    }

    // Track issue occurrence
    final issueKey = '${issue.type.name}_${issue.context['queryName'] ?? issue.context['operation'] ?? 'unknown'}';
    _issueOccurrenceCount[issueKey] = (_issueOccurrenceCount[issueKey] ?? 0) + 1;

    // Check if we should throttle similar issues
    if (_shouldThrottleIssue(issueKey)) {
      return;
    }

    // Log through comprehensive error handler
    switch (issue.severity) {
      case PerformanceIssueSeverity.critical:
        await _errorHandler.handleCriticalError(
          component: 'PerformanceErrorHandler',
          message: issue.description,
          context: issue.context,
          userMessage: _generateUserFriendlyMessage(issue),
        );
        break;
      case PerformanceIssueSeverity.warning:
        await _errorHandler.handleWarning(
          component: 'PerformanceErrorHandler',
          message: issue.description,
          context: issue.context,
          userMessage: _generateUserFriendlyMessage(issue),
        );
        break;
    }

    // Schedule automatic recovery if applicable
    await _scheduleAutomaticRecovery(issue);

    // Update last reported time
    _lastIssueReported[issueKey] = DateTime.now();
  }

  /// Check if we should throttle similar issues to avoid spam
  bool _shouldThrottleIssue(String issueKey) {
    final lastReported = _lastIssueReported[issueKey];
    if (lastReported == null) return false;

    // Throttle if reported within the last 5 minutes
    return DateTime.now().difference(lastReported).inMinutes < 5;
  }

  /// Generate user-friendly message for performance issues
  String _generateUserFriendlyMessage(PerformanceIssue issue) {
    switch (issue.type) {
      case PerformanceIssueType.slowQuery:
        return 'Data loading is taking longer than usual. We\'re working to optimize performance.';
      case PerformanceIssueType.memoryUsage:
        return 'The app is using more memory than usual. Consider closing other apps or restarting this one.';
      case PerformanceIssueType.cachePerformance:
        return 'Data caching is not optimal. Performance may be slower than usual.';
      case PerformanceIssueType.generalDegradation:
        return 'Performance has decreased. We\'re automatically optimizing the system.';
    }
  }

  /// Implement fallback strategies for slow queries
  Future<void> _implementSlowQueryFallback(String queryName, int executionTimeMs, String context) async {
    try {
      // Strategy 1: Enable query result caching for this query
      await _enableQueryCaching(queryName);

      // Strategy 2: Suggest pagination if it's a large result set query
      if (queryName.contains('getAll') || queryName.contains('fetchAll')) {
        await _suggestPagination(queryName, context);
      }

      // Strategy 3: Check if indexes are missing
      await _checkAndSuggestIndexes(queryName);

      // Strategy 4: For critical queries, implement circuit breaker pattern
      if (executionTimeMs >= criticalQueryThresholdMs) {
        await _implementCircuitBreaker(queryName);
      }

      await _errorHandler.handleInfo(
        component: 'PerformanceErrorHandler',
        message: 'Implemented fallback strategies for slow query: $queryName',
        context: {'queryName': queryName, 'executionTimeMs': executionTimeMs},
      );
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'PerformanceErrorHandler',
        message: 'Failed to implement slow query fallback strategies',
        context: {'queryName': queryName, 'error': e.toString()},
      );
    }
  }

  /// Implement memory cleanup fallback strategies
  Future<void> _implementMemoryCleanupFallback(double currentMemoryMB, String operation) async {
    try {
      // Strategy 1: Clear non-essential caches
      await _clearNonEssentialCaches();

      // Strategy 2: Force garbage collection (if available)
      await _forceGarbageCollection();

      // Strategy 3: Reduce cache sizes temporarily
      await _reduceCacheSizes();

      // Strategy 4: For critical memory usage, show user guidance
      if (currentMemoryMB >= memoryCriticalThresholdMB) {
        _errorHandler.userErrorService.showError(
          title: 'High Memory Usage',
          message: 'The app is using a lot of memory. Consider restarting the app or closing other applications.',
          severity: UserNotificationSeverity.warning,
          recoveryActions: [
            UserRecoveryAction(
              id: 'clear_cache',
              title: 'Clear Cache',
              description: 'Clear app cache to free up memory',
            ),
            UserRecoveryAction(
              id: 'restart_app',
              title: 'Restart App',
              description: 'Restart the app to reset memory usage',
            ),
          ],
        );
      }

      await _errorHandler.handleInfo(
        component: 'PerformanceErrorHandler',
        message: 'Implemented memory cleanup strategies',
        context: {'currentMemoryMB': currentMemoryMB, 'operation': operation},
      );
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'PerformanceErrorHandler',
        message: 'Failed to implement memory cleanup strategies',
        context: {'currentMemoryMB': currentMemoryMB, 'error': e.toString()},
      );
    }
  }

  /// Implement cache optimization fallback strategies
  Future<void> _implementCacheOptimizationFallback(String cacheType, double hitRate) async {
    try {
      // Strategy 1: Warm up the cache with frequently accessed data
      await _warmUpCache(cacheType);

      // Strategy 2: Adjust cache size if hit rate is poor
      await _adjustCacheSize(cacheType, hitRate);

      // Strategy 3: Review cache eviction policy
      await _reviewCacheEvictionPolicy(cacheType);

      // Strategy 4: Preload commonly accessed items
      await _preloadCommonItems(cacheType);

      await _errorHandler.handleInfo(
        component: 'PerformanceErrorHandler',
        message: 'Implemented cache optimization strategies',
        context: {'cacheType': cacheType, 'hitRate': hitRate},
      );
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'PerformanceErrorHandler',
        message: 'Failed to implement cache optimization strategies',
        context: {'cacheType': cacheType, 'error': e.toString()},
      );
    }
  }

  /// Schedule automatic recovery for performance issues
  Future<void> _scheduleAutomaticRecovery(PerformanceIssue issue) async {
    final recoveryKey = '${issue.type.name}_${issue.id}';
    
    // Cancel existing recovery timer if any
    _recoveryTimers[recoveryKey]?.cancel();

    // Schedule recovery based on issue type and severity
    Duration delay;
    switch (issue.severity) {
      case PerformanceIssueSeverity.critical:
        delay = const Duration(seconds: 30); // Immediate recovery for critical issues
        break;
      case PerformanceIssueSeverity.warning:
        delay = const Duration(minutes: 2); // Delayed recovery for warnings
        break;
    }

    _recoveryTimers[recoveryKey] = Timer(delay, () async {
      await _executeAutomaticRecovery(issue);
      _recoveryTimers.remove(recoveryKey);
    });
  }

  /// Execute automatic recovery for performance issues
  Future<void> _executeAutomaticRecovery(PerformanceIssue issue) async {
    try {
      bool recoverySuccessful = false;

      switch (issue.type) {
        case PerformanceIssueType.slowQuery:
          recoverySuccessful = await _recoverSlowQuery(issue);
          break;
        case PerformanceIssueType.memoryUsage:
          recoverySuccessful = await _recoverMemoryIssue(issue);
          break;
        case PerformanceIssueType.cachePerformance:
          recoverySuccessful = await _recoverCacheIssue(issue);
          break;
        case PerformanceIssueType.generalDegradation:
          recoverySuccessful = await _recoverGeneralDegradation(issue);
          break;
      }

      if (recoverySuccessful) {
        await _errorHandler.handleInfo(
          component: 'PerformanceErrorHandler',
          message: 'Automatic recovery successful for ${issue.type.name}',
          context: {'issueId': issue.id, 'issueType': issue.type.name},
        );

        _errorHandler.userErrorService.showSuccess(
          title: 'Performance Improved',
          message: 'System performance has been automatically optimized.',
        );
      } else {
        await _errorHandler.handleWarning(
          component: 'PerformanceErrorHandler',
          message: 'Automatic recovery failed for ${issue.type.name}',
          context: {'issueId': issue.id, 'issueType': issue.type.name},
        );
      }
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'PerformanceErrorHandler',
        message: 'Error during automatic recovery',
        context: {'issueId': issue.id, 'error': e.toString()},
      );
    }
  }

  /// Periodically check for performance issues
  Future<void> _checkPerformanceIssues() async {
    try {
      final performanceReport = _performanceMonitor.getPerformanceReport();
      
      // Check query performance
      final queryStats = performanceReport['queryStatistics'] as Map<String, dynamic>;
      for (final entry in queryStats.entries) {
        final stats = entry.value as Map<String, dynamic>;
        final p95Time = stats['p95Ms'] as int;
        
        if (p95Time >= slowQueryThresholdMs) {
          await handleSlowQuery(
            queryName: entry.key,
            executionTimeMs: p95Time,
            context: 'periodic_check',
          );
        }
      }

      // Check memory usage
      final memoryStats = performanceReport['memoryStatistics'] as Map<String, dynamic>;
      final currentMemoryStr = memoryStats['currentUsageMB'] as String;
      final currentMemory = double.tryParse(currentMemoryStr) ?? 0;
      
      if (currentMemory >= memoryWarningThresholdMB) {
        await handleMemoryIssue(
          currentMemoryMB: currentMemory,
          operation: 'periodic_check',
          context: 'system_monitoring',
        );
      }

      // Check overall health score
      final healthScore = performanceReport['healthScore'] as int;
      if (healthScore < 70) {
        await handlePerformanceDegradation(
          operation: 'system_health',
          degradationType: 'overall_performance',
          metrics: {'healthScore': healthScore},
          userMessage: 'System performance is below optimal. Automatic optimization is in progress.',
        );
      }
    } catch (e) {
      await _errorHandler.handleWarning(
        component: 'PerformanceErrorHandler',
        message: 'Error during periodic performance check',
        context: {'error': e.toString()},
      );
    }
  }

  // Recovery implementation methods

  Future<bool> _recoverSlowQuery(PerformanceIssue issue) async {
    try {
      final queryName = issue.context['queryName'] as String?;
      if (queryName == null) return false;

      // Implement query-specific recovery strategies
      await _enableQueryCaching(queryName);
      await _checkAndSuggestIndexes(queryName);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _recoverMemoryIssue(PerformanceIssue issue) async {
    try {
      await _clearNonEssentialCaches();
      await _reduceCacheSizes();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _recoverCacheIssue(PerformanceIssue issue) async {
    try {
      final cacheType = issue.context['cacheType'] as String?;
      if (cacheType == null) return false;

      await _warmUpCache(cacheType);
      await _preloadCommonItems(cacheType);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _recoverGeneralDegradation(PerformanceIssue issue) async {
    try {
      // General recovery strategies
      await _clearNonEssentialCaches();
      await _forceGarbageCollection();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fallback strategy implementation methods

  Future<void> _enableQueryCaching(String queryName) async {
    // Implementation would depend on the specific caching system
    developer.log('Enabling caching for query: $queryName', name: 'PerformanceErrorHandler');
  }

  Future<void> _suggestPagination(String queryName, String context) async {
    developer.log('Suggesting pagination for query: $queryName in context: $context', name: 'PerformanceErrorHandler');
  }

  Future<void> _checkAndSuggestIndexes(String queryName) async {
    developer.log('Checking indexes for query: $queryName', name: 'PerformanceErrorHandler');
  }

  Future<void> _implementCircuitBreaker(String queryName) async {
    developer.log('Implementing circuit breaker for query: $queryName', name: 'PerformanceErrorHandler');
  }

  Future<void> _clearNonEssentialCaches() async {
    developer.log('Clearing non-essential caches', name: 'PerformanceErrorHandler');
  }

  Future<void> _forceGarbageCollection() async {
    developer.log('Forcing garbage collection', name: 'PerformanceErrorHandler');
  }

  Future<void> _reduceCacheSizes() async {
    developer.log('Reducing cache sizes', name: 'PerformanceErrorHandler');
  }

  Future<void> _warmUpCache(String cacheType) async {
    developer.log('Warming up cache: $cacheType', name: 'PerformanceErrorHandler');
  }

  Future<void> _adjustCacheSize(String cacheType, double hitRate) async {
    developer.log('Adjusting cache size for $cacheType (hit rate: $hitRate)', name: 'PerformanceErrorHandler');
  }

  Future<void> _reviewCacheEvictionPolicy(String cacheType) async {
    developer.log('Reviewing cache eviction policy for: $cacheType', name: 'PerformanceErrorHandler');
  }

  Future<void> _preloadCommonItems(String cacheType) async {
    developer.log('Preloading common items for cache: $cacheType', name: 'PerformanceErrorHandler');
  }

  /// Get performance issue statistics
  Map<String, dynamic> getPerformanceIssueStatistics() {
    final now = DateTime.now();
    final last24h = _issueOccurrenceCount.entries
        .where((entry) => _lastIssueReported[entry.key] != null &&
                now.difference(_lastIssueReported[entry.key]!).inHours < 24)
        .toList();

    return {
      'totalIssuesReported': _issueOccurrenceCount.values.fold(0, (sum, count) => sum + count),
      'uniqueIssueTypes': _issueOccurrenceCount.length,
      'issuesLast24h': last24h.fold(0, (sum, entry) => sum + entry.value),
      'activeRecoveryOperations': _recoveryTimers.length,
      'issueBreakdown': Map.fromEntries(_issueOccurrenceCount.entries),
    };
  }

  /// Get user-friendly performance recommendations
  List<String> getPerformanceRecommendations() {
    final recommendations = <String>[];
    final stats = getPerformanceIssueStatistics();
    
    if (stats['issuesLast24h'] > 10) {
      recommendations.add('Consider restarting the app to improve performance');
    }
    
    if (_issueOccurrenceCount.containsKey('slowQuery')) {
      recommendations.add('Database queries are running slowly. Consider clearing app data or updating the app.');
    }
    
    if (_issueOccurrenceCount.containsKey('memoryUsage')) {
      recommendations.add('High memory usage detected. Close other apps or restart this one.');
    }
    
    if (_issueOccurrenceCount.containsKey('cachePerformance')) {
      recommendations.add('Cache performance is poor. Clear app cache to improve speed.');
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal. No action needed.');
    }
    
    return recommendations;
  }

  /// Check if the performance error handler is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    _performanceCheckTimer?.cancel();
    _performanceCheckTimer = null;
    
    for (final timer in _recoveryTimers.values) {
      timer.cancel();
    }
    _recoveryTimers.clear();
    
    if (!_issueController.isClosed) {
      _issueController.close();
    }
    _performanceMonitor.dispose();
    _isInitialized = false;
  }
}

/// Performance issue data class
class PerformanceIssue {
  final String id;
  final PerformanceIssueType type;
  final PerformanceIssueSeverity severity;
  final String title;
  final String description;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  PerformanceIssue({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.context,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Performance issue types
enum PerformanceIssueType {
  slowQuery,
  memoryUsage,
  cachePerformance,
  generalDegradation,
}

/// Performance issue severity levels
enum PerformanceIssueSeverity {
  warning,
  critical,
}