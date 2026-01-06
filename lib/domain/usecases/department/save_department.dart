// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/department.dart';
import 'package:pos/domain/repositories/department_repository.dart';

/// Save Department Use Case
class SaveDepartment implements UseCase<void, SaveDepartmentParams> {
  final DepartmentRepository repository;

  SaveDepartment(this.repository);

  @override
  Future<Result<void>> call(SaveDepartmentParams params) {
    return repository.saveDepartment(params.adminUid, params.department);
  }
}

class SaveDepartmentParams {
  final String adminUid;
  final Department department;

  const SaveDepartmentParams({
    required this.adminUid,
    required this.department,
  });
}
