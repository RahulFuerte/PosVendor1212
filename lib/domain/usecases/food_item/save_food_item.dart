// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/food_item.dart';
import 'package:pos/domain/repositories/food_item_repository.dart';

/// Save Food Item Use Case
class SaveFoodItem implements UseCase<void, SaveFoodItemParams> {
  final FoodItemRepository repository;

  SaveFoodItem(this.repository);

  @override
  Future<Result<void>> call(SaveFoodItemParams params) {
    return repository.saveFoodItem(params.adminUid, params.foodItem);
  }
}

class SaveFoodItemParams {
  final String adminUid;
  final FoodItem foodItem;

  const SaveFoodItemParams({
    required this.adminUid,
    required this.foodItem,
  });
}
