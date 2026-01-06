// Project imports:
import 'package:pos/core/error/exceptions.dart';
import 'package:pos/data/models/bill_model.dart';
import 'package:pos/data/models/department_model.dart';
import 'package:pos/data/models/food_item_model.dart';
import 'sqlite_dao.dart';

/// Local data source interface for food items (SQLite)
abstract class FoodItemLocalDataSource {
  Future<List<FoodItemModel>> getFoodItems(String adminUid, {String? department});
  Future<FoodItemModel?> getFoodItem(String adminUid, String itemId);
  Future<void> saveFoodItem(String adminUid, FoodItemModel foodItem);
  Future<void> updateFoodItem(String adminUid, String itemId, FoodItemModel foodItem);
  Future<void> deleteFoodItem(String adminUid, String itemId);
  Future<List<FoodItemModel>> searchFoodItems(String adminUid, String query, {String? department, int limit = 20});
  Future<void> cacheFoodItems(String adminUid, List<FoodItemModel> items);
  Future<void> markAsSynced(String itemId);
  Future<void> markAsPending(String itemId);
}

/// Department local data source interface
abstract class DepartmentLocalDataSource {
  Future<List<DepartmentModel>> getDepartments(String adminUid);
  Future<DepartmentModel?> getDepartment(String adminUid, String departmentId);
  Future<void> saveDepartment(String adminUid, DepartmentModel department);
  Future<void> updateDepartment(String adminUid, String departmentId, DepartmentModel department);
  Future<void> deleteDepartment(String adminUid, String departmentId);
  Future<void> markAsSynced(String itemId);
  Future<void> markAsPending(String itemId);
}

/// Bill local data source interface
abstract class BillLocalDataSource {
  Future<List<BillModel>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate});
  Future<BillModel?> getBill(String adminUid, String billId);
  Future<void> saveBill(String adminUid, BillModel bill);
  Future<void> updateBill(String adminUid, String billId, BillModel bill);
  Future<void> deleteBill(String adminUid, String billId);
  Future<List<BillModel>> getOfflineBills(String adminUid);
  Future<void> markAsSynced(String itemId);
  Future<void> markAsPending(String itemId);
}

/// Implementation using existing SQLiteDAO
class FoodItemLocalDataSourceImpl implements FoodItemLocalDataSource {
  final SQLiteDAO _sqliteDAO;

  FoodItemLocalDataSourceImpl(this._sqliteDAO);

