/// Domain entity for a Department / Category of food items.
class Department {
  final String? id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String adminId;
  final String? syncStatus;

  Department({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.adminId = '',
    this.syncStatus,
  });
}
