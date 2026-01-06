// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/bill.dart';

/// Bill Repository Interface (Domain Layer)
abstract class BillRepository {
  /// Get all bills for an admin
  Future<Result<List<Bill>>> getBills(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
  });
  
  /// Get a single bill by ID
  Future<Result<Bill?>> getBill(String adminUid, String billId);
  
  /// Save a new bill
  Future<Result<void>> saveBill(String adminUid, Bill bill);
  
  /// Update an existing bill
  Future<Result<void>> updateBill(String adminUid, String billId, Bill bill);
  
  /// Delete a bill
  Future<Result<void>> deleteBill(String adminUid, String billId);
  
  /// Get bills with pagination
  Future<Result<List<Bill>>> getBillsPaginated(
    String adminUid, {
    DateTime? startDate,
    DateTime? endDate,
    int offset = 0,
    int limit = 20,
  });
  
  /// Get offline/pending bills
  Future<Result<List<Bill>>> getOfflineBills(String adminUid);
  
  /// Get count of offline bills
  Future<Result<int>> getOfflineBillsCount(String adminUid);
  
  /// Sync offline bills to server
  Future<Result<SyncResult>> syncOfflineBills(String adminUid);
}

/// Sync result for bill synchronization
class SyncResult {
  final int syncedCount;
  final int failedCount;
  final List<String> failedBillIds;
  final String? errorMessage;

  const SyncResult({
    required this.syncedCount,
    required this.failedCount,
    this.failedBillIds = const [],
    this.errorMessage,
  });

  bool get isSuccess => failedCount == 0;
}
