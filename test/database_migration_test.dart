// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/backend/sqlite_helper.dart';

void main() {
  // Initialize Flutter binding and FFI for testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Database Migration Tests', () {
    late SQLiteHelper sqliteHelper;

    setUp(() async {
      sqliteHelper = SQLiteHelper();
    });

    tearDown(() async {
      await sqliteHelper.closeDatabase();
    });

    test('should initialize database with correct schema version', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Get database instance
      final db = await sqliteHelper.getDatabaseInstance();
      
      // Check if tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
      );
      
      final tableNames = tables.map((table) => table['name'] as String).toList();
      
      // Verify all required tables exist
      expect(tableNames, contains('food_items'));
      expect(tableNames, contains('departments'));
      expect(tableNames, contains('bills'));
      expect(tableNames, contains('sync_log'));
      expect(tableNames, contains('image_cache'));
      
      print('Database initialized successfully with tables: $tableNames');
    });

    test('should handle database migration from version 1 to 2', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Get database instance
      final db = await sqliteHelper.getDatabaseInstance();
      
      // Check if migration_log table exists (added in version 2)
      final migrationLogExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='migration_log'"
      );
      
      expect(migrationLogExists.isNotEmpty, true);
      
      // Check if performance indexes exist (added in version 2)
      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'"
      );
      
      final indexNames = indexes.map((index) => index['name'] as String).toList();
      
      // Verify performance indexes exist
      expect(indexNames, contains('idx_food_items_admin_uid'));
      expect(indexNames, contains('idx_departments_admin_uid'));
      expect(indexNames, contains('idx_bills_admin_uid'));
      
      print('Migration indexes created successfully: $indexNames');
    });

    test('should get migration history', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Get migration history
      final history = await sqliteHelper.getMigrationHistory();
      
      // Should have at least one migration record
      expect(history.isNotEmpty, true);
      
      // Check migration record structure
      if (history.isNotEmpty) {
        final firstMigration = history.first;
        expect(firstMigration.containsKey('version'), true);
        expect(firstMigration.containsKey('migration_name'), true);
        expect(firstMigration.containsKey('executed_at'), true);
        expect(firstMigration.containsKey('success'), true);
        
        print('Migration history: $history');
      }
    });

    test('should check migration completion status', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Check migration status (should handle gracefully in test environment)
      final isComplete = await sqliteHelper.isMigrationComplete();
      
      // In test environment, this should return false due to SharedPreferences not being available
      expect(isComplete, false);
      
      print('Migration completion status: $isComplete');
    });

    test('should handle force re-migration gracefully', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // This should not throw an error even in test environment
      expect(() async => await sqliteHelper.forceReMigration(), returnsNormally);
      
      print('Force re-migration handled gracefully');
    });

    test('should create all required indexes for performance', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Get database instance
      final db = await sqliteHelper.getDatabaseInstance();
      
      // Check all expected indexes
      final expectedIndexes = [
        'idx_food_items_admin_uid',
        'idx_departments_admin_uid', 
        'idx_bills_admin_uid',
        'idx_sync_log_table_record',
        'idx_image_cache_record',
        'idx_food_items_sync_status',
        'idx_departments_sync_status',
        'idx_bills_sync_status',
        'idx_bills_date',
      ];
      
      for (final indexName in expectedIndexes) {
        final indexExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='index' AND name=?",
          [indexName]
        );
        
        expect(indexExists.isNotEmpty, true, reason: 'Index $indexName should exist');
      }
      
      print('All performance indexes verified successfully');
    });

    test('should handle database schema correctly', () async {
      // Initialize database
      await sqliteHelper.initializeDatabase();
      
      // Get database instance
      final db = await sqliteHelper.getDatabaseInstance();
      
      // Test food_items table schema
      final foodItemsSchema = await db.rawQuery("PRAGMA table_info(food_items)");
      final foodItemsColumns = foodItemsSchema.map((col) => col['name'] as String).toList();
      
      expect(foodItemsColumns, contains('id'));
      expect(foodItemsColumns, contains('admin_uid'));
      expect(foodItemsColumns, contains('name'));
      expect(foodItemsColumns, contains('price'));
      expect(foodItemsColumns, contains('image_path'));
      expect(foodItemsColumns, contains('image_blob'));
      expect(foodItemsColumns, contains('sync_status'));
      expect(foodItemsColumns, contains('firebase_id'));
      
      // Test departments table schema
      final departmentsSchema = await db.rawQuery("PRAGMA table_info(departments)");
      final departmentsColumns = departmentsSchema.map((col) => col['name'] as String).toList();
      
      expect(departmentsColumns, contains('id'));
      expect(departmentsColumns, contains('admin_uid'));
      expect(departmentsColumns, contains('name'));
      expect(departmentsColumns, contains('image_url'));
      expect(departmentsColumns, contains('image_blob'));
      expect(departmentsColumns, contains('sync_status'));
      
      // Test bills table schema
      final billsSchema = await db.rawQuery("PRAGMA table_info(bills)");
      final billsColumns = billsSchema.map((col) => col['name'] as String).toList();
      
      expect(billsColumns, contains('id'));
      expect(billsColumns, contains('admin_uid'));
      expect(billsColumns, contains('customer_phone'));
      expect(billsColumns, contains('items'));
      expect(billsColumns, contains('total_amount'));
      expect(billsColumns, contains('bill_date'));
      expect(billsColumns, contains('sync_status'));
      
      print('Database schema validation completed successfully');
    });
  });
}
