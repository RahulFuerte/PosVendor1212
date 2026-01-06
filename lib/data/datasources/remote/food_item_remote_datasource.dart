// Project imports:
import 'package:pos/core/error/exceptions.dart';
import 'package:pos/data/models/bill_model.dart';
import 'package:pos/data/models/department_model.dart';
import 'package:pos/data/models/food_item_model.dart';
import 'firebase_dao.dart';

/// Remote data source interface for food items (Firebase)
abstract class FoodItemRemoteDataSource {
  Future<List<FoodItemModel>> getFoodItems(String adminUid, {String? department});
  Future<FoodItemModel?> getFoodItem(String adminUid, String itemId);
  Future<void> saveFoodItem(String adminUid, FoodItemModel foodItem);
  Future<void> updateFoodItem(String adminUid, String itemId, FoodItemModel foodItem);
  Future<void> deleteFoodItem(String adminUid, String itemId);
}

/// Department remote data source interface
abstract class DepartmentRemoteDataSource {
  Future<List<DepartmentModel>> getDepartments(String adminUid);
  Future<DepartmentModel?> getDepartment(String adminUid, String departmentId);
  Future<void> saveDepartment(String adminUid, DepartmentModel department);
  Future<void> updateDepartment(String adminUid, String departmentId, DepartmentModel department);
  Future<void> deleteDepartment(String adminUid, String departmentId);
}

/// Bill remote data source interface
abstract class BillRemoteDataSource {
  Future<List<BillModel>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate});
  Future<BillModel?> getBill(String adminUid, String billId);
  Future<void> saveBill(String adminUid, BillModel bill);
  Future<void> updateBill(String adminUid, String billId, BillModel bill);
  Future<void> deleteBill(String adminUid, String billId);
}

/// Implementation using existing FirebaseDAO
class FoodItemRemoteDataSourceImpl implements FoodItemRemoteDataSource {
  final FirebaseDAO _firebaseDAO;

  FoodItemRemoteDataSourceImpl(this._firebaseDAO);

  @override
  Future<List<FoodItemModel>> getFoodItems(String adminUid, {String? department}) async {
    try {
      final items = await _firebaseDAO.getFoodItems(adminUid, department: department);
      return items.map((map) => FoodItemModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw ServerException('Failed to get food items from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<FoodItemModel?> getFoodItem(String adminUid, String itemId) async {
    try {
      final item = await _firebaseDAO.getFoodItem(adminUid, itemId);
      return item != null ? FoodItemModel.fromMap(item) : null;
    } on Exception catch (e) {
      throw ServerException('Failed to get food item from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> saveFoodItem(String adminUid, FoodItemModel foodItem) async {
    try {
      final map = foodItem.toFirebaseMap();
      await _firebaseDAO.saveFoodItem(adminUid, map);
    } on Exception catch (e) {
      throw ServerException('Failed to save food item to Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> updateFoodItem(String adminUid, String itemId, FoodItemModel foodItem) async {
    try {
      final map = foodItem.toFirebaseMap();
      await _firebaseDAO.updateFoodItem(adminUid, itemId, map);
    } on Exception catch (e) {
      throw ServerException('Failed to update food item in Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteFoodItem(String adminUid, String itemId) async {
    try {
      await _firebaseDAO.deleteFoodItem(adminUid, itemId);
    } on Exception catch (e) {
      throw ServerException('Failed to delete food item from Firebase: ${e.toString()}');
    }
  }
}

/// Department remote data source implementation
class DepartmentRemoteDataSourceImpl implements DepartmentRemoteDataSource {
  final FirebaseDAO _firebaseDAO;

  DepartmentRemoteDataSourceImpl(this._firebaseDAO);

  @override
  Future<List<DepartmentModel>> getDepartments(String adminUid) async {
    try {
      final departments = await _firebaseDAO.getDepartments(adminUid);
      return departments.map((map) => DepartmentModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw ServerException('Failed to get departments from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<DepartmentModel?> getDepartment(String adminUid, String departmentId) async {
    try {
      final department = await _firebaseDAO.getDepartment(adminUid, departmentId);
      return department != null ? DepartmentModel.fromMap(department) : null;
    } on Exception catch (e) {
      throw ServerException('Failed to get department from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> saveDepartment(String adminUid, DepartmentModel department) async {
    try {
      final map = department.toFirebaseMap();
      await _firebaseDAO.saveDepartment(adminUid, map);
    } on Exception catch (e) {
      throw ServerException('Failed to save department to Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> updateDepartment(String adminUid, String departmentId, DepartmentModel department) async {
    try {
      final map = department.toFirebaseMap();
      await _firebaseDAO.updateDepartment(adminUid, departmentId, map);
    } on Exception catch (e) {
      throw ServerException('Failed to update department in Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteDepartment(String adminUid, String departmentId) async {
    try {
      await _firebaseDAO.deleteDepartment(adminUid, departmentId);
    } on Exception catch (e) {
      throw ServerException('Failed to delete department from Firebase: ${e.toString()}');
    }
  }
}

/// Bill remote data source implementation
class BillRemoteDataSourceImpl implements BillRemoteDataSource {
  final FirebaseDAO _firebaseDAO;

  BillRemoteDataSourceImpl(this._firebaseDAO);

  @override
  Future<List<BillModel>> getBills(String adminUid, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final bills = await _firebaseDAO.getBills(adminUid, startDate: startDate, endDate: endDate);
      return bills.map((map) => BillModel.fromMap(map)).toList();
    } on Exception catch (e) {
      throw ServerException('Failed to get bills from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<BillModel?> getBill(String adminUid, String billId) async {
    try {
      final bill = await _firebaseDAO.getBill(adminUid, billId);
      return bill != null ? BillModel.fromMap(bill) : null;
    } on Exception catch (e) {
      throw ServerException('Failed to get bill from Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> saveBill(String adminUid, BillModel bill) async {
    try {
      final map = bill.toFirebaseMap();
      await _firebaseDAO.saveBill(adminUid, map);
    } on Exception catch (e) {
      throw ServerException('Failed to save bill to Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> updateBill(String adminUid, String billId, BillModel bill) async {
    try {
      final map = bill.toFirebaseMap();
      await _firebaseDAO.updateBill(adminUid, billId, map);
    } on Exception catch (e) {
      throw ServerException('Failed to update bill in Firebase: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteBill(String adminUid, String billId) async {
    try {
      await _firebaseDAO.deleteBill(adminUid, billId);
    } on Exception catch (e) {
      throw ServerException('Failed to delete bill from Firebase: ${e.toString()}');
    }
  }
}
