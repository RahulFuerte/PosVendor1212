// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/bill.dart';
import 'package:pos/domain/repositories/bill_repository.dart';

/// Get Bills Use Case
class GetBills implements UseCase<List<Bill>, GetBillsParams> {
  final BillRepository repository;

  GetBills(this.repository);

  @override
  Future<Result<List<Bill>>> call(GetBillsParams params) {
    return repository.getBills(
      params.adminUid,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

class GetBillsParams {
  final String adminUid;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetBillsParams({
    required this.adminUid,
    this.startDate,
    this.endDate,
  });
}
