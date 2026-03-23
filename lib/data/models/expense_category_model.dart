class ExpenseCategoryModel {
  final String? id;
  final String name;
  final String adminId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseCategoryModel({
    this.id,
    required this.name,
    required this.adminId,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['_id'] as String?,
      name: json['name'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'adminId': adminId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
