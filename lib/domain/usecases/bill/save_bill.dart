// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/bill.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Save Bill Use Case
class SaveBill implements UseCase<void, SaveBillParams> {
  final BillRepository repository;

  SaveBill(this.repository);

  @override
  Future<Result<void>> call(SaveBillParams params) {
    return repository.saveBill(params.adminUid, params.bill);
  }
}

class SaveBillParams {
  final String adminUid;
  final Bill bill;

  const SaveBillParams({
    required this.adminUid,
    required this.bill,
  });
}
