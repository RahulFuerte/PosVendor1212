// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/department.dart';

/// Department Repository Interface (Domain Layer)
abstract class DepartmentRepository {
  /// Get all departments for an admin
  Future<Result<List<Department>>> getDepartments(String adminUid);
  
  /// Get a single department by ID
  Future<Result<Department?>> getDepartment(String adminUid, String departmentId);
  
  /// Save a new department
  Future<Result<void>> saveDepartment(String adminUid, Department department);
  
  /// Update an existing department
  Future<Result<void>> updateDepartment(String adminUid, String departmentId, Department department);
  
  /// Delete a department
  Future<Result<void>> deleteDepartment(String adminUid, String departmentId);
  
  /// Get departments with pagination
  Future<Result<List<Department>>> getDepartmentsPaginated(
    String adminUid, {
    int offset = 0,
    int limit = 20,
  });
}
