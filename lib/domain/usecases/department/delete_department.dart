// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/repositories/department_repository.dart';

/// Delete Department Use Case
class DeleteDepartment implements UseCase<void, DeleteDepartmentParams> {
  final DepartmentRepository repository;

  DeleteDepartment(this.repository);

  @override
  Future<Result<void>> call(DeleteDepartmentParams params) {
    return repository.deleteDepartment(params.adminUid, params.departmentId);
  }
}

class DeleteDepartmentParams {
  final String adminUid;
  final String departmentId;

  const DeleteDepartmentParams({
    required this.adminUid,
    required this.departmentId,
  });
}
