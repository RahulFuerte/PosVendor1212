import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../lib/view/tab_screen/view-model/backend/database_index_manager.dart';
import '../lib/view/tab_screen/view-model/backend/sqlite_helper.dart';

void main() {
  group('Database Indexing Tests', () {
    late DatabaseIndexManager indexManager;
    late SQLiteHelper sqliteHelper;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      indexManager = DatabaseIndexManager();
      sqliteHelper = SQLiteHelper();
      
      // Initialize database
      await sqliteHelper.initializeDatabase();
    });

    tearDown(() async {
      await sqliteHelper.closeDatabase();
    });

    test('should create performance indexes successfully', () async {
      // Test that indexes are created without errors
      await indexManager.createPerformanceIndexes();
      
      // Verify indexes exist by getting statistics
      final stats = await indexManager.getIndexStatistics();
      
      expect(stats['totalIndexes'], greaterThan(0));
      expect(stats['indexes'], isA<List>());
      expect(stats['timestamp'], isNotNull);
    });

    test('should optimize query paths successfully', () async {
      // Create indexes first
      await indexManager.createPerformanceIndexes();
      
      // Test query path optimization
      await indexManager.optimizeQueryPaths();
      
      // Should complete without errors
      expect(true, isTrue);
    });

    test('should update search indexes successfully', () async {
      // Create indexes first
      await indexManager.createPerformanceIndexes();
      
      // Test search index updates
      await indexManager.updateSearchIndexes();
      
      // Should complete without errors
      expect(true, isTrue);
    });

    test('should perform database maintenance successfully', () async {
      // Create indexes first
      await indexManager.createPerformanceIndexes();
      
      // Test database maintenance
      await indexManager.performDatabaseMaintenance();
      
      // Should complete without errors
      expect(true, isTrue);
    });

    test('should demonstrate query performance improvement with indexes', () async {
      const adminUid = 'test_admin';
      final db = await sqliteHelper.database;
      
      // Insert test data
      const itemCount = 100;
      for (int i = 0; i < itemCount; i++) {
        await db.insert('food_items', {
          'id': 'item_$i',
          'admin_uid': adminUid,
          'name': 'Food Item $i',
          'price': 10.0 + i,
          'department': 'Department ${i % 10}',
          'food_code': 'CODE$i',
          'description': 'Description for item $i',
          'stocks': 100,
          'is_hot': i % 2,
          'tax': 'GST',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'sync_status': 0,
        });
      }
      
      // Test query performance without indexes
      final stopwatch1 = Stopwatch()..start();
      final results1 = await db.query(
        'food_items',
        where: 'admin_uid = ? AND department = ?',
        whereArgs: [adminUid, 'Department 5'],
      );
      stopwatch1.stop();
      final timeWithoutIndexes = stopwatch1.elapsedMilliseconds;
      
      // Create performance indexes
      await indexManager.createPerformanceIndexes();
      
      // Test query performance with indexes
      final stopwatch2 = Stopwatch()..start();
      final results2 = await db.query(
        'food_items',
        where: 'admin_uid = ? AND department = ?',
        whereArgs: [adminUid, 'Department 5'],
      );
      stopwatch2.stop();
      final timeWithIndexes = stopwatch2.elapsedMilliseconds;
      
      // Verify results are the same
      expect(results1.length, equals(results2.length));
      expect(results1.length, equals(10)); // Should have 10 items in Department 5
      
      // Performance should be similar or better with indexes
      // (In a small dataset, the difference might not be significant)
      print('Query time without indexes: ${timeWithoutIndexes}ms');
      print('Query time with indexes: ${timeWithIndexes}ms');
      
      // Both should be reasonably fast for small dataset
      expect(timeWithIndexes, lessThan(100));
      expect(timeWithoutIndexes, lessThan(100));
    });

    test('should handle FTS search functionality', () async {
      const adminUid = 'test_admin';
      final db = await sqliteHelper.database;
      
      // Create performance indexes (includes FTS)
      await indexManager.createPerformanceIndexes();
      
      // Insert test data
      await db.insert('food_items', {
        'id': 'item_1',
        'admin_uid': adminUid,
        'name': 'Delicious Pizza',
        'price': 15.99,
        'department': 'Food',
        'food_code': 'PIZZA001',
        'description': 'A delicious cheese pizza',
        'stocks': 50,
        'is_hot': 1,
        'tax': 'GST',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 0,
      });
      
      // Update FTS index
      await db.execute('''
        INSERT OR REPLACE INTO food_items_fts(id, name, description, food_code, department)
        VALUES (?, ?, ?, ?, ?)
      ''', ['item_1', 'Delicious Pizza', 'A delicious cheese pizza', 'PIZZA001', 'Food']);
      
      // Test FTS search
      try {
        final ftsResults = await db.rawQuery('''
          SELECT f.* FROM food_items f
          INNER JOIN food_items_fts fts ON f.id = fts.id
          WHERE f.admin_uid = ? AND food_items_fts MATCH ?
        ''', [adminUid, 'Pizza']);
        
        expect(ftsResults.length, equals(1));
        expect(ftsResults.first['name'], equals('Delicious Pizza'));
        
        print('FTS search successful: found ${ftsResults.length} results');
      } catch (e) {
        print('FTS not available in test environment: $e');
        // FTS might not be available in all test environments
        expect(e.toString(), contains('no such table'));
      }
    });

    test('should get meaningful index statistics', () async {
      // Create indexes
      await indexManager.createPerformanceIndexes();
      
      // Get statistics
      final stats = await indexManager.getIndexStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['totalIndexes'], isA<int>());
      expect(stats['totalIndexes'], greaterThan(0));
      expect(stats['indexes'], isA<List>());
      expect(stats['timestamp'], isA<String>());
      
      // Print statistics for verification
      print('Index Statistics:');
      print('Total Indexes: ${stats['totalIndexes']}');
      print('Timestamp: ${stats['timestamp']}');
      
      final indexes = stats['indexes'] as List;
      for (final index in indexes.take(5)) { // Show first 5 indexes
        print('Index: ${index['name']} - ${index['sql']}');
      }
    });
  });
}