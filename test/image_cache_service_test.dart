// Dart imports:
import 'dart:math';
import 'dart:typed_data';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/image_cache_service.dart';

void main() {
  group('ImageCacheService Tests', () {
    late ImageCacheService imageCacheService;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      imageCacheService = ImageCacheService();
    });

    test('should store and retrieve image BLOB', () async {
      // Arrange
      const tableName = 'food_items';
      const recordId = 'test_item_1';
      const imageUrl = 'https://example.com/image.jpg';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Act
      await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
      final retrievedData = await imageCacheService.getImageBlob(tableName, recordId);

      // Assert
      expect(retrievedData, isNotNull);
      expect(retrievedData, equals(imageData));
    });

    test('should return null for non-existent image', () async {
      // Arrange
      const tableName = 'food_items';
      const recordId = 'non_existent_item';

      // Act
      final retrievedData = await imageCacheService.getImageBlob(tableName, recordId);

      // Assert
      expect(retrievedData, isNull);
    });

    test('should check if image is cached correctly', () async {
      // Arrange
      const tableName = 'departments';
      const recordId = 'test_dept_1';
      const imageUrl = 'https://example.com/dept.jpg';
      final imageData = Uint8List.fromList([10, 20, 30]);

      // Act - Before caching
      final isInitiallyCached = await imageCacheService.isImageCached(tableName, recordId);
      
      // Cache the image
      await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
      
      // Act - After caching
      final isCachedAfterStore = await imageCacheService.isImageCached(tableName, recordId);

      // Assert
      expect(isInitiallyCached, isFalse);
      expect(isCachedAfterStore, isTrue);
    });

    test('should clear image cache', () async {
      // Arrange
      const tableName = 'food_items';
      const recordId = 'test_item_clear';
      const imageUrl = 'https://example.com/clear.jpg';
      final imageData = Uint8List.fromList([100, 200]);

      // Store image first
      await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
      
      // Verify it's cached
      final isInitiallyCached = await imageCacheService.isImageCached(tableName, recordId);
      expect(isInitiallyCached, isTrue);

      // Act - Clear cache
      await imageCacheService.clearImageCache();

      // Assert
      final isCachedAfterClear = await imageCacheService.isImageCached(tableName, recordId);
      expect(isCachedAfterClear, isFalse);
    });

    test('should get cache statistics', () async {
      // Arrange
      const tableName = 'food_items';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Store multiple images
      await imageCacheService.storeImageBlob(tableName, 'item1', 'url1', imageData);
      await imageCacheService.storeImageBlob(tableName, 'item2', 'url2', imageData);

      // Act
      final stats = await imageCacheService.getCacheStatistics();

      // Assert
      expect(stats['totalImages'], equals(2));
      expect(stats['totalSizeBytes'], equals(imageData.length * 2));
      expect(stats['oldestCacheTime'], isNotNull);
      expect(stats['mostRecentAccess'], isNotNull);
    });

    test('should remove specific cached image', () async {
      // Arrange
      const tableName = 'departments';
      const recordId = 'test_remove';
      const imageUrl = 'https://example.com/remove.jpg';
      final imageData = Uint8List.fromList([50, 60, 70]);

      // Store image
      await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
      
      // Verify it's cached
      final isInitiallyCached = await imageCacheService.isImageCached(tableName, recordId);
      expect(isInitiallyCached, isTrue);

      // Act - Remove specific image
      await imageCacheService.removeCachedImage(tableName, recordId);

      // Assert
      final isCachedAfterRemoval = await imageCacheService.isImageCached(tableName, recordId);
      expect(isCachedAfterRemoval, isFalse);
    });

    test('should get detailed cache statistics', () async {
      // Arrange
      const tableName = 'food_items';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Store multiple images
      await imageCacheService.storeImageBlob(tableName, 'item1', 'url1', imageData);
      await imageCacheService.storeImageBlob(tableName, 'item2', 'url2', imageData);

      // Act
      final stats = await imageCacheService.getDetailedCacheStatistics();

      // Assert
      expect(stats['totalImages'], equals(2));
      expect(stats['totalSizeBytes'], equals(imageData.length * 2));
      expect(stats['tableStatistics'], isA<List>());
      expect(stats['cacheHitRate'], isA<double>());
      expect(stats['storageEfficiency'], isA<double>());
      expect(stats['maxCacheSizeBytes'], isA<int>());
      expect(stats['cacheUtilization'], isA<double>());
    });

    test('should generate cache health report', () async {
      // Arrange
      const tableName = 'food_items';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Store an image
      await imageCacheService.storeImageBlob(tableName, 'item1', 'url1', imageData);

      // Act
      final healthReport = await imageCacheService.getCacheHealthReport();

      // Assert
      expect(healthReport['status'], isA<String>());
      expect(healthReport['recommendations'], isA<List>());
      expect(healthReport['statistics'], isA<Map>());
    });

    test('should perform cache maintenance', () async {
      // Arrange
      const tableName = 'food_items';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Store some images
      await imageCacheService.storeImageBlob(tableName, 'item1', 'url1', imageData);
      await imageCacheService.storeImageBlob(tableName, 'item2', 'url2', imageData);

      // Act
      await imageCacheService.performMaintenance();

      // Assert - Should complete without errors
      final stats = await imageCacheService.getCacheStatistics();
      expect(stats['totalImages'], isA<int>());
    });

    test('should optimize storage', () async {
      // Arrange
      const tableName = 'food_items';
      final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Store some images
      await imageCacheService.storeImageBlob(tableName, 'item1', 'url1', imageData);
      await imageCacheService.storeImageBlob(tableName, 'item2', 'url2', imageData);

      // Act
      await imageCacheService.optimizeStorage();

      // Assert - Should complete without errors
      final stats = await imageCacheService.getCacheStatistics();
      expect(stats, isA<Map<String, dynamic>>());
    });

    tearDown(() async {
      // Clean up after each test
      await imageCacheService.clearImageCache();
    });

    // **Feature: sqlite-firebase-sync, Property 28: Image BLOB caching consistency**
    // **Validates: Requirements 1.3, 2.1**
    test('Property 28: Image BLOB caching consistency - For any image downloaded from Firebase, the image cache service should store the image as BLOB in SQLite for offline access', () async {
      final random = Random();
      
      // Run property test with 100 iterations as specified in design
      for (int i = 0; i < 100; i++) {
        // Generate random test data
        final tableNames = ['food_items', 'departments'];
        final tableName = tableNames[random.nextInt(tableNames.length)];
        final recordId = 'test_record_$i'; // Use iteration number for uniqueness
        final imageUrl = 'https://example.com/image_$i.jpg';
        
        // Generate random image data (1-100 bytes for faster testing)
        final imageSize = random.nextInt(100) + 1;
        final imageData = Uint8List.fromList(
          List.generate(imageSize, (index) => random.nextInt(256))
        );

        try {
          // Property: When an image is stored as BLOB, it should be retrievable with identical data
          await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
          
          // Verify the image is cached
          final isCached = await imageCacheService.isImageCached(tableName, recordId);
          expect(isCached, isTrue, 
            reason: 'Image should be marked as cached after storing BLOB for iteration $i');
          
          // Retrieve the cached image
          final retrievedData = await imageCacheService.getImageBlob(tableName, recordId);
          
          // Property assertion: Retrieved data should be identical to stored data
          expect(retrievedData, isNotNull, 
            reason: 'Retrieved image data should not be null for iteration $i');
          expect(retrievedData, equals(imageData), 
            reason: 'Retrieved image data should match stored data exactly for iteration $i');
          expect(retrievedData!.length, equals(imageData.length), 
            reason: 'Retrieved image size should match stored size for iteration $i');
          
        } catch (e) {
          fail('Property test failed at iteration $i: $e');
        }
      }
      
      // Clean up all test data at the end
      await imageCacheService.clearImageCache();
    }, timeout: const Timeout(Duration(minutes: 2)));

    // **Feature: sqlite-firebase-sync, Property 30: Image cache cleanup efficiency**
    // **Validates: Requirements 6.4**
    test('Property 30: Image cache cleanup efficiency - For any unused image BLOB older than cache retention period, the image cache service should automatically remove it to manage storage space', () async {
      final random = Random();
      
      // Run property test with 100 iterations as specified in design
      for (int i = 0; i < 100; i++) {
        // Generate random test data
        final tableNames = ['food_items', 'departments'];
        final tableName = tableNames[random.nextInt(tableNames.length)];
        final recordId = 'cleanup_test_$i';
        final imageUrl = 'https://example.com/cleanup_$i.jpg';
        
        // Generate random image data (1-100 bytes for faster testing)
        final imageSize = random.nextInt(100) + 1;
        final imageData = Uint8List.fromList(
          List.generate(imageSize, (index) => random.nextInt(256))
        );

        try {
          // Store the image
          await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
          
          // Verify it's initially cached
          final isInitiallyCached = await imageCacheService.isImageCached(tableName, recordId);
          expect(isInitiallyCached, isTrue, 
            reason: 'Image should be cached after storing for iteration $i');
          
          // Get initial cache statistics
          final initialStats = await imageCacheService.getCacheStatistics();
          final initialImageCount = initialStats['totalImages'] as int;
          
          // Property test: Clear images older than 0 days (should remove all)
          await imageCacheService.clearImageCache(olderThanDays: 0);
          
          // Verify the image was removed
          final isCachedAfterCleanup = await imageCacheService.isImageCached(tableName, recordId);
          expect(isCachedAfterCleanup, isFalse, 
            reason: 'Image should be removed after cleanup for iteration $i');
          
          // Verify cache statistics reflect the cleanup
          final finalStats = await imageCacheService.getCacheStatistics();
          final finalImageCount = finalStats['totalImages'] as int;
          
          // Property assertion: Image count should be reduced after cleanup
          expect(finalImageCount, lessThan(initialImageCount), 
            reason: 'Cache cleanup should reduce image count for iteration $i');
          
        } catch (e) {
          fail('Property test failed at iteration $i: $e');
        }
      }
      
      // Test automatic cleanup with retention period
      for (int i = 0; i < 10; i++) {
        const tableName = 'food_items';
        final recordId = 'auto_cleanup_$i';
        final imageUrl = 'https://example.com/auto_$i.jpg';
        final imageData = Uint8List.fromList([i, i + 1, i + 2]);
        
        try {
          // Store image
          await imageCacheService.storeImageBlob(tableName, recordId, imageUrl, imageData);
          
          // Get initial count
          final initialStats = await imageCacheService.getCacheStatistics();
          final initialCount = initialStats['totalImages'] as int;
          
          // Perform automatic cleanup (should remove old images based on retention period)
          await imageCacheService.performAutomaticCleanup();
          
          // Get final count
          final finalStats = await imageCacheService.getCacheStatistics();
          final finalCount = finalStats['totalImages'] as int;
          
          // Property assertion: Cleanup should not increase image count
          expect(finalCount, lessThanOrEqualTo(initialCount), 
            reason: 'Automatic cleanup should not increase image count for iteration $i');
          
        } catch (e) {
          fail('Automatic cleanup property test failed at iteration $i: $e');
        }
      }
      
      // Clean up all test data at the end
      await imageCacheService.clearImageCache();
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
