// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/data/datasources/database_maintenance_service.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:

import 'test_database_helper.dart';

void main() {
  late SQLiteHelper sqliteHelper;
  late DatabaseMaintenanceService maintenanceService;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Use test database helper for isolated testing
    await TestDatabaseHelper.getTestDatabase();
    sqliteHelper = SQLiteHelper();
    maintenanceService = DatabaseMaintenanceService();
    
    // Initialize database
    await sqliteHelper.initializeDatabase();
  });

  tearDown(() async {
    await TestDatabaseHelper.closeTestDatabase();
  });

  group('Database Maintenance Service Tests', () {
    test('should perform vacuum operation successfully', () async {
      // Add some test data first
      await _addTestData();
      
      // Perform vacuum
      final result = await maintenanceService.performVacuum();
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.sizeBefore, greaterThanOrEqualTo(0));
      expect(result.sizeAfter, greaterThanOrEqualTo(0));
      expect(result.duration, isNotNull);
    });

    test('should perform integrity check successfully', () async {
      // Add some test data
      await _addTestData();
      
      // Perform integrity check
      final result = await maintenanceService.performIntegrityCheck();
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.isHealthy, isTrue);
      expect(result.sqliteIntegrityOk, isTrue);
      expect(result.foreignKeyConstraintsOk, isTrue);
      expect(result.duration, isNotNull);
    });

    test('should get database size information', () async {
      // Add some test data
      await _addTestData();
      
      // Get size information
      final sizeInfo = await maintenanceService.getDatabaseSizeInfo();
      
      expect(sizeInfo.success, isTrue);
      expect(sizeInfo.error, isNull);
      expect(sizeInfo.totalSizeMB, greaterThan(0));
      expect(sizeInfo.pageCount, greaterThan(0));
      expect(sizeInfo.pageSize, greaterThan(0));
      expect(sizeInfo.tableSizes, isNotEmpty);
    });

    test('should perform data cleanup successfully', () async {
      // Add test data including old sync logs
      await _addTestDataWithOldLogs();
      
      // Perform cleanup
      final result = await maintenanceService.performDataCleanup();
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.itemsRemoved, greaterThanOrEqualTo(0));
      expect(result.duration, isNotNull);
    });

    test('should optimize indexes successfully', () async {
      // Add some test data
      await _addTestData();
      
      // Optimize indexes
      final result = await maintenanceService.optimizeIndexes();
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.statisticsUpdated, isTrue);
      expect(result.indexesAnalyzed, greaterThanOrEqualTo(0));
      expect(result.duration, isNotNull);
    });

    test('should perform comprehensive maintenance successfully', () async {
      // Add test data
      await _addTestData();
      
      // Perform full maintenance
      final result = await maintenanceService.performMaintenance(
        forceVacuum: true,
        forceIntegrityCheck: true,
        cleanupOldData: true,
        optimizeIndexes: true,
      );
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.sizeInfo, isNotNull);
      expect(result.vacuumResult, isNotNull);
      expect(result.integrityCheckResult, isNotNull);
      expect(result.cleanupResult, isNotNull);
      expect(result.indexOptimizationResult, isNotNull);
      expect(result.duration, isNotNull);
    });

    test('should handle database size monitoring correctly', () async {
      // Get initial size
      final initialSize = await maintenanceService.getDatabaseSizeInfo();
      expect(initialSize.success, isTrue);
      
      // Add significant amount of test data
      await _addLargeTestDataset();
      
      // Get size after adding data
      final sizeAfterData = await maintenanceService.getDatabaseSizeInfo();
      expect(sizeAfterData.success, isTrue);
      expect(sizeAfterData.totalSizeMB, greaterThan(initialSize.totalSizeMB));
    });

    test('should detect and handle integrity issues', () async {
      // Add test data
      await _addTestData();
      
      // Perform initial integrity check (should pass)
      final initialCheck = await maintenanceService.performIntegrityCheck();
      expect(initialCheck.isHealthy, isTrue);
      
      // The integrity check should still pass with valid data
      expect(initialCheck.sqliteIntegrityOk, isTrue);
      expect(initialCheck.foreignKeyConstraintsOk, isTrue);
    });

    test('should manage maintenance history correctly', () async {
      // Perform some maintenance operations
      await maintenanceService.performVacuum();
      await maintenanceService.performIntegrityCheck();
      
      // Get maintenance history
      final history = await maintenanceService.getMaintenanceHistory(limit: 10);
      
      expect(history, isNotEmpty);
      expect(history.length, lessThanOrEqualTo(10));
      
      // Check that history entries have required fields
      for (final entry in history) {
        expect(entry['operation'], isNotNull);
        expect(entry['executed_at'], isNotNull);
        expect(entry['success'], isNotNull);
      }
    });
  });

  group('SQLiteHelper Maintenance Integration Tests', () {
    test('should integrate maintenance operations through SQLiteHelper', () async {
      // Add test data
      await _addTestData();
      
      // Test vacuum through SQLiteHelper
      final vacuumResult = await sqliteHelper.performDatabaseVacuum();
      expect(vacuumResult.success, isTrue);
      
      // Test integrity check through SQLiteHelper
      final integrityResult = await sqliteHelper.performDatabaseIntegrityCheck();
      expect(integrityResult.success, isTrue);
      
      // Test size information through SQLiteHelper
      final sizeInfo = await sqliteHelper.getDatabaseSizeInformation();
      expect(sizeInfo.success, isTrue);
      
      // Test cleanup through SQLiteHelper
      final cleanupResult = await sqliteHelper.performDatabaseCleanup();
      expect(cleanupResult.success, isTrue);
      
      // Test index optimization through SQLiteHelper
      final indexResult = await sqliteHelper.optimizeDatabaseIndexes();
      expect(indexResult.success, isTrue);
    });

    test('should perform comprehensive maintenance through SQLiteHelper', () async {
      // Add test data
      await _addTestData();
      
      // Perform comprehensive maintenance
      final result = await sqliteHelper.performDatabaseMaintenance(
        forceVacuum: true,
        forceIntegrityCheck: true,
        cleanupOldData: true,
        optimizeIndexes: true,
      );
      
      expect(result.success, isTrue);
      expect(result.error, isNull);
      expect(result.sizeInfo, isNotNull);
      expect(result.vacuumResult, isNotNull);
      expect(result.integrityCheckResult, isNotNull);
      expect(result.cleanupResult, isNotNull);
      expect(result.indexOptimizationResult, isNotNull);
    });

    test('should get maintenance history through SQLiteHelper', () async {
      // Perform some operations to create history
      await sqliteHelper.performDatabaseVacuum();
      await sqliteHelper.performDatabaseIntegrityCheck();
      
      // Get history
      final history = await sqliteHelper.getMaintenanceHistory(limit: 5);
      
      expect(history, isNotEmpty);
      expect(history.length, lessThanOrEqualTo(5));
    });
  });
}

