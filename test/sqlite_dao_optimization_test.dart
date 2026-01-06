// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/sqlite_dao.dart';
import 'test_database_helper.dart';

void main() {
  group('SQLiteDAO Optimization Tests', () {
    late SQLiteDAO sqliteDAO;
    const String testAdminUid = 'test_admin_optimization';

    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Initialize test database
      await TestDatabaseHelper.getTestDatabase();
    });

    setUp(() async {
      sqliteDAO = SQLiteDAO();
      await sqliteDAO.initialize();
    });

    tearDown(() async {
      try {
        await sqliteDAO.close();
      } catch (e) {
        // Ignore cleanup errors in tests
      }
      await TestDatabaseHelper.clearAllTables();
    });

    tearDownAll(() async {
      await TestDatabaseHelper.closeTestDatabase();
    });

    group('Batch Operations', () {
      test('should perform batch insert operations efficiently', () async {
        // Create test food items
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 10; i++) {
          foodItems.add({
            'id': 'batch_item_$i',
            'name': 'Batch Food Item $i',
            'price': 10.0 + i,
            'description': 'Test batch item $i',
            'food_code': 'BATCH$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': i % 2 == 0,
          });
        }

        // Perform batch insert
        final stopwatch = Stopwatch()..start();
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);
        stopwatch.stop();

        // Verify all items were inserted
        final allItems = await sqliteDAO.getFoodItems(testAdminUid);
        final batchItems = allItems.where((item) => 
          (item['id'] as String).startsWith('batch_item_')
        ).toList();

        expect(batchItems.length, equals(10));
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast

        // Verify sync status
        for (final item in batchItems) {
          expect(item['sync_status'], equals(SyncStatus.pending.value));
        }
      });

      test('should perform batch update operations efficiently', () async {
        // First insert some items
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          foodItems.add({
            'id': 'update_item_$i',
            'name': 'Update Food Item $i',
            'price': 10.0 + i,
            'description': 'Test update item $i',
            'food_code': 'UPDATE$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Prepare batch updates
        final updates = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          updates.add({
            'id': 'update_item_$i',
            'name': 'Updated Food Item $i',
            'price': 20.0 + i,
            'is_hot': true,
          });
        }

        // Perform batch update
        final stopwatch = Stopwatch()..start();
        await sqliteDAO.batchUpdateFoodItems(testAdminUid, updates);
        stopwatch.stop();

        // Verify updates
        for (int i = 0; i < 5; i++) {
          final item = await sqliteDAO.getFoodItem(testAdminUid, 'update_item_$i');
          expect(item, isNotNull);
          expect(item!['name'], equals('Updated Food Item $i'));
          expect(item['price'], equals(20.0 + i));
          expect(item['is_hot'], equals(1)); // SQLite stores as integer
          expect(item['sync_status'], equals(SyncStatus.pending.value));
        }

        expect(stopwatch.elapsedMilliseconds, lessThan(500)); // Should be fast
      });

      test('should perform batch delete operations efficiently', () async {
        // First insert some items
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 8; i++) {
          foodItems.add({
            'id': 'delete_item_$i',
            'name': 'Delete Food Item $i',
            'price': 10.0 + i,
            'description': 'Test delete item $i',
            'food_code': 'DELETE$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Prepare items to delete
        final itemsToDelete = ['delete_item_2', 'delete_item_4', 'delete_item_6'];

        // Perform batch delete
        final stopwatch = Stopwatch()..start();
        await sqliteDAO.batchDeleteFoodItems(testAdminUid, itemsToDelete);
        stopwatch.stop();

        // Verify deletions
        for (final itemId in itemsToDelete) {
          final item = await sqliteDAO.getFoodItem(testAdminUid, itemId);
          expect(item, isNull);
        }

        // Verify remaining items
        final remainingItems = await sqliteDAO.getFoodItems(testAdminUid);
        final deleteTestItems = remainingItems.where((item) => 
          (item['id'] as String).startsWith('delete_item_')
        ).toList();
        expect(deleteTestItems.length, equals(5)); // 8 - 3 = 5

        expect(stopwatch.elapsedMilliseconds, lessThan(300)); // Should be fast
      });
    });

    group('Enhanced Query Methods', () {
      test('should perform advanced food items queries with filtering', () async {
        // Insert test data with various attributes
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 20; i++) {
          foodItems.add({
            'id': 'advanced_item_$i',
            'name': 'Advanced Food Item $i',
            'price': 5.0 + (i * 2.5), // Prices from 5.0 to 52.5
            'description': 'Test advanced item $i',
            'food_code': 'ADV$i',
            'department': i < 10 ? 'Department A' : 'Department B',
            'stocks': 50 + (i * 5), // Stocks from 50 to 145
            'is_hot': i % 3 == 0, // Every third item is hot
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Test price range filtering
        final priceFilteredItems = await sqliteDAO.getFoodItemsAdvanced(
          testAdminUid,
          minPrice: 15.0,
          maxPrice: 30.0,
          sortBy: 'price',
          sortOrder: 'ASC',
        );

        expect(priceFilteredItems.isNotEmpty, isTrue);
        for (final item in priceFilteredItems) {
          final price = item['price'] as double;
          expect(price, greaterThanOrEqualTo(15.0));
          expect(price, lessThanOrEqualTo(30.0));
        }

        // Test department filtering
        final deptFilteredItems = await sqliteDAO.getFoodItemsAdvanced(
          testAdminUid,
          department: 'Department A',
        );

        expect(deptFilteredItems.length, equals(10));
        for (final item in deptFilteredItems) {
          expect(item['department'], equals('Department A'));
        }

        // Test hot items filtering
        final hotItems = await sqliteDAO.getFoodItemsAdvanced(
          testAdminUid,
          isHot: true,
        );

        expect(hotItems.isNotEmpty, isTrue);
        for (final item in hotItems) {
          expect(item['is_hot'], equals(1)); // SQLite stores as integer
        }

        // Test stock level filtering
        final highStockItems = await sqliteDAO.getFoodItemsAdvanced(
          testAdminUid,
          minStocks: 100,
          sortBy: 'stocks',
          sortOrder: 'DESC',
        );

        expect(highStockItems.isNotEmpty, isTrue);
        for (final item in highStockItems) {
          expect(item['stocks'] as int, greaterThanOrEqualTo(100));
        }
      });

      test('should perform cursor-based pagination efficiently', () async {
        // Insert test data
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 50; i++) {
          foodItems.add({
            'id': 'cursor_item_${i.toString().padLeft(3, '0')}',
            'name': 'Cursor Item ${i.toString().padLeft(3, '0')}',
            'price': 10.0 + i,
            'description': 'Test cursor item $i',
            'food_code': 'CURSOR$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Test cursor-based pagination
        const pageSize = 10;
        String? cursor;
        int totalItemsRetrieved = 0;
        int pageCount = 0;

        while (pageCount < 3) { // Test first 3 pages
          final result = await sqliteDAO.getFoodItemsPaginatedWithCursor(
            testAdminUid,
            cursor: cursor,
            limit: pageSize,
            sortBy: 'name',
            sortOrder: 'ASC',
          );

          final items = result['items'] as List<Map<String, dynamic>>;
          final hasNextPage = result['hasNextPage'] as bool;
          final nextCursor = result['nextCursor'] as String?;

          expect(items.length, lessThanOrEqualTo(pageSize));
          totalItemsRetrieved += items.length;

          if (hasNextPage) {
            expect(nextCursor, isNotNull);
            cursor = nextCursor;
          } else {
            expect(nextCursor, isNull);
            break;
          }

          pageCount++;
        }

        expect(totalItemsRetrieved, greaterThan(0));
        expect(pageCount, greaterThan(0));
      });

      test('should perform enhanced search with ranking', () async {
        // Insert test data with searchable content
        final foodItems = <Map<String, dynamic>>[];
        final searchTerms = ['Pizza', 'Burger', 'Pasta', 'Salad', 'Soup'];
        
        for (int i = 0; i < 25; i++) {
          final term = searchTerms[i % searchTerms.length];
          foodItems.add({
            'id': 'search_item_$i',
            'name': '$term Special $i',
            'price': 10.0 + i,
            'description': 'Delicious $term with special ingredients',
            'food_code': 'SEARCH$i',
            'department': 'Restaurant',
            'stocks': 100 + i,
            'is_hot': i % 2 == 0,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Test search with ranking
        final searchResults = await sqliteDAO.searchFoodItems(
          testAdminUid,
          'Pizza',
          enableRanking: true,
          limit: 10,
        );

        expect(searchResults.isNotEmpty, isTrue);
        
        // All results should contain 'Pizza' in name or description
        for (final item in searchResults) {
          final name = (item['name'] as String).toLowerCase();
          final description = (item['description'] as String).toLowerCase();
          expect(
            name.contains('pizza') || description.contains('pizza'),
            isTrue,
          );
        }

        // Test auto-complete search
        final autoCompleteResults = await sqliteDAO.searchFoodItemsAutoComplete(
          testAdminUid,
          'Piz',
          limit: 5,
        );

        expect(autoCompleteResults.isNotEmpty, isTrue);
        for (final item in autoCompleteResults) {
          final name = (item['name'] as String).toLowerCase();
          expect(name.startsWith('piz'), isTrue);
        }
      });
    });

    group('Performance Optimization', () {
      test('should provide query optimization statistics', () async {
        // Insert some test data
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 10; i++) {
          foodItems.add({
            'id': 'stats_item_$i',
            'name': 'Stats Food Item $i',
            'price': 10.0 + i,
            'description': 'Test stats item $i',
            'food_code': 'STATS$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Perform some queries to populate cache
        await sqliteDAO.getFoodItems(testAdminUid);
        await sqliteDAO.getFoodItems(testAdminUid, department: 'Test Department');
        await sqliteDAO.searchFoodItems(testAdminUid, 'Stats');

        // Get optimization statistics
        final stats = sqliteDAO.getQueryOptimizationStatistics();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['cacheStatistics'], isA<Map<String, dynamic>>());
        expect(stats['preparedStatements'], isA<int>());
        expect(stats['preparedStatements'], greaterThan(0));

        final cacheStats = stats['cacheStatistics'] as Map<String, dynamic>;
        expect(cacheStats['totalEntries'], isA<int>());
        expect(cacheStats['maxCacheSize'], equals(100));
      });

      test('should provide database metrics', () async {
        // Insert some test data
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          foodItems.add({
            'id': 'metrics_item_$i',
            'name': 'Metrics Food Item $i',
            'price': 10.0 + i,
            'description': 'Test metrics item $i',
            'food_code': 'METRICS$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Get database metrics
        final metrics = await sqliteDAO.getDatabaseMetrics();

        expect(metrics, isA<Map<String, dynamic>>());
        expect(metrics['tableCounts'], isA<Map<String, dynamic>>());
        
        final tableCounts = metrics['tableCounts'] as Map<String, dynamic>;
        expect(tableCounts['food_items'], isA<int>());
        expect(tableCounts['food_items'], greaterThanOrEqualTo(5));
      });

      test('should suggest query optimizations', () async {
        // Get optimization suggestions
        final suggestions = await sqliteDAO.suggestQueryOptimizations();

        expect(suggestions, isA<List<String>>());
        // Suggestions should be provided even with minimal data
        expect(suggestions.isNotEmpty, isTrue);
      });

      test('should warm up cache efficiently', () async {
        // Insert some test data
        final foodItems = <Map<String, dynamic>>[];
        for (int i = 0; i < 5; i++) {
          foodItems.add({
            'id': 'warmup_item_$i',
            'name': 'Warmup Food Item $i',
            'price': 10.0 + i,
            'description': 'Test warmup item $i',
            'food_code': 'WARMUP$i',
            'department': 'Test Department',
            'stocks': 100 + i,
            'is_hot': false,
          });
        }
        await sqliteDAO.batchInsertFoodItems(testAdminUid, foodItems);

        // Warm up cache
        final stopwatch = Stopwatch()..start();
        await sqliteDAO.warmUpCache(testAdminUid);
        stopwatch.stop();

        // Cache warmup should be fast
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));

        // Verify cache has entries
        final stats = sqliteDAO.getQueryOptimizationStatistics();
        final cacheStats = stats['cacheStatistics'] as Map<String, dynamic>;
        expect(cacheStats['totalEntries'], greaterThan(0));
      });
    });
  });
}