  @override
  Future<List<FoodItemModel>> getFoodItems(String adminUid, {String? department}) async {
    try {
      final items = await _sqliteDAO.getFoodItems(adminUid, department: department);
      return items.map((map) => FoodItemModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to get food items: ${e.toString()}');
    }
  }

  @override
  Future<FoodItemModel?> getFoodItem(String adminUid, String itemId) async {
    try {
      final item = await _sqliteDAO.getFoodItem(adminUid, itemId);
      return item != null ? FoodItemModel.fromMap(item) : null;
    } on Exception catch (e) {
      throw DatabaseException('Failed to get food item: ${e.toString()}');
    }
  }

  @override
  Future<void> saveFoodItem(String adminUid, FoodItemModel foodItem) async {
    try {
      final map = foodItem.toSqliteMap();
      await _sqliteDAO.saveFoodItem(adminUid, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to save food item: ${e.toString()}');
    }
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, FoodItemModel foodItem) async {
    try {
      final map = foodItem.toSqliteMap();
      await _sqliteDAO.updateFoodItem(adminUid, itemId, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to update food item: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    try {
      await _sqliteDAO.deleteFoodItem(adminUid, itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to delete food item: ${e.toString()}');
    }
  }

  @override
  Future<List<FoodItemModel>> searchFoodItems(String adminUid, String query, {String? department, int limit = 20}) async {
    try {
      final items = await _sqliteDAO.searchFoodItems(adminUid, query, 
        department: department, limit: limit);
      return items.map((map) => FoodItemModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to search food items: ${e.toString()}');
    }
  }

  @override
  Future<void> cacheFoodItems(String adminUid, List<FoodItemModel> items) async {
    try {
      for (final item in items) {
        await saveFoodItem(adminUid, item);
      }
    } on Exception catch (e) {
      throw DatabaseException('Failed to cache food items: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsSynced(String itemId) async {
    try {
      await _sqliteDAO.markAsSynced('food_items', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark food item as synced: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsPending(String itemId) async {
    try {
      await _sqliteDAO.markAsPending('food_items', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark food item as pending: ${e.toString()}');
    }
  }
}

/// Department local data source implementation
class DepartmentLocalDataSourceImpl implements DepartmentLocalDataSource {
  final SQLiteDAO _sqliteDAO;

  DepartmentLocalDataSourceImpl(this._sqliteDAO);

  @override
  Future<List<DepartmentModel>> getDepartments(String adminUid) async {
    try {
      final departments = await _sqliteDAO.getDepartments(adminUid);
      return departments.map((map) => DepartmentModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to get departments: ${e.toString()}');
    }
  }

  @override
  Future<DepartmentModel?> getDepartment(String adminUid, String departmentId) async {
    try {
      final department = await _sqliteDAO.getDepartment(adminUid, departmentId);
      return department != null ? DepartmentModel.fromMap(department) : null;
    } on Exception catch (e) {
      throw DatabaseException('Failed to get department: ${e.toString()}');
    }
  }

  @override
  Future<void> saveDepartment(String adminUid, DepartmentModel department) async {
    try {
      final map = department.toSqliteMap();
      await _sqliteDAO.saveDepartment(adminUid, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to save department: ${e.toString()}');
    }
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, DepartmentModel department) async {
    try {
      final map = department.toSqliteMap();
      await _sqliteDAO.updateDepartment(adminUid, departmentId, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to update department: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    try {
      await _sqliteDAO.deleteDepartment(adminUid, departmentId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to delete department: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsSynced(String itemId) async {
    try {
      await _sqliteDAO.markAsSynced('departments', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark department as synced: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsPending(String itemId) async {
    try {
      await _sqliteDAO.markAsPending('departments', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark department as pending: ${e.toString()}');
    }
  }
}

/// Bill local data source implementation
class BillLocalDataSourceImpl implements BillLocalDataSource {
  final SQLiteDAO _sqliteDAO;

  BillLocalDataSourceImpl(this._sqliteDAO);

  @override
  Future<List<BillModel>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final bills = await _sqliteDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
      return bills.map((map) => BillModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to get bills: ${e.toString()}');
    }
  }

  @override
  Future<BillModel?> getBill(String adminUid, String billId) async {
    try {
      final bill = await _sqliteDAO.getBill(adminUid, billId);
      return bill != null ? BillModel.fromMap(bill) : null;
    } on Exception catch (e) {
      throw DatabaseException('Failed to get bill: ${e.toString()}');
    }
  }

  @override
  Future<void> saveBill(String adminUid, BillModel bill) async {
    try {
      final map = bill.toSqliteMap();
      await _sqliteDAO.saveBill(adminUid, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to save bill: ${e.toString()}');
    }
  }

  @override
  Future<void> updateBill(String adminUid, String billId, BillModel bill) async {
    try {
      final map = bill.toSqliteMap();
      await _sqliteDAO.updateBill(adminUid, billId, map);
    } on Exception catch (e) {
      throw DatabaseException('Failed to update bill: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    try {
      await _sqliteDAO.deleteBill(adminUid, billId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to delete bill: ${e.toString()}');
    }
  }

  @override
  Future<List<BillModel>> getOfflineBills(String adminUid) async {
    try {
      // Get all bills with pending sync status
      final bills = await _sqliteDAO.getPendingItemsByTable('bills');
      return bills.map((map) => BillModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw DatabaseException('Failed to get offline bills: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsSynced(String itemId) async {
    try {
      await _sqliteDAO.markAsSynced('bills', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark bill as synced: ${e.toString()}');
    }
  }

  @override
  Future<void> markAsPending(String itemId) async {
    try {
      await _sqliteDAO.markAsPending('bills', itemId);
    } on Exception catch (e) {
      throw DatabaseException('Failed to mark bill as pending: ${e.toString()}');
    }
  }
}
