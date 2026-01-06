// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/lazy_loading_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/performance_monitor.dart';
import 'test_database_helper.dart';

void main() {
  group('Simple Performance Tests', () {
    late PerformanceMonitor performanceMonitor;
    late LazyLoadingService lazyLoadingService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      await TestDatabaseHelper.getTestDatabase();
      
      performanceMonitor = PerformanceMonitor();
      performanceMonitor.startMonitoring();
      
      lazyLoadingService = LazyLoadingService();
    });

    tearDown(() async {
      performanceMonitor.stopMonitoring();
      performanceMonitor.dispose();
      lazyLoadingService.clearAllCaches();
      await TestDatabaseHelper.clearAllTables();
      await TestDatabaseHelper.closeTestDatabase();
    });

    group('Performance Monitor Tests', () {
      test('should track query performance accurately', () async {
        // Perform tracked queries
        for (int i = 0; i < 5; i++) {
          await performanceMonitor.trackQuery('test_query', () async {
            // Simulate database query
            await Future.delayed(Duration(milliseconds: 10 + i * 5));
            return 'result_$i';
          });
        }
        
        // Check performance statistics
        final queryStats = performanceMonitor.getQueryStatistics();
        expect(queryStats.containsKey('test_query'), isTrue);
        
        final testQueryStats = queryStats['test_query'] as Map<String, dynamic>;
        expect(testQueryStats['count'], equals(5));
        expect(testQueryStats['averageMs'], greaterThan(0));
        expect(testQueryStats['minMs'], greaterThan(0));
        expect(testQueryStats['maxMs'], greaterThanOrEqualTo(testQueryStats['minMs']));
        
        print('Query statistics: $testQueryStats');
      });

      test('should generate performance recommendations', () async {
        // Simulate some operations to generate metrics
        for (int i = 0; i < 10; i++) {
          await performanceMonitor.trackQuery('fast_query', () async {
            await Future.delayed(const Duration(milliseconds: 5));
            return 'fast_result';
          });
        }
        
        // Get performance report
        final report = performanceMonitor.getPerformanceReport();
        expect(report.containsKey('queryStatistics'), isTrue);
        expect(report.containsKey('memoryStatistics'), isTrue);
        
        // Get recommendations
        final recommendations = performanceMonitor.getPerformanceRecommendations();
        expect(recommendations.isNotEmpty, isTrue);
        
        print('Performance recommendations:');
        for (final recommendation in recommendations) {
          print('- $recommendation');
        }
      });

      test('should track memory usage', () async {
        // Get initial memory statistics
        final initialStats = performanceMonitor.getMemoryStatistics();
        expect(initialStats.containsKey('currentUsageMB'), isTrue);
        expect(initialStats.containsKey('snapshotCount'), isTrue);
        
        print('Memory statistics: $initialStats');
        
        // Memory statistics should be valid
        expect(initialStats['snapshotCount'], greaterThanOrEqualTo(0));
      });
    });

    group('Lazy Loading Tests', () {
      test('should create and use lazy loader efficiently', () async {
        // Create test data
        final testData = <Map<String, dynamic>>[];
        for (int i = 0; i < 100; i++) {
          testData.add({
            'id': 'item_$i',
            'name': 'Item $i',
            'value': i * 10,
          });
        }
        
        // Create lazy loader
        final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
          cacheKey: 'test_items',
          pageSize: 10,
          itemIdExtractor: (item) => item['id'] as String,
          dataFetcher: (offset, limit) async {
            final endIndex = (offset + limit).clamp(0, testData.length);
            return testData.sublist(offset.clamp(0, testData.length), endIndex);
          },
        );
        
        // Test loading performance
        final stopwatch = Stopwatch()..start();
        
        final page0 = await loader.loadPage(0);
        
        stopwatch.stop();
        final firstLoadTime = stopwatch.elapsedMilliseconds;
        
        expect(page0.length, equals(10));
        print('First page load time: ${firstLoadTime}ms');
        
        // Test cache performance (second load should be faster)
        stopwatch.reset();
        stopwatch.start();
        
        final cachedPage0 = await loader.loadPage(0);
        
        stopwatch.stop();
        final cachedLoadTime = stopwatch.elapsedMilliseconds;
        
        expect(cachedPage0.length, equals(10));
        expect(cachedLoadTime, lessThan(firstLoadTime));
        print('Cached page load time: ${cachedLoadTime}ms');
        
        // Check loader statistics
        final stats = loader.getStatistics();
        expect(stats['cacheHits'], greaterThan(0));
        expect(stats['cacheMisses'], greaterThan(0));
        
        print('Loader stats: ${stats['cacheHits']} hits, ${stats['cacheMisses']} misses');
      });

      test('should handle preloading efficiently', () async {
        // Create test data
        final testData = <Map<String, dynamic>>[];
        for (int i = 0; i < 50; i++) {
          testData.add({
            'id': 'preload_item_$i',
            'name': 'Preload Item $i',
            'value': i * 5,
          });
        }
        
        // Create lazy loader
        final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
          cacheKey: 'preload_test',
          pageSize: 10,
          itemIdExtractor: (item) => item['id'] as String,
          dataFetcher: (offset, limit) async {
            final endIndex = (offset + limit).clamp(0, testData.length);
            return testData.sublist(offset.clamp(0, testData.length), endIndex);
          },
        );
        
        // Test preloading
        final stopwatch = Stopwatch()..start();
        
        await loader.preloadPages([0, 1, 2]);
        
        stopwatch.stop();
        final preloadTime = stopwatch.elapsedMilliseconds;
        
        print('Preloaded 3 pages in ${preloadTime}ms');
        
        // Verify all pages are cached
        for (int page = 0; page < 3; page++) {
          expect(loader.isPageLoaded(page), isTrue, reason: 'Page $page should be preloaded');
        }
        
        expect(preloadTime, lessThan(1000), reason: 'Preloading should complete quickly');
      });

      test('should manage cache size efficiently', () async {
        // Create multiple loaders to test cache management
        final loaders = <LazyDataLoader<Map<String, dynamic>>>[];
        
        for (int loaderIndex = 0; loaderIndex < 5; loaderIndex++) {
          final testData = <Map<String, dynamic>>[];
          for (int i = 0; i < 20; i++) {
            testData.add({
              'id': 'loader_${loaderIndex}_item_$i',
              'name': 'Loader $loaderIndex Item $i',
              'value': i,
            });
          }
          
          final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
            cacheKey: 'cache_test_$loaderIndex',
            pageSize: 5,
            itemIdExtractor: (item) => item['id'] as String,
            dataFetcher: (offset, limit) async {
              final endIndex = (offset + limit).clamp(0, testData.length);
              return testData.sublist(offset.clamp(0, testData.length), endIndex);
            },
          );
          
          loaders.add(loader);
        }
        
        // Load data from all loaders
        for (final loader in loaders) {
          await loader.loadPage(0);
          await loader.loadPage(1);
        }
        
        // Check cache statistics
        final cacheStats = lazyLoadingService.getCacheStatistics();
        expect(cacheStats.length, equals(5));
        
        print('Cache statistics: $cacheStats');
        
        // Cleanup expired caches
        lazyLoadingService.cleanupExpiredCaches();
        
        // Cache should still exist (not expired yet)
        final statsAfterCleanup = lazyLoadingService.getCacheStatistics();
        expect(statsAfterCleanup.length, equals(5));
      });
    });

    group('Stress Tests', () {
      test('should handle multiple concurrent operations', () async {
        const operationCount = 20;
        
        // Create concurrent operations
        final futures = <Future>[];
        
        for (int i = 0; i < operationCount; i++) {
          futures.add(
            performanceMonitor.trackQuery('concurrent_op_$i', () async {
              // Simulate work
              await Future.delayed(Duration(milliseconds: 10 + (i % 5) * 5));
              return 'result_$i';
            }),
          );
        }
        
        final stopwatch = Stopwatch()..start();
        final results = await Future.wait(futures);
        stopwatch.stop();
        
        expect(results.length, equals(operationCount));
        print('Completed $operationCount concurrent operations in ${stopwatch.elapsedMilliseconds}ms');
        
        // Check that all operations were tracked
        final queryStats = performanceMonitor.getQueryStatistics();
        int trackedOperations = 0;
        
        for (final key in queryStats.keys) {
          if (key.startsWith('concurrent_op_')) {
            trackedOperations++;
          }
        }
        
        expect(trackedOperations, equals(operationCount));
      });

      test('should maintain performance under load', () async {
        const batchSize = 50;
        const batchCount = 5;
        
        final batchTimes = <int>[];
        
        for (int batch = 0; batch < batchCount; batch++) {
          final stopwatch = Stopwatch()..start();
          
          // Create batch operations
          final batchFutures = <Future>[];
          
          for (int i = 0; i < batchSize; i++) {
            batchFutures.add(
              performanceMonitor.trackQuery('batch_${batch}_op_$i', () async {
                await Future.delayed(Duration(milliseconds: 1 + (i % 3)));
                return 'batch_${batch}_result_$i';
              }),
            );
          }
          
          await Future.wait(batchFutures);
          
          stopwatch.stop();
          batchTimes.add(stopwatch.elapsedMilliseconds);
          
          print('Batch $batch ($batchSize operations) completed in ${stopwatch.elapsedMilliseconds}ms');
        }
        
        // Analyze performance consistency
        final avgBatchTime = batchTimes.reduce((a, b) => a + b) / batchTimes.length;
        final maxBatchTime = batchTimes.reduce((a, b) => a > b ? a : b);
        final minBatchTime = batchTimes.reduce((a, b) => a < b ? a : b);
        
        print('Batch times - Min: ${minBatchTime}ms, Max: ${maxBatchTime}ms, Avg: ${avgBatchTime.toStringAsFixed(2)}ms');
        
        // Performance should be consistent (max shouldn't be more than 3x min)
        expect(maxBatchTime / minBatchTime, lessThan(3.0), reason: 'Performance should be consistent across batches');
      });
    });
  });
}
