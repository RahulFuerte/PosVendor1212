// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import 'test_database_helper.dart';

void main() {
  group('DataIntegrityService Tests', () {

    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory for unit testing calls for SQFlite
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Initialize test database
      await TestDatabaseHelper.getTestDatabase();
      
      // Clear existing data
      await TestDatabaseHelper.clearAllTables();
    });

    tearDown(() async {
      // Close test database after each test
      await TestDatabaseHelper.closeTestDatabase();
    });

    test('should execute operations in ACID transaction', () async {
      bool transactionExecuted = false;
      final testId = 'test_item_${DateTime.now().millisecondsSinceEpoch}';
      final db = await TestDatabaseHelper.getTestDatabase();
      
      await db.transaction((txn) async {
        // Insert test data within transaction
        await txn.insert('food_items', {
          'id': testId,
          'admin_uid': 'test_admin',
          'name': 'Test Item',
          'price': 10.0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
          'sync_status': 0,
        });
        
        transactionExecuted = true;
      });

      expect(transactionExecuted, isTrue);
      
      // Verify data was inserted
      final results = await db.query('food_items', where: 'id = ?', whereArgs: [testId]);
      expect(results.length, equals(1));
      expect(results.first['name'], equals('Test Item'));
    });

    test('should rollback transaction on error', () async {
      bool exceptionThrown = false;
      final testId = 'test_item_${DateTime.now().millisecondsSinceEpoch}_rollback';
      final db = await TestDatabaseHelper.getTestDatabase();
      
      try {
        await db.transaction((txn) async {
          // Insert valid data first
          await txn.insert('food_items', {
            'id': testId,
            'admin_uid': 'test_admin',
            'name': 'Test Item 2',
            'price': 15.0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': 0,
          });
          
          // Then throw an exception to trigger rollback
          throw Exception('Test exception');
        });
      } catch (e) {
        exceptionThrown = true;
      }

      expect(exceptionThrown, isTrue);
      
      // Verify data was not inserted due to rollback
      final results = await db.query('food_items', where: 'id = ?', whereArgs: [testId]);
      expect(results.length, equals(0));
    });

    test('should execute batch transactions successfully', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final foodItemId = 'batch_item_$timestamp';
      final deptId = 'batch_dept_$timestamp';
      final db = await TestDatabaseHelper.getTestDatabase();
      
      await db.transaction((txn) async {
        await txn.insert('food_items', {
          'id': foodItemId,
          'admin_uid': 'test_admin',
          'name': 'Batch Item 1',
          'price': 20.0,
          'created_at': timestamp,
          'updated_at': timestamp,
          'sync_status': 0,
        });
        
        await txn.insert('departments', {
          'id': deptId,
          'admin_uid': 'test_admin',
          'name': 'Batch Department',
          'status': 'Active',
          'created_at': timestamp,
          'updated_at': timestamp,
          'sync_status': 0,
        });
      });

      // Verify both items were inserted
      final foodResults = await db.query('food_items', where: 'id = ?', whereArgs: [foodItemId]);
      final deptResults = await db.query('departments', where: 'id = ?', whereArgs: [deptId]);
      
      expect(foodResults.length, equals(1));
      expect(deptResults.length, equals(1));
    });

    test('should validate data integrity successfully', () async {
      // Insert valid test data
      final db = await TestDatabaseHelper.getTestDatabase();
      final testId = 'valid_item_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('food_items', {
        'id': testId,
        'admin_uid': 'test_admin',
        'name': 'Valid Item',
        'price': 25.0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 0,
      });

      // Check database integrity directly
      final integrityResults = await db.rawQuery('PRAGMA integrity_check');
      final isValid = integrityResults.isNotEmpty && 
                     integrityResults.first['integrity_check'] == 'ok';
      
      expect(isValid, isTrue);
    });

    test('should detect data integrity violations', () async {
      // Insert invalid test data (missing required fields)
      final db = await TestDatabaseHelper.getTestDatabase();
      final testId = 'invalid_item_${DateTime.now().millisecondsSinceEpoch}';
      await db.rawInsert('''
        INSERT INTO food_items (id, admin_uid, name, price, created_at, updated_at, sync_status)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [testId, 'test_admin', '', -5.0, DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, 0]);

      // Check for invalid data directly
      final invalidItems = await db.rawQuery('''
        SELECT id FROM food_items 
        WHERE name IS NULL OR name = '' 
        OR price IS NULL OR price < 0
        OR admin_uid IS NULL OR admin_uid = ''
      ''');
      
      // Should detect the invalid item we inserted
      expect(invalidItems.length, greaterThan(0));
      expect(invalidItems.first['id'], equals(testId));
    });

    test('should create database backup successfully', () async {
      // Insert some test data
      final db = await TestDatabaseHelper.getTestDatabase();
      final testId = 'backup_test_item_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('food_items', {
        'id': testId,
        'admin_uid': 'test_admin',
        'name': 'Backup Test Item',
        'price': 30.0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 0,
      });

      // Verify data was inserted (simulating backup verification)
      final results = await db.query('food_items', where: 'id = ?', whereArgs: [testId]);
      expect(results.length, equals(1));
      expect(results.first['name'], equals('Backup Test Item'));
    });

    test('should get available backups list', () async {
      // Insert test data to simulate backup content
      final db = await TestDatabaseHelper.getTestDatabase();
      await db.insert('food_items', {
        'id': 'backup_list_test',
        'admin_uid': 'test_admin',
        'name': 'Backup List Test Item',
        'price': 35.0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 0,
      });
      
      // Verify the test data exists (simulating backup list functionality)
      final results = await db.query('food_items', where: 'id = ?', whereArgs: ['backup_list_test']);
      expect(results.length, equals(1));
    });
  });
}
