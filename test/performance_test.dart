import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import '../lib/view/tab_screen/view-model/backend/performance_monitor.dart';
import '../lib/view/tab_screen/view-model/backend/lazy_loading_service.dart';
import '../lib/view/tab_screen/view-model/backend/sqlite_dao.dart';
import '../lib/view/tab_screen/view-model/backend/sync_manager.dart';
import '../lib/view/tab_screen/view-model/backend/image_cache_service.dart';
import 'test_database_helper.dart';

void main() {
  group('Performance Tests', () {
    late TestDatabaseHelper testHelper;
    late SQLiteDAO sqliteDAO;
    late PerformanceMonitor performanceMonitor;
    late LazyLoadingService lazyLoadingService;
    late ImageCacheService imageCacheService;

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
      
      lazyLoadingService = LazyLoadingService();
      imageCacheService = ImageCacheService();
    });

    tearDown(() async {
      performanceMonitor.stopMonitoring();
      performanceMonitor.dispose();
      lazyLoadingService.clearAllCaches();
      await sqliteDAO.close();
      await TestDatabaseHelper.clearAllTables();
      await TestDatabaseHelper.closeTestDatabase();
    });

    group('Database Query Performance', () {
      test('should handle large dataset queries efficiently', () async {
        const adminUid = 'test_admin';
        const itemCount = 1000;
        
        // Insert large dataset
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + (i % 50),
            'department': 'Department ${i % 10}',
            'food_code': 'CODE$i',
            'description': 'Description for item $i',
            'stocks': 100 - (i % 100),
            'is_hot': i % 2 == 0,
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        stopwatch.stop();
        final insertTime = stopwatch.elapsedMilliseconds;
        print('Inserted $itemCount items in ${insertTime}ms (${(insertTime / itemCount).toStringAsFixed(2)}ms per item)');
        
        // Test query performance
        stopwatch.reset();
        stopwatch.start();
        
        final allItems = await sqliteDAO.getFoodItems(adminUid);
        
        stopwatch.stop();
        final queryTime = stopwatch.elapsedMilliseconds;
        print('Queried ${allItems.length} items in ${queryTime}ms');
        
        expect(allItems.length, equals(itemCount));
        expect(queryTime, lessThan(1000), reason: 'Query should complete within 1 second');
      });

      test('should perform paginated queries efficiently', () async {
        const adminUid = 'test_admin';
        const itemCount = 500;
        const pageSize = 20;
        
        // Insert test data
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
            'department': 'Department ${i % 5}',
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        // Test paginated queries
        final pageTimes = <int>[];
        
        for (int page = 0; page < (itemCount / pageSize).ceil(); page++) {
          final stopwatch = Stopwatch()..start();
          
          final pageItems = await sqliteDAO.getFoodItemsPaginated(
            adminUid,
            offset: page * pageSize,
            limit: pageSize,
          );
          
          stopwatch.stop();
          pageTimes.add(stopwatch.elapsedMilliseconds);
          
          expect(pageItems.length, lessThanOrEqualTo(pageSize));
        }
        
        final avgPageTime = pageTimes.reduce((a, b) => a + b) / pageTimes.length;
        final maxPageTime = pageTimes.reduce((a, b) => a > b ? a : b);
        
        print('Average page query time: ${avgPageTime.toStringAsFixed(2)}ms');
        print('Max page query time: ${maxPageTime}ms');
        
        expect(avgPageTime, lessThan(100), reason: 'Average page query should be under 100ms');
        expect(maxPageTime, lessThan(200), reason: 'Max page query should be under 200ms');
      });

      test('should handle search queries efficiently', () async {
        const adminUid = 'test_admin';
        const itemCount = 1000;
        
        // Insert test data with searchable content
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
            'food_code': 'CODE$i',
            'description': 'Delicious food item number $i',
            'department': 'Department ${i % 10}',
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        // Test search performance
        final searchTerms = ['Food', 'CODE1', 'Delicious', 'Item 5'];
        
        for (final searchTerm in searchTerms) {
          final stopwatch = Stopwatch()..start();
          
          final searchResults = await sqliteDAO.searchFoodItems(adminUid, searchTerm);
          
          stopwatch.stop();
          final searchTime = stopwatch.elapsedMilliseconds;
          
          print('Search for "$searchTerm" returned ${searchResults.length} results in ${searchTime}ms');
          
          expect(searchTime, lessThan(500), reason: 'Search should complete within 500ms');
          expect(searchResults.isNotEmpty, isTrue, reason: 'Search should return results');
        }
      });
    });

    group('Memory Usage Tests', () {
      test('should manage memory efficiently during large operations', () async {
        const adminUid = 'test_admin';
        const itemCount = 2000;
        
        // Monitor memory during large insert operation
        final initialStats = performanceMonitor.getMemoryStatistics();
        print('Initial memory: ${initialStats['currentUsageMB']}MB');
        
        // Insert large dataset
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i with a longer description to use more memory',
            'price': 10.0 + i,
            'department': 'Department ${i % 10}',
            'description': 'This is a longer description for item $i that should use more memory to test memory management during large operations',
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
          
          // Check memory every 100 items
          if (i % 100 == 0) {
            final currentStats = performanceMonitor.getMemoryStatistics();
            print('Memory at item $i: ${currentStats['currentUsageMB']}MB');
          }
        }
        
        final finalStats = performanceMonitor.getMemoryStatistics();
        print('Final memory: ${finalStats['currentUsageMB']}MB');
        
        // Memory should not grow excessively
        final initialMemory = double.tryParse(initialStats['currentUsageMB'].toString()) ?? 0;
        final finalMemory = double.tryParse(finalStats['currentUsageMB'].toString()) ?? 0;
        final memoryIncrease = finalMemory - initialMemory;
        
        print('Memory increase: ${memoryIncrease.toStringAsFixed(2)}MB');
        
        // Memory increase should be reasonable (less than 50MB for this test)
        expect(memoryIncrease, lessThan(50), reason: 'Memory increase should be reasonable');
      });

      test('should handle image cache memory efficiently', () async {
        // Create test image data
        final testImages = <Uint8List>[];
        for (int i = 0; i < 50; i++) {
          // Create fake image data (1KB each)
          final imageData = Uint8List(1024);
          for (int j = 0; j < imageData.length; j++) {
            imageData[j] = (i + j) % 256;
          }
          testImages.add(imageData);
        }
        
        // Cache images and monitor memory
        final initialStats = performanceMonitor.getMemoryStatistics();
        
        for (int i = 0; i < testImages.length; i++) {
          await imageCacheService.storeImageBlob(
            'food_items',
            'item_$i',
            'https://example.com/image_$i.jpg',
            testImages[i],
          );
        }
        
        final finalStats = performanceMonitor.getMemoryStatistics();
        final cacheStats = await imageCacheService.getCacheStatistics();
        
        print('Cached ${cacheStats['totalImages']} images (${cacheStats['totalSizeBytes']} bytes)');
        print('Memory before: ${initialStats['currentUsageMB']}MB');
        print('Memory after: ${finalStats['currentUsageMB']}MB');
        
        expect(cacheStats['totalImages'], equals(testImages.length));
        expect(cacheStats['totalSizeBytes'], greaterThan(0));
      });
    });

    group('Lazy Loading Performance', () {
      test('should load data efficiently with lazy loading', () async {
        const adminUid = 'test_admin';
        const itemCount = 500;
        const pageSize = 25;
        
        // Insert test data
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
            'department': 'Department ${i % 5}',
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        // Create lazy loader
        final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
          cacheKey: 'test_food_items',
          pageSize: pageSize,
          itemIdExtractor: (item) => item['id'] as String,
          dataFetcher: (offset, limit) async {
            return await sqliteDAO.getFoodItemsPaginated(
              adminUid,
              offset: offset,
              limit: limit,
            );
          },
        );
        
        // Test loading performance
        final loadTimes = <int>[];
        
        for (int page = 0; page < 5; page++) {
          final stopwatch = Stopwatch()..start();
          
          final pageData = await loader.loadPage(page);
          
          stopwatch.stop();
          loadTimes.add(stopwatch.elapsedMilliseconds);
          
          expect(pageData.length, lessThanOrEqualTo(pageSize));
          print('Page $page loaded in ${stopwatch.elapsedMilliseconds}ms (${pageData.length} items)');
        }
        
        // Test cache performance (second load should be faster)
        final stopwatch = Stopwatch()..start();
        final cachedPage = await loader.loadPage(0);
        stopwatch.stop();
        
        print('Cached page 0 loaded in ${stopwatch.elapsedMilliseconds}ms');
        
        expect(cachedPage.length, equals(pageSize));
        expect(stopwatch.elapsedMilliseconds, lessThan(10), reason: 'Cached page should load very quickly');
        
        // Check loader statistics
        final stats = loader.getStatistics();
        print('Loader stats: ${stats['cacheHits']} hits, ${stats['cacheMisses']} misses, ${stats['hitRate'].toStringAsFixed(1)}% hit rate');
        
        expect(stats['cacheHits'], greaterThan(0));
        expect(stats['hitRate'], greaterThan(0));
      });

      test('should preload pages efficiently', () async {
        const adminUid = 'test_admin';
        const itemCount = 200;
        const pageSize = 20;
        
        // Insert test data
        for (int i = 0; i < itemCount; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        // Create lazy loader
        final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
          cacheKey: 'test_preload',
          pageSize: pageSize,
          itemIdExtractor: (item) => item['id'] as String,
          dataFetcher: (offset, limit) async {
            return await sqliteDAO.getFoodItemsPaginated(
              adminUid,
              offset: offset,
              limit: limit,
            );
          },
        );
        
        // Test preloading
        final stopwatch = Stopwatch()..start();
        
        await loader.preloadPages([0, 1, 2, 3, 4]);
        
        stopwatch.stop();
        final preloadTime = stopwatch.elapsedMilliseconds;
        
        print('Preloaded 5 pages in ${preloadTime}ms');
        
        // Verify all pages are cached
        for (int page = 0; page < 5; page++) {
          expect(loader.isPageLoaded(page), isTrue, reason: 'Page $page should be preloaded');
        }
        
        expect(preloadTime, lessThan(1000), reason: 'Preloading should complete within 1 second');
      });
    });

    group('Performance Monitoring', () {
      test('should track query performance accurately', () async {
        const adminUid = 'test_admin';
        
        // Insert some test data
        for (int i = 0; i < 100; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
        }
        
        // Perform tracked queries
        for (int i = 0; i < 10; i++) {
          await performanceMonitor.trackQuery('test_query', () async {
            return await sqliteDAO.getFoodItems(adminUid);
          });
        }
        
        // Check performance statistics
        final queryStats = performanceMonitor.getQueryStatistics();
        expect(queryStats.containsKey('test_query'), isTrue);
        
        final testQueryStats = queryStats['test_query'] as Map<String, dynamic>;
        expect(testQueryStats['count'], equals(10));
        expect(testQueryStats['averageMs'], greaterThan(0));
        expect(testQueryStats['minMs'], greaterThan(0));
        expect(testQueryStats['maxMs'], greaterThanOrEqualTo(testQueryStats['minMs']));
        
        print('Query statistics: $testQueryStats');
      });

      test('should generate performance recommendations', () async {
        // Simulate some operations to generate metrics
        const adminUid = 'test_admin';
        
        for (int i = 0; i < 50; i++) {
          final foodItem = {
            'id': 'item_$i',
            'name': 'Food Item $i',
            'price': 10.0 + i,
          };
          
          await sqliteDAO.saveFoodItem(adminUid, foodItem);
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
    });

    group('Stress Tests', () {
      test('should handle concurrent operations efficiently', () async {
        const adminUid = 'test_admin';
        const concurrentOperations = 20;
        
        // Create concurrent insert operations
        final futures = <Future>[];
        
        for (int i = 0; i < concurrentOperations; i++) {
          futures.add(
            performanceMonitor.trackQuery('concurrent_insert_$i', () async {
              final foodItem = {
                'id': 'concurrent_item_$i',
                'name': 'Concurrent Food Item $i',
                'price': 10.0 + i,
                'department': 'Concurrent Department',
              };
              
              await sqliteDAO.saveFoodItem(adminUid, foodItem);
            }),
          );
        }
        
        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();
        
        print('Completed $concurrentOperations concurrent operations in ${stopwatch.elapsedMilliseconds}ms');
        
        // Verify all items were inserted
        final allItems = await sqliteDAO.getFoodItems(adminUid);
        final concurrentItems = allItems.where((item) => item['id'].toString().startsWith('concurrent_item_')).toList();
        
        expect(concurrentItems.length, equals(concurrentOperations));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000), reason: 'Concurrent operations should complete within 5 seconds');
      });

      test('should maintain performance under heavy load', () async {
        const adminUid = 'test_admin';
        const batchSize = 100;
        const batchCount = 10;
        
        final batchTimes = <int>[];
        
        for (int batch = 0; batch < batchCount; batch++) {
          final stopwatch = Stopwatch()..start();
          
          // Insert batch of items
          for (int i = 0; i < batchSize; i++) {
            final itemId = 'batch_${batch}_item_$i';
            final foodItem = {
              'id': itemId,
              'name': 'Batch $batch Item $i',
              'price': 10.0 + i,
              'department': 'Batch Department $batch',
            };
            
            await sqliteDAO.saveFoodItem(adminUid, foodItem);
          }
          
          stopwatch.stop();
          batchTimes.add(stopwatch.elapsedMilliseconds);
          
          print('Batch $batch ($batchSize items) completed in ${stopwatch.elapsedMilliseconds}ms');
        }
        
        // Analyze performance degradation
        final firstBatchTime = batchTimes.first;
        final lastBatchTime = batchTimes.last;
        final avgBatchTime = batchTimes.reduce((a, b) => a + b) / batchTimes.length;
        
        print('First batch: ${firstBatchTime}ms');
        print('Last batch: ${lastBatchTime}ms');
        print('Average batch: ${avgBatchTime.toStringAsFixed(2)}ms');
        
        // Performance should not degrade significantly
        final performanceDegradation = (lastBatchTime - firstBatchTime) / firstBatchTime;
        expect(performanceDegradation, lessThan(2.0), reason: 'Performance should not degrade more than 200%');
        
        // Verify total item count
        final totalItems = await sqliteDAO.getFoodItemsCount(adminUid);
        expect(totalItems, equals(batchSize * batchCount));
      });
    });
  });
}