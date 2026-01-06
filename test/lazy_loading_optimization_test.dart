// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/lazy_loading_service.dart';

/// Unit tests for lazy loading optimization functionality
/// Tests the core lazy loading logic without UI dependencies
void main() {
  group('Lazy Loading Service Tests', () {
    late LazyLoadingService lazyLoadingService;

    setUp(() {
      lazyLoadingService = LazyLoadingService();
    });

    tearDown(() {
      lazyLoadingService.clearAllCaches();
    });

    test('should create lazy data loader with correct configuration', () {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 10,
      );

      expect(loader.cacheKey, equals('test_items'));
      expect(loader.pageSize, equals(10));
    });

    test('should load page data correctly', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      final page0 = await loader.loadPage(0);
      expect(page0.length, equals(5));
      expect(page0[0]['id'], equals('0'));
      expect(page0[4]['id'], equals('4'));

      final page1 = await loader.loadPage(1);
      expect(page1.length, equals(5));
      expect(page1[0]['id'], equals('5'));
      expect(page1[4]['id'], equals('9'));
    });

    test('should cache loaded pages', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      // Load page 0 first time
      await loader.loadPage(0);
      expect(loader.isPageLoaded(0), isTrue);
      expect(loader.isPageLoaded(1), isFalse);

      // Load page 1
      await loader.loadPage(1);
      expect(loader.isPageLoaded(0), isTrue);
      expect(loader.isPageLoaded(1), isTrue);
    });

    test('should track cache statistics', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      // Load page 0 twice to test cache hits
      await loader.loadPage(0);
      await loader.loadPage(0);

      final stats = loader.getStatistics();
      expect(stats['cacheKey'], equals('test_items'));
      expect(stats['pageSize'], equals(5));
      expect(stats['cacheHits'], greaterThan(0));
    });

    test('should load items around specific index', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      final itemsAround = await loader.loadItemsAround(7, bufferSize: 3);
      expect(itemsAround.length, greaterThan(0));
      
      // Should load items around index 7 (items 4-10 with buffer of 3)
      final itemIds = itemsAround.map((item) => item['id']).toList();
      expect(itemIds, contains('7'));
    });

    test('should preload multiple pages', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      await loader.preloadPages([0, 1, 2]);
      
      expect(loader.isPageLoaded(0), isTrue);
      expect(loader.isPageLoaded(1), isTrue);
      expect(loader.isPageLoaded(2), isTrue);
      expect(loader.isPageLoaded(3), isFalse);
    });

    test('should clear cache correctly', () async {
      final loader = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'test_items',
        dataFetcher: (offset, limit) async {
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 5,
      );

      await loader.loadPage(0);
      expect(loader.isPageLoaded(0), isTrue);

      loader.invalidateCache();
      expect(loader.isPageLoaded(0), isFalse);
    });

    test('should get cache statistics for all loaders', () async {
      final loader1 = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'items_1',
        dataFetcher: (offset, limit) async => [],
        itemIdExtractor: (item) => item['id'] as String,
      );

      final loader2 = lazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'items_2',
        dataFetcher: (offset, limit) async => [],
        itemIdExtractor: (item) => item['id'] as String,
      );

      await loader1.loadPage(0);
      await loader2.loadPage(0);

      final allStats = lazyLoadingService.getCacheStatistics();
      expect(allStats.keys, contains('items_1'));
      expect(allStats.keys, contains('items_2'));
    });
  });

  group('Performance Optimization Tests', () {
    late LazyLoadingService testLazyLoadingService;

    setUp(() {
      testLazyLoadingService = LazyLoadingService();
    });

    tearDown(() {
      testLazyLoadingService.clearAllCaches();
    });

    test('should handle large datasets efficiently', () async {
      final loader = testLazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'large_dataset',
        dataFetcher: (offset, limit) async {
          // Simulate large dataset
          return List.generate(limit, (index) => {
            'id': '${offset + index}',
            'name': 'Item ${offset + index}',
            'price': '${(offset + index) * 10}.00',
            'department': 'Department ${(offset + index) % 5}',
          });
        },
        itemIdExtractor: (item) => item['id'] as String,
        pageSize: 50,
      );

      // Load multiple pages to simulate scrolling
      final pages = await Future.wait([
        loader.loadPage(0),
        loader.loadPage(1),
        loader.loadPage(2),
      ]);

      expect(pages[0].length, equals(50));
      expect(pages[1].length, equals(50));
      expect(pages[2].length, equals(50));

      // Verify data integrity
      expect(pages[0][0]['id'], equals('0'));
      expect(pages[1][0]['id'], equals('50'));
      expect(pages[2][0]['id'], equals('100'));
    });

    test('should cleanup expired caches', () async {
      final loader = testLazyLoadingService.createLoader<Map<String, dynamic>>(
        cacheKey: 'expiry_test',
        dataFetcher: (offset, limit) async => [],
        itemIdExtractor: (item) => item['id'] as String,
      );

      await loader.loadPage(0);
      
      // Verify cache exists
      final statsBefore = testLazyLoadingService.getCacheStatistics();
      expect(statsBefore.keys, contains('expiry_test'));

      // Cleanup expired caches
      testLazyLoadingService.cleanupExpiredCaches();
      
      // Cache should still exist as it's not expired yet
      final statsAfter = testLazyLoadingService.getCacheStatistics();
      expect(statsAfter.keys, contains('expiry_test'));
    });
  });
}

