// Project imports:
import 'package:pos/core/error/exceptions.dart';
import 'package:pos/core/error/failures.dart';
import 'package:pos/core/network/network_info.dart';
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/data/datasources/local/food_item_local_datasource.dart';
import 'package:pos/data/datasources/remote/food_item_remote_datasource.dart';
import 'package:pos/data/models/bill_model.dart';
import 'package:pos/domain/entities/bill.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Bill Repository Implementation
/// Implements offline-first strategy with automatic sync
class BillRepositoryImpl implements BillRepository {
  final BillLocalDataSource localDataSource;
  final BillRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  BillRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Result<List<Bill>>> getBills(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Always try local first (offline-first)
      final localItems = await localDataSource.getBills(adminUid, startDate: startDate, endDate: endDate);
      
      // If online and no specific date range, fetch from remote and cache
      if ((startDate == null && endDate == null) && await networkInfo.isConnected) {
        try {
          final remoteItems = await remoteDataSource.getBills(adminUid, startDate: startDate, endDate: endDate);
          // Cache remote items locally
          await _cacheBills(adminUid, remoteItems);
          return Result.success(remoteItems.map((m) => m.toEntity()).toList());
        } on ServerException {
          // Remote failed, return local data
        }
      }
      
      return Result.success(localItems.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get bills: $e'));
    }
  }

  @override
  Future<Result<Bill?>> getBill(String adminUid, String billId) async {
    try {
      final localItem = await localDataSource.getBill(adminUid, billId);
      
      if (localItem != null) {
        return Result.success(localItem.toEntity());
      }
      
      // Try remote if not found locally
      if (await networkInfo.isConnected) {
        try {
          final remoteItem = await remoteDataSource.getBill(adminUid, billId);
          if (remoteItem != null) {
            await localDataSource.saveBill(adminUid, remoteItem);
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
      return Result.failure(DatabaseFailure('Failed to get bill: $e'));
    }
  }

  @override
  Future<Result<void>> saveBill(String adminUid, Bill bill) async {
    try {
      final model = BillModel.fromEntity(bill);
      
      // Always save locally first
      await localDataSource.saveBill(adminUid, model);
      
      // Try to sync to remote if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.saveBill(adminUid, model);
          await localDataSource.markAsSynced(model.id);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to save bill: $e'));
    }
  }

  @override
  Future<Result<void>> updateBill(String adminUid, String billId, Bill bill) async {
    try {
      final model = BillModel.fromEntity(bill);
      
      await localDataSource.updateBill(adminUid, billId, model);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.updateBill(adminUid, billId, model);
          await localDataSource.markAsSynced(billId);
        } on ServerException {
          // Remote failed, item stays pending
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to update bill: $e'));
    }
  }

  @override
  Future<Result<void>> deleteBill(String adminUid, String billId) async {
    try {
      await localDataSource.deleteBill(adminUid, billId);
      
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.deleteBill(adminUid, billId);
        } on ServerException {
          // Remote failed, deletion will sync later
        }
      }
      
      return Result.success(null);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to delete bill: $e'));
    }
  }

  @override
  Future<Result<List<Bill>>> getBillsPaginated(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final items = await localDataSource.getBills(adminUid, startDate: startDate, endDate: endDate);
      // Apply pagination locally
      final paginated = items.skip(offset).take(limit).toList();
      return Result.success(paginated.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get paginated bills: $e'));
    }
  }

  @override
  Future<Result<List<Bill>>> getOfflineBills(String adminUid) async {
    try {
      final offlineItems = await localDataSource.getOfflineBills(adminUid);
      return Result.success(offlineItems.map((m) => m.toEntity()).toList());
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get offline bills: $e'));
    }
  }

  @override
  Future<Result<SyncResult>> syncOfflineBills(String adminUid) async {
    try {
      final offlineBills = await localDataSource.getOfflineBills(adminUid);
      int syncedCount = 0;
      int failedCount = 0;
      List<String> failedBillIds = [];

      for (final bill in offlineBills) {
        try {
          final billModel = BillModel.fromEntity(bill);
          await remoteDataSource.saveBill(adminUid, billModel);
          await localDataSource.markAsSynced(bill.id);
          syncedCount++;
        } catch (e) {
          failedCount++;
          failedBillIds.add(bill.id);
        }
      }

      return Result.success(
        SyncResult(
          syncedCount: syncedCount,
          failedCount: failedCount,
          failedBillIds: failedBillIds,
        ),
      );
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to sync offline bills: $e'));
    }
  }

  @override
  Future<Result<int>> getOfflineBillsCount(String adminUid) async {
    try {
      final offlineBills = await localDataSource.getOfflineBills(adminUid);
      return Result.success(offlineBills.length);
    } on DatabaseException catch (e) {
      return Result.failure(DatabaseFailure(e.message));
    } catch (e) {
      return Result.failure(DatabaseFailure('Failed to get offline bills count: $e'));
    }
  }

  /// Cache bills locally
  Future<void> _cacheBills(String adminUid, List<BillModel> bills) async {
    for (final bill in bills) {
      await localDataSource.saveBill(adminUid, bill);
    }
  }
}