/// Helper function to add test data
Future<void> _addTestData() async {
  final db = await SQLiteHelper().database;
  final now = DateTime.now().millisecondsSinceEpoch;
  
  // Add test food items
  for (int i = 0; i < 10; i++) {
    await db.insert('food_items', {
      'id': 'test_food_$i',
      'admin_uid': 'test_admin',
      'name': 'Test Food Item $i',
      'price': 10.0 + i,
      'department': 'Test Department',
      'stocks': 100,
      'is_hot': i % 2,
      'tax': 'GST',
      'created_at': now,
      'updated_at': now,
      'sync_status': 0,
    });
  }
  
  // Add test departments
  for (int i = 0; i < 3; i++) {
    await db.insert('departments', {
      'id': 'test_dept_$i',
      'admin_uid': 'test_admin',
      'name': 'Test Department $i',
      'status': 'Active',
      'created_at': now,
      'updated_at': now,
      'sync_status': 0,
    });
  }
  
  // Add test bills
  for (int i = 0; i < 5; i++) {
    await db.insert('bills', {
      'id': 'test_bill_$i',
      'admin_uid': 'test_admin',
      'customer_phone': '1234567890',
      'items': '[]',
      'total_amount': 50.0 + i,
      'bill_date': now,
      'created_at': now,
      'updated_at': now,
      'sync_status': 0,
    });
  }
}

/// Helper function to add test data with old logs
Future<void> _addTestDataWithOldLogs() async {
  await _addTestData();
  
  final db = await SQLiteHelper().database;
  final oldTime = DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch;
  
  // Add old sync log entries
  for (int i = 0; i < 20; i++) {
    await db.insert('sync_log', {
      'table_name': 'food_items',
      'record_id': 'old_record_$i',
      'operation': 'INSERT',
      'sync_status': 0,
      'created_at': oldTime,
    });
  }
  
  // Add old image cache entries
  for (int i = 0; i < 10; i++) {
    await db.insert('image_cache', {
      'id': 'old_image_$i',
      'table_name': 'food_items',
      'record_id': 'old_record_$i',
      'image_url': 'https://example.com/image_$i.jpg',
      'file_size': 1024,
      'cached_at': oldTime,
      'last_accessed': oldTime,
    });
  }
}

/// Helper function to add large test dataset
Future<void> _addLargeTestDataset() async {
  final db = await SQLiteHelper().database;
  final now = DateTime.now().millisecondsSinceEpoch;
  
  // Add many food items to increase database size
  for (int i = 0; i < 100; i++) {
    await db.insert('food_items', {
      'id': 'large_test_food_$i',
      'admin_uid': 'test_admin',
      'name': 'Large Test Food Item $i with long description to increase size',
      'price': 10.0 + i,
      'description': 'This is a very long description for test food item $i that is designed to increase the database size for testing purposes. ' * 5,
      'department': 'Large Test Department',
      'stocks': 100,
      'is_hot': i % 2,
      'tax': 'GST',
      'created_at': now,
      'updated_at': now,
      'sync_status': 0,
    });
  }
}
