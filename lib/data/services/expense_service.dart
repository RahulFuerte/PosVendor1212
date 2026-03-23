import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../models/expense_category_model.dart';
import '../constants/api_constants.dart';
import 'demo_data.dart';

class ExpenseService {
  static const String expenseBaseUrl = ApiConstants.expenses;
  static const String categoryBaseUrl = ApiConstants.expenseCategories;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // ===============================
  // EXPENSE CATEGORY METHODS
  // ===============================

  Future<ExpenseCategoryModel> createExpenseCategory(String name) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(categoryBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'name': name}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ExpenseCategoryModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create expense category');
    }
  }

  Future<List<ExpenseCategoryModel>> getExpenseCategories() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      return DemoData.expenseCategories;
    }
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(categoryBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ExpenseCategoryModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get expense categories');
    }
  }

  Future<ExpenseCategoryModel> updateExpenseCategory(String id, String name) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$categoryBaseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'name': name}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ExpenseCategoryModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update expense category');
    }
  }

  Future<void> deleteExpenseCategory(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$categoryBaseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete expense category');
    }
  }

  // ===============================
  // EXPENSE METHODS
  // ===============================

  Future<ExpenseModel> addExpense({
    required String expenseCategoryId,
    required double amount,
    String? note,
    DateTime? date,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(expenseBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'expenseCategoryId': expenseCategoryId,
        'amount': amount,
        'note': note,
        'date': date?.toIso8601String(),
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ExpenseModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to add expense');
    }
  }

  Future<List<ExpenseModel>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? expenseCategoryId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      return DemoData.expenses;
    }
    final token = await _getToken();

    String query = '';
    if (startDate != null) query += 'startDate=${startDate.toIso8601String().split('T')[0]}&';
    if (endDate != null) query += 'endDate=${endDate.toIso8601String().split('T')[0]}&';
    if (expenseCategoryId != null) query += 'expenseCategoryId=$expenseCategoryId';

    final response = await http.get(
      Uri.parse('$expenseBaseUrl?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ExpenseModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get expenses');
    }
  }

  Future<ExpenseModel> updateExpense({
    required String id,
    String? expenseCategoryId,
    double? amount,
    String? note,
    DateTime? date,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$expenseBaseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        if (expenseCategoryId != null) 'expenseCategoryId': expenseCategoryId,
        if (amount != null) 'amount': amount,
        if (note != null) 'note': note,
        if (date != null) 'date': date.toIso8601String(),
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ExpenseModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update expense');
    }
  }

  Future<void> deleteExpense(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$expenseBaseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete expense');
    }
  }
}
