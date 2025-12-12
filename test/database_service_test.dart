import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'package:pos/view/tab_screen/view-model/backend/sqlite_dao.dart';

void main() {
  // Initialize Flutter binding and FFI for testing
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late SQLiteDAO sqliteDAO;
    const String testAdminUid = 'test_admin_123';

    setUp(() async {
      sqliteDAO = SQLiteDAO();
      await sqliteDAO.initialize();
    });

    tearDown(() async {
      await sqliteDAO.close();
    });

    test('should initialize database successfully', () async {
      expect(await sqliteDAO.isOnline(), true);
    });

    test('should save and retrieve food item', () async {
      final foodItem = {
        'id': 'food_001',
        'name': 'Test Pizza',
        'price': 15.99,
        'description': 'Delicious test pizza',
        'department': 'Main Course',
        'stocks': 10,
        'is_hot': 1, // Use integer instead of boolean
      };

      // Save food item
      await sqliteDAO.saveFoodItem(testAdminUid, foodItem);

      // Retrieve food item
      final retrievedItem = await sqliteDAO.getFoodItem(testAdminUid, 'food_001');

      expect(retrievedItem, isNotNull);
      expect(retrievedItem!['name'], 'Test Pizza');
      expect(retrievedItem['price'], 15.99);
      expect(retrievedItem['admin_uid'], testAdminUid);
      expect(retrievedItem['sync_status'], SyncStatus.pending.value);
    });

    test('should save and retrieve department', () async {
      final department = {
        'id': 'dept_001',
        'name': 'Test Department',
        'status': 'Active',
        'image_url': 'https://example.com/image.jpg',
      };

      // Save department
      await sqliteDAO.saveDepartment(testAdminUid, department);

      // Retrieve department
      final retrievedDept = await sqliteDAO.getDepartment(testAdminUid, 'dept_001');

      expect(retrievedDept, isNotNull);
      expect(retrievedDept!['name'], 'Test Department');
      expect(retrievedDept['status'], 'Active');
      expect(retrievedDept['admin_uid'], testAdminUid);
      expect(retrievedDept['sync_status'], SyncStatus.pending.value);
    });

    test('should save and retrieve bill', () async {
      final bill = {
        'id': 'bill_001',
        'customer_phone': '+1234567890',
        'items': '{"item1": {"name": "Pizza", "price": 15.99}}',
        'total_amount': 15.99,
        'bill_date': DateTime.now().millisecondsSinceEpoch,
      };

      // Save bill
      await sqliteDAO.saveBill(testAdminUid, bill);

      // Retrieve bill
      final retrievedBill = await sqliteDAO.getBill(testAdminUid, 'bill_001');

      expect(retrievedBill, isNotNull);
      expect(retrievedBill!['customer_phone'], '+1234567890');
      expect(retrievedBill['total_amount'], 15.99);
      expect(retrievedBill['admin_uid'], testAdminUid);
      expect(retrievedBill['sync_status'], SyncStatus.pending.value);
    });

    test('should update food item and mark as pending sync', () async {
      final foodItem = {
        'id': 'food_002',
        'name': 'Original Pizza',
        'price': 12.99,
        'department': 'Main Course',
      };

      // Save original item
      await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
      await sqliteDAO.markAsSynced('food_items', 'food_002');

      // Update item
      await sqliteDAO.updateFoodItem(testAdminUid, 'food_002', {
        'name': 'Updated Pizza',
        'price': 14.99,
      });

      // Retrieve updated item
      final updatedItem = await sqliteDAO.getFoodItem(testAdminUid, 'food_002');

      expect(updatedItem, isNotNull);
      expect(updatedItem!['name'], 'Updated Pizza');
      expect(updatedItem['price'], 14.99);
      expect(updatedItem['sync_status'], SyncStatus.pending.value);
    });

    test('should get pending sync items', () async {
      final foodItem = {
        'id': 'food_003',
        'name': 'Pending Pizza',
        'price': 13.99,
        'department': 'Main Course',
      };

      // Save item (will be marked as pending)
      await sqliteDAO.saveFoodItem(testAdminUid, foodItem);

      // Get pending items
      final pendingItems = await sqliteDAO.getPendingSyncItems();

      expect(pendingItems.isNotEmpty, true);
      expect(pendingItems.any((item) => item['record_id'] == 'food_003'), true);
    });

    test('should get food items by department', () async {
      final pizza = {
        'id': 'pizza_001',
        'name': 'Margherita Pizza',
        'price': 12.99,
        'department': 'Pizza',
      };

      final burger = {
        'id': 'burger_001',
        'name': 'Cheese Burger',
        'price': 8.99,
        'department': 'Burgers',
      };

      // Save items in different departments
      await sqliteDAO.saveFoodItem(testAdminUid, pizza);
      await sqliteDAO.saveFoodItem(testAdminUid, burger);

      // Get pizza items only
      final pizzaItems = await sqliteDAO.getFoodItems(testAdminUid, department: 'Pizza');

      expect(pizzaItems.length, 1);
      expect(pizzaItems.first['name'], 'Margherita Pizza');
      expect(pizzaItems.first['department'], 'Pizza');
    });

    test('should get bills within date range', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));

      final todayBill = {
        'id': 'bill_today',
        'customer_phone': '+1111111111',
        'items': '{}',
        'total_amount': 10.0,
        'bill_date': now.millisecondsSinceEpoch,
      };

      final yesterdayBill = {
        'id': 'bill_yesterday',
        'customer_phone': '+2222222222',
        'items': '{}',
        'total_amount': 20.0,
        'bill_date': yesterday.millisecondsSinceEpoch,
      };

      // Save bills
      await sqliteDAO.saveBill(testAdminUid, todayBill);
      await sqliteDAO.saveBill(testAdminUid, yesterdayBill);

      // Get bills from today only
      final todayBills = await sqliteDAO.getBills(
        testAdminUid,
        startDate: DateTime(now.year, now.month, now.day),
        endDate: tomorrow,
      );

      // Should find the bill from today
      expect(todayBills.length, greaterThanOrEqualTo(1));
      expect(todayBills.any((bill) => bill['id'] == 'bill_today'), true);
    });

    // **Feature: sqlite-firebase-sync, Property 3: Offline CRUD operations functionality**
    // **Validates: Requirements 1.3**
    test('Property 3: Offline CRUD operations functionality - For any CRUD operation performed while offline, the SQLite database should handle the operation successfully', () async {
      final random = Random();
      
      // Run property test with 100 iterations as specified in design
      for (int i = 0; i < 100; i++) {
        try {
          // Generate random test data for each iteration
          final itemId = 'offline_item_$i';
          final deptId = 'offline_dept_$i';
          final billId = 'offline_bill_$i';
          
          // Generate random food item data
          final foodItem = {
            'id': itemId,
            'name': 'Offline Food ${random.nextInt(1000)}',
            'price': (random.nextDouble() * 100).roundToDouble(),
            'description': 'Test food item for offline operation',
            'department': 'Test Department',
            'stocks': random.nextInt(100),
            'is_hot': random.nextBool() ? 1 : 0,
          };

          // Generate random department data
          final department = {
            'id': deptId,
            'name': 'Offline Dept ${random.nextInt(1000)}',
            'status': random.nextBool() ? 'Active' : 'Inactive',
            'image_url': 'https://example.com/dept_$i.jpg',
          };

          // Generate random bill data
          final bill = {
            'id': billId,
            'customer_phone': '+${random.nextInt(9000000000) + 1000000000}',
            'items': '{"item_$i": {"name": "${foodItem['name']}", "price": ${foodItem['price']}}}',
            'total_amount': foodItem['price'],
            'bill_date': DateTime.now().millisecondsSinceEpoch,
          };

          // Property: CREATE operations should work offline
          // Save food item
          await sqliteDAO.saveFoodItem(testAdminUid, foodItem);
          
          // Save department
          await sqliteDAO.saveDepartment(testAdminUid, department);
          
          // Save bill
          await sqliteDAO.saveBill(testAdminUid, bill);

          // Property: READ operations should work offline
          // Retrieve and verify food item
          final retrievedFood = await sqliteDAO.getFoodItem(testAdminUid, itemId);
          expect(retrievedFood, isNotNull, 
            reason: 'Food item should be retrievable offline for iteration $i');
          expect(retrievedFood!['name'], equals(foodItem['name']), 
            reason: 'Retrieved food item name should match for iteration $i');
          expect(retrievedFood['price'], equals(foodItem['price']), 
            reason: 'Retrieved food item price should match for iteration $i');

          // Retrieve and verify department
          final retrievedDept = await sqliteDAO.getDepartment(testAdminUid, deptId);
          expect(retrievedDept, isNotNull, 
            reason: 'Department should be retrievable offline for iteration $i');
          expect(retrievedDept!['name'], equals(department['name']), 
            reason: 'Retrieved department name should match for iteration $i');

          // Retrieve and verify bill
          final retrievedBill = await sqliteDAO.getBill(testAdminUid, billId);
          expect(retrievedBill, isNotNull, 
            reason: 'Bill should be retrievable offline for iteration $i');
          expect(retrievedBill!['customer_phone'], equals(bill['customer_phone']), 
            reason: 'Retrieved bill customer phone should match for iteration $i');
          expect(retrievedBill['total_amount'], equals(bill['total_amount']), 
            reason: 'Retrieved bill total amount should match for iteration $i');

          // Property: UPDATE operations should work offline
          final updatedName = 'Updated Offline Food ${random.nextInt(1000)}';
          final updatedPrice = (random.nextDouble() * 200).roundToDouble();
          
          await sqliteDAO.updateFoodItem(testAdminUid, itemId, {
            'name': updatedName,
            'price': updatedPrice,
          });

          // Verify update worked
          final updatedFood = await sqliteDAO.getFoodItem(testAdminUid, itemId);
          expect(updatedFood, isNotNull, 
            reason: 'Updated food item should be retrievable offline for iteration $i');
          expect(updatedFood!['name'], equals(updatedName), 
            reason: 'Food item name should be updated offline for iteration $i');
          expect(updatedFood['price'], equals(updatedPrice), 
            reason: 'Food item price should be updated offline for iteration $i');

          // Update department
          final updatedDeptName = 'Updated Offline Dept ${random.nextInt(1000)}';
          await sqliteDAO.updateDepartment(testAdminUid, deptId, {
            'name': updatedDeptName,
          });

          // Verify department update
          final updatedDept = await sqliteDAO.getDepartment(testAdminUid, deptId);
          expect(updatedDept, isNotNull, 
            reason: 'Updated department should be retrievable offline for iteration $i');
          expect(updatedDept!['name'], equals(updatedDeptName), 
            reason: 'Department name should be updated offline for iteration $i');

          // Update bill
          final updatedAmount = (random.nextDouble() * 300).roundToDouble();
          await sqliteDAO.updateBill(testAdminUid, billId, {
            'total_amount': updatedAmount,
          });

          // Verify bill update
          final updatedBill = await sqliteDAO.getBill(testAdminUid, billId);
          expect(updatedBill, isNotNull, 
            reason: 'Updated bill should be retrievable offline for iteration $i');
          expect(updatedBill!['total_amount'], equals(updatedAmount), 
            reason: 'Bill total amount should be updated offline for iteration $i');

          // Property: DELETE operations should work offline
          // Delete food item
          await sqliteDAO.deleteFoodItem(testAdminUid, itemId);
          final deletedFood = await sqliteDAO.getFoodItem(testAdminUid, itemId);
          expect(deletedFood, isNull, 
            reason: 'Deleted food item should not be retrievable for iteration $i');

          // Delete department
          await sqliteDAO.deleteDepartment(testAdminUid, deptId);
          final deletedDept = await sqliteDAO.getDepartment(testAdminUid, deptId);
          expect(deletedDept, isNull, 
            reason: 'Deleted department should not be retrievable for iteration $i');

          // Delete bill
          await sqliteDAO.deleteBill(testAdminUid, billId);
          final deletedBill = await sqliteDAO.getBill(testAdminUid, billId);
          expect(deletedBill, isNull, 
            reason: 'Deleted bill should not be retrievable for iteration $i');

          // Property: All operations should complete without throwing exceptions
          // (If we reach this point, all operations succeeded)
          
        } catch (e) {
          fail('Property test failed at iteration $i: $e');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}