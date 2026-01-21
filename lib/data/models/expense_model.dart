import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryModel {
  final String id;
  final String name;

  CategoryModel({
    required this.id,
    required this.name,
  });

  factory CategoryModel.fromFirestore(Map<String, dynamic> json, String id) {
    return CategoryModel(
      id: id,
      name: json['name'],
    );
  }
}


class ExpenseModel {
  final String id;
  final String categoryName;
  final int amount;
  final DateTime date;

  ExpenseModel({
    required this.id,
    required this.categoryName,
    required this.amount,
    required this.date,
  });

  factory ExpenseModel.fromFirestore(Map<String, dynamic> json, String id) {
    return ExpenseModel(
      id: id,
      categoryName: json['categoryName'],
      amount: json['amount'],
      date: (json['date'] as Timestamp).toDate(),
    );
  }
}
