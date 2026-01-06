// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Sync Offline Bills Use Case
class SyncOfflineBills implements UseCase<SyncResult, SyncOfflineBillsParams> {
  final BillRepository repository;

  SyncOfflineBills(this.repository);

  @override
  Future<Result<SyncResult>> call(SyncOfflineBillsParams params) {
    return repository.syncOfflineBills(params.adminUid);
  }
}

class SyncOfflineBillsParams {
  final String adminUid;

  const SyncOfflineBillsParams({required this.adminUid});
}
