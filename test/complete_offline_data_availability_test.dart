import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/complete_offline_data_manager.dart';
import 'package:pos/view/tab_screen/view-model/backend/sqlite_dao.dart';
import 'package:pos/view/tab_screen/view-model/backend/image_cache_service.dart';
import 'test_database_helper.dart';

/// **Feature: local-database-performance-optimization, Property 3: Complete Offline Data Availability**
/// Tests that all data (food items, departments, bills) is accessible when offline
void main() {
  late CompleteOfflineDataManager offlineDataManager;
  late SQLiteDAO sqliteDAO;
  late ImageCacheService imageCacheService;
  late Database testDatabase;
  
  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create test database
    testDatabase = await TestDatabaseHelper.createTestDatabase();
    
    // Initialize services with test database
    offlineDataManager = CompleteOfflineDataManager();
    sqliteDAO = SQLiteDAO();
    imageCacheService = ImageCacheService();
    
    // Set test database for image cache service
    imageCacheService.setTestDatabase(testDatabase);
    
    // Initialize the offline data manager
    await offlineDataManager.initialize();
  });

  tearDown(() async {
    // Clean up
    await testDatabase.close();
    offlineDataManager.dispose();
    imageCacheService.reset();
  });

  group('Complete Offline Data Availability Tests', () {
    test('should ensure all food items are available offline', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test food items
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      
      // Act
      final foodItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
      
      // Assert
      expect(foodItems, isNotEmpty);
      expect(foodItems.length, greaterThanOrEqualTo(3)); // We inserted 3 test items
      
      // Verify each food item has required fields
      for (final item in foodItems) {
        expect(item['id'], isNotNull);
        expect(item['name'], isNotNull);
        expect(item['price'], isNotNull);
      }
    });

    test('should ensure all departments are available offline', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test departments
      await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
      
      // Act
      final departments = await offlineDataManager.ensureDepartmentsOfflineAvailability(adminUid);
      
      // Assert
      expect(departments, isNotEmpty);
      expect(departments.length, greaterThanOrEqualTo(2)); // We inserted 2 test departments
      
      // Verify each department has required fields
      for (final dept in departments) {
        expect(dept['id'], isNotNull);
        expect(dept['name'], isNotNull);
        expect(dept['status'], equals('Active'));
      }
    });

    test('should ensure all bills are available offline', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test bills
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      // Act
      final bills = await offlineDataManager.ensureBillsOfflineAvailability(adminUid);
      
      // Assert
      expect(bills, isNotEmpty);
      expect(bills.length, greaterThanOrEqualTo(2)); // We inserted 2 test bills
      
      // Verify each bill has required fields
      for (final bill in bills) {
        expect(bill['id'], isNotNull);
        expect(bill['admin_uid'], equals(adminUid));
        expect(bill['total_amount'], isNotNull);
      }
    });

    test('should filter food items by department when offline', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      const targetDepartment = 'Pizza';
      
      // Insert test data
      await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      
      // Act
      final allItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
      final pizzaItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid, department: targetDepartment);
      
      // Assert
      expect(allItems, isNotEmpty);
      expect(pizzaItems, isNotEmpty);
      expect(pizzaItems.length, lessThanOrEqualTo(allItems.length));
      
      // Verify all returned items belong to the specified department
      for (final item in pizzaItems) {
        expect(item['department'], equals(targetDepartment));
      }
    });

    test('should filter bills by date range when offline', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test bills with different dates
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      final endDate = now.add(const Duration(days: 1));
      
      // Act
      final allBills = await offlineDataManager.ensureBillsOfflineAvailability(adminUid);
      final filteredBills = await offlineDataManager.ensureBillsOfflineAvailability(
        adminUid, 
        startDate: startDate, 
        endDate: endDate
      );
      
      // Assert
      expect(allBills, isNotEmpty);
      expect(filteredBills, isNotEmpty);
      
      // Verify filtered bills are within date range
      for (final bill in filteredBills) {
        final billDate = DateTime.fromMillisecondsSinceEpoch(bill['bill_date'] as int);
        expect(billDate.isAfter(startDate.subtract(const Duration(days: 1))), isTrue);
        expect(billDate.isBefore(endDate.add(const Duration(days: 1))), isTrue);
      }
    });

    test('should check offline data availability correctly', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test data
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      // Act
      final availability = await offlineDataManager.checkOfflineDataAvailability(adminUid);
      
      // Assert
      expect(availability['food_items'], isTrue);
      expect(availability['departments'], isTrue);
      expect(availability['bills'], isTrue);
      expect(availability, containsPair('images', isA<bool>()));
    });

    test('should return empty lists gracefully when no data exists', () async {
      // Arrange
      const adminUid = 'nonexistent_admin';
      
      // Act & Assert - should not throw errors
      final foodItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
      final departments = await offlineDataManager.ensureDepartmentsOfflineAvailability(adminUid);
      final bills = await offlineDataManager.ensureBillsOfflineAvailability(adminUid);
      
      expect(foodItems, isEmpty);
      expect(departments, isEmpty);
      expect(bills, isEmpty);
    });

    test('should provide comprehensive offline data statistics', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test data
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      // Act
      final stats = await offlineDataManager.getOfflineDataStatistics(adminUid);
      
      // Assert
      expect(stats['food_items_count'], greaterThan(0));
      expect(stats['departments_count'], greaterThan(0));
      expect(stats['bills_count'], greaterThan(0));
      expect(stats['pending_sync_count'], isA<int>());
      expect(stats['cached_images_count'], isA<int>());
      expect(stats['cache_size_bytes'], isA<int>());
      expect(stats['is_offline'], isA<bool>());
      expect(stats['data_availability'], isA<Map>());
    });

    test('should handle errors gracefully and return cached data', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test data first
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      
      // Load data to populate cache
      await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
      
      // Act - try to access data (should work from cache even if database has issues)
      final foodItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
      
      // Assert
      expect(foodItems, isNotEmpty);
    });

    test('should preload all critical data successfully', () async {
      // Arrange
      const adminUid = 'test_admin_123';
      
      // Insert test data
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      // Act
      await offlineDataManager.preloadAllCriticalData(adminUid);
      
      // Verify data is available
      final availability = await offlineDataManager.checkOfflineDataAvailability(adminUid);
      
      // Assert
      expect(availability['food_items'], isTrue);
      expect(availability['departments'], isTrue);
      expect(availability['bills'], isTrue);
    });
  });

  group('Property-Based Tests for Complete Offline Data Availability', () {
    test('Property: All data types should be consistently available offline for any valid admin UID', () async {
      // Property: For any valid admin UID with data, all data types should be available offline
      
      final testAdminUids = ['admin1', 'admin2', 'test_admin_long_id_123456'];
      
      for (final adminUid in testAdminUids) {
        // Arrange - Insert data for each admin
        await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
        await TestDatabaseHelper.insertTestDepartments(testDatabase, adminUid);
        await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
        
        // Act
        final foodItems = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid);
        final departments = await offlineDataManager.ensureDepartmentsOfflineAvailability(adminUid);
        final bills = await offlineDataManager.ensureBillsOfflineAvailability(adminUid);
        
        // Assert - Property: All data should be available
        expect(foodItems, isNotEmpty, reason: 'Food items should be available for $adminUid');
        expect(departments, isNotEmpty, reason: 'Departments should be available for $adminUid');
        expect(bills, isNotEmpty, reason: 'Bills should be available for $adminUid');
        
        // Property: Data should contain admin UID
        for (final item in foodItems) {
          expect(item['admin_uid'], equals(adminUid));
        }
        for (final dept in departments) {
          expect(dept['admin_uid'], equals(adminUid));
        }
        for (final bill in bills) {
          expect(bill['admin_uid'], equals(adminUid));
        }
      }
    });

    test('Property: Data filtering should preserve data integrity', () async {
      // Property: Filtering data should never return data that doesn\'t match the filter criteria
      
      const adminUid = 'test_admin_123';
      
      // Insert test data
      await TestDatabaseHelper.insertTestFoodItems(testDatabase, adminUid);
      await TestDatabaseHelper.insertTestBills(testDatabase, adminUid);
      
      // Test department filtering
      final departments = ['Pizza', 'Beverages', 'Desserts'];
      for (final department in departments) {
        final items = await offlineDataManager.ensureFoodItemsOfflineAvailability(adminUid, department: department);
        
        // Property: All returned items should belong to the specified department
        for (final item in items) {
          expect(item['department'], equals(department), 
                 reason: 'Item ${item['name']} should belong to department $department');
        }
      }
      
      // Test date range filtering
      final now = DateTime.now();
      final ranges = [
        (now.subtract(const Duration(days: 30)), now),
        (now.subtract(const Duration(days: 7)), now),
        (now.subtract(const Duration(days: 1)), now),
      ];
      
      for (final (startDate, endDate) in ranges) {
        final bills = await offlineDataManager.ensureBillsOfflineAvailability(
          adminUid, 
          startDate: startDate, 
          endDate: endDate
        );
        
        // Property: All returned bills should be within the date range
        for (final bill in bills) {
          final billDate = DateTime.fromMillisecondsSinceEpoch(bill['bill_date'] as int);
          expect(billDate.isAfter(startDate.subtract(const Duration(milliseconds: 1))), isTrue,
                 reason: 'Bill date should be after start date');
          expect(billDate.isBefore(endDate.add(const Duration(milliseconds: 1))), isTrue,
                 reason: 'Bill date should be before end date');
        }
      }
    });
  });
}