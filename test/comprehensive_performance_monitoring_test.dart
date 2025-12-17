import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';
import '../lib/view/tab_screen/view-model/backend/performance_monitor.dart';
import '../lib/view/tab_screen/view-model/backend/performance_analytics_dashboard.dart';
import '../lib/view/tab_screen/view-model/backend/performance_optimization_service.dart';
import '../lib/view/tab_screen/view-model/backend/sqlite_dao.dart';
import 'test_database_helper.dart';

void main() {
  group('Comprehensive Performance Monitoring Tests', () {
    late TestDatabaseHelper testHelper;
    late SQLiteDAO sqliteDAO;
    late PerformanceMonitor performanceMonitor;
    late PerformanceAnalyticsDashboard analyticsDashboard;
    late PerformanceOptimizationService optimizationService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      testHelper = TestDatabaseHelper();
      await TestDatabaseHelper.getTestDatabase();
      
      sqliteDAO = SQLiteDAO();
      await sqliteDAO.initialize();
      
      performanceMonitor = PerformanceMonitor();
      performanceMonitor.startMonitoring();
      
      analyticsDashboard = PerformanceAnalyticsDashboard();
      await analyticsDashboard.initialize();
      
      optimizationService = PerformanceOptimizationService();
      await optimizationService.initialize();
    });

    tearDown(() async {
      performanceMonitor.stopMonitoring();
      performanceMonitor.dispose();
      analyticsDashboard.dispose();
      optimizationService.dispose();
      await sqliteDAO.close();
      await TestDatabaseHelper.clearAllTables();
      await TestDatabaseHelper.closeTestDatabase();
    });

    group('Enhanced Performance Monitor', () {
      test('should track query execution times with threshold monitoring', () async {
        const adminUid = 'test_admin';
        
        // Insert test data to create queries
        for (int i = 0; i < 10; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
            'department': 'Test Department',
          };
          
          await performanceMonitor.trackQuery('test_insert', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Get performance statistics
        final queryStats = performanceMonitor.getQueryStatistics();
        expect(queryStats.containsKey('test_insert'), isTrue);
        
        final testInsertStats = queryStats['test_insert'] as Map<String, dynamic>;
        expect(testInsertStats['count'], equals(10));
        expect(testInsertStats['averageMs'], greaterThan(0));
        
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
          'test_threshold',
          PerformanceThreshold(
            name: 'Test Threshold',
            type: ThresholdType.queryTime,
            warningThreshold: 1.0, // 1ms
            criticalThreshold: 2.0, // 2ms
            unit: 'ms',
          ),
        );
        
        const adminUid = 'test_admin';
        
        // Perform operations that should trigger alerts
        for (int i = 0; i < 5; i++) {
          final foodItem = {
            'id': 'slow_item_$i',
            'name': 'Slow Food Item $i',
            'price': 10.0 + i,
          };
          
          await performanceMonitor.trackQuery('slow_query', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
            // Add a small delay to ensure we exceed the threshold
            await Future.delayed(const Duration(milliseconds: 5));
          });
        }
        
        // Wait for alert monitoring to run
        await Future.delayed(const Duration(seconds: 1));
        
        // Check for alerts
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
        const adminUid = 'test_admin';
        
        // Create some performance data
        for (int i = 0; i < 20; i++) {
          final foodItem = {
            'id': 'rec_item_$i',
            'name': 'Recommendation Item $i',
            'price': 10.0 + i,
          };
          
          await performanceMonitor.trackQuery('recommendation_query', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
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
        // Initial health score should be high
        final initialHealthScore = performanceMonitor.calculateHealthScore();
        expect(initialHealthScore, greaterThanOrEqualTo(90));
        
        // Create some performance issues to lower the score
        performanceMonitor.setPerformanceThreshold(
          'health_test',
          PerformanceThreshold(
            name: 'Health Test',
            type: ThresholdType.queryTime,
            warningThreshold: 1.0,
            criticalThreshold: 2.0,
            unit: 'ms',
          ),
        );
        
        const adminUid = 'test_admin';
        
        // Generate slow queries to create alerts
        for (int i = 0; i < 3; i++) {
          await performanceMonitor.trackQuery('health_test_query', () async {
            await Future.delayed(const Duration(milliseconds: 10));
            final foodItem = {
              'id': 'health_item_$i',
              'name': 'Health Item $i',
              'price': 10.0,
            };
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Wait for alerts to be processed
        await Future.delayed(const Duration(seconds: 1));
        
        // Health score should be lower now
        final finalHealthScore = performanceMonitor.calculateHealthScore();
        expect(finalHealthScore, lessThan(initialHealthScore));
        expect(finalHealthScore, greaterThanOrEqualTo(0));
        expect(finalHealthScore, lessThanOrEqualTo(100));
      });
    });

    group('Performance Analytics Dashboard', () {
      test('should provide comprehensive dashboard data', () async {
        const adminUid = 'test_admin';
        
        // Generate some performance data
        for (int i = 0; i < 15; i++) {
          final foodItem = {
            'id': 'dashboard_item_$i',
            'name': 'Dashboard Item $i',
            'price': 10.0 + i,
            'department': 'Dashboard Department ${i % 3}',
          };
          
          await performanceMonitor.trackQuery('dashboard_query_${i % 3}', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Get dashboard data
        final dashboardData = await analyticsDashboard.getDashboardData();
        
        // Verify dashboard structure
        expect(dashboardData.containsKey('lastUpdated'), isTrue);
        expect(dashboardData.containsKey('realTimeMetrics'), isTrue);
        expect(dashboardData.containsKey('performanceTrends'), isTrue);
        expect(dashboardData.containsKey('queryAnalysis'), isTrue);
        expect(dashboardData.containsKey('memoryAnalysis'), isTrue);
        expect(dashboardData.containsKey('alertAnalysis'), isTrue);
        expect(dashboardData.containsKey('recommendations'), isTrue);
        expect(dashboardData.containsKey('healthAssessment'), isTrue);
        
        // Verify real-time metrics
        final realTimeMetrics = dashboardData['realTimeMetrics'] as Map<String, dynamic>;
        expect(realTimeMetrics.containsKey('performanceReport'), isTrue);
        expect(realTimeMetrics.containsKey('healthScore'), isTrue);
        expect(realTimeMetrics.containsKey('systemStatus'), isTrue);
      });

      test('should provide detailed query analysis', () async {
        const adminUid = 'test_admin';
        
        // Create varied query performance data
        for (int i = 0; i < 30; i++) {
          final foodItem = {
            'id': 'analysis_item_$i',
            'name': 'Analysis Item $i',
            'price': 10.0 + i,
          };
          
          final queryType = i % 3 == 0 ? 'fast_query' : 
                           i % 3 == 1 ? 'medium_query' : 'slow_query';
          
          await performanceMonitor.trackQuery(queryType, () async {
            if (queryType == 'slow_query') {
              await Future.delayed(const Duration(milliseconds: 2));
            }
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Get query analysis
        final queryAnalysis = await analyticsDashboard.getQueryAnalysis();
        
        // Verify analysis structure
        expect(queryAnalysis.containsKey('overview'), isTrue);
        expect(queryAnalysis.containsKey('slowestQueries'), isTrue);
        expect(queryAnalysis.containsKey('mostFrequentQueries'), isTrue);
        expect(queryAnalysis.containsKey('queryOptimizationSuggestions'), isTrue);
        expect(queryAnalysis.containsKey('queryPerformanceDistribution'), isTrue);
        
        // Verify overview data
        final overview = queryAnalysis['overview'] as Map<String, dynamic>;
        expect(overview.containsKey('totalQueryTypes'), isTrue);
        expect(overview.containsKey('totalExecutions'), isTrue);
        expect(overview.containsKey('averageResponseTime'), isTrue);
        
        final totalExecutions = overview['totalExecutions'] as int;
        expect(totalExecutions, equals(30));
      });

      test('should provide memory analysis', () async {
        // Get memory analysis
        final memoryAnalysis = await analyticsDashboard.getMemoryAnalysis();
        
        // Verify analysis structure
        expect(memoryAnalysis.containsKey('overview'), isTrue);
        expect(memoryAnalysis.containsKey('memoryBreakdown'), isTrue);
        expect(memoryAnalysis.containsKey('memoryLeaks'), isTrue);
        expect(memoryAnalysis.containsKey('memoryOptimizationSuggestions'), isTrue);
        expect(memoryAnalysis.containsKey('cacheEfficiency'), isTrue);
        
        // Verify overview data
        final overview = memoryAnalysis['overview'] as Map<String, dynamic>;
        expect(overview.containsKey('currentUsageMB'), isTrue);
        expect(overview.containsKey('peakUsageMB'), isTrue);
        expect(overview.containsKey('status'), isTrue);
      });

      test('should export comprehensive performance report', () async {
        const adminUid = 'test_admin';
        
        // Generate some data for the report
        for (int i = 0; i < 10; i++) {
          final foodItem = {
            'id': 'report_item_$i',
            'name': 'Report Item $i',
            'price': 10.0 + i,
          };
          
          await performanceMonitor.trackQuery('report_query', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Export performance report
        final report = await analyticsDashboard.exportPerformanceReport(
          includeRawData: true,
          days: 7,
        );
        
        // Verify report structure
        expect(report.containsKey('reportMetadata'), isTrue);
        expect(report.containsKey('executiveSummary'), isTrue);
        expect(report.containsKey('performanceOverview'), isTrue);
        expect(report.containsKey('queryAnalysis'), isTrue);
        expect(report.containsKey('memoryAnalysis'), isTrue);
        expect(report.containsKey('alertAnalysis'), isTrue);
        expect(report.containsKey('recommendations'), isTrue);
        expect(report.containsKey('healthAssessment'), isTrue);
        expect(report.containsKey('trends'), isTrue);
        expect(report.containsKey('rawData'), isTrue);
        
        // Verify metadata
        final metadata = report['reportMetadata'] as Map<String, dynamic>;
        expect(metadata['period'], equals('7d'));
        expect(metadata['includeRawData'], isTrue);
        
        // Verify executive summary
        final executiveSummary = report['executiveSummary'] as Map<String, dynamic>;
        expect(executiveSummary.containsKey('overallHealth'), isTrue);
        expect(executiveSummary.containsKey('healthScore'), isTrue);
        expect(executiveSummary.containsKey('keyMetrics'), isTrue);
      });
    });

    group('Performance Optimization Service Integration', () {
      test('should integrate with analytics dashboard', () async {
        // Get analytics dashboard through optimization service
        final dashboardData = await optimizationService.getAnalyticsDashboard();
        
        expect(dashboardData.isNotEmpty, isTrue);
        expect(dashboardData.containsKey('lastUpdated') || dashboardData.containsKey('error'), isTrue);
      });

      test('should provide real-time metrics', () {
        final realTimeMetrics = optimizationService.getRealTimeMetrics();
        
        expect(realTimeMetrics.containsKey('timestamp'), isTrue);
        expect(realTimeMetrics.containsKey('performanceReport'), isTrue);
        expect(realTimeMetrics.containsKey('healthScore'), isTrue);
        expect(realTimeMetrics.containsKey('systemStatus'), isTrue);
      });

      test('should provide performance trends', () {
        final trends = optimizationService.getPerformanceTrends(days: 7);
        
        expect(trends.containsKey('period'), isTrue);
        expect(trends.containsKey('queryPerformanceTrend'), isTrue);
        expect(trends.containsKey('memoryUsageTrend'), isTrue);
        expect(trends.containsKey('alertFrequencyTrend'), isTrue);
        
        expect(trends['period'], equals('7d'));
      });

      test('should provide system health assessment', () {
        final healthAssessment = optimizationService.getSystemHealthAssessment();
        
        expect(healthAssessment.containsKey('overallHealthScore'), isTrue);
        expect(healthAssessment.containsKey('healthStatus'), isTrue);
        expect(healthAssessment.containsKey('performanceGrade'), isTrue);
        
        final healthScore = healthAssessment['overallHealthScore'] as int;
        expect(healthScore, greaterThanOrEqualTo(0));
        expect(healthScore, lessThanOrEqualTo(100));
        
        final healthStatus = healthAssessment['healthStatus'] as String;
        expect(['excellent', 'good', 'fair', 'poor'].contains(healthStatus), isTrue);
      });

      test('should export comprehensive performance report', () async {
        const adminUid = 'test_admin';
        
        // Generate some performance data
        for (int i = 0; i < 5; i++) {
          final foodItem = {
            'id': 'export_item_$i',
            'name': 'Export Item $i',
            'price': 10.0 + i,
          };
          
          await performanceMonitor.trackQuery('export_query', () async {
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          });
        }
        
        // Export report through optimization service
        final report = await optimizationService.exportPerformanceReport(
          includeRawData: false,
          days: 30,
        );
        
        expect(report.containsKey('reportMetadata'), isTrue);
        expect(report.containsKey('executiveSummary'), isTrue);
        expect(report.containsKey('performanceOverview'), isTrue);
        
        final metadata = report['reportMetadata'] as Map<String, dynamic>;
        expect(metadata['period'], equals('30d'));
        expect(metadata['includeRawData'], isFalse);
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
    });
  });
}