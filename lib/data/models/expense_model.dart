class ExpenseModel {
  final String? id;
  final String adminId;
  final String expenseCategoryId;
  final String categoryName; // Flattened from category join for UI display
  final double amount;
  final String? note;
  final DateTime date; // Non-nullable — required for display
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    this.id,
    required this.adminId,
    required this.expenseCategoryId,
    this.categoryName = '',
    required this.amount,
    this.note,
    DateTime? date,
    this.createdAt,
    this.updatedAt,
  }) : date = date ?? DateTime.now();

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['_id'] as String?,
      adminId: json['adminId'] as String? ?? '',
      expenseCategoryId: json['expenseCategoryId'] as String? ?? json['categoryId'] as String? ?? '',
      // support both flat 'categoryName' and nested 'category.name'
      categoryName: json['categoryName'] as String? ??
          (json['category'] is Map ? (json['category'] as Map)['name'] as String? : null) ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'adminId': adminId,
      'expenseCategoryId': expenseCategoryId,
      'categoryName': categoryName,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
