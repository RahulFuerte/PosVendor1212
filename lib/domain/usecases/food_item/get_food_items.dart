// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/food_item.dart';
import 'package:pos/domain/repositories/food_item_repository.dart';

/// Get Food Items Use Case
class GetFoodItems implements UseCase<List<FoodItem>, GetFoodItemsParams> {
  final FoodItemRepository repository;

  GetFoodItems(this.repository);

  @override
  Future<Result<List<FoodItem>>> call(GetFoodItemsParams params) {
    return repository.getFoodItems(params.adminUid, department: params.department);
  }
}

class GetFoodItemsParams {
  final String adminUid;
  final String? department;

  const GetFoodItemsParams({
    required this.adminUid,
    this.department,
  });
}
