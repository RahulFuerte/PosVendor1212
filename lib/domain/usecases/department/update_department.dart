// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/department.dart';
import 'package:pos/domain/repositories/department_repository.dart';

/// Update Department Use Case
class UpdateDepartment implements UseCase<void, UpdateDepartmentParams> {
  final DepartmentRepository repository;

  UpdateDepartment(this.repository);

  @override
  Future<Result<void>> call(UpdateDepartmentParams params) {
    return repository.updateDepartment(params.adminUid, params.departmentId, params.department);
  }
}

class UpdateDepartmentParams {
  final String adminUid;
  final String departmentId;
  final Department department;

  const UpdateDepartmentParams({
    required this.adminUid,
    required this.departmentId,
    required this.department,
  });
}
