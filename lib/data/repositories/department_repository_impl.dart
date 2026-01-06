// Project imports:
import 'package:pos/core/error/exceptions.dart';
import 'package:pos/core/error/failures.dart';
import 'package:pos/core/network/network_info.dart';
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/data/datasources/local/food_item_local_datasource.dart';
import 'package:pos/data/datasources/remote/food_item_remote_datasource.dart';
import 'package:pos/data/models/department_model.dart';
import 'package:pos/domain/entities/department.dart';
import 'package:pos/domain/repositories/department_repository.dart';

/// Department Repository Implementation
/// Implements offline-first strategy with automatic sync
class DepartmentRepositoryImpl implements DepartmentRepository {
  final DepartmentLocalDataSource localDataSource;
  final DepartmentRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  DepartmentRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<List<Department>>> getDepartments(String adminUid) async {
    try {
      // Always try local first (offline-first)
      final localItems = await localDataSource.getDepartments(adminUid);
      
      // If online and local is empty, fetch from remote
      if (localItems.isEmpty && await networkInfo.isConnected) {
        try {
          final remoteItems = await remoteDataSource.getDepartments(adminUid);
          // Cache remote items locally
          await _cacheDepartments(adminUid, remoteItems);
          return Result.success(remoteItems.map((m) => m.toEntity()).toList());
        } on ServerException {
          // Remote failed, return empty local
          return Result.success([]);
        }
      }
      
      return Result.success(localItems.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get departments: $e'));
    }
  }

  @override
  Future<Result<Department?>> getDepartment(String adminUid, String departmentId) async {
    try {
      final localItem = await localDataSource.getDepartment(adminUid, departmentId);
      
      if (localItem != null) {
        return Result.success(localItem.toEntity());
      }
      
      // Try remote if not found locally
      if (await networkInfo.isConnected) {
        try {
          final remoteItem = await remoteDataSource.getDepartment(adminUid, departmentId);
          if (remoteItem != null) {
            await localDataSource.saveDepartment(adminUid, remoteItem);
            return Result.success(remoteItem.toEntity());
          }
        } on ServerException {
          // Remote failed, return null
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get department: $e'));
    }
  }

  @override
  Future<Result<void>> saveDepartment(String adminUid, Department department) async {
    try {
      final model = DepartmentModel.fromEntity(department);
      
      // Always save locally first
      await localDataSource.saveDepartment(adminUid, model);
      
      // Try to sync to remote if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.saveDepartment(adminUid, model);
          await localDataSource.markAsSynced(model.id);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to save department: $e'));
    }
  }

  @override
  Future<Result<void>> updateDepartment(String adminUid, String departmentId, Department department) async {
    try {
      final model = DepartmentModel.fromEntity(department);
      
      await localDataSource.updateDepartment(adminUid, departmentId, model);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.updateDepartment(adminUid, departmentId, model);
          await localDataSource.markAsSynced(departmentId);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update department: $e'));
    }
  }

  @override
  Future<Result<void>> deleteDepartment(String adminUid, String departmentId) async {
    try {
      await localDataSource.deleteDepartment(adminUid, departmentId);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.deleteDepartment(adminUid, departmentId);
        } on ServerException {
          // Remote failed, deletion will sync later
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete department: $e'));
    }
  }

  @override
  Future<Result<List<Department>>> getDepartmentsPaginated(
    String adminUid, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final items = await localDataSource.getDepartments(adminUid);
      // Apply pagination locally
      final paginated = items.skip(offset).take(limit).toList();
      return Result.success(paginated.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get paginated departments: $e'));
    }
  }

  /// Cache departments locally
  Future<void> _cacheDepartments(String adminUid, List<DepartmentModel> departments) async {
    for (final department in departments) {
      await localDataSource.saveDepartment(adminUid, department);
    }
  }
}
