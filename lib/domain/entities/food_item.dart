/// Domain entity for a Food Item (menu item / product).
class FoodItem {
  final String? id;
  final String name;
  final double price;
  final String? category;
  final String? imageUrl;
  final String? description;
  final bool isAvailable;
  final int stock;
  final String adminId;
  final String? syncStatus;

  FoodItem({
    this.id,
    required this.name,
    this.price = 0.0,
    this.category,
    this.imageUrl,
    this.description,
    this.isAvailable = true,
    this.stock = 0,
    this.adminId = '',
    this.syncStatus,
  });
}
