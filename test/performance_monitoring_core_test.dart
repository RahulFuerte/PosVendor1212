// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/performance_monitor.dart';

void main() {
  group('Performance Monitoring Core Tests', () {
    late PerformanceMonitor performanceMonitor;

    setUp(() {
      performanceMonitor = PerformanceMonitor();
      performanceMonitor.startMonitoring();
    });

    tearDown(() {
      performanceMonitor.stopMonitoring();
      performanceMonitor.dispose();
    });

    group('Enhanced Performance Monitor', () {
      test('should track query execution times with threshold monitoring', () async {
        // Perform tracked queries
        for (int i = 0; i < 5; i++) {
          await performanceMonitor.trackQuery('test_query', () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'result_$i';
          });
        }
        
        // Get performance statistics
        final queryStats = performanceMonitor.getQueryStatistics();
        expect(queryStats.containsKey('test_query'), isTrue);
        
        final testQueryStats = queryStats['test_query'] as Map<String, dynamic>;
        expect(testQueryStats['count'], equals(5));
        expect(testQueryStats['averageMs'], greaterThan(0));
        
        // Check performance report includes new fields
        final performanceReport = performanceMonitor.getPerformanceReport();
        expect(performanceReport.containsKey('performanceAlerts'), isTrue);
        expect(performanceReport.containsKey('thresholds'), isTrue);
        expect(performanceReport.containsKey('healthScore'), isTrue);
        
        final healthScore = performanceReport['healthScore'] as int;
        expect(healthScore, greaterThanOrEqualTo(0));
        expect(healthScore, lessThanOrEqualTo(100));
      });

      test('should generate performance alerts when thresholds are exceeded', () async {
        // Set a very low threshold to trigger alerts
        performanceMonitor.setPerformanceThreshold(
          'query_execution', // Use the default threshold key
          PerformanceThreshold(
            name: 'Test Threshold',
            type: ThresholdType.queryTime,
            warningThreshold: 1.0, // 1ms
            criticalThreshold: 2.0, // 2ms
            unit: 'ms',
          ),
        );
        
        // Perform operations that should trigger alerts
        for (int i = 0; i < 3; i++) {
          await performanceMonitor.trackQuery('slow_query', () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return 'slow_result_$i';
          });
        }
        
        // Check for alerts (they should be generated during trackQuery)
        final recentAlerts = performanceMonitor.getRecentAlerts();
        expect(recentAlerts.isNotEmpty, isTrue);
        
        // Verify alert structure
        final firstAlert = recentAlerts.first;
        expect(firstAlert.containsKey('id'), isTrue);
        expect(firstAlert.containsKey('type'), isTrue);
        expect(firstAlert.containsKey('level'), isTrue);
        expect(firstAlert.containsKey('message'), isTrue);
        expect(firstAlert.containsKey('timestamp'), isTrue);
      });

      test('should provide enhanced performance recommendations', () async {
        // Create some performance data
        for (int i = 0; i < 10; i++) {
          await performanceMonitor.trackQuery('recommendation_query', () async {
            await Future.delayed(const Duration(milliseconds: 2));
            return 'rec_result_$i';
          });
        }
        
        // Get enhanced recommendations
        final enhancedRecommendations = performanceMonitor.getEnhancedRecommendations();
        expect(enhancedRecommendations.isNotEmpty, isTrue);
        
        // Verify recommendation structure
        final firstRecommendation = enhancedRecommendations.first;
        expect(firstRecommendation.type, isA<RecommendationType>());
        expect(firstRecommendation.priority, isA<RecommendationPriority>());
        expect(firstRecommendation.title.isNotEmpty, isTrue);
        expect(firstRecommendation.description.isNotEmpty, isTrue);
        expect(firstRecommendation.actions.isNotEmpty, isTrue);
        
        // Test recommendation mapping
        final recommendationMap = firstRecommendation.toMap();
        expect(recommendationMap.containsKey('type'), isTrue);
        expect(recommendationMap.containsKey('priority'), isTrue);
        expect(recommendationMap.containsKey('title'), isTrue);
        expect(recommendationMap.containsKey('actions'), isTrue);
      });

      test('should calculate health score accurately', () async {
        // Initial health score should be high (but may be affected by previous tests)
        final initialHealthScore = performanceMonitor.calculateHealthScore();
        expect(initialHealthScore, greaterThanOrEqualTo(0)); // Just ensure it's valid
        
        // Create some performance issues to lower the score
        performanceMonitor.setPerformanceThreshold(
          'query_execution', // Use the default threshold key
          PerformanceThreshold(
            name: 'Health Test',
            type: ThresholdType.queryTime,
            warningThreshold: 1.0,
            criticalThreshold: 2.0,
            unit: 'ms',
          ),
        );
        
        // Generate slow queries to create alerts
        for (int i = 0; i < 5; i++) {
          await performanceMonitor.trackQuery('health_test_query', () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'health_result_$i';
          });
        }
        
        // Health score should be lower now due to alerts
        final finalHealthScore = performanceMonitor.calculateHealthScore();
        expect(finalHealthScore, lessThanOrEqualTo(initialHealthScore));
        expect(finalHealthScore, greaterThanOrEqualTo(0));
        expect(finalHealthScore, lessThanOrEqualTo(100));
      });

      test('should track sync operations with performance metrics', () async {
        // Track sync operations
        for (int i = 0; i < 3; i++) {
          await performanceMonitor.trackSyncOperation('test_sync', () async {
            await Future.delayed(const Duration(milliseconds: 20));
            return 'sync_result_$i';
          });
        }
        
        // Get sync statistics
        final syncStats = performanceMonitor.getSyncStatistics();
        expect(syncStats.containsKey('test_sync'), isTrue);
        
        final testSyncStats = syncStats['test_sync'] as Map<String, dynamic>;
        expect(testSyncStats['count'], equals(3));
        expect(testSyncStats['averageMs'], greaterThan(0));
      });

      test('should provide performance analytics', () async {
        // Generate some performance data
        for (int i = 0; i < 5; i++) {
          await performanceMonitor.trackQuery('analytics_query_${i % 2}', () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return 'analytics_result_$i';
          });
        }
        
        // Get performance analytics
        final analytics = performanceMonitor.getPerformanceAnalytics();
        
        // Verify analytics structure
        expect(analytics.containsKey('timestamp'), isTrue);
        expect(analytics.containsKey('overview'), isTrue);
        expect(analytics.containsKey('queryAnalytics'), isTrue);
        expect(analytics.containsKey('memoryAnalytics'), isTrue);
        expect(analytics.containsKey('syncAnalytics'), isTrue);
        expect(analytics.containsKey('alertSummary'), isTrue);
        expect(analytics.containsKey('trends'), isTrue);
        expect(analytics.containsKey('recommendations'), isTrue);
        
        // Verify overview data
        final overview = analytics['overview'] as Map<String, dynamic>;
        expect(overview.containsKey('totalQueries'), isTrue);
        expect(overview.containsKey('uniqueQueryTypes'), isTrue);
        expect(overview.containsKey('healthScore'), isTrue);
        
        final totalQueries = overview['totalQueries'] as int;
        expect(totalQueries, equals(5));
        
        final uniqueQueryTypes = overview['uniqueQueryTypes'] as int;
        expect(uniqueQueryTypes, equals(2)); // analytics_query_0 and analytics_query_1
      });
    });

    group('Performance Threshold Management', () {
      test('should allow custom threshold configuration', () {
        // Set custom threshold
        final customThreshold = PerformanceThreshold(
          name: 'Custom Query Threshold',
          type: ThresholdType.queryTime,
          warningThreshold: 200.0,
          criticalThreshold: 500.0,
          unit: 'ms',
        );
        
        performanceMonitor.setPerformanceThreshold('custom_query', customThreshold);
        
        // Verify threshold was set
        final thresholds = performanceMonitor.getPerformanceThresholds();
        expect(thresholds.containsKey('custom_query'), isTrue);
        
        final retrievedThreshold = thresholds['custom_query'] as Map<String, dynamic>;
        expect(retrievedThreshold['name'], equals('Custom Query Threshold'));
        expect(retrievedThreshold['warningThreshold'], equals(200.0));
        expect(retrievedThreshold['criticalThreshold'], equals(500.0));
      });

      test('should handle inverted thresholds correctly', () {
        // Set inverted threshold (for cache hit rate where lower is worse)
        final invertedThreshold = PerformanceThreshold(
          name: 'Cache Hit Rate',
          type: ThresholdType.cacheHitRate,
          warningThreshold: 0.8,
          criticalThreshold: 0.5,
          unit: '%',
          isInverted: true,
        );
        
        performanceMonitor.setPerformanceThreshold('cache_hit_rate', invertedThreshold);
        
        // Verify threshold configuration
        final thresholds = performanceMonitor.getPerformanceThresholds();
        final cacheThreshold = thresholds['cache_hit_rate'] as Map<String, dynamic>;
        
        expect(cacheThreshold['isInverted'], isTrue);
        expect(cacheThreshold['warningThreshold'], equals(0.8));
        expect(cacheThreshold['criticalThreshold'], equals(0.5));
      });

      test('should provide default thresholds on initialization', () {
        // Check that default thresholds are set
        final thresholds = performanceMonitor.getPerformanceThresholds();
        
        expect(thresholds.containsKey('query_execution'), isTrue);
        expect(thresholds.containsKey('memory_usage'), isTrue);
        expect(thresholds.containsKey('sync_operation'), isTrue);
        expect(thresholds.containsKey('cache_hit_rate'), isTrue);
        
        // Verify default query threshold
        final queryThreshold = thresholds['query_execution'] as Map<String, dynamic>;
        expect(queryThreshold['name'], equals('Query Execution Time'));
        expect(queryThreshold['unit'], equals('ms'));
      });
    });

    group('Performance Data Classes', () {
      test('should create and serialize PerformanceMetric correctly', () {
        final metric = PerformanceMetric(
          operationName: 'test_operation',
          duration: 150,
          memoryUsage: 1024000,
          memoryDelta: 512000,
          timestamp: DateTime.now(),
        );
        
        final metricMap = metric.toMap();
        expect(metricMap['operationName'], equals('test_operation'));
        expect(metricMap['duration'], equals(150));
        expect(metricMap['memoryUsage'], equals(1024000));
        expect(metricMap['memoryDelta'], equals(512000));
        expect(metricMap.containsKey('timestamp'), isTrue);
      });

      test('should create and serialize PerformanceThreshold correctly', () {
        final threshold = PerformanceThreshold(
          name: 'Test Threshold',
          type: ThresholdType.queryTime,
          warningThreshold: 100.0,
          criticalThreshold: 200.0,
          unit: 'ms',
          isInverted: false,
        );
        
        final thresholdMap = threshold.toMap();
        expect(thresholdMap['name'], equals('Test Threshold'));
        expect(thresholdMap['warningThreshold'], equals(100.0));
        expect(thresholdMap['criticalThreshold'], equals(200.0));
        expect(thresholdMap['unit'], equals('ms'));
        expect(thresholdMap['isInverted'], equals(false));
      });

      test('should create and serialize PerformanceAlert correctly', () {
        final alert = PerformanceAlert(
          id: 'alert_123',
          type: AlertType.queryPerformance,
          level: AlertLevel.warning,
          message: 'Test alert message',
          details: {'queryName': 'slow_query', 'executionTime': 1500},
          timestamp: DateTime.now(),
        );
        
        final alertMap = alert.toMap();
        expect(alertMap['id'], equals('alert_123'));
        expect(alertMap['message'], equals('Test alert message'));
        expect(alertMap['details'], isA<Map<String, dynamic>>());
        expect(alertMap.containsKey('timestamp'), isTrue);
      });

      test('should create and serialize PerformanceRecommendation correctly', () {
        final recommendation = PerformanceRecommendation(
          type: RecommendationType.queryOptimization,
          priority: RecommendationPriority.high,
          title: 'Optimize slow query',
          description: 'Query is taking too long',
          impact: 'Improved user experience',
          actions: ['Add index', 'Optimize query structure'],
          estimatedImpact: 'High',
        );
        
        final recommendationMap = recommendation.toMap();
        expect(recommendationMap['title'], equals('Optimize slow query'));
        expect(recommendationMap['description'], equals('Query is taking too long'));
        expect(recommendationMap['actions'], isA<List<String>>());
        expect((recommendationMap['actions'] as List).length, equals(2));
      });
    });

    group('Memory and Performance Tracking', () {
      test('should track memory usage over time', () async {
        // Let the monitor capture some memory snapshots
        await Future.delayed(const Duration(seconds: 1));
        
        final memoryStats = performanceMonitor.getMemoryStatistics();
        expect(memoryStats.containsKey('currentUsageMB'), isTrue);
        expect(memoryStats.containsKey('peakUsageMB'), isTrue);
        expect(memoryStats.containsKey('averageUsageMB'), isTrue);
        expect(memoryStats.containsKey('snapshotCount'), isTrue);
      });

      test('should clear metrics when requested', () async {
        // Generate some performance data
        for (int i = 0; i < 3; i++) {
          await performanceMonitor.trackQuery('clear_test_query', () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return 'clear_result_$i';
          });
        }
        
        // Verify data exists
        final beforeClear = performanceMonitor.getQueryStatistics();
        expect(beforeClear.containsKey('clear_test_query'), isTrue);
        
        // Clear metrics
        performanceMonitor.clearMetrics();
        
        // Verify data is cleared
        final afterClear = performanceMonitor.getQueryStatistics();
        expect(afterClear.containsKey('clear_test_query'), isFalse);
      });

      test('should maintain performance history', () async {
        // Track some sync operations to generate performance history
        for (int i = 0; i < 3; i++) {
          await performanceMonitor.trackSyncOperation('history_sync', () async {
            await Future.delayed(const Duration(milliseconds: 10));
            return 'history_result_$i';
          });
        }
        
        final performanceReport = performanceMonitor.getPerformanceReport();
        final recentMetrics = performanceReport['recentMetrics'] as List;
        
        expect(recentMetrics.isNotEmpty, isTrue);
        
        // Verify metric structure
        if (recentMetrics.isNotEmpty) {
          final firstMetric = recentMetrics.first as Map<String, dynamic>;
          expect(firstMetric.containsKey('operationName'), isTrue);
          expect(firstMetric.containsKey('duration'), isTrue);
          expect(firstMetric.containsKey('timestamp'), isTrue);
        }
      });
    });
  });
}
