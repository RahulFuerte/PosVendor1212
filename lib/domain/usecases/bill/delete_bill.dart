// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Delete Bill Use Case
class DeleteBill implements UseCase<void, DeleteBillParams> {
  final BillRepository repository;

  DeleteBill(this.repository);

  @override
  Future<Result<void>> call(DeleteBillParams params) {
    return repository.deleteBill(params.adminUid, params.billId);
  }
}

class DeleteBillParams {
  final String adminUid;
  final String billId;

  const DeleteBillParams({
    required this.adminUid,
    required this.billId,
  });
}
