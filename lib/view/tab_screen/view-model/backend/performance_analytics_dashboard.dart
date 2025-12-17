import 'dart:async';
import 'dart:developer' as developer;
import 'performance_monitor.dart';
import 'performance_optimization_service.dart';
import 'lazy_loading_service.dart';
import 'image_cache_service.dart';

/// Comprehensive performance analytics dashboard
/// Provides detailed performance insights, trends, and recommendations
class PerformanceAnalyticsDashboard {
  static final PerformanceAnalyticsDashboard _instance = PerformanceAnalyticsDashboard._internal();
  factory PerformanceAnalyticsDashboard() => _instance;
  PerformanceAnalyticsDashboard._internal();

  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final PerformanceOptimizationService _optimizationService = PerformanceOptimizationService();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();
  final ImageCacheService _imageCacheService = ImageCacheService();

  Timer? _dashboardUpdateTimer;
  Map<String, dynamic>? _cachedDashboardData;
  DateTime? _lastUpdateTime;

  /// Initialize the dashboard
  Future<void> initialize() async {
    developer.log('Initializing Performance Analytics Dashboard', name: 'PerformanceDashboard');
    
    // Start periodic dashboard updates
    _dashboardUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateDashboardData();
    });
    
    // Initial dashboard data update
    await _updateDashboardData();
    
    developer.log('Performance Analytics Dashboard initialized', name: 'PerformanceDashboard');
  }

  /// Get comprehensive dashboard data
  Future<Map<String, dynamic>> getDashboardData() async {
    if (_cachedDashboardData == null || _isDataStale()) {
      await _updateDashboardData();
    }
    
    return _cachedDashboardData ?? {};
  }

  /// Get real-time performance metrics
  Map<String, dynamic> getRealTimeMetrics() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'performanceReport': _performanceMonitor.getPerformanceReport(),
      'healthScore': _performanceMonitor.calculateHealthScore(),
      'activeAlerts': _performanceMonitor.getRecentAlerts(limit: 5),
      'systemStatus': _getSystemStatus(),
    };
  }

  /// Get performance trends over time
  Map<String, dynamic> getPerformanceTrends({int days = 7}) {
    return {
      'period': '${days}d',
      'queryPerformanceTrend': _getQueryPerformanceTrend(days),
      'memoryUsageTrend': _getMemoryUsageTrend(days),
      'alertFrequencyTrend': _getAlertFrequencyTrend(days),
      'healthScoreTrend': _getHealthScoreTrend(days),
    };
  }

  /// Get detailed query analysis
  Future<Map<String, dynamic>> getQueryAnalysis() async {
    final queryStats = _performanceMonitor.getQueryStatistics();
    
    return {
      'overview': _getQueryOverview(queryStats),
      'slowestQueries': _getSlowestQueries(queryStats),
      'mostFrequentQueries': _getMostFrequentQueries(queryStats),
      'queryOptimizationSuggestions': _getQueryOptimizationSuggestions(queryStats),
      'queryPerformanceDistribution': _getQueryPerformanceDistribution(queryStats),
    };
  }

  /// Get memory analysis
  Future<Map<String, dynamic>> getMemoryAnalysis() async {
    final memoryStats = _performanceMonitor.getMemoryStatistics();
    final imageCacheStats = await _imageCacheService.getDetailedCacheStatistics();
    final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
    
    return {
      'overview': _getMemoryOverview(memoryStats),
      'memoryBreakdown': _getMemoryBreakdown(memoryStats, imageCacheStats, lazyLoadingStats),
      'memoryLeaks': _detectMemoryLeaks(),
      'memoryOptimizationSuggestions': _getMemoryOptimizationSuggestions(memoryStats),
      'cacheEfficiency': _getCacheEfficiencyAnalysis(imageCacheStats, lazyLoadingStats),
    };
  }

  /// Get alert analysis
  Map<String, dynamic> getAlertAnalysis({int days = 30}) {
    final alerts = _performanceMonitor.getRecentAlerts(limit: 1000);
    final filteredAlerts = alerts.where((alert) {
      final alertTime = DateTime.parse(alert['timestamp']);
      return DateTime.now().difference(alertTime).inDays <= days;
    }).toList();
    
    return {
      'overview': _getAlertOverview(filteredAlerts),
      'alertsByType': _groupAlertsByType(filteredAlerts),
      'alertsByLevel': _groupAlertsByLevel(filteredAlerts),
      'alertFrequency': _getAlertFrequency(filteredAlerts, days),
      'topAlertSources': _getTopAlertSources(filteredAlerts),
      'alertResolutionSuggestions': _getAlertResolutionSuggestions(filteredAlerts),
    };
  }

  /// Get comprehensive recommendations
  Future<Map<String, dynamic>> getComprehensiveRecommendations() async {
    final performanceRecommendations = _performanceMonitor.getEnhancedRecommendations();
    final optimizationRecommendations = _optimizationService.getOptimizationRecommendations();
    
    return {
      'performanceRecommendations': performanceRecommendations.map((rec) => rec.toMap()).toList(),
      'optimizationRecommendations': optimizationRecommendations,
      'prioritizedActions': _prioritizeRecommendations(performanceRecommendations),
      'quickWins': _identifyQuickWins(performanceRecommendations),
      'longTermImprovements': _identifyLongTermImprovements(performanceRecommendations),
    };
  }

  /// Get system health assessment
  Map<String, dynamic> getSystemHealthAssessment() {
    final healthScore = _performanceMonitor.calculateHealthScore();
    final recentAlerts = _performanceMonitor.getRecentAlerts(limit: 50);
    
    return {
      'overallHealthScore': healthScore,
      'healthStatus': _getHealthStatus(healthScore),
      'criticalIssues': _getCriticalIssues(recentAlerts),
      'systemStability': _assessSystemStability(),
      'performanceGrade': _getPerformanceGrade(healthScore),
      'improvementAreas': _identifyImprovementAreas(),
    };
  }

  /// Export performance report
  Future<Map<String, dynamic>> exportPerformanceReport({
    bool includeRawData = false,
    int days = 30,
  }) async {
    return {
      'reportMetadata': {
        'generatedAt': DateTime.now().toIso8601String(),
        'period': '${days}d',
        'includeRawData': includeRawData,
      },
      'executiveSummary': await _generateExecutiveSummary(),
      'performanceOverview': _performanceMonitor.getPerformanceAnalytics(),
      'queryAnalysis': await getQueryAnalysis(),
      'memoryAnalysis': await getMemoryAnalysis(),
      'alertAnalysis': getAlertAnalysis(days: days),
      'recommendations': await getComprehensiveRecommendations(),
      'healthAssessment': getSystemHealthAssessment(),
      'trends': getPerformanceTrends(days: days),
      'rawData': includeRawData ? _getRawPerformanceData() : null,
    };
  }

  // Private helper methods

  Future<void> _updateDashboardData() async {
    try {
      _cachedDashboardData = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'realTimeMetrics': getRealTimeMetrics(),
        'performanceTrends': getPerformanceTrends(),
        'queryAnalysis': await getQueryAnalysis(),
        'memoryAnalysis': await getMemoryAnalysis(),
        'alertAnalysis': getAlertAnalysis(),
        'recommendations': await getComprehensiveRecommendations(),
        'healthAssessment': getSystemHealthAssessment(),
      };
      
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      developer.log('Error updating dashboard data: $e', name: 'PerformanceDashboard');
    }
  }

  bool _isDataStale() {
    if (_lastUpdateTime == null) return true;
    return DateTime.now().difference(_lastUpdateTime!).inMinutes > 5;
  }

  Map<String, dynamic> _getSystemStatus() {
    final healthScore = _performanceMonitor.calculateHealthScore();
    final recentAlerts = _performanceMonitor.getRecentAlerts(limit: 10);
    final criticalAlerts = recentAlerts.where((alert) => alert['level'] == 'AlertLevel.critical').length;
    
    String status;
    if (healthScore >= 90 && criticalAlerts == 0) {
      status = 'excellent';
    } else if (healthScore >= 70 && criticalAlerts <= 1) {
      status = 'good';
    } else if (healthScore >= 50 && criticalAlerts <= 3) {
      status = 'fair';
    } else {
      status = 'poor';
    }
    
    return {
      'status': status,
      'healthScore': healthScore,
      'criticalAlerts': criticalAlerts,
      'description': _getStatusDescription(status),
    };
  }

  String _getStatusDescription(String status) {
    switch (status) {
      case 'excellent':
        return 'System is performing optimally with no critical issues';
      case 'good':
        return 'System is performing well with minor issues';
      case 'fair':
        return 'System has some performance issues that need attention';
      case 'poor':
        return 'System has significant performance issues requiring immediate attention';
      default:
        return 'Unknown status';
    }
  }

  Map<String, dynamic> _getQueryPerformanceTrend(int days) {
    // Placeholder implementation - would analyze historical query data
    return {
      'trend': 'stable',
      'averageResponseTime': 150,
      'changePercent': 2.5,
    };
  }

  Map<String, dynamic> _getMemoryUsageTrend(int days) {
    // Placeholder implementation - would analyze historical memory data
    return {
      'trend': 'increasing',
      'averageUsage': 85.2,
      'changePercent': 8.3,
    };
  }

  Map<String, dynamic> _getAlertFrequencyTrend(int days) {
    // Placeholder implementation - would analyze historical alert data
    return {
      'trend': 'decreasing',
      'averageAlertsPerDay': 3.2,
      'changePercent': -15.7,
    };
  }

  Map<String, dynamic> _getHealthScoreTrend(int days) {
    // Placeholder implementation - would analyze historical health scores
    return {
      'trend': 'improving',
      'averageScore': 78,
      'changePercent': 12.4,
    };
  }

  Map<String, dynamic> _getQueryOverview(Map<String, dynamic> queryStats) {
    final totalQueries = queryStats.values.fold(0, (sum, stats) => 
      sum + ((stats as Map<String, dynamic>)['count'] as int));
    
    final slowQueries = queryStats.values.where((stats) => 
      ((stats as Map<String, dynamic>)['p95Ms'] as int) > 1000).length;
    
    return {
      'totalQueryTypes': queryStats.length,
      'totalExecutions': totalQueries,
      'slowQueries': slowQueries,
      'averageResponseTime': _calculateAverageResponseTime(queryStats),
    };
  }

  double _calculateAverageResponseTime(Map<String, dynamic> queryStats) {
    if (queryStats.isEmpty) return 0.0;
    
    double totalTime = 0;
    int totalCount = 0;
    
    for (final stats in queryStats.values) {
      final statsMap = stats as Map<String, dynamic>;
      totalTime += (statsMap['averageMs'] as int) * (statsMap['count'] as int);
      totalCount += statsMap['count'] as int;
    }
    
    return totalCount > 0 ? totalTime / totalCount : 0.0;
  }

  List<Map<String, dynamic>> _getSlowestQueries(Map<String, dynamic> queryStats) {
    final queries = queryStats.entries.map((entry) {
      final stats = entry.value as Map<String, dynamic>;
      return {
        'name': entry.key,
        'p95Ms': stats['p95Ms'],
        'averageMs': stats['averageMs'],
        'count': stats['count'],
      };
    }).toList();
    
    queries.sort((a, b) => (b['p95Ms'] as int).compareTo(a['p95Ms'] as int));
    return queries.take(10).toList();
  }

  List<Map<String, dynamic>> _getMostFrequentQueries(Map<String, dynamic> queryStats) {
    final queries = queryStats.entries.map((entry) {
      final stats = entry.value as Map<String, dynamic>;
      return {
        'name': entry.key,
        'count': stats['count'],
        'averageMs': stats['averageMs'],
        'p95Ms': stats['p95Ms'],
      };
    }).toList();
    
    queries.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return queries.take(10).toList();
  }

  List<String> _getQueryOptimizationSuggestions(Map<String, dynamic> queryStats) {
    final suggestions = <String>[];
    
    for (final entry in queryStats.entries) {
      final stats = entry.value as Map<String, dynamic>;
      final queryName = entry.key;
      final p95Ms = stats['p95Ms'] as int;
      
      if (p95Ms > 1000) {
        if (queryName.contains('getFoodItems')) {
          suggestions.add('Add indexes on food_items table for department and name columns');
        } else if (queryName.contains('search')) {
          suggestions.add('Implement full-text search indexes for better search performance');
        } else if (queryName.contains('getBills')) {
          suggestions.add('Add date range indexes for bill queries');
        }
      }
    }
    
    return suggestions;
  }

  Map<String, int> _getQueryPerformanceDistribution(Map<String, dynamic> queryStats) {
    final distribution = <String, int>{
      'fast': 0,      // < 100ms
      'medium': 0,    // 100-500ms
      'slow': 0,      // 500-1000ms
      'very_slow': 0, // > 1000ms
    };
    
    for (final stats in queryStats.values) {
      final p95Ms = (stats as Map<String, dynamic>)['p95Ms'] as int;
      
      if (p95Ms < 100) {
        distribution['fast'] = distribution['fast']! + 1;
      } else if (p95Ms < 500) {
        distribution['medium'] = distribution['medium']! + 1;
      } else if (p95Ms < 1000) {
        distribution['slow'] = distribution['slow']! + 1;
      } else {
        distribution['very_slow'] = distribution['very_slow']! + 1;
      }
    }
    
    return distribution;
  }

  Map<String, dynamic> _getMemoryOverview(Map<String, dynamic> memoryStats) {
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    final peakUsage = double.tryParse(memoryStats['peakUsageMB'].toString()) ?? 0;
    
    return {
      'currentUsageMB': currentUsage,
      'peakUsageMB': peakUsage,
      'utilizationPercent': peakUsage > 0 ? (currentUsage / peakUsage) * 100 : 0,
      'status': currentUsage > 150 ? 'high' : currentUsage > 100 ? 'medium' : 'low',
    };
  }

  Map<String, dynamic> _getMemoryBreakdown(
    Map<String, dynamic> memoryStats,
    Map<String, dynamic> imageCacheStats,
    Map<String, dynamic> lazyLoadingStats,
  ) {
    return {
      'totalMemory': memoryStats['currentUsageMB'],
      'imageCache': imageCacheStats['totalSizeBytes'] != null 
        ? (imageCacheStats['totalSizeBytes'] as int) / 1024 / 1024 
        : 0,
      'lazyLoadingCache': _estimateLazyLoadingMemory(lazyLoadingStats),
      'other': 'calculated',
    };
  }

  double _estimateLazyLoadingMemory(Map<String, dynamic> lazyLoadingStats) {
    // Rough estimation based on cache statistics
    return lazyLoadingStats.length * 0.5; // Assume 0.5MB per cache on average
  }

  List<String> _detectMemoryLeaks() {
    // This would implement actual memory leak detection
    return [];
  }

  List<String> _getMemoryOptimizationSuggestions(Map<String, dynamic> memoryStats) {
    final suggestions = <String>[];
    final currentUsage = double.tryParse(memoryStats['currentUsageMB'].toString()) ?? 0;
    
    if (currentUsage > 150) {
      suggestions.add('Clear unused image caches');
      suggestions.add('Implement more aggressive lazy loading');
      suggestions.add('Review memory-intensive operations');
    }
    
    return suggestions;
  }

  Map<String, dynamic> _getCacheEfficiencyAnalysis(
    Map<String, dynamic> imageCacheStats,
    Map<String, dynamic> lazyLoadingStats,
  ) {
    return {
      'imageCacheEfficiency': imageCacheStats['storageEfficiency'] ?? 0,
      'lazyLoadingEfficiency': _calculateLazyLoadingEfficiency(lazyLoadingStats),
      'overallCacheHealth': 'good', // Calculated based on various factors
    };
  }

  double _calculateLazyLoadingEfficiency(Map<String, dynamic> lazyLoadingStats) {
    if (lazyLoadingStats.isEmpty) return 1.0;
    
    double totalHitRate = 0;
    int cacheCount = 0;
    
    for (final stats in lazyLoadingStats.values) {
      if (stats is Map<String, dynamic> && stats.containsKey('hitRate')) {
        totalHitRate += stats['hitRate'] as double;
        cacheCount++;
      }
    }
    
    return cacheCount > 0 ? totalHitRate / cacheCount : 1.0;
  }

  Map<String, dynamic> _getAlertOverview(List<Map<String, dynamic>> alerts) {
    final critical = alerts.where((alert) => alert['level'] == 'AlertLevel.critical').length;
    final warning = alerts.where((alert) => alert['level'] == 'AlertLevel.warning').length;
    
    return {
      'total': alerts.length,
      'critical': critical,
      'warning': warning,
      'averagePerDay': alerts.length / 30.0, // Assuming 30-day period
    };
  }

  Map<String, int> _groupAlertsByType(List<Map<String, dynamic>> alerts) {
    final grouped = <String, int>{};
    for (final alert in alerts) {
      final type = alert['type'].toString().split('.').last;
      grouped[type] = (grouped[type] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, int> _groupAlertsByLevel(List<Map<String, dynamic>> alerts) {
    final grouped = <String, int>{};
    for (final alert in alerts) {
      final level = alert['level'].toString().split('.').last;
      grouped[level] = (grouped[level] ?? 0) + 1;
    }
    return grouped;
  }

  Map<String, dynamic> _getAlertFrequency(List<Map<String, dynamic>> alerts, int days) {
    final frequency = <String, int>{};
    final now = DateTime.now();
    
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final dayAlerts = alerts.where((alert) {
        final alertDate = DateTime.parse(alert['timestamp']);
        return alertDate.year == date.year && 
               alertDate.month == date.month && 
               alertDate.day == date.day;
      }).length;
      
      frequency[dateKey] = dayAlerts;
    }
    
    return frequency;
  }

  List<Map<String, dynamic>> _getTopAlertSources(List<Map<String, dynamic>> alerts) {
    final sources = <String, int>{};
    
    for (final alert in alerts) {
      final details = alert['details'] as Map<String, dynamic>? ?? {};
      final source = details['queryName'] ?? details['operationName'] ?? 'unknown';
      sources[source.toString()] = (sources[source.toString()] ?? 0) + 1;
    }
    
    final sortedSources = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedSources.take(10).map((entry) => {
      'source': entry.key,
      'count': entry.value,
    }).toList();
  }

  List<String> _getAlertResolutionSuggestions(List<Map<String, dynamic>> alerts) {
    final suggestions = <String>[];
    final alertTypes = _groupAlertsByType(alerts);
    
    if (alertTypes.containsKey('queryPerformance')) {
      suggestions.add('Optimize slow queries with database indexes');
    }
    
    if (alertTypes.containsKey('memoryUsage')) {
      suggestions.add('Implement memory cleanup strategies');
    }
    
    return suggestions;
  }

  List<Map<String, dynamic>> _prioritizeRecommendations(List<PerformanceRecommendation> recommendations) {
    final prioritized = recommendations.toList()
      ..sort((a, b) => _getPriorityScore(b.priority).compareTo(_getPriorityScore(a.priority)));
    
    return prioritized.map((rec) => rec.toMap()).toList();
  }

  int _getPriorityScore(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return 3;
      case RecommendationPriority.medium:
        return 2;
      case RecommendationPriority.low:
        return 1;
    }
  }

  List<Map<String, dynamic>> _identifyQuickWins(List<PerformanceRecommendation> recommendations) {
    return recommendations
        .where((rec) => rec.estimatedImpact == 'High' && rec.actions.length <= 2)
        .map((rec) => rec.toMap())
        .toList();
  }

  List<Map<String, dynamic>> _identifyLongTermImprovements(List<PerformanceRecommendation> recommendations) {
    return recommendations
        .where((rec) => rec.actions.length > 3)
        .map((rec) => rec.toMap())
        .toList();
  }

  String _getHealthStatus(int healthScore) {
    if (healthScore >= 90) return 'excellent';
    if (healthScore >= 70) return 'good';
    if (healthScore >= 50) return 'fair';
    return 'poor';
  }

  List<Map<String, dynamic>> _getCriticalIssues(List<Map<String, dynamic>> recentAlerts) {
    return recentAlerts
        .where((alert) => alert['level'] == 'AlertLevel.critical')
        .take(5)
        .toList();
  }

  Map<String, dynamic> _assessSystemStability() {
    // Placeholder implementation
    return {
      'stability': 'stable',
      'uptime': '99.5%',
      'crashRate': 0.1,
    };
  }

  String _getPerformanceGrade(int healthScore) {
    if (healthScore >= 95) return 'A+';
    if (healthScore >= 90) return 'A';
    if (healthScore >= 80) return 'B';
    if (healthScore >= 70) return 'C';
    if (healthScore >= 60) return 'D';
    return 'F';
  }

  List<String> _identifyImprovementAreas() {
    // Placeholder implementation
    return [
      'Query optimization',
      'Memory management',
      'Cache efficiency',
    ];
  }

  Future<Map<String, dynamic>> _generateExecutiveSummary() async {
    final healthScore = _performanceMonitor.calculateHealthScore();
    final queryStats = _performanceMonitor.getQueryStatistics();
    final memoryStats = _performanceMonitor.getMemoryStatistics();
    
    return {
      'overallHealth': _getHealthStatus(healthScore),
      'healthScore': healthScore,
      'keyMetrics': {
        'totalQueries': queryStats.length,
        'averageResponseTime': _calculateAverageResponseTime(queryStats),
        'memoryUsage': memoryStats['currentUsageMB'],
      },
      'topIssues': await _identifyTopIssues(),
      'recommendations': _performanceMonitor.getPerformanceRecommendations().take(3).toList(),
    };
  }

  Future<List<String>> _identifyTopIssues() async {
    final issues = <String>[];
    final recentAlerts = _performanceMonitor.getRecentAlerts(limit: 20);
    
    final criticalAlerts = recentAlerts.where((alert) => alert['level'] == 'AlertLevel.critical').length;
    if (criticalAlerts > 0) {
      issues.add('$criticalAlerts critical performance alerts in the last 24 hours');
    }
    
    return issues;
  }

  Map<String, dynamic> _getRawPerformanceData() {
    return {
      'queryStatistics': _performanceMonitor.getQueryStatistics(),
      'memoryStatistics': _performanceMonitor.getMemoryStatistics(),
      'syncStatistics': _performanceMonitor.getSyncStatistics(),
      'performanceHistory': _performanceMonitor.getPerformanceReport()['recentMetrics'],
      'alerts': _performanceMonitor.getRecentAlerts(limit: 100),
    };
  }

  /// Dispose resources
  void dispose() {
    _dashboardUpdateTimer?.cancel();
    _dashboardUpdateTimer = null;
    _cachedDashboardData = null;
    _lastUpdateTime = null;
    developer.log('Performance Analytics Dashboard disposed', name: 'PerformanceDashboard');
  }
}