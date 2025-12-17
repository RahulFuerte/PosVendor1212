import 'dart:async';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'advanced_caching_service.dart';
import 'cache_warming_coordinator.dart';
import 'cache_invalidation_manager.dart';
import 'performance_monitor.dart';
import 'image_cache_service.dart';
import 'lazy_loading_service.dart';

/// Comprehensive cache performance analytics and monitoring service
/// Provides detailed insights into cache behavior, efficiency, and optimization opportunities
class CachePerformanceAnalytics {
  static final CachePerformanceAnalytics _instance = CachePerformanceAnalytics._internal();
  factory CachePerformanceAnalytics() => _instance;
  CachePerformanceAnalytics._internal();

  final AdvancedCachingService _cachingService = AdvancedCachingService();
  final CacheWarmingCoordinator _warmingCoordinator = CacheWarmingCoordinator();
  final CacheInvalidationManager _invalidationManager = CacheInvalidationManager();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final ImageCacheService _imageCacheService = ImageCacheService();
  final LazyLoadingService _lazyLoadingService = LazyLoadingService();

  // Analytics data storage
  final List<CacheMetricsSnapshot> _metricsHistory = [];
  final Map<String, CacheOperationMetrics> _operationMetrics = {};
  final Map<String, CacheEfficiencyTrend> _efficiencyTrends = {};
  
  Timer? _analyticsTimer;
  Timer? _reportTimer;

  // Configuration
  static const Duration _metricsCollectionInterval = Duration(minutes: 5);
  static const Duration _reportGenerationInterval = Duration(hours: 1);
  static const int _maxHistoryEntries = 288; // 24 hours of 5-minute intervals
  static const int _trendAnalysisPeriod = 12; // 1 hour of data points

  /// Initialize the cache performance analytics service
  Future<void> initialize() async {
    await _performanceMonitor.trackQuery('cache_analytics_init', () async {
      try {
        // Start metrics collection
        _startMetricsCollection();
        
        // Start report generation
        _startReportGeneration();
        
        // Collect initial baseline metrics
        await _collectBaselineMetrics();

        developer.log('Cache performance analytics initialized', name: 'CachePerformanceAnalytics');
      } catch (e) {
        developer.log('Error initializing cache performance analytics: $e', name: 'CachePerformanceAnalytics');
        rethrow;
      }
    });
  }

