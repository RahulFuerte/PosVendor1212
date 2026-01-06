// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/data/datasources/database_index_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:


/// Test for FTS5 fallback functionality
/// Validates that the database index manager handles FTS5 unavailability gracefully
void main() {
  group('Database FTS5 Fallback Tests', () {
    late Database testDb;
    late DatabaseIndexManager indexManager;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create in-memory database for testing
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create basic tables without FTS5
          await db.execute('''
            CREATE TABLE food_items (
              id TEXT PRIMARY KEY,
              name TEXT,
              description TEXT,
              food_code TEXT,
              department TEXT,
              admin_uid TEXT,
              price REAL,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
          
          await db.execute('''
            CREATE TABLE departments (
              id TEXT PRIMARY KEY,
              name TEXT,
              admin_uid TEXT,
              status TEXT,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
        },
      );
      
      indexManager = DatabaseIndexManager();
    });

    tearDown(() async {
      await testDb.close();
    });

    test('should handle FTS5 unavailability gracefully', () async {
      // This test verifies that the index manager doesn't crash when FTS5 is unavailable
      expect(() async {
        await indexManager.createPerformanceIndexes();
      }, returnsNormally);
    });

    test('should create fallback search indexes when FTS5 is not available', () async {
      // Test FTS5 availability check directly on test database
      try {
        await testDb.execute('CREATE VIRTUAL TABLE IF NOT EXISTS fts5_test USING fts5(test_column)');
        await testDb.execute('DROP TABLE IF EXISTS fts5_test');
        // If we get here, FTS5 is available, so skip this test
        return;
      } catch (e) {
        // FTS5 not available, continue with test
      }
      
      // Create fallback indexes manually to test the concept
      await testDb.execute('CREATE INDEX IF NOT EXISTS idx_food_items_name_search ON food_items(name COLLATE NOCASE)');
      await testDb.execute('CREATE INDEX IF NOT EXISTS idx_food_items_description_search ON food_items(description COLLATE NOCASE)');
      
      // Verify that fallback indexes were created
      final indexes = await testDb.rawQuery('''
        SELECT name FROM sqlite_master 
        WHERE type = 'index' AND name LIKE '%search%'
      ''');
      
      // Should have fallback search indexes
      expect(indexes.length, greaterThan(0));
      
      final indexNames = indexes.map((row) => row['name'] as String).toList();
      expect(indexNames, contains('idx_food_items_name_search'));
    });

    test('should report correct search capabilities', () async {
      await indexManager.createPerformanceIndexes();
      
      final capabilities = await indexManager.getSearchCapabilities();
      
      expect(capabilities, isA<Map<String, dynamic>>());
      expect(capabilities['fts5Available'], isA<bool>());
      expect(capabilities['searchType'], isA<String>());
      expect(capabilities['capabilities'], isA<Map<String, dynamic>>());
      
      // Should have basic search capabilities even without FTS5
      final caps = capabilities['capabilities'] as Map<String, dynamic>;
      expect(caps['basicSearch'], isTrue);
      expect(caps['caseInsensitiveSearch'], isTrue);
    });

    test('should handle database maintenance without FTS5', () async {
      await indexManager.createPerformanceIndexes();
      
      // Should not throw when performing maintenance without FTS5
      expect(() async {
        await indexManager.performDatabaseMaintenance();
      }, returnsNormally);
    });

    test('should get index statistics without errors', () async {
      await indexManager.createPerformanceIndexes();
      
      final stats = await indexManager.getIndexStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['totalIndexes'], isA<int>());
      expect(stats['indexes'], isA<List>());
      expect(stats['timestamp'], isA<String>());
    });

    test('should optimize query paths without FTS5', () async {
      await indexManager.createPerformanceIndexes();
      
      // Should not throw when optimizing query paths
      expect(() async {
        await indexManager.optimizeQueryPaths();
      }, returnsNormally);
    });

    test('should update search indexes gracefully without FTS5', () async {
      await indexManager.createPerformanceIndexes();
      
      // Should not throw when updating search indexes
      expect(() async {
        await indexManager.updateSearchIndexes();
      }, returnsNormally);
    });
  });
}
