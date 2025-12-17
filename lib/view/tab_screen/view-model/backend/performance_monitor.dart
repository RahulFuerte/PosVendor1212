import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

/// Performance monitoring service for database and sync operations
/// Tracks memory usage, query performance, and sync operation metrics
/// Provides comprehensive performance analytics and threshold monitoring
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, List<int>> _queryTimes = {};
  final Map<String, int> _queryCount = {};
  final Map<String, List<int>> _syncTimes = {};
  final Map<String, int> _memorySnapshots = {};
  final List<PerformanceMetric> _performanceHistory = [];
  final List<PerformanceAlert> _performanceAlerts = [];
  final Map<String, PerformanceThreshold> _performanceThresholds = {};
  
  Timer? _memoryMonitorTimer;
  Timer? _alertMonitorTimer;
  bool _isMonitoring = false;
  
  // Performance thresholds (configurable)
  static const int defaultQueryThresholdMs = 1000;
  static const int defaultMemoryThresholdMB = 150;
  static const int defaultSyncThresholdMs = 5000;
  static const double defaultCacheHitRateThreshold = 0.7;

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    developer.log('Performance monitoring started', name: 'PerformanceMonitor');
    
    // Initialize default thresholds
    _initializeDefaultThresholds();
    
    // Monitor memory usage every 5 seconds
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _captureMemorySnapshot();
    });
    
    // Monitor performance alerts every 30 seconds
    _alertMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkPerformanceThresholds();
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    _isMonitoring = false;
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    _alertMonitorTimer?.cancel();
    _alertMonitorTimer = null;
    developer.log('Performance monitoring stopped', name: 'PerformanceMonitor');
  }

  /// Track database query performance
  Future<T> trackQuery<T>(String queryName, Future<T> Function() queryFunction) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await queryFunction();
      stopwatch.stop();
      
      _recordQueryTime(queryName, stopwatch.elapsedMilliseconds);
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordQueryTime('${queryName}_error', stopwatch.elapsedMilliseconds);
      rethrow;
    }
  }

  /// Track sync operation performance
  Future<T> trackSyncOperation<T>(String operationName, Future<T> Function() syncFunction) async {
    final stopwatch = Stopwatch()..start();
    final initialMemory = _getCurrentMemoryUsage();
    
    try {
      final result = await syncFunction();
      stopwatch.stop();
      
      final finalMemory = _getCurrentMemoryUsage();
      _recordSyncOperation(operationName, stopwatch.elapsedMilliseconds, initialMemory, finalMemory);
      
      return result;
    } catch (e) {
      stopwatch.stop();
      final finalMemory = _getCurrentMemoryUsage();
      _recordSyncOperation('${operationName}_error', stopwatch.elapsedMilliseconds, initialMemory, finalMemory);
      rethrow;
    }
  }

  /// Initialize default performance thresholds
  void _initializeDefaultThresholds() {
    _performanceThresholds['query_execution'] = PerformanceThreshold(
      name: 'Query Execution Time',
      type: ThresholdType.queryTime,
      warningThreshold: defaultQueryThresholdMs * 0.7,
      criticalThreshold: defaultQueryThresholdMs.toDouble(),
      unit: 'ms',
    );
    
    _performanceThresholds['memory_usage'] = PerformanceThreshold(
      name: 'Memory Usage',
      type: ThresholdType.memoryUsage,
      warningThreshold: defaultMemoryThresholdMB * 0.8,
      criticalThreshold: defaultMemoryThresholdMB.toDouble(),
      unit: 'MB',
    );
    
    _performanceThresholds['sync_operation'] = PerformanceThreshold(
      name: 'Sync Operation Time',
      type: ThresholdType.syncTime,
      warningThreshold: defaultSyncThresholdMs * 0.7,
      criticalThreshold: defaultSyncThresholdMs.toDouble(),
      unit: 'ms',
    );
    
    _performanceThresholds['cache_hit_rate'] = PerformanceThreshold(
      name: 'Cache Hit Rate',
      type: ThresholdType.cacheHitRate,
      warningThreshold: defaultCacheHitRateThreshold,
      criticalThreshold: defaultCacheHitRateThreshold * 0.5,
      unit: '%',
      isInverted: true, // Lower values are worse
    );
  }

  /// Record query execution time
  void _recordQueryTime(String queryName, int milliseconds) {
    _queryTimes.putIfAbsent(queryName, () => []).add(milliseconds);
    _queryCount[queryName] = (_queryCount[queryName] ?? 0) + 1;
    
    // Keep only last 100 measurements per query
    if (_queryTimes[queryName]!.length > 100) {
      _queryTimes[queryName]!.removeAt(0);
    }
    
    // Check against thresholds and create alerts
    _checkQueryThreshold(queryName, milliseconds);
    
    // Log slow queries (> 1 second)
    if (milliseconds > 1000) {
      developer.log('Slow query detected: $queryName took ${milliseconds}ms', name: 'PerformanceMonitor');
    }
  }

  /// Record sync operation metrics
  void _recordSyncOperation(String operationName, int milliseconds, int initialMemory, int finalMemory) {
    _syncTimes.putIfAbsent(operationName, () => []).add(milliseconds);
    
    // Keep only last 50 sync measurements
    if (_syncTimes[operationName]!.length > 50) {
      _syncTimes[operationName]!.removeAt(0);
    }
    
    final memoryDelta = finalMemory - initialMemory;
    final metric = PerformanceMetric(
      operationName: operationName,
      duration: milliseconds,
      memoryUsage: finalMemory,
      memoryDelta: memoryDelta,
      timestamp: DateTime.now(),
    );
    
    _performanceHistory.add(metric);
    
    // Keep only last 200 performance metrics
    if (_performanceHistory.length > 200) {
      _performanceHistory.removeAt(0);
    }
    
    // Log memory-intensive operations (> 10MB increase)
    if (memoryDelta > 10 * 1024 * 1024) {
      developer.log('Memory-intensive operation: $operationName used ${(memoryDelta / 1024 / 1024).toStringAsFixed(2)}MB', 
                   name: 'PerformanceMonitor');
    }
  }

  /// Check query execution time against thresholds
  void _checkQueryThreshold(String queryName, int milliseconds) {
    final threshold = _performanceThresholds['query_execution'];
    if (threshold == null) return;
    
    AlertLevel? alertLevel;
    if (milliseconds >= threshold.criticalThreshold) {
      alertLevel = AlertLevel.critical;
    } else if (milliseconds >= threshold.warningThreshold) {
      alertLevel = AlertLevel.warning;
    }
    
    if (alertLevel != null) {
      _createAlert(
        type: AlertType.queryPerformance,
        level: alertLevel,
        message: 'Query "$queryName" took ${milliseconds}ms (threshold: ${threshold.criticalThreshold}ms)',
        details: {
          'queryName': queryName,
          'executionTime': milliseconds,
          'threshold': threshold.criticalThreshold,
        },
      );
    }
  }

  /// Check performance thresholds and create alerts
  void checkPerformanceThresholds() {
    try {
      // Check memory usage
      _checkMemoryThreshold();
      
      // Check cache performance
      _checkCachePerformance();
      
      // Clean up old alerts (keep only last 50)
      if (_performanceAlerts.length > 50) {
        _performanceAlerts.removeRange(0, _performanceAlerts.length - 50);
      }
    } catch (e) {
      developer.log('Error checking performance thresholds: $e', name: 'PerformanceMonitor');
    }
  }

  /// Check memory usage against thresholds
  void _checkMemoryThreshold() {
    final currentMemoryMB = _getCurrentMemoryUsage() / 1024 / 1024;
    final threshold = _performanceThresholds['memory_usage'];
    if (threshold == null) return;
    
    AlertLevel? alertLevel;
    if (currentMemoryMB >= threshold.criticalThreshold) {
      alertLevel = AlertLevel.critical;
    } else if (currentMemoryMB >= threshold.warningThreshold) {
      alertLevel = AlertLevel.warning;
    }
    
    if (alertLevel != null) {
      _createAlert(
        type: AlertType.memoryUsage,
        level: alertLevel,
        message: 'High memory usage: ${currentMemoryMB.toStringAsFixed(1)}MB (threshold: ${threshold.criticalThreshold}MB)',
        details: {
          'currentUsageMB': currentMemoryMB,
          'threshold': threshold.criticalThreshold,
        },
      );
    }
  }

  /// Check cache performance
  void _checkCachePerformance() {
    // This would be implemented with actual cache statistics
    // For now, we'll create a placeholder that can be extended
    final threshold = _performanceThresholds['cache_hit_rate'];
    if (threshold == null) return;
    
    // Placeholder for cache hit rate calculation
    // In a real implementation, this would get actual cache statistics
  }

  /// Create a performance alert
  void _createAlert({
    required AlertType type,
    required AlertLevel level,
    required String message,
    Map<String, dynamic>? details,
  }) {
    final alert = PerformanceAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      level: level,
      message: message,
      details: details ?? {},
      timestamp: DateTime.now(),
    );
    
    _performanceAlerts.add(alert);
    
    // Log the alert
    final logLevel = level == AlertLevel.critical ? 'CRITICAL' : 'WARNING';
    developer.log('[$logLevel] Performance Alert: $message', name: 'PerformanceMonitor');
  }

  /// Capture memory usage snapshot
  void _captureMemorySnapshot() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final memoryUsage = _getCurrentMemoryUsage();
    _memorySnapshots[timestamp.toString()] = memoryUsage;
    
    // Keep only last 100 snapshots (about 8 minutes of data)
    if (_memorySnapshots.length > 100) {
      final oldestKey = _memorySnapshots.keys.first;
      _memorySnapshots.remove(oldestKey);
    }
  }

  /// Get current memory usage in bytes
  int _getCurrentMemoryUsage() {
    try {
      // On mobile platforms, use ProcessInfo if available
      if (Platform.isAndroid || Platform.isIOS) {
        return ProcessInfo.currentRss;
      }
      
      // Fallback for other platforms
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get query performance statistics
  Map<String, dynamic> getQueryStatistics() {
    final stats = <String, dynamic>{};
    
    for (final queryName in _queryTimes.keys) {
      final times = _queryTimes[queryName]!;
      final count = _queryCount[queryName] ?? 0;
      
      if (times.isNotEmpty) {
        times.sort();
        final avg = times.reduce((a, b) => a + b) / times.length;
        final median = times[times.length ~/ 2];
        final p95 = times[(times.length * 0.95).floor()];
        final min = times.first;
        final max = times.last;
        
        stats[queryName] = {
          'count': count,
          'averageMs': avg.round(),
          'medianMs': median,
          'p95Ms': p95,
          'minMs': min,
          'maxMs': max,
        };
      }
    }
    
    return stats;
  }

  /// Get sync operation performance statistics
  Map<String, dynamic> getSyncStatistics() {
    final stats = <String, dynamic>{};
    
    for (final operationName in _syncTimes.keys) {
      final times = _syncTimes[operationName]!;
      
      if (times.isNotEmpty) {
        times.sort();
        final avg = times.reduce((a, b) => a + b) / times.length;
        final median = times[times.length ~/ 2];
        final p95 = times[(times.length * 0.95).floor()];
        final min = times.first;
        final max = times.last;
        
        stats[operationName] = {
          'count': times.length,
          'averageMs': avg.round(),
          'medianMs': median,
          'p95Ms': p95,
          'minMs': min,
          'maxMs': max,
        };
      }
    }
    
    return stats;
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStatistics() {
    if (_memorySnapshots.isEmpty) {
      return {
        'currentUsageMB': 0,
        'peakUsageMB': 0,
        'averageUsageMB': 0,
        'snapshotCount': 0,
      };
    }
    
    final values = _memorySnapshots.values.toList();
    values.sort();
    
    final current = values.last;
    final peak = values.last;
    final average = values.reduce((a, b) => a + b) / values.length;
    
    return {
      'currentUsageMB': (current / 1024 / 1024).toStringAsFixed(2),
      'peakUsageMB': (peak / 1024 / 1024).toStringAsFixed(2),
      'averageUsageMB': (average / 1024 / 1024).toStringAsFixed(2),
      'snapshotCount': values.length,
    };
  }

  /// Get comprehensive performance report
  Map<String, dynamic> getPerformanceReport() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'isMonitoring': _isMonitoring,
      'queryStatistics': getQueryStatistics(),
      'syncStatistics': getSyncStatistics(),
      'memoryStatistics': getMemoryStatistics(),
      'recentMetrics': _performanceHistory.take(10).map((m) => m.toMap()).toList(),
      'performanceAlerts': getRecentAlerts(),
      'thresholds': getPerformanceThresholds(),
      'healthScore': calculateHealthScore(),
    };
  }

  /// Get performance analytics dashboard data
  Map<String, dynamic> getPerformanceAnalytics() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'overview': _getPerformanceOverview(),
      'queryAnalytics': _getQueryAnalytics(),
      'memoryAnalytics': _getMemoryAnalytics(),
      'syncAnalytics': _getSyncAnalytics(),
      'alertSummary': _getAlertSummary(),
      'trends': _getPerformanceTrends(),
      'recommendations': getEnhancedRecommendations(),
    };
  }

  /// Get performance overview for dashboard
  Map<String, dynamic> _getPerformanceOverview() {
    final queryStats = getQueryStatistics();
    final memoryStats = getMemoryStatistics();
    final syncStats = getSyncStatistics();
    
    return {
      'totalQueries': _queryCount.values.fold(0, (sum, count) => sum + count),
      'uniqueQueryTypes': queryStats.length,
      'averageQueryTime': _calculateOverallAverageQueryTime(),
      'currentMemoryUsage': memoryStats['currentUsageMB'],
      'peakMemoryUsage': memoryStats['peakUsageMB'],
      'totalSyncOperations': syncStats.values.fold(0, (sum, stats) => sum + (stats['count'] as int)),
      'activeAlerts': _performanceAlerts.where((alert) => 
        DateTime.now().difference(alert.timestamp).inHours < 1).length,
      'healthScore': calculateHealthScore(),
    };
  }

  /// Get detailed query analytics
  Map<String, dynamic> _getQueryAnalytics() {
    final queryStats = getQueryStatistics();
    final slowQueries = <String, dynamic>{};
    final fastQueries = <String, dynamic>{};
    
    for (final entry in queryStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      if (stats['p95Ms'] > 500) {
        slowQueries[entry.key] = stats;
      } else if (stats['p95Ms'] < 100) {
        fastQueries[entry.key] = stats;
      }
    }
    
    return {
      'totalQueryTypes': queryStats.length,
      'slowQueries': slowQueries,
      'fastQueries': fastQueries,
      'queryDistribution': _getQueryDistribution(),
      'performanceByQueryType': queryStats,
    };
  }

  /// Get memory analytics
  Map<String, dynamic> _getMemoryAnalytics() {
    final memoryStats = getMemoryStatistics();
    final memoryTrend = _getMemoryTrend();
    
    return {
      'current': memoryStats,
      'trend': memoryTrend,
      'memoryLeaks': _detectMemoryLeaks(),
      'memoryEfficiency': _calculateMemoryEfficiency(),
    };
  }

  /// Get sync analytics
  Map<String, dynamic> _getSyncAnalytics() {
    final syncStats = getSyncStatistics();
    
    return {
      'operations': syncStats,
      'syncEfficiency': _calculateSyncEfficiency(),
      'syncTrends': _getSyncTrends(),
    };
  }

  /// Get alert summary
  Map<String, dynamic> _getAlertSummary() {
    final recentAlerts = _performanceAlerts.where((alert) => 
      DateTime.now().difference(alert.timestamp).inHours < 24).toList();
    
    final criticalAlerts = recentAlerts.where((alert) => alert.level == AlertLevel.critical).length;
    final warningAlerts = recentAlerts.where((alert) => alert.level == AlertLevel.warning).length;
    
    return {
      'total24h': recentAlerts.length,
      'critical24h': criticalAlerts,
      'warning24h': warningAlerts,
      'alertsByType': _groupAlertsByType(recentAlerts),
      'recentAlerts': recentAlerts.take(10).map((alert) => alert.toMap()).toList(),
    };
  }

  /// Get performance trends
  Map<String, dynamic> _getPerformanceTrends() {
    return {
      'queryPerformanceTrend': _getQueryPerformanceTrend(),
      'memoryUsageTrend': _getMemoryTrend(),
      'alertFrequencyTrend': _getAlertFrequencyTrend(),
    };
  }

  /// Get enhanced performance recommendations based on collected metrics
  List<PerformanceRecommendation> getEnhancedRecommendations() {
    final recommendations = <PerformanceRecommendation>[];
    
    // Check for slow queries
    final queryStats = getQueryStatistics();
    for (final entry in queryStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      if (stats['p95Ms'] > 500) {
        recommendations.add(PerformanceRecommendation(
          type: RecommendationType.queryOptimization,
          priority: stats['p95Ms'] > 1000 ? RecommendationPriority.high : RecommendationPriority.medium,
          title: 'Optimize slow query: ${entry.key}',
          description: 'Query "${entry.key}" has P95 latency of ${stats['p95Ms']}ms',
          impact: 'Reducing query time will improve user experience and reduce resource usage',
          actions: [
            'Add database indexes on frequently queried columns',
            'Consider query result caching',
            'Optimize query structure and joins',
            'Implement pagination for large result sets',
          ],
          estimatedImpact: stats['p95Ms'] > 1000 ? 'High' : 'Medium',
        ));
      }
    }
    
    // Check memory usage
    final memoryStats = getMemoryStatistics();
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    if (currentUsage > 100) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.memoryOptimization,
        priority: currentUsage > 150 ? RecommendationPriority.high : RecommendationPriority.medium,
        title: 'Optimize memory usage',
        description: 'Current memory usage is ${currentUsage.toStringAsFixed(1)}MB',
        impact: 'Reducing memory usage will prevent crashes and improve performance',
        actions: [
          'Clear unused caches',
          'Implement lazy loading for large datasets',
          'Optimize image cache size',
          'Review memory leaks in long-running operations',
        ],
        estimatedImpact: currentUsage > 150 ? 'High' : 'Medium',
      ));
    }
    
    // Check sync performance
    final syncStats = getSyncStatistics();
    for (final entry in syncStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      if (stats['p95Ms'] > 5000) {
        recommendations.add(PerformanceRecommendation(
          type: RecommendationType.syncOptimization,
          priority: stats['p95Ms'] > 10000 ? RecommendationPriority.high : RecommendationPriority.medium,
          title: 'Optimize sync operation: ${entry.key}',
          description: 'Sync operation "${entry.key}" has P95 latency of ${stats['p95Ms']}ms',
          impact: 'Faster sync operations will improve data consistency and user experience',
          actions: [
            'Implement incremental sync',
            'Reduce batch sizes for large operations',
            'Add compression for data transfer',
            'Implement retry logic with exponential backoff',
          ],
          estimatedImpact: stats['p95Ms'] > 10000 ? 'High' : 'Medium',
        ));
      }
    }
    
    // Check for frequent alerts
    final recentAlerts = _performanceAlerts.where((alert) => 
      DateTime.now().difference(alert.timestamp).inHours < 24).toList();
    
    if (recentAlerts.length > 10) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.alertOptimization,
        priority: RecommendationPriority.medium,
        title: 'High alert frequency detected',
        description: '${recentAlerts.length} performance alerts in the last 24 hours',
        impact: 'Reducing alert frequency indicates improved system stability',
        actions: [
          'Review and adjust performance thresholds',
          'Implement proactive performance optimization',
          'Add automated performance tuning',
          'Schedule regular maintenance tasks',
        ],
        estimatedImpact: 'Medium',
      ));
    }
    
    if (recommendations.isEmpty) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.maintenance,
        priority: RecommendationPriority.low,
        title: 'Performance looks good!',
        description: 'No critical performance issues detected',
        impact: 'Continue monitoring to maintain optimal performance',
        actions: [
          'Continue regular performance monitoring',
          'Schedule periodic maintenance tasks',
          'Review performance trends monthly',
        ],
        estimatedImpact: 'Low',
      ));
    }
    
    return recommendations;
  }

  /// Get legacy performance recommendations (for backward compatibility)
  List<String> getPerformanceRecommendations() {
    return getEnhancedRecommendations()
        .map((rec) => '${rec.title}: ${rec.description}')
        .toList();
  }

  /// Clear all performance data
  void clearMetrics() {
    _queryTimes.clear();
    _queryCount.clear();
    _syncTimes.clear();
    _memorySnapshots.clear();
    _performanceHistory.clear();
    developer.log('Performance metrics cleared', name: 'PerformanceMonitor');
  }

  /// Set custom performance threshold
  void setPerformanceThreshold(String key, PerformanceThreshold threshold) {
    _performanceThresholds[key] = threshold;
  }

  /// Get performance thresholds
  Map<String, dynamic> getPerformanceThresholds() {
    return _performanceThresholds.map((key, threshold) => 
      MapEntry(key, threshold.toMap()));
  }

  /// Get recent alerts
  List<Map<String, dynamic>> getRecentAlerts({int limit = 20}) {
    return _performanceAlerts
        .take(limit)
        .map((alert) => alert.toMap())
        .toList();
  }

  /// Calculate overall health score (0-100)
  int calculateHealthScore() {
    int score = 100;
    
    // Deduct points for recent critical alerts
    final recentCriticalAlerts = _performanceAlerts
        .where((alert) => alert.level == AlertLevel.critical && 
               DateTime.now().difference(alert.timestamp).inHours < 24)
        .length;
    score -= recentCriticalAlerts * 15;
    
    // Deduct points for recent warning alerts
    final recentWarningAlerts = _performanceAlerts
        .where((alert) => alert.level == AlertLevel.warning && 
               DateTime.now().difference(alert.timestamp).inHours < 24)
        .length;
    score -= recentWarningAlerts * 5;
    
    // Deduct points for slow queries
    final queryStats = getQueryStatistics();
    final slowQueries = queryStats.values
        .where((stats) => (stats as Map<String, dynamic>)['p95Ms'] > 1000)
        .length;
    score -= slowQueries * 10;
    
    // Deduct points for high memory usage
    final memoryStats = getMemoryStatistics();
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    if (currentUsage > 150) {
      score -= 20;
    } else if (currentUsage > 100) {
      score -= 10;
    }
    
    return score.clamp(0, 100);
  }

  // Helper methods for analytics
  
  double _calculateOverallAverageQueryTime() {
    final queryStats = getQueryStatistics();
    if (queryStats.isEmpty) return 0.0;
    
    double totalTime = 0;
    int totalQueries = 0;
    
    for (final stats in queryStats.values) {
      final statsMap = stats as Map<String, dynamic>;
      totalTime += (statsMap['averageMs'] as int) * (statsMap['count'] as int);
      totalQueries += statsMap['count'] as int;
    }
    
    return totalQueries > 0 ? totalTime / totalQueries : 0.0;
  }

  Map<String, int> _getQueryDistribution() {
    final distribution = <String, int>{};
    for (final entry in _queryCount.entries) {
      final category = _categorizeQuery(entry.key);
      distribution[category] = (distribution[category] ?? 0) + entry.value;
    }
    return distribution;
  }

  String _categorizeQuery(String queryName) {
    if (queryName.contains('get') || queryName.contains('fetch')) return 'Read';
    if (queryName.contains('save') || queryName.contains('insert') || queryName.contains('update')) return 'Write';
    if (queryName.contains('delete')) return 'Delete';
    if (queryName.contains('search')) return 'Search';
    return 'Other';
  }

  Map<String, dynamic> _getMemoryTrend() {
    if (_memorySnapshots.length < 2) return {'trend': 'insufficient_data'};
    
    final values = _memorySnapshots.values.toList();
    final recent = values.length > 10 ? values.sublist(values.length - 10) : values;
    final older = values.take(values.length - 10).toList();
    
    if (older.isEmpty) return {'trend': 'insufficient_data'};
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final changePercent = ((recentAvg - olderAvg) / olderAvg) * 100;
    
    return {
      'trend': changePercent > 10 ? 'increasing' : changePercent < -10 ? 'decreasing' : 'stable',
      'changePercent': changePercent,
      'recentAverage': recentAvg / 1024 / 1024, // Convert to MB
      'olderAverage': olderAvg / 1024 / 1024,
    };
  }

  List<String> _detectMemoryLeaks() {
    final leaks = <String>[];
    final memoryTrend = _getMemoryTrend();
    
    if (memoryTrend['trend'] == 'increasing' && memoryTrend['changePercent'] > 20) {
      leaks.add('Potential memory leak detected: ${memoryTrend['changePercent'].toStringAsFixed(1)}% increase');
    }
    
    return leaks;
  }

  double _calculateMemoryEfficiency() {
    final memoryStats = getMemoryStatistics();
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    final peakUsage = double.tryParse(memoryStats['peakUsageMB'].toString()) ?? 0;
    
    if (peakUsage == 0) return 1.0;
    return (currentUsage / peakUsage).clamp(0.0, 1.0);
  }

  double _calculateSyncEfficiency() {
    final syncStats = getSyncStatistics();
    if (syncStats.isEmpty) return 1.0;
    
    double totalEfficiency = 0;
    for (final stats in syncStats.values) {
      final statsMap = stats as Map<String, dynamic>;
      final avgTime = statsMap['averageMs'] as int;
      // Efficiency decreases as time increases (arbitrary scale)
      final efficiency = 1.0 / (1.0 + (avgTime / 1000.0));
      totalEfficiency += efficiency;
    }
    
    return totalEfficiency / syncStats.length;
  }

  Map<String, dynamic> _getSyncTrends() {
    // Placeholder for sync trend analysis
    return {'trend': 'stable'};
  }

  Map<String, int> _groupAlertsByType(List<PerformanceAlert> alerts) {
    final grouped = <String, int>{};
    for (final alert in alerts) {
      final typeStr = alert.type.toString().split('.').last;
      grouped[typeStr] = (grouped[typeStr] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, dynamic> _getQueryPerformanceTrend() {
    // Placeholder for query performance trend analysis
    return {'trend': 'stable'};
  }

  Map<String, dynamic> _getAlertFrequencyTrend() {
    final now = DateTime.now();
    final last24h = _performanceAlerts.where((alert) => 
      now.difference(alert.timestamp).inHours < 24).length;
    final previous24h = _performanceAlerts.where((alert) => 
      now.difference(alert.timestamp).inHours >= 24 && 
      now.difference(alert.timestamp).inHours < 48).length;
    
    return {
      'current24h': last24h,
      'previous24h': previous24h,
      'trend': last24h > previous24h ? 'increasing' : 
               last24h < previous24h ? 'decreasing' : 'stable',
    };
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    clearMetrics();
  }
}

/// Performance metric data class
class PerformanceMetric {
  final String operationName;
  final int duration;
  final int memoryUsage;
  final int memoryDelta;
  final DateTime timestamp;

  PerformanceMetric({
    required this.operationName,
    required this.duration,
    required this.memoryUsage,
    required this.memoryDelta,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationName': operationName,
      'duration': duration,
      'memoryUsage': memoryUsage,
      'memoryDelta': memoryDelta,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Performance threshold configuration
class PerformanceThreshold {
  final String name;
  final ThresholdType type;
  final double warningThreshold;
  final double criticalThreshold;
  final String unit;
  final bool isInverted; // For metrics where lower values are worse (e.g., cache hit rate)

  PerformanceThreshold({
    required this.name,
    required this.type,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.unit,
    this.isInverted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.toString(),
      'warningThreshold': warningThreshold,
      'criticalThreshold': criticalThreshold,
      'unit': unit,
      'isInverted': isInverted,
    };
  }
}

/// Performance alert data class
class PerformanceAlert {
  final String id;
  final AlertType type;
  final AlertLevel level;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  PerformanceAlert({
    required this.id,
    required this.type,
    required this.level,
    required this.message,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString(),
      'level': level.toString(),
      'message': message,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Performance recommendation data class
class PerformanceRecommendation {
  final RecommendationType type;
  final RecommendationPriority priority;
  final String title;
  final String description;
  final String impact;
  final List<String> actions;
  final String estimatedImpact;

  PerformanceRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.impact,
    required this.actions,
    required this.estimatedImpact,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'priority': priority.toString(),
      'title': title,
      'description': description,
      'impact': impact,
      'actions': actions,
      'estimatedImpact': estimatedImpact,
    };
  }
}

/// Threshold types
enum ThresholdType {
  queryTime,
  memoryUsage,
  syncTime,
  cacheHitRate,
}

/// Alert types
enum AlertType {
  queryPerformance,
  memoryUsage,
  syncPerformance,
  cachePerformance,
}

/// Alert levels
enum AlertLevel {
  warning,
  critical,
}

/// Recommendation types
enum RecommendationType {
  queryOptimization,
  memoryOptimization,
  syncOptimization,
  alertOptimization,
  maintenance,
}

/// Recommendation priorities
enum RecommendationPriority {
  low,
  medium,
  high,
}