  /// Get comprehensive cache performance report
  Future<Map<String, dynamic>> getPerformanceReport() async {
    return await _performanceMonitor.trackQuery('cache_performance_report', () async {
      try {
        final currentMetrics = await _collectCurrentMetrics();
        final trends = _analyzeTrends();
        final efficiency = await _analyzeEfficiency();
        final recommendations = await _generateRecommendations();
        
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'currentMetrics': currentMetrics,
          'trends': trends,
          'efficiency': efficiency,
          'recommendations': recommendations,
          'historicalData': _getHistoricalDataSummary(),
          'operationMetrics': _getOperationMetricsSummary(),
          'systemHealth': await _assessSystemHealth(),
        };
      } catch (e) {
        developer.log('Error generating performance report: $e', name: 'CachePerformanceAnalytics');
        return {'error': e.toString()};
      }
    });
  }

  /// Get real-time cache metrics
  Future<Map<String, dynamic>> getRealTimeMetrics() async {
    return await _performanceMonitor.trackQuery('real_time_metrics', () async {
      try {
        final metrics = await _collectCurrentMetrics();
        
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'metrics': metrics,
          'alerts': _generateRealTimeAlerts(metrics),
          'performance': _calculatePerformanceScores(metrics),
        };
      } catch (e) {
        developer.log('Error getting real-time metrics: $e', name: 'CachePerformanceAnalytics');
        return {'error': e.toString()};
      }
    });
  }

  /// Analyze cache efficiency over time
  Future<Map<String, dynamic>> analyzeCacheEfficiency({
    Duration? period,
  }) async {
    return await _performanceMonitor.trackQuery('analyze_cache_efficiency', () async {
      try {
        final analysisStart = DateTime.now().subtract(period ?? const Duration(hours: 24));
        final relevantSnapshots = _metricsHistory
            .where((snapshot) => snapshot.timestamp.isAfter(analysisStart))
            .toList();

        if (relevantSnapshots.isEmpty) {
          return {'error': 'Insufficient data for analysis'};
        }

        final efficiency = _calculateEfficiencyMetrics(relevantSnapshots);
        final patterns = _identifyUsagePatterns(relevantSnapshots);
        final optimization = _identifyOptimizationOpportunities(relevantSnapshots);

        return {
          'period': {
            'start': analysisStart.toIso8601String(),
            'end': DateTime.now().toIso8601String(),
            'dataPoints': relevantSnapshots.length,
          },
          'efficiency': efficiency,
          'patterns': patterns,
          'optimization': optimization,
        };
      } catch (e) {
        developer.log('Error analyzing cache efficiency: $e', name: 'CachePerformanceAnalytics');
        return {'error': e.toString()};
      }
    });
  }

  /// Generate cache optimization recommendations
  Future<List<Map<String, dynamic>>> generateOptimizationRecommendations() async {
    return await _performanceMonitor.trackQuery('optimization_recommendations', () async {
      try {
        final recommendations = <Map<String, dynamic>>[];
        
        // Analyze current performance
        final currentMetrics = await _collectCurrentMetrics();
        final trends = _analyzeTrends();
        
        // Hit rate recommendations
        final hitRate = currentMetrics['overallHitRate'] as double? ?? 0.0;
        if (hitRate < 0.7) {
          recommendations.add({
            'type': 'hit_rate_improvement',
            'priority': 'high',
            'title': 'Improve Cache Hit Rate',
            'description': 'Current hit rate is ${(hitRate * 100).toStringAsFixed(1)}%. Consider more aggressive cache warming.',
            'actions': [
              'Increase cache warming frequency',
              'Preload frequently accessed data',
              'Analyze access patterns for better prediction',
            ],
            'expectedImpact': 'Reduce data loading times by 30-50%',
          });
        }
        
        // Memory utilization recommendations
        final memoryUtilization = currentMetrics['memoryUtilization'] as double? ?? 0.0;
        if (memoryUtilization > 0.9) {
          recommendations.add({
            'type': 'memory_optimization',
            'priority': 'high',
            'title': 'Optimize Memory Usage',
            'description': 'Memory cache utilization is ${(memoryUtilization * 100).toStringAsFixed(1)}%.',
            'actions': [
              'Implement more aggressive LRU eviction',
              'Reduce cache size for low-priority data',
              'Increase cache invalidation frequency',
            ],
            'expectedImpact': 'Prevent memory pressure and improve stability',
          });
        }
        
        // Cache warming recommendations
        final warmingEfficiency = await _analyzeWarmingEfficiency();
        if (warmingEfficiency < 0.6) {
          recommendations.add({
            'type': 'warming_optimization',
            'priority': 'medium',
            'title': 'Optimize Cache Warming',
            'description': 'Cache warming efficiency is ${(warmingEfficiency * 100).toStringAsFixed(1)}%.',
            'actions': [
              'Review warming strategies',
              'Adjust warming intervals',
              'Improve data prediction algorithms',
            ],
            'expectedImpact': 'Improve cache hit rate and reduce cold starts',
          });
        }
        
        // Invalidation recommendations
        final invalidationEfficiency = await _analyzeInvalidationEfficiency();
        if (invalidationEfficiency < 0.8) {
          recommendations.add({
            'type': 'invalidation_optimization',
            'priority': 'medium',
            'title': 'Optimize Cache Invalidation',
            'description': 'Cache invalidation efficiency is ${(invalidationEfficiency * 100).toStringAsFixed(1)}%.',
            'actions': [
              'Review invalidation policies',
              'Implement more granular invalidation',
              'Reduce unnecessary invalidations',
            ],
            'expectedImpact': 'Reduce cache misses and improve data freshness',
          });
        }
        
        // Performance trend recommendations
        if (trends['hitRateTrend'] == 'declining') {
          recommendations.add({
            'type': 'performance_trend',
            'priority': 'medium',
            'title': 'Address Declining Performance',
            'description': 'Cache hit rate has been declining over time.',
            'actions': [
              'Analyze recent changes in data access patterns',
              'Review cache sizing and policies',
              'Consider cache architecture improvements',
            ],
            'expectedImpact': 'Stabilize and improve cache performance',
          });
        }
        
        return recommendations;
      } catch (e) {
        developer.log('Error generating optimization recommendations: $e', name: 'CachePerformanceAnalytics');
        return [];
      }
    });
  }

  /// Start metrics collection timer
  void _startMetricsCollection() {
    _analyticsTimer = Timer.periodic(_metricsCollectionInterval, (timer) async {
      try {
        await _collectAndStoreMetrics();
      } catch (e) {
        developer.log('Error during metrics collection: $e', name: 'CachePerformanceAnalytics');
      }
    });
  }

  /// Start report generation timer
  void _startReportGeneration() {
    _reportTimer = Timer.periodic(_reportGenerationInterval, (timer) async {
      try {
        await _generatePeriodicReport();
      } catch (e) {
        developer.log('Error during report generation: $e', name: 'CachePerformanceAnalytics');
      }
    });
  }

  /// Collect baseline metrics on initialization
  Future<void> _collectBaselineMetrics() async {
    try {
      await _collectAndStoreMetrics();
      developer.log('Baseline metrics collected', name: 'CachePerformanceAnalytics');
    } catch (e) {
      developer.log('Error collecting baseline metrics: $e', name: 'CachePerformanceAnalytics');
    }
  }

  /// Collect and store current metrics
  Future<void> _collectAndStoreMetrics() async {
    final metrics = await _collectCurrentMetrics();
    final snapshot = CacheMetricsSnapshot(
      timestamp: DateTime.now(),
      metrics: metrics,
    );
    
    _metricsHistory.add(snapshot);
    
    // Maintain history size limit
    if (_metricsHistory.length > _maxHistoryEntries) {
      _metricsHistory.removeAt(0);
    }
    
    // Update efficiency trends
    _updateEfficiencyTrends(snapshot);
  }

  /// Collect current metrics from all cache services
  Future<Map<String, dynamic>> _collectCurrentMetrics() async {
    try {
      // Advanced caching service metrics
      final advancedCacheAnalytics = await _cachingService.getPerformanceAnalytics();
      
      // Image cache metrics
      final imageCacheStats = await _imageCacheService.getDetailedCacheStatistics();
      
      // Lazy loading metrics
      final lazyLoadingStats = _lazyLoadingService.getCacheStatistics();
      
      // Performance monitor metrics
      final performanceReport = _performanceMonitor.getPerformanceReport();
      
      // Calculate overall metrics
      final overallMetrics = _calculateOverallMetrics(
        advancedCacheAnalytics,
        imageCacheStats,
        lazyLoadingStats,
        performanceReport,
      );
      
      return {
        'advancedCache': advancedCacheAnalytics,
        'imageCache': imageCacheStats,
        'lazyLoading': lazyLoadingStats,
        'performance': performanceReport,
        'overall': overallMetrics,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Error collecting current metrics: $e', name: 'CachePerformanceAnalytics');
      return {'error': e.toString()};
    }
  }

  /// Calculate overall metrics from individual service metrics
  Map<String, dynamic> _calculateOverallMetrics(
    Map<String, dynamic> advancedCache,
    Map<String, dynamic> imageCache,
    Map<String, dynamic> lazyLoading,
    Map<String, dynamic> performance,
  ) {
    try {
      // Extract hit rates
      final advancedHitRate = (advancedCache['overallMetrics'] as Map<String, dynamic>?)?['hitRate'] as double? ?? 0.0;
      final imageCacheHitRate = imageCache['cacheHitRate'] as double? ?? 0.0;
      
      // Calculate weighted overall hit rate
      final overallHitRate = (advancedHitRate + imageCacheHitRate) / 2;
      
      // Extract memory utilization
      final memoryStats = advancedCache['memoryCacheStats'] as Map<String, dynamic>?;
      final memoryUtilization = memoryStats?['utilization'] as double? ?? 0.0;
      
      // Extract storage efficiency
      final storageEfficiency = imageCache['storageEfficiency'] as double? ?? 1.0;
      
      // Calculate performance score
      final performanceScore = _calculatePerformanceScore(
        hitRate: overallHitRate,
        memoryUtilization: memoryUtilization,
        storageEfficiency: storageEfficiency,
      );
      
      return {
        'overallHitRate': overallHitRate,
        'memoryUtilization': memoryUtilization,
        'storageEfficiency': storageEfficiency,
        'performanceScore': performanceScore,
        'totalCacheEntries': _calculateTotalCacheEntries(advancedCache, imageCache, lazyLoading),
        'totalCacheSize': _calculateTotalCacheSize(advancedCache, imageCache),
      };
    } catch (e) {
      developer.log('Error calculating overall metrics: $e', name: 'CachePerformanceAnalytics');
      return {};
    }
  }

  /// Calculate performance score based on various metrics
  double _calculatePerformanceScore({
    required double hitRate,
    required double memoryUtilization,
    required double storageEfficiency,
  }) {
    // Weighted scoring system
    final hitRateScore = hitRate * 0.5; // 50% weight
    final memoryScore = (1.0 - (memoryUtilization - 0.7).clamp(0.0, 0.3) / 0.3) * 0.3; // 30% weight
    final storageScore = storageEfficiency * 0.2; // 20% weight
    
    return (hitRateScore + memoryScore + storageScore).clamp(0.0, 1.0);
  }

  /// Calculate total cache entries across all services
  int _calculateTotalCacheEntries(
    Map<String, dynamic> advancedCache,
    Map<String, dynamic> imageCache,
    Map<String, dynamic> lazyLoading,
  ) {
    final advancedEntries = (advancedCache['memoryCacheStats'] as Map<String, dynamic>?)?['entryCount'] as int? ?? 0;
    final imageEntries = imageCache['totalImages'] as int? ?? 0;
    final lazyEntries = lazyLoading.length;
    
    return advancedEntries + imageEntries + lazyEntries;
  }

  /// Calculate total cache size across all services
  int _calculateTotalCacheSize(
    Map<String, dynamic> advancedCache,
    Map<String, dynamic> imageCache,
  ) {
    final advancedSize = (advancedCache['memoryCacheStats'] as Map<String, dynamic>?)?['totalSize'] as int? ?? 0;
    final imageSize = imageCache['totalSizeBytes'] as int? ?? 0;
    
    return advancedSize + imageSize;
  }

  /// Analyze trends in cache performance
  Map<String, dynamic> _analyzeTrends() {
    if (_metricsHistory.length < _trendAnalysisPeriod) {
      return {'insufficient_data': true};
    }
    
    final recentSnapshots = _metricsHistory.length > _trendAnalysisPeriod 
        ? _metricsHistory.sublist(_metricsHistory.length - _trendAnalysisPeriod)
        : _metricsHistory;
    
    // Analyze hit rate trend
    final hitRates = recentSnapshots
        .map((snapshot) => (snapshot.metrics['overall'] as Map<String, dynamic>?)?['overallHitRate'] as double? ?? 0.0)
        .toList();
    
    final hitRateTrend = _calculateTrend(hitRates);
    
    // Analyze memory utilization trend
    final memoryUtilizations = recentSnapshots
        .map((snapshot) => (snapshot.metrics['overall'] as Map<String, dynamic>?)?['memoryUtilization'] as double? ?? 0.0)
        .toList();
    
    final memoryTrend = _calculateTrend(memoryUtilizations);
    
    // Analyze performance score trend
    final performanceScores = recentSnapshots
        .map((snapshot) => (snapshot.metrics['overall'] as Map<String, dynamic>?)?['performanceScore'] as double? ?? 0.0)
        .toList();
    
    final performanceTrend = _calculateTrend(performanceScores);
    
    return {
      'hitRateTrend': hitRateTrend,
      'memoryTrend': memoryTrend,
      'performanceTrend': performanceTrend,
      'analysisWindow': _trendAnalysisPeriod,
      'dataPoints': recentSnapshots.length,
    };
  }

  /// Calculate trend direction for a series of values
  String _calculateTrend(List<double> values) {
    if (values.length < 2) return 'stable';
    
    final firstHalf = values.take(values.length ~/ 2).toList();
    final secondHalf = values.skip(values.length ~/ 2).toList();
    
    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    
    final change = (secondAvg - firstAvg) / firstAvg;
    
    if (change > 0.05) return 'improving';
    if (change < -0.05) return 'declining';
    return 'stable';
  }

  /// Analyze cache efficiency
  Future<Map<String, dynamic>> _analyzeEfficiency() async {
    try {
      final currentMetrics = await _collectCurrentMetrics();
      
      // Calculate efficiency scores
      final hitRateEfficiency = (currentMetrics['overall'] as Map<String, dynamic>?)?['overallHitRate'] as double? ?? 0.0;
      final memoryEfficiency = 1.0 - ((currentMetrics['overall'] as Map<String, dynamic>?)?['memoryUtilization'] as double? ?? 0.0);
      final storageEfficiency = (currentMetrics['imageCache'] as Map<String, dynamic>?)?['storageEfficiency'] as double? ?? 1.0;
      
      // Calculate warming efficiency
      final warmingEfficiency = await _analyzeWarmingEfficiency();
      
      // Calculate invalidation efficiency
      final invalidationEfficiency = await _analyzeInvalidationEfficiency();
      
      return {
        'hitRateEfficiency': hitRateEfficiency,
        'memoryEfficiency': memoryEfficiency,
        'storageEfficiency': storageEfficiency,
        'warmingEfficiency': warmingEfficiency,
        'invalidationEfficiency': invalidationEfficiency,
        'overallEfficiency': (hitRateEfficiency + memoryEfficiency + storageEfficiency + warmingEfficiency + invalidationEfficiency) / 5,
      };
    } catch (e) {
      developer.log('Error analyzing efficiency: $e', name: 'CachePerformanceAnalytics');
      return {'error': e.toString()};
    }
  }

  /// Analyze cache warming efficiency
  Future<double> _analyzeWarmingEfficiency() async {
    try {
      final warmingAnalytics = await _warmingCoordinator.getWarmingAnalytics();
      final warmingStats = warmingAnalytics['warmingStatistics'] as Map<String, dynamic>?;
      
      if (warmingStats == null || warmingStats.isEmpty) return 0.0;
      
      int totalExecutions = 0;
      int totalSuccesses = 0;
      
      for (final stats in warmingStats.values) {
        if (stats is Map<String, dynamic>) {
          totalExecutions += (stats['executionCount'] as int? ?? 0);
          totalSuccesses += (stats['successCount'] as int? ?? 0);
        }
      }
      
      return totalExecutions > 0 ? (totalSuccesses / totalExecutions) : 0.0;
    } catch (e) {
      developer.log('Error analyzing warming efficiency: $e', name: 'CachePerformanceAnalytics');
      return 0.0;
    }
  }

  /// Analyze cache invalidation efficiency
  Future<double> _analyzeInvalidationEfficiency() async {
    try {
      final invalidationAnalytics = await _invalidationManager.getInvalidationAnalytics();
      final invalidationStats = invalidationAnalytics['statistics'] as Map<String, dynamic>?;
      
      if (invalidationStats == null || invalidationStats.isEmpty) return 1.0;
      
      int totalExecutions = 0;
      int totalSuccesses = 0;
      
      for (final stats in invalidationStats.values) {
        if (stats is Map<String, dynamic>) {
          totalExecutions += (stats['executionCount'] as int? ?? 0);
          totalSuccesses += (stats['successCount'] as int? ?? 0);
        }
      }
      
      return totalExecutions > 0 ? (totalSuccesses / totalExecutions) : 1.0;
    } catch (e) {
      developer.log('Error analyzing invalidation efficiency: $e', name: 'CachePerformanceAnalytics');
      return 1.0;
    }
  }

  /// Generate comprehensive recommendations
  Future<List<Map<String, dynamic>>> _generateRecommendations() async {
    try {
      final optimizationRecommendations = await generateOptimizationRecommendations();
      final warmingRecommendations = await _generateWarmingRecommendations();
      final invalidationRecommendations = await _generateInvalidationRecommendations();
      
      final allRecommendations = <Map<String, dynamic>>[];
      allRecommendations.addAll(optimizationRecommendations);
      allRecommendations.addAll(warmingRecommendations);
      allRecommendations.addAll(invalidationRecommendations);
      
      // Sort by priority
      allRecommendations.sort((a, b) {
        final priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
        final aPriority = priorityOrder[a['priority']] ?? 3;
        final bPriority = priorityOrder[b['priority']] ?? 3;
        return aPriority.compareTo(bPriority);
      });
      
      return allRecommendations;
    } catch (e) {
      developer.log('Error generating recommendations: $e', name: 'CachePerformanceAnalytics');
      return [];
    }
  }

  /// Generate warming-specific recommendations
  Future<List<Map<String, dynamic>>> _generateWarmingRecommendations() async {
    final recommendations = <Map<String, dynamic>>[];
    
    try {
      final warmingAnalytics = await _warmingCoordinator.getWarmingAnalytics();
      final warmingRecommendations = warmingAnalytics['recommendations'] as List<dynamic>?;
      
      if (warmingRecommendations != null) {
        for (final recommendation in warmingRecommendations) {
          if (recommendation is String) {
            recommendations.add({
              'type': 'cache_warming',
              'priority': 'medium',
              'title': 'Cache Warming Optimization',
              'description': recommendation,
              'actions': ['Review warming configuration'],
              'expectedImpact': 'Improve cache warming efficiency',
            });
          }
        }
      }
    } catch (e) {
      developer.log('Error generating warming recommendations: $e', name: 'CachePerformanceAnalytics');
    }
    
    return recommendations;
  }

  /// Generate invalidation-specific recommendations
  Future<List<Map<String, dynamic>>> _generateInvalidationRecommendations() async {
    final recommendations = <Map<String, dynamic>>[];
    
    try {
      final invalidationAnalytics = await _invalidationManager.getInvalidationAnalytics();
      final invalidationRecommendations = invalidationAnalytics['recommendations'] as List<dynamic>?;
      
      if (invalidationRecommendations != null) {
        for (final recommendation in invalidationRecommendations) {
          if (recommendation is String) {
            recommendations.add({
              'type': 'cache_invalidation',
              'priority': 'medium',
              'title': 'Cache Invalidation Optimization',
              'description': recommendation,
              'actions': ['Review invalidation policies'],
              'expectedImpact': 'Improve cache invalidation efficiency',
            });
          }
        }
      }
    } catch (e) {
      developer.log('Error generating invalidation recommendations: $e', name: 'CachePerformanceAnalytics');
    }
    
    return recommendations;
  }

  /// Update efficiency trends
  void _updateEfficiencyTrends(CacheMetricsSnapshot snapshot) {
    final overallMetrics = snapshot.metrics['overall'] as Map<String, dynamic>?;
    if (overallMetrics == null) return;
    
    final hitRate = overallMetrics['overallHitRate'] as double? ?? 0.0;
    final performanceScore = overallMetrics['performanceScore'] as double? ?? 0.0;
    
    // Update hit rate trend
    final hitRateTrend = _efficiencyTrends['hitRate'] ??= CacheEfficiencyTrend('hitRate');
    hitRateTrend.addDataPoint(snapshot.timestamp, hitRate);
    
    // Update performance score trend
    final performanceTrend = _efficiencyTrends['performance'] ??= CacheEfficiencyTrend('performance');
    performanceTrend.addDataPoint(snapshot.timestamp, performanceScore);
  }

  /// Calculate efficiency metrics from snapshots
  Map<String, dynamic> _calculateEfficiencyMetrics(List<CacheMetricsSnapshot> snapshots) {
    if (snapshots.isEmpty) return {};
    
    final hitRates = snapshots
        .map((s) => (s.metrics['overall'] as Map<String, dynamic>?)?['overallHitRate'] as double? ?? 0.0)
        .toList();
    
    final performanceScores = snapshots
        .map((s) => (s.metrics['overall'] as Map<String, dynamic>?)?['performanceScore'] as double? ?? 0.0)
        .toList();
    
    return {
      'averageHitRate': hitRates.reduce((a, b) => a + b) / hitRates.length,
      'minHitRate': hitRates.reduce(math.min),
      'maxHitRate': hitRates.reduce(math.max),
      'averagePerformanceScore': performanceScores.reduce((a, b) => a + b) / performanceScores.length,
      'minPerformanceScore': performanceScores.reduce(math.min),
      'maxPerformanceScore': performanceScores.reduce(math.max),
    };
  }

  /// Identify usage patterns from snapshots
  Map<String, dynamic> _identifyUsagePatterns(List<CacheMetricsSnapshot> snapshots) {
    // This would implement pattern recognition algorithms
    // For now, return basic pattern analysis
    return {
      'peakUsageHours': _identifyPeakUsageHours(snapshots),
      'accessPatterns': _analyzeAccessPatterns(snapshots),
      'dataTypeDistribution': _analyzeDataTypeDistribution(snapshots),
    };
  }

  /// Identify peak usage hours
  List<int> _identifyPeakUsageHours(List<CacheMetricsSnapshot> snapshots) {
    final hourlyActivity = <int, double>{};
    
    for (final snapshot in snapshots) {
      final hour = snapshot.timestamp.hour;
      final activity = (snapshot.metrics['overall'] as Map<String, dynamic>?)?['totalCacheEntries'] as int? ?? 0;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0.0) + activity.toDouble();
    }
    
    // Find hours with above-average activity
    final averageActivity = hourlyActivity.values.reduce((a, b) => a + b) / hourlyActivity.length;
    
    return hourlyActivity.entries
        .where((entry) => entry.value > averageActivity * 1.2)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  /// Analyze access patterns
  Map<String, dynamic> _analyzeAccessPatterns(List<CacheMetricsSnapshot> snapshots) {
    // Simplified access pattern analysis
    return {
      'totalAccesses': snapshots.length,
      'averageInterval': snapshots.length > 1 
          ? snapshots.last.timestamp.difference(snapshots.first.timestamp).inMinutes / snapshots.length
          : 0,
    };
  }

  /// Analyze data type distribution
  Map<String, dynamic> _analyzeDataTypeDistribution(List<CacheMetricsSnapshot> snapshots) {
    // This would analyze the distribution of different data types in cache
    return {
      'imageData': 'high',
      'textData': 'medium',
      'structuredData': 'low',
    };
  }

  /// Identify optimization opportunities
  Map<String, dynamic> _identifyOptimizationOpportunities(List<CacheMetricsSnapshot> snapshots) {
    final opportunities = <String, dynamic>{};
    
    // Analyze hit rate opportunities
    final hitRates = snapshots
        .map((s) => (s.metrics['overall'] as Map<String, dynamic>?)?['overallHitRate'] as double? ?? 0.0)
        .toList();
    
    if (hitRates.isNotEmpty) {
      final avgHitRate = hitRates.reduce((a, b) => a + b) / hitRates.length;
      if (avgHitRate < 0.8) {
        opportunities['hitRateImprovement'] = {
          'current': avgHitRate,
          'target': 0.8,
          'potential': '${((0.8 - avgHitRate) * 100).toStringAsFixed(1)}% improvement possible',
        };
      }
    }
    
    return opportunities;
  }

  /// Generate real-time alerts
  List<Map<String, dynamic>> _generateRealTimeAlerts(Map<String, dynamic> metrics) {
    final alerts = <Map<String, dynamic>>[];
    
    try {
      final overallMetrics = metrics['overall'] as Map<String, dynamic>?;
      if (overallMetrics == null) return alerts;
      
      // Hit rate alert
      final hitRate = overallMetrics['overallHitRate'] as double? ?? 0.0;
      if (hitRate < 0.5) {
        alerts.add({
          'type': 'performance',
          'severity': 'high',
          'message': 'Cache hit rate is critically low: ${(hitRate * 100).toStringAsFixed(1)}%',
          'recommendation': 'Increase cache warming or review cache policies',
        });
      }
      
      // Memory utilization alert
      final memoryUtilization = overallMetrics['memoryUtilization'] as double? ?? 0.0;
      if (memoryUtilization > 0.95) {
        alerts.add({
          'type': 'memory',
          'severity': 'critical',
          'message': 'Memory cache is nearly full: ${(memoryUtilization * 100).toStringAsFixed(1)}%',
          'recommendation': 'Immediate cache cleanup required',
        });
      }
      
      // Performance score alert
      final performanceScore = overallMetrics['performanceScore'] as double? ?? 0.0;
      if (performanceScore < 0.6) {
        alerts.add({
          'type': 'performance',
          'severity': 'medium',
          'message': 'Overall cache performance is below optimal: ${(performanceScore * 100).toStringAsFixed(1)}%',
          'recommendation': 'Review cache configuration and optimization opportunities',
        });
      }
    } catch (e) {
      alerts.add({
        'type': 'system',
        'severity': 'low',
        'message': 'Error generating alerts: $e',
        'recommendation': 'Check analytics service configuration',
      });
    }
    
    return alerts;
  }

  /// Calculate performance scores for different aspects
  Map<String, double> _calculatePerformanceScores(Map<String, dynamic> metrics) {
    final overallMetrics = metrics['overall'] as Map<String, dynamic>?;
    if (overallMetrics == null) return {};
    
    return {
      'hitRate': (overallMetrics['overallHitRate'] as double? ?? 0.0),
      'memoryEfficiency': 1.0 - (overallMetrics['memoryUtilization'] as double? ?? 0.0),
      'storageEfficiency': (overallMetrics['storageEfficiency'] as double? ?? 1.0),
      'overall': (overallMetrics['performanceScore'] as double? ?? 0.0),
    };
  }

  /// Get historical data summary
  Map<String, dynamic> _getHistoricalDataSummary() {
    if (_metricsHistory.isEmpty) {
      return {'dataPoints': 0};
    }
    
    return {
      'dataPoints': _metricsHistory.length,
      'oldestEntry': _metricsHistory.first.timestamp.toIso8601String(),
      'newestEntry': _metricsHistory.last.timestamp.toIso8601String(),
      'collectionInterval': _metricsCollectionInterval.inMinutes,
    };
  }

  /// Get operation metrics summary
  Map<String, dynamic> _getOperationMetricsSummary() {
    return _operationMetrics.map((key, metrics) => MapEntry(key, {
      'operationType': metrics.operationType,
      'totalOperations': metrics.totalOperations,
      'successfulOperations': metrics.successfulOperations,
      'averageLatency': metrics.averageLatency.inMilliseconds,
      'successRate': metrics.successRate,
    }));
  }

  /// Assess system health
  Future<Map<String, dynamic>> _assessSystemHealth() async {
    try {
      final currentMetrics = await _collectCurrentMetrics();
      final overallMetrics = currentMetrics['overall'] as Map<String, dynamic>?;
      
      if (overallMetrics == null) {
        return {'status': 'unknown', 'score': 0.0};
      }
      
      final performanceScore = overallMetrics['performanceScore'] as double? ?? 0.0;
      
      String status;
      if (performanceScore >= 0.8) {
        status = 'excellent';
      } else if (performanceScore >= 0.6) {
        status = 'good';
      } else if (performanceScore >= 0.4) {
        status = 'fair';
      } else {
        status = 'poor';
      }
      
      return {
        'status': status,
        'score': performanceScore,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'score': 0.0,
        'error': e.toString(),
      };
    }
  }

  /// Generate periodic report
  Future<void> _generatePeriodicReport() async {
    try {
      final report = await getPerformanceReport();
      developer.log('Periodic cache performance report generated', name: 'CachePerformanceAnalytics');
      
      // Here you could save the report to a file or send it to a monitoring service
      // For now, we'll just log key metrics
      final overallMetrics = report['currentMetrics']?['overall'] as Map<String, dynamic>?;
      if (overallMetrics != null) {
        final hitRate = overallMetrics['overallHitRate'] as double? ?? 0.0;
        final performanceScore = overallMetrics['performanceScore'] as double? ?? 0.0;
        
        developer.log('Cache Performance - Hit Rate: ${(hitRate * 100).toStringAsFixed(1)}%, Score: ${(performanceScore * 100).toStringAsFixed(1)}%', 
                     name: 'CachePerformanceAnalytics');
      }
    } catch (e) {
      developer.log('Error generating periodic report: $e', name: 'CachePerformanceAnalytics');
    }
  }

  /// Dispose the analytics service and clean up resources
  Future<void> dispose() async {
    _analyticsTimer?.cancel();
    _reportTimer?.cancel();
    
    _metricsHistory.clear();
    _operationMetrics.clear();
    _efficiencyTrends.clear();
    
    developer.log('Cache performance analytics disposed', name: 'CachePerformanceAnalytics');
  }
}

