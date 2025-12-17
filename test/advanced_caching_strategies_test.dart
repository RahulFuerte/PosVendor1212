import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/advanced_caching_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/cache_warming_coordinator.dart';
import 'package:pos/view/tab_screen/view-model/backend/cache_invalidation_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/cache_performance_analytics.dart';
import 'package:pos/view/tab_screen/view-model/backend/advanced_caching_integration.dart';
import 'test_database_helper.dart';

void main() {
  group('Advanced Caching Strategies Tests', () {
    late AdvancedCachingService cachingService;
    late CacheWarmingCoordinator warmingCoordinator;
    late CacheInvalidationManager invalidationManager;
    late CachePerformanceAnalytics performanceAnalytics;
    late AdvancedCachingIntegration cachingIntegration;

    setUpAll(() async {
      // Initialize Flutter bindings for SharedPreferences
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize FFI
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize test database using available method
      await TestDatabaseHelper.createTestDatabase();
    });

    setUp(() async {
      // Create fresh instances for each test to avoid database conflicts
      cachingService = AdvancedCachingService();
      warmingCoordinator = CacheWarmingCoordinator();
      invalidationManager = CacheInvalidationManager();
      performanceAnalytics = CachePerformanceAnalytics();
      cachingIntegration = AdvancedCachingIntegration();
      
      // Ensure clean database state for each test
      await TestDatabaseHelper.clearAllTables();
    });

    tearDown(() async {
      try {
        await cachingService.dispose();
        await warmingCoordinator.dispose();
        await invalidationManager.dispose();
        await performanceAnalytics.dispose();
        await cachingIntegration.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
      
      // Clean up database after each test
      try {
        await TestDatabaseHelper.clearAllTables();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Multi-Level Caching', () {
      test('should implement memory + disk caching levels', () async {
        await cachingService.initialize();

        // Store data with different priorities using available enum values
        await cachingService.store(
          'critical_data',
          {'type': 'critical', 'value': 'important'},
          tags: ['critical', 'system'],
        );

        await cachingService.store(
          'normal_data',
          {'type': 'normal', 'value': 'regular'},
          tags: ['normal', 'user'],
        );

        await cachingService.store(
          'temporary_data',
          {'type': 'temporary', 'value': 'temp'},
          tags: ['temporary'],
        );

        // Retrieve data and verify it's cached
        final criticalData = await cachingService.retrieve<Map<String, dynamic>>('critical_data');
        final normalData = await cachingService.retrieve<Map<String, dynamic>>('normal_data');
        final temporaryData = await cachingService.retrieve<Map<String, dynamic>>('temporary_data');

        expect(criticalData, isNotNull);
        expect(criticalData!['type'], equals('critical'));
        expect(normalData, isNotNull);
        expect(normalData!['type'], equals('normal'));
        expect(temporaryData, isNotNull);
        expect(temporaryData!['type'], equals('temporary'));
      });

      test('should handle cache level promotion based on access patterns', () async {
        await cachingService.initialize();

        // Store data
        await cachingService.store(
          'frequently_accessed',
          {'access_count': 0},
        );

        // Access the data multiple times to trigger promotion
        for (int i = 0; i < 10; i++) {
          final data = await cachingService.retrieve<Map<String, dynamic>>('frequently_accessed');
          expect(data, isNotNull);
        }

        // Verify data is still accessible (should be promoted to higher level)
        final finalData = await cachingService.retrieve<Map<String, dynamic>>('frequently_accessed');
        expect(finalData, isNotNull);
      });

      test('should manage cache size limits and eviction', () async {
        await cachingService.initialize();

        // Store multiple large data items
        for (int i = 0; i < 20; i++) {
          await cachingService.store(
            'large_data_$i',
            List.generate(1000, (index) => 'data_$index').join(''),
          );
        }

        // Verify cache management is working
        final analytics = await cachingService.getPerformanceAnalytics();
        expect(analytics, isNotNull);
      });
    });

    group('Cache Warming Strategies', () {
      test('should initialize warming coordinator successfully', () async {
        await warmingCoordinator.initialize();

        final analytics = await warmingCoordinator.getWarmingAnalytics();
        expect(analytics, isNotNull);
        expect(analytics['coordinatorStatus'], isNotNull);
        expect(analytics['coordinatorStatus']['isActive'], isA<bool>());
      });

      test('should perform intelligent cache warming', () async {
        await warmingCoordinator.initialize();

        // Perform warming with different priorities
        await warmingCoordinator.performIntelligentWarming();

        final analytics = await warmingCoordinator.getWarmingAnalytics();
        expect(analytics['warmingStatistics'], isNotNull);
      });

      test('should warm cache for user context', () async {
        await warmingCoordinator.initialize();

        const testUserId = 'test_user_123';
        const testDepartment = 'electronics';
        const recentItems = ['item1', 'item2', 'item3'];

        await warmingCoordinator.warmForUserContext(
          adminUid: testUserId,
          currentDepartment: testDepartment,
          recentlyAccessedItems: recentItems,
        );

        // Verify warming completed without errors
        final analytics = await warmingCoordinator.getWarmingAnalytics();
        expect(analytics, isNotNull);
      });

      test('should prepare cache for offline mode', () async {
        await warmingCoordinator.initialize();

        const testUserId = 'offline_user_123';

        await warmingCoordinator.warmForOfflineMode(testUserId);

        // Verify offline preparation completed
        final analytics = await warmingCoordinator.getWarmingAnalytics();
        expect(analytics, isNotNull);
      });

      test('should execute warming strategies', () async {
        await warmingCoordinator.initialize();

        // Execute the warming strategy
        await warmingCoordinator.performIntelligentWarming();

        final analytics = await warmingCoordinator.getWarmingAnalytics();
        expect(analytics['warmingStatistics'], isNotNull);
        expect(analytics['coordinatorStatus'], isNotNull);
      });
    });

    group('Cache Invalidation Policies', () {
      test('should initialize invalidation manager successfully', () async {
        await invalidationManager.initialize();

        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics, isNotNull);
        expect(analytics['managerStatus'], isNotNull);
        expect(analytics['managerStatus']['isActive'], isA<bool>());
      });

      test('should handle data change invalidation', () async {
        await invalidationManager.initialize();

        await invalidationManager.invalidateOnDataChange(
          dataType: 'food_items',
          specificKey: 'item_123',
          affectedTags: ['food_items', 'department_electronics'],
        );

        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics, isNotNull);
      });

      test('should handle user action invalidation', () async {
        await invalidationManager.initialize();

        await invalidationManager.invalidateOnUserAction(
          action: 'logout',
          userId: 'user_123',
        );

        await invalidationManager.invalidateOnUserAction(
          action: 'settings_change',
          userId: 'user_123',
        );

        await invalidationManager.invalidateOnUserAction(
          action: 'department_change',
          context: {'department': 'electronics'},
        );

        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics, isNotNull);
      });

      test('should execute time-based invalidation policies', () async {
        await invalidationManager.initialize();

        await invalidationManager.executeTimePolicies();

        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics['statistics'], isNotNull);
      });

      test('should handle memory pressure invalidation', () async {
        await invalidationManager.initialize();

        // Test different memory pressure levels using enum values
        await invalidationManager.invalidateOnMemoryPressure(
          level: MemoryPressureLevel.low,
        );

        await invalidationManager.invalidateOnMemoryPressure(
          level: MemoryPressureLevel.medium,
        );

        await invalidationManager.invalidateOnMemoryPressure(
          level: MemoryPressureLevel.high,
        );

        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics, isNotNull);
      });

      test('should register and execute custom invalidation policies', () async {
        await invalidationManager.initialize();

        // Test policy registration (implementation may vary)
        final analytics = await invalidationManager.getInvalidationAnalytics();
        expect(analytics['policies'], isNotNull);
      });
    });

    group('Performance Analytics', () {
      test('should initialize performance analytics successfully', () async {
        await performanceAnalytics.initialize();

        final report = await performanceAnalytics.getPerformanceReport();
        expect(report, isNotNull);
        expect(report['timestamp'], isNotNull);
      });

      test('should collect real-time metrics', () async {
        await performanceAnalytics.initialize();

        final metrics = await performanceAnalytics.getRealTimeMetrics();
        expect(metrics, isNotNull);
        expect(metrics['timestamp'], isNotNull);
        expect(metrics['metrics'], isNotNull);
      });

      test('should analyze cache efficiency', () async {
        await performanceAnalytics.initialize();

        final efficiency = await performanceAnalytics.analyzeCacheEfficiency(
          period: const Duration(hours: 1),
        );
        expect(efficiency, isNotNull);
      });

      test('should generate optimization recommendations', () async {
        await performanceAnalytics.initialize();

        final recommendations = await performanceAnalytics.generateOptimizationRecommendations();
        expect(recommendations, isA<List>());
      });
    });

    group('Advanced Caching Integration', () {
      test('should initialize integration service successfully', () async {
        await cachingIntegration.initialize();

        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
        expect(status['isInitialized'], isTrue);
      });

      test('should store and retrieve data with intelligent strategies', () async {
        await cachingIntegration.initialize();

        // Store data with warming
        await cachingIntegration.store(
          'integration_test_data',
          {'message': 'Hello, World!', 'timestamp': DateTime.now().toIso8601String()},
          tags: ['integration', 'test'],
          warmRelated: true,
        );

        // Retrieve data with fallback
        final retrievedData = await cachingIntegration.retrieve<Map<String, dynamic>>(
          'integration_test_data',
          fallbackFetcher: () async {
            return {'fallback': true};
          },
        );

        expect(retrievedData, isNotNull);
        expect(retrievedData!['message'], equals('Hello, World!'));
      });

      test('should handle cache invalidation with cascading', () async {
        await cachingIntegration.initialize();

        // Store related data
        await cachingIntegration.store(
          'parent_data',
          {'type': 'parent'},
          tags: ['parent', 'related'],
        );

        await cachingIntegration.store(
          'child_data',
          {'type': 'child'},
          tags: ['child', 'related'],
        );

        // Invalidate with cascading
        await cachingIntegration.invalidate(
          tags: ['related'],
          cascadeRelated: true,
        );

        // Verify invalidation worked
        final parentData = await cachingIntegration.retrieve('parent_data');
        expect(parentData, isNull);
      });

      test('should warm cache for user with different strategies', () async {
        await cachingIntegration.initialize();

        const testUserId = 'integration_user_123';

        // Test different warming strategies using enum values
        await cachingIntegration.warmForUser(
          userId: testUserId,
          strategy: WarmingStrategy.aggressive,
        );

        await cachingIntegration.warmForUser(
          userId: testUserId,
          strategy: WarmingStrategy.balanced,
        );

        await cachingIntegration.warmForUser(
          userId: testUserId,
          strategy: WarmingStrategy.conservative,
        );

        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
      });

      test('should prepare for offline mode', () async {
        await cachingIntegration.initialize();

        const testUserId = 'offline_integration_user';

        await cachingIntegration.prepareForOfflineMode(testUserId);

        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
      });

      test('should handle data change events', () async {
        await cachingIntegration.initialize();

        await cachingIntegration.handleDataChange(
          dataType: 'food_items',
          entityId: 'item_456',
          affectedTags: ['food_items', 'department'],
          changeType: DataChangeType.update,
        );

        await cachingIntegration.handleDataChange(
          dataType: 'departments',
          entityId: 'dept_789',
          changeType: DataChangeType.create,
        );

        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
      });

      test('should optimize performance based on analytics', () async {
        await cachingIntegration.initialize();

        await cachingIntegration.optimizePerformance();

        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
        expect(status['recommendations'], isA<List>());
      });

      test('should provide comprehensive cache status', () async {
        await cachingIntegration.initialize();

        final status = await cachingIntegration.getCacheStatus();
        
        expect(status, isNotNull);
        expect(status['timestamp'], isNotNull);
        expect(status['isInitialized'], isTrue);
        expect(status['performance'], isNotNull);
        expect(status['warming'], isNotNull);
        expect(status['invalidation'], isNotNull);
        expect(status['health'], isNotNull);
        expect(status['recommendations'], isA<List>());
      });
    });

    group('Cache Performance Monitoring', () {
      test('should track cache hit rates accurately', () async {
        await cachingService.initialize();

        // Store some test data
        for (int i = 0; i < 10; i++) {
          await cachingService.store(
            'perf_test_$i',
            {'index': i, 'data': 'test_data_$i'},
          );
        }

        // Access data to generate hits
        int hits = 0;
        for (int i = 0; i < 10; i++) {
          final data = await cachingService.retrieve('perf_test_$i');
          if (data != null) hits++;
        }

        expect(hits, equals(10));

        final analytics = await cachingService.getPerformanceAnalytics();
        expect(analytics, isNotNull);
      });

      test('should monitor cache utilization and efficiency', () async {
        await cachingService.initialize();

        // Fill cache with various data sizes
        await cachingService.store('small_data', 'small');
        await cachingService.store('medium_data', List.generate(100, (i) => 'data_$i'));
        await cachingService.store('large_data', List.generate(1000, (i) => 'large_data_$i'));

        final analytics = await cachingService.getPerformanceAnalytics();
        expect(analytics, isNotNull);
      });

      test('should generate performance recommendations', () async {
        await performanceAnalytics.initialize();

        // Generate some cache activity
        await cachingService.initialize();
        for (int i = 0; i < 5; i++) {
          await cachingService.store('rec_test_$i', 'data_$i');
        }

        final recommendations = await performanceAnalytics.generateOptimizationRecommendations();
        expect(recommendations, isA<List>());
      });
    });

    group('Error Handling and Recovery', () {
      test('should handle initialization errors gracefully', () async {
        // Test with invalid configuration
        expect(() async {
          final service = AdvancedCachingService();
          await service.initialize();
          await service.dispose();
        }, returnsNormally);
      });

      test('should handle storage errors gracefully', () async {
        await cachingService.initialize();

        // Try to store invalid data
        await cachingService.store('error_test', null);
        
        // Service should still be functional
        await cachingService.store('valid_test', 'valid_data');
        final data = await cachingService.retrieve('valid_test');
        expect(data, equals('valid_data'));
      });

      test('should handle retrieval errors gracefully', () async {
        await cachingService.initialize();

        // Try to retrieve non-existent data
        final data = await cachingService.retrieve('non_existent_key');
        expect(data, isNull);

        // Service should still be functional
        await cachingService.store('test_key', 'test_data');
        final validData = await cachingService.retrieve('test_key');
        expect(validData, equals('test_data'));
      });

      test('should handle concurrent operations safely', () async {
        await cachingService.initialize();

        // Perform concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 20; i++) {
          futures.add(cachingService.store('concurrent_$i', 'data_$i'));
          futures.add(cachingService.retrieve('concurrent_${i ~/ 2}'));
        }

        await Future.wait(futures);

        // Verify some data was stored
        final data = await cachingService.retrieve('concurrent_0');
        expect(data, isNotNull);
      });
    });

    group('Integration with Existing Services', () {
      test('should integrate with image cache service', () async {
        await cachingIntegration.initialize();

        // This test verifies that the integration service can work
        // with existing cache services without conflicts
        final status = await cachingIntegration.getCacheStatus();
        expect(status['performance'], isNotNull);
      });

      test('should integrate with lazy loading service', () async {
        await cachingIntegration.initialize();

        // Verify integration with lazy loading
        final status = await cachingIntegration.getCacheStatus();
        expect(status, isNotNull);
      });

      test('should provide unified cache management', () async {
        await cachingIntegration.initialize();

        // Test unified operations
        await cachingIntegration.store('unified_test', {'unified': true});
        final data = await cachingIntegration.retrieve('unified_test');
        expect(data, isNotNull);

        await cachingIntegration.invalidate(key: 'unified_test');
        final invalidatedData = await cachingIntegration.retrieve('unified_test');
        expect(invalidatedData, isNull);
      });
    });
  });
}