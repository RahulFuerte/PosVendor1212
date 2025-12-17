import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/fts5_fallback_service.dart';

void main() {
  group('FTS5 Fallback Service Tests', () {
    late Database database;
    late FTS5FallbackService fts5Service;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create in-memory database for testing
      database = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create test tables
          await db.execute('''
            CREATE TABLE food_items (
              id TEXT PRIMARY KEY,
              admin_uid TEXT NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              food_code TEXT,
              department TEXT,
              price REAL,
              created_at INTEGER
            )
          ''');

          await db.execute('''
            CREATE TABLE departments (
              id TEXT PRIMARY KEY,
              admin_uid TEXT NOT NULL,
              name TEXT NOT NULL,
              status TEXT,
              created_at INTEGER
            )
          ''');

          // Insert test data
          await db.execute('''
            INSERT INTO food_items (id, admin_uid, name, description, food_code, department, price, created_at)
            VALUES 
              ('1', 'admin1', 'Margherita Pizza', 'Classic pizza with tomato and mozzarella', 'PIZZA001', 'Pizza', 12.99, 1234567890),
              ('2', 'admin1', 'Chicken Burger', 'Grilled chicken burger with lettuce', 'BURGER001', 'Burgers', 8.99, 1234567891),
              ('3', 'admin1', 'Spicy Chicken Wings', 'Hot and spicy chicken wings', 'WINGS001', 'Appetizers', 6.99, 1234567892),
              ('4', 'admin1', 'Caesar Salad', 'Fresh caesar salad with croutons', 'SALAD001', 'Salads', 7.99, 1234567893),
              ('5', 'admin1', 'Pepperoni Pizza', 'Pizza with pepperoni and cheese', 'PIZZA002', 'Pizza', 14.99, 1234567894)
          ''');

          await db.execute('''
            INSERT INTO departments (id, admin_uid, name, status, created_at)
            VALUES 
              ('1', 'admin1', 'Pizza', 'Active', 1234567890),
              ('2', 'admin1', 'Burgers', 'Active', 1234567891),
              ('3', 'admin1', 'Appetizers', 'Active', 1234567892),
              ('4', 'admin1', 'Salads', 'Active', 1234567893)
          ''');
        },
      );

      fts5Service = FTS5FallbackService();
    });

    tearDown(() async {
      await database.close();
    });

    test('should detect FTS5 availability correctly', () async {
      final isAvailable = await fts5Service.isFTS5Available(database);
      
      // FTS5 availability depends on SQLite compilation
      // This test just ensures the method doesn't crash
      expect(isAvailable, isA<bool>());
    });

    test('should setup search infrastructure without errors', () async {
      // This should not throw an exception regardless of FTS5 availability
      await expectLater(
        fts5Service.setupSearchInfrastructure(database),
        completes,
      );
    });

    test('should search food items with fallback method', () async {
      // Setup search infrastructure
      await fts5Service.setupSearchInfrastructure(database);

      // Test basic search
      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'pizza',
        limit: 10,
      );

      expect(results, isA<List<Map<String, dynamic>>>());
      expect(results.length, greaterThan(0));
      
      // Should find pizza items
      final pizzaItems = results.where((item) => 
        item['name'].toString().toLowerCase().contains('pizza')
      ).toList();
      expect(pizzaItems.length, greaterThan(0));
    });

    test('should search with department filter', () async {
      await fts5Service.setupSearchInfrastructure(database);

      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'pizza',
        department: 'Pizza',
        limit: 10,
      );

      expect(results, isA<List<Map<String, dynamic>>>());
      
      // All results should be from Pizza department
      for (final item in results) {
        expect(item['department'], equals('Pizza'));
      }
    });

    test('should handle multi-word search terms', () async {
      await fts5Service.setupSearchInfrastructure(database);

      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'chicken burger',
        limit: 10,
      );

      expect(results, isA<List<Map<String, dynamic>>>());
      
      // Should find chicken burger
      final hasChickenBurger = results.any((item) => 
        item['name'].toString().toLowerCase().contains('chicken') &&
        item['name'].toString().toLowerCase().contains('burger')
      );
      expect(hasChickenBurger, isTrue);
    });

    test('should handle empty search terms gracefully', () async {
      await fts5Service.setupSearchInfrastructure(database);

      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        '',
        limit: 10,
      );

      expect(results, isA<List<Map<String, dynamic>>>());
      expect(results.length, equals(0));
    });

    test('should handle non-existent admin uid', () async {
      await fts5Service.setupSearchInfrastructure(database);

      final results = await fts5Service.searchFoodItems(
        database,
        'non_existent_admin',
        'pizza',
        limit: 10,
      );

      expect(results, isA<List<Map<String, dynamic>>>());
      expect(results.length, equals(0));
    });

    test('should return search status information', () {
      final status = fts5Service.getSearchStatus();

      expect(status, isA<Map<String, dynamic>>());
      expect(status.containsKey('fts5Available'), isTrue);
      expect(status.containsKey('searchType'), isTrue);
      expect(status.containsKey('capabilities'), isTrue);
      
      final capabilities = status['capabilities'] as Map<String, dynamic>;
      expect(capabilities['basicSearch'], isTrue);
      expect(capabilities['caseInsensitiveSearch'], isTrue);
    });

    test('should update search indexes when data changes', () async {
      await fts5Service.setupSearchInfrastructure(database);

      // Add new item
      final newItem = {
        'id': '6',
        'admin_uid': 'admin1',
        'name': 'Hawaiian Pizza',
        'description': 'Pizza with ham and pineapple',
        'food_code': 'PIZZA003',
        'department': 'Pizza',
        'price': 15.99,
      };

      await database.insert('food_items', newItem);
      await fts5Service.updateSearchIndexes(database, 'food_items', newItem);

      // Search should find the new item
      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'hawaiian',
        limit: 10,
      );

      expect(results.length, greaterThan(0));
      final hasHawaiian = results.any((item) => 
        item['name'].toString().toLowerCase().contains('hawaiian')
      );
      expect(hasHawaiian, isTrue);
    });

    test('should remove items from search indexes', () async {
      await fts5Service.setupSearchInfrastructure(database);

      // Remove an item
      await database.delete('food_items', where: 'id = ?', whereArgs: ['1']);
      await fts5Service.removeFromSearchIndexes(database, 'food_items', '1');

      // Search should not find the removed item
      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'margherita',
        limit: 10,
      );

      final hasMargherita = results.any((item) => 
        item['name'].toString().toLowerCase().contains('margherita')
      );
      expect(hasMargherita, isFalse);
    });

    test('should rebuild search indexes', () async {
      await fts5Service.setupSearchInfrastructure(database);

      // This should complete without errors
      await expectLater(
        fts5Service.rebuildSearchIndexes(database),
        completes,
      );

      // Search should still work after rebuild
      final results = await fts5Service.searchFoodItems(
        database,
        'admin1',
        'pizza',
        limit: 10,
      );

      expect(results.length, greaterThan(0));
    });
  });
}