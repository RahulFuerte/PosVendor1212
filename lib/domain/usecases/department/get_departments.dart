// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/department.dart';
import 'package:pos/domain/repositories/department_repository.dart';

/// Get Departments Use Case
class GetDepartments implements UseCase<List<Department>, GetDepartmentsParams> {
  final DepartmentRepository repository;

  GetDepartments(this.repository);

  @override
  Future<Result<List<Department>>> call(GetDepartmentsParams params) {
    return repository.getDepartments(params.adminUid);
  }
}

class GetDepartmentsParams {
  final String adminUid;

  const GetDepartmentsParams({required this.adminUid});
}
