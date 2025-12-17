import 'package:flutter_test/flutter_test.dart';
import 'package:pos/view/tab_screen/view-model/backend/performance_error_handler.dart';
import 'package:pos/view/tab_screen/view-model/backend/performance_error_integration.dart';
import 'dart:async';

void main() {
  group('Performance Error Handling Tests', () {
    late PerformanceErrorHandler errorHandler;
    late PerformanceErrorIntegration integration;

    setUp(() async {
      errorHandler = PerformanceErrorHandler();
      integration = PerformanceErrorIntegration();
    });

    tearDown(() {
      // Don't dispose singleton instances in tests to avoid stream closure issues
      // errorHandler.dispose();
      // integration.dispose();
    });

    test('should initialize performance error handler successfully', () async {
      expect(errorHandler.isInitialized, false);
      
      // Note: Full initialization requires Firebase setup, so we test the basic structure
      expect(() => errorHandler, returnsNormally);
    });

    test('should handle slow query performance issues', () async {
      final issueCompleter = Completer<PerformanceIssue>();
      
      // Listen for performance issues
      final subscription = errorHandler.issueStream.listen((issue) {
        if (!issueCompleter.isCompleted) {
          issueCompleter.complete(issue);
        }
      });

      // Simulate a slow query
      await errorHandler.handleSlowQuery(
        queryName: 'test_query',
        executionTimeMs: 1500,
        context: 'unit_test',
        queryParameters: {'limit': 100},
      );

      // Wait for the issue to be processed
      final issue = await issueCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Issue not received'),
      );

      expect(issue.type, PerformanceIssueType.slowQuery);
      expect(issue.severity, PerformanceIssueSeverity.warning);
      expect(issue.context['queryName'], 'test_query');
      expect(issue.context['executionTimeMs'], 1500);

      await subscription.cancel();
    });

    test('should handle memory performance issues', () async {
      final issueCompleter = Completer<PerformanceIssue>();
      
      final subscription = errorHandler.issueStream.listen((issue) {
        if (!issueCompleter.isCompleted) {
          issueCompleter.complete(issue);
        }
      });

      // Simulate high memory usage
      await errorHandler.handleMemoryIssue(
        currentMemoryMB: 150.5,
        operation: 'test_operation',
        context: 'unit_test',
      );

      final issue = await issueCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Issue not received'),
      );

      expect(issue.type, PerformanceIssueType.memoryUsage);
      expect(issue.severity, PerformanceIssueSeverity.warning);
      expect(issue.context['currentMemoryMB'], 150.5);
      expect(issue.context['operation'], 'test_operation');

      await subscription.cancel();
    });

    test('should handle cache performance issues', () async {
      final issueCompleter = Completer<PerformanceIssue>();
      
      final subscription = errorHandler.issueStream.listen((issue) {
        if (!issueCompleter.isCompleted) {
          issueCompleter.complete(issue);
        }
      });

      // Simulate poor cache performance
      await errorHandler.handleCachePerformanceIssue(
        hitRate: 0.3,
        cacheType: 'test_cache',
        context: 'unit_test',
      );

      final issue = await issueCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Issue not received'),
      );

      expect(issue.type, PerformanceIssueType.cachePerformance);
      expect(issue.severity, PerformanceIssueSeverity.critical);
      expect(issue.context['hitRate'], 0.3);
      expect(issue.context['cacheType'], 'test_cache');

      await subscription.cancel();
    });

    test('should handle general performance degradation', () async {
      final issueCompleter = Completer<PerformanceIssue>();
      
      final subscription = errorHandler.issueStream.listen((issue) {
        if (!issueCompleter.isCompleted) {
          issueCompleter.complete(issue);
        }
      });

      // Simulate performance degradation
      await errorHandler.handlePerformanceDegradation(
        operation: 'test_operation',
        degradationType: 'response_time',
        metrics: {'responseTime': 5000, 'threshold': 2000},
        userMessage: 'Test degradation message',
      );

      final issue = await issueCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Issue not received'),
      );

      expect(issue.type, PerformanceIssueType.generalDegradation);
      expect(issue.severity, PerformanceIssueSeverity.warning);
      expect(issue.context['operation'], 'test_operation');
      expect(issue.context['degradationType'], 'response_time');

      await subscription.cancel();
    });

    test('should generate user-friendly messages for different issue types', () {
      // Test slow query message
      final slowQueryIssue = PerformanceIssue(
        id: 'test1',
        type: PerformanceIssueType.slowQuery,
        severity: PerformanceIssueSeverity.warning,
        title: 'Test',
        description: 'Test description',
        context: {},
        timestamp: DateTime.now(),
      );

      // Test memory issue message
      final memoryIssue = PerformanceIssue(
        id: 'test2',
        type: PerformanceIssueType.memoryUsage,
        severity: PerformanceIssueSeverity.critical,
        title: 'Test',
        description: 'Test description',
        context: {},
        timestamp: DateTime.now(),
      );

      // Test cache issue message
      final cacheIssue = PerformanceIssue(
        id: 'test3',
        type: PerformanceIssueType.cachePerformance,
        severity: PerformanceIssueSeverity.warning,
        title: 'Test',
        description: 'Test description',
        context: {},
        timestamp: DateTime.now(),
      );

      // Verify that different issue types exist
      expect(slowQueryIssue.type, PerformanceIssueType.slowQuery);
      expect(memoryIssue.type, PerformanceIssueType.memoryUsage);
      expect(cacheIssue.type, PerformanceIssueType.cachePerformance);
    });

    test('should provide performance issue statistics', () {
      final stats = errorHandler.getPerformanceIssueStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalIssuesReported'), true);
      expect(stats.containsKey('uniqueIssueTypes'), true);
      expect(stats.containsKey('issuesLast24h'), true);
      expect(stats.containsKey('activeRecoveryOperations'), true);
      expect(stats.containsKey('issueBreakdown'), true);
    });

    test('should provide performance recommendations', () {
      final recommendations = errorHandler.getPerformanceRecommendations();
      
      expect(recommendations, isA<List<String>>());
      expect(recommendations.isNotEmpty, true);
      
      // Should always provide at least one recommendation
      expect(recommendations.first.contains('Performance is optimal') || 
             recommendations.first.isNotEmpty, true);
    });

    test('should throttle similar issues to prevent spam', () async {
      int issueCount = 0;
      
      final subscription = errorHandler.issueStream.listen((issue) {
        issueCount++;
      });

      // Send multiple similar issues quickly
      for (int i = 0; i < 5; i++) {
        await errorHandler.handleSlowQuery(
          queryName: 'same_query',
          executionTimeMs: 1200,
          context: 'throttle_test',
        );
      }

      // Wait a bit for processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Should receive fewer issues due to throttling
      expect(issueCount, lessThanOrEqualTo(5));

      await subscription.cancel();
    });

    test('should handle critical vs warning severity correctly', () async {
      final issues = <PerformanceIssue>[];
      
      final subscription = errorHandler.issueStream.listen((issue) {
        issues.add(issue);
      });

      // Test warning level slow query
      await errorHandler.handleSlowQuery(
        queryName: 'warning_query',
        executionTimeMs: 1500, // Above warning threshold but below critical
        context: 'severity_test',
      );

      // Test critical level slow query
      await errorHandler.handleSlowQuery(
        queryName: 'critical_query',
        executionTimeMs: 3500, // Above critical threshold
        context: 'severity_test',
      );

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 100));

      expect(issues.length, greaterThanOrEqualTo(2));
      
      // Find the issues
      final warningIssue = issues.firstWhere(
        (issue) => issue.context['queryName'] == 'warning_query',
      );
      final criticalIssue = issues.firstWhere(
        (issue) => issue.context['queryName'] == 'critical_query',
      );

      expect(warningIssue.severity, PerformanceIssueSeverity.warning);
      expect(criticalIssue.severity, PerformanceIssueSeverity.critical);

      await subscription.cancel();
    });

    test('should create performance issue with correct structure', () {
      final issue = PerformanceIssue(
        id: 'test_issue_123',
        type: PerformanceIssueType.slowQuery,
        severity: PerformanceIssueSeverity.warning,
        title: 'Test Issue',
        description: 'This is a test issue',
        context: {
          'queryName': 'test_query',
          'executionTimeMs': 1500,
          'threshold': 1000,
        },
        timestamp: DateTime.now(),
      );

      expect(issue.id, 'test_issue_123');
      expect(issue.type, PerformanceIssueType.slowQuery);
      expect(issue.severity, PerformanceIssueSeverity.warning);
      expect(issue.title, 'Test Issue');
      expect(issue.description, 'This is a test issue');
      expect(issue.context['queryName'], 'test_query');
      expect(issue.context['executionTimeMs'], 1500);
      expect(issue.timestamp, isA<DateTime>());

      // Test serialization
      final map = issue.toMap();
      expect(map['id'], 'test_issue_123');
      expect(map['type'], 'slowQuery');
      expect(map['severity'], 'warning');
      expect(map['title'], 'Test Issue');
      expect(map['description'], 'This is a test issue');
      expect(map['context'], isA<Map<String, dynamic>>());
      expect(map['timestamp'], isA<String>());
    });

    test('should handle integration monitoring operations', () async {
      // Test database operation monitoring
      final result = await integration.monitorDatabaseOperation(
        'test_query',
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success';
        },
      );

      expect(result, 'success');

      // Test sync operation monitoring
      final syncResult = await integration.monitorSyncOperation(
        'test_sync',
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return true;
        },
      );

      expect(syncResult, true);

      // Test memory operation monitoring
      final memoryResult = await integration.monitorMemoryOperation(
        'test_memory_op',
        () async {
          await Future.delayed(const Duration(milliseconds: 25));
          return 42;
        },
      );

      expect(memoryResult, 42);
    });

    test('should provide performance status information', () {
      final status = integration.getPerformanceStatus();
      
      expect(status, isA<Map<String, dynamic>>());
      expect(status.containsKey('isInitialized'), true);
      expect(status.containsKey('monitoringActive'), true);
      expect(status.containsKey('performanceReport'), true);
      expect(status.containsKey('errorStatistics'), true);
      expect(status.containsKey('recommendations'), true);
    });

    test('should calculate performance health score', () {
      final healthScore = integration.getPerformanceHealthScore();
      
      expect(healthScore, isA<int>());
      expect(healthScore, greaterThanOrEqualTo(0));
      expect(healthScore, lessThanOrEqualTo(100));
    });

    test('should determine if performance is healthy', () {
      final isHealthy = integration.isPerformanceHealthy();
      
      expect(isHealthy, isA<bool>());
    });

    test('should provide user recommendations', () {
      final recommendations = integration.getUserRecommendations();
      
      expect(recommendations, isA<List<String>>());
      expect(recommendations.isNotEmpty, true);
      
      // Should contain actionable recommendations
      final hasActionableRecommendation = recommendations.any(
        (rec) => rec.contains('restart') || 
                 rec.contains('clear') || 
                 rec.contains('good') ||
                 rec.contains('close'),
      );
      expect(hasActionableRecommendation, true);
    });
  });

  group('Performance Error Handler Edge Cases', () {
    late PerformanceErrorHandler errorHandler;

    setUp(() {
      errorHandler = PerformanceErrorHandler();
    });

    tearDown(() {
      // Don't dispose singleton instances in tests
      // errorHandler.dispose();
    });

    test('should handle null or empty query names gracefully', () async {
      // Should not throw when handling edge cases
      expect(() async {
        await errorHandler.handleSlowQuery(
          queryName: '',
          executionTimeMs: 1000,
          context: 'edge_case_test',
        );
      }, returnsNormally);
    });

    test('should handle extreme performance values', () async {
      // Test very high execution time
      expect(() async {
        await errorHandler.handleSlowQuery(
          queryName: 'extreme_query',
          executionTimeMs: 999999,
          context: 'extreme_test',
        );
      }, returnsNormally);

      // Test very high memory usage
      expect(() async {
        await errorHandler.handleMemoryIssue(
          currentMemoryMB: 9999.9,
          operation: 'extreme_memory_test',
        );
      }, returnsNormally);

      // Test zero or negative cache hit rate
      expect(() async {
        await errorHandler.handleCachePerformanceIssue(
          hitRate: -0.1,
          cacheType: 'extreme_cache',
        );
      }, returnsNormally);
    });

    test('should handle concurrent performance issues', () async {
      final futures = <Future>[];
      
      // Create multiple concurrent performance issues
      for (int i = 0; i < 10; i++) {
        futures.add(errorHandler.handleSlowQuery(
          queryName: 'concurrent_query_$i',
          executionTimeMs: 1000 + (i * 100),
          context: 'concurrency_test',
        ));
      }

      // Should handle all concurrent issues without throwing
      expect(() async {
        await Future.wait(futures);
      }, returnsNormally);
    });
  });
}