// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/bill.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Update Bill Use Case
class UpdateBill implements UseCase<void, UpdateBillParams> {
  final BillRepository repository;

  UpdateBill(this.repository);

  @override
  Future<Result<void>> call(UpdateBillParams params) {
    return repository.updateBill(params.adminUid, params.billId, params.bill);
  }
}

class UpdateBillParams {
  final String adminUid;
  final String billId;
  final Bill bill;

  const UpdateBillParams({
    required this.adminUid,
    required this.billId,
    required this.bill,
  });
}
