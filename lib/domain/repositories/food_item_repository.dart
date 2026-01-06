// Project imports:
import 'package:pos/core/usecases/usecase.dart';
import 'package:pos/domain/entities/food_item.dart';

/// Food Item Repository Interface (Domain Layer)
/// Defines the contract for data operations - implementation is in data layer
abstract class FoodItemRepository {
  /// Get all food items for an admin
  Future<Result<List<FoodItem>>> getFoodItems(String adminUid, {String? department});
  
  /// Get a single food item by ID
  Future<Result<FoodItem?>> getFoodItem(String adminUid, String itemId);
  
  /// Save a new food item
  Future<Result<void>> saveFoodItem(String adminUid, FoodItem foodItem);
  
  /// Update an existing food item
  Future<Result<void>> updateFoodItem(String adminUid, String itemId, FoodItem foodItem);
  
  /// Delete a food item
  Future<Result<void>> deleteFoodItem(String adminUid, String itemId);
  
  /// Search food items
  Future<Result<List<FoodItem>>> searchFoodItems(
    String adminUid,
    String query, {
    String? department,
    int limit = 20,
  });
  
  /// Get food items with pagination
  Future<Result<List<FoodItem>>> getFoodItemsPaginated(
    String adminUid, {
    String? department,
    int offset = 0,
    int limit = 20,
  });
  
  /// Get total count of food items
  Future<Result<int>> getFoodItemsCount(String adminUid, {String? department});
}
