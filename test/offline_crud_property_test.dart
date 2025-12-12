import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/view/tab_screen/view-model/backend/database_service.dart';
import 'test_database_helper.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Offline CRUD Property Tests', () {
    const String testAdminUid = 'test_admin_offline';

    setUp(() async {
      await TestDatabaseHelper.getTestDatabase();
      await TestDatabaseHelper.clearAllTables();
    });

    tearDown(() async {
      await TestDatabaseHelper.closeTestDatabase();
    });

    // **Feature: sqlite-firebase-sync, Property 3: Offline CRUD operations functionality**
    // **Validates: Requirements 1.3**
    test('Property 3: Offline CRUD operations functionality - For any CRUD operation performed while offline, the SQLite database should handle the operation successfully', () async {
      final random = Random();
      final db = await TestDatabaseHelper.getTestDatabase();
      
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
            'admin_uid': testAdminUid,
            'name': 'Offline Food ${random.nextInt(1000)}',
            'price': (random.nextDouble() * 100).roundToDouble(),
            'description': 'Test food item for offline operation',
            'department': 'Test Department',
            'stocks': random.nextInt(100),
            'is_hot': random.nextBool() ? 1 : 0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.pending.value,
          };

          // Generate random department data
          final department = {
            'id': deptId,
            'admin_uid': testAdminUid,
            'name': 'Offline Dept ${random.nextInt(1000)}',
            'status': random.nextBool() ? 'Active' : 'Inactive',
            'image_url': 'https://example.com/dept_$i.jpg',
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.pending.value,
          };

          // Generate random bill data
          final bill = {
            'id': billId,
            'admin_uid': testAdminUid,
            'customer_phone': '+1${random.nextInt(900000000) + 100000000}',
            'items': '{"item_$i": {"name": "${foodItem['name']}", "price": ${foodItem['price']}}}',
            'total_amount': foodItem['price'],
            'bill_date': DateTime.now().millisecondsSinceEpoch,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'sync_status': SyncStatus.pending.value,
          };

          // Property: CREATE operations should work offline
          // Insert food item directly into SQLite
          await db.insert('food_items', foodItem);
          
          // Insert department directly into SQLite
          await db.insert('departments', department);
          
          // Insert bill directly into SQLite
          await db.insert('bills', bill);

          // Property: READ operations should work offline
          // Retrieve and verify food item
          final retrievedFoodList = await db.query(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, itemId],
          );
          expect(retrievedFoodList.isNotEmpty, isTrue, 
            reason: 'Food item should be retrievable offline for iteration $i');
          
          final retrievedFood = retrievedFoodList.first;
          expect(retrievedFood['name'], equals(foodItem['name']), 
            reason: 'Retrieved food item name should match for iteration $i');
          expect(retrievedFood['price'], equals(foodItem['price']), 
            reason: 'Retrieved food item price should match for iteration $i');

          // Retrieve and verify department
          final retrievedDeptList = await db.query(
            'departments',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, deptId],
          );
          expect(retrievedDeptList.isNotEmpty, isTrue, 
            reason: 'Department should be retrievable offline for iteration $i');
          
          final retrievedDept = retrievedDeptList.first;
          expect(retrievedDept['name'], equals(department['name']), 
            reason: 'Retrieved department name should match for iteration $i');

          // Retrieve and verify bill
          final retrievedBillList = await db.query(
            'bills',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, billId],
          );
          expect(retrievedBillList.isNotEmpty, isTrue, 
            reason: 'Bill should be retrievable offline for iteration $i');
          
          final retrievedBill = retrievedBillList.first;
          expect(retrievedBill['customer_phone'], equals(bill['customer_phone']), 
            reason: 'Retrieved bill customer phone should match for iteration $i');
          expect(retrievedBill['total_amount'], equals(bill['total_amount']), 
            reason: 'Retrieved bill total amount should match for iteration $i');

          // Property: UPDATE operations should work offline
          final updatedName = 'Updated Offline Food ${random.nextInt(1000)}';
          final updatedPrice = (random.nextDouble() * 200).roundToDouble();
          final updateTime = DateTime.now().millisecondsSinceEpoch;
          
          // Update food item
          final foodUpdateCount = await db.update(
            'food_items',
            {
              'name': updatedName,
              'price': updatedPrice,
              'updated_at': updateTime,
              'sync_status': SyncStatus.pending.value,
            },
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, itemId],
          );
          expect(foodUpdateCount, equals(1), 
            reason: 'Food item update should affect exactly one row for iteration $i');

          // Verify food item update worked
          final updatedFoodList = await db.query(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, itemId],
          );
          expect(updatedFoodList.isNotEmpty, isTrue, 
            reason: 'Updated food item should be retrievable offline for iteration $i');
          
          final updatedFood = updatedFoodList.first;
          expect(updatedFood['name'], equals(updatedName), 
            reason: 'Food item name should be updated offline for iteration $i');
          expect(updatedFood['price'], equals(updatedPrice), 
            reason: 'Food item price should be updated offline for iteration $i');

          // Update department
          final updatedDeptName = 'Updated Offline Dept ${random.nextInt(1000)}';
          final deptUpdateCount = await db.update(
            'departments',
            {
              'name': updatedDeptName,
              'updated_at': updateTime,
              'sync_status': SyncStatus.pending.value,
            },
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, deptId],
          );
          expect(deptUpdateCount, equals(1), 
            reason: 'Department update should affect exactly one row for iteration $i');

          // Verify department update
          final updatedDeptList = await db.query(
            'departments',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, deptId],
          );
          expect(updatedDeptList.isNotEmpty, isTrue, 
            reason: 'Updated department should be retrievable offline for iteration $i');
          
          final updatedDept = updatedDeptList.first;
          expect(updatedDept['name'], equals(updatedDeptName), 
            reason: 'Department name should be updated offline for iteration $i');

          // Update bill
          final updatedAmount = (random.nextDouble() * 300).roundToDouble();
          final billUpdateCount = await db.update(
            'bills',
            {
              'total_amount': updatedAmount,
              'updated_at': updateTime,
              'sync_status': SyncStatus.pending.value,
            },
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, billId],
          );
          expect(billUpdateCount, equals(1), 
            reason: 'Bill update should affect exactly one row for iteration $i');

          // Verify bill update
          final updatedBillList = await db.query(
            'bills',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, billId],
          );
          expect(updatedBillList.isNotEmpty, isTrue, 
            reason: 'Updated bill should be retrievable offline for iteration $i');
          
          final updatedBill = updatedBillList.first;
          expect(updatedBill['total_amount'], equals(updatedAmount), 
            reason: 'Bill total amount should be updated offline for iteration $i');

          // Property: DELETE operations should work offline
          // Delete food item
          final foodDeleteCount = await db.delete(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, itemId],
          );
          expect(foodDeleteCount, equals(1), 
            reason: 'Food item deletion should affect exactly one row for iteration $i');
          
          // Verify food item is deleted
          final deletedFoodList = await db.query(
            'food_items',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, itemId],
          );
          expect(deletedFoodList.isEmpty, isTrue, 
            reason: 'Deleted food item should not be retrievable for iteration $i');

          // Delete department
          final deptDeleteCount = await db.delete(
            'departments',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, deptId],
          );
          expect(deptDeleteCount, equals(1), 
            reason: 'Department deletion should affect exactly one row for iteration $i');
          
          // Verify department is deleted
          final deletedDeptList = await db.query(
            'departments',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, deptId],
          );
          expect(deletedDeptList.isEmpty, isTrue, 
            reason: 'Deleted department should not be retrievable for iteration $i');

          // Delete bill
          final billDeleteCount = await db.delete(
            'bills',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, billId],
          );
          expect(billDeleteCount, equals(1), 
            reason: 'Bill deletion should affect exactly one row for iteration $i');
          
          // Verify bill is deleted
          final deletedBillList = await db.query(
            'bills',
            where: 'admin_uid = ? AND id = ?',
            whereArgs: [testAdminUid, billId],
          );
          expect(deletedBillList.isEmpty, isTrue, 
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