// Project imports:
import 'package:pos/core/error/exceptions.dart';
import 'package:pos/core/error/failures.dart';
import 'package:pos/core/network/network_info.dart';
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/data/datasources/local/food_item_local_datasource.dart';
import 'package:pos/data/datasources/remote/food_item_remote_datasource.dart';
import 'package:pos/data/models/food_item_model.dart';
import 'package:pos/domain/entities/food_item.dart';
import 'package:pos/domain/repositories/food_item_repository.dart';

/// Food Item Repository Implementation
/// Implements offline-first strategy with automatic sync
class FoodItemRepositoryImpl implements FoodItemRepository {
  final FoodItemLocalDataSource localDataSource;
  final FoodItemRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  FoodItemRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<List<FoodItem>>> getFoodItems(String adminUid, {String? department}) async {
    try {
      // Always try local first (offline-first)
      final localItems = await localDataSource.getFoodItems(adminUid, department: department);
      
      // If online and local is empty, fetch from remote
      if (localItems.isEmpty && await networkInfo.isConnected) {
        try {
          final remoteItems = await remoteDataSource.getFoodItems(adminUid, department: department);
          // Cache remote items locally
          await localDataSource.cacheFoodItems(adminUid, remoteItems);
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
      return Result.failure(DatabaseFailure('Failed to get food items: $e'));
    }
  }

  @override
  Future<Result<FoodItem?>> getFoodItem(String adminUid, String itemId) async {
    try {
      final localItem = await localDataSource.getFoodItem(adminUid, itemId);
      
      if (localItem != null) {
        return Result.success(localItem.toEntity());
      }
      
      // Try remote if not found locally
      if (await networkInfo.isConnected) {
        try {
          final remoteItem = await remoteDataSource.getFoodItem(adminUid, itemId);
          if (remoteItem != null) {
            await localDataSource.saveFoodItem(adminUid, remoteItem);
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
      return Result.failure(DatabaseFailure('Failed to get food item: $e'));
    }
  }

  @override
  Future<Result<void>> saveFoodItem(String adminUid, FoodItem foodItem) async {
    try {
      final model = FoodItemModel.fromEntity(foodItem);
      
      // Always save locally first
      await localDataSource.saveFoodItem(adminUid, model);
      
      // Try to sync to remote if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.saveFoodItem(adminUid, model);
          await localDataSource.markAsSynced(foodItem.id);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to save food item: $e'));
    }
  }

  @override
  Future<Result<void>> updateFoodItem(String adminUid, String itemId, FoodItem foodItem) async {
    try {
      final model = FoodItemModel.fromEntity(foodItem);
      
      await localDataSource.updateFoodItem(adminUid, itemId, model);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.updateFoodItem(adminUid, itemId, model);
          await localDataSource.markAsSynced(itemId);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update food item: $e'));
    }
  }

  @override
  Future<Result<void>> deleteFoodItem(String adminUid, String itemId) async {
    try {
      await localDataSource.deleteFoodItem(adminUid, itemId);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.deleteFoodItem(adminUid, itemId);
        } on ServerException {
          // Remote failed, deletion will sync later
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete food item: $e'));
    }
  }

  @override
  Future<Result<List<FoodItem>>> searchFoodItems(
    String adminUid,
    String query, {
    String? department,
    int limit = 20,
  }) async {
    try {
      final items = await localDataSource.searchFoodItems(
        adminUid,
        query,
        department: department,
        limit: limit,
      );
      return Result.success(items.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to search food items: $e'));
    }
  }

  @override
  Future<Result<List<FoodItem>>> getFoodItemsPaginated(
    String adminUid, {
    String? department,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final items = await localDataSource.getFoodItems(adminUid, department: department);
      // Apply pagination locally
      final paginated = items.skip(offset).take(limit).toList();
      return Result.success(paginated.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get paginated food items: $e'));
    }
  }

  @override
  Future<Result<int>> getFoodItemsCount(String adminUid, {String? department}) async {
    try {
      final items = await localDataSource.getFoodItems(adminUid, department: department);
      return Result.success(items.length);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get food items count: $e'));
    }
  }
}