/// Cache metrics snapshot for historical tracking
class CacheMetricsSnapshot {
  final DateTime timestamp;
  final Map<String, dynamic> metrics;

  CacheMetricsSnapshot({
    required this.timestamp,
    required this.metrics,
  });
}

/// Cache operation metrics tracking
class CacheOperationMetrics {
  final String operationType;
  
  int totalOperations = 0;
  int successfulOperations = 0;
  Duration totalLatency = Duration.zero;
  DateTime? lastOperation;

  CacheOperationMetrics(this.operationType);

  double get successRate => totalOperations > 0 ? (successfulOperations / totalOperations) : 0.0;
  Duration get averageLatency => totalOperations > 0 
      ? Duration(milliseconds: totalLatency.inMilliseconds ~/ totalOperations)
      : Duration.zero;

  void recordOperation({required bool success, required Duration latency}) {
    totalOperations++;
    totalLatency += latency;
    lastOperation = DateTime.now();
    
    if (success) {
      successfulOperations++;
    }
  }
}

/// Cache efficiency trend tracking
class CacheEfficiencyTrend {
  final String metricName;
  final List<TrendDataPoint> dataPoints = [];
  
  static const int maxDataPoints = 100;

  CacheEfficiencyTrend(this.metricName);

  void addDataPoint(DateTime timestamp, double value) {
    dataPoints.add(TrendDataPoint(timestamp, value));
    
    // Maintain size limit
    if (dataPoints.length > maxDataPoints) {
      dataPoints.removeAt(0);
    }
  }

  double? get currentValue => dataPoints.isNotEmpty ? dataPoints.last.value : null;
  
  String get trend {
    if (dataPoints.length < 2) return 'stable';
    
    final recent = dataPoints.length >= 5 
        ? dataPoints.sublist(dataPoints.length - 5).map((dp) => dp.value).toList()
        : dataPoints.map((dp) => dp.value).toList();
    final older = dataPoints.length > 10 
        ? dataPoints.sublist(dataPoints.length - 10, dataPoints.length - 5).map((dp) => dp.value).toList()
        : recent;
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    final change = (recentAvg - olderAvg) / olderAvg;
    
    if (change > 0.05) return 'improving';
    if (change < -0.05) return 'declining';
    return 'stable';
  }
}

/// Individual trend data point
class TrendDataPoint {
  final DateTime timestamp;
  final double value;

  TrendDataPoint(this.timestamp, this.value);
}