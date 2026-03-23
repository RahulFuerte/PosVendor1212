import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../constants/api_constants.dart';
import 'demo_data.dart';

class CategoryService {
  static const String baseUrl = ApiConstants.categories;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<CategoryModel> createCategory(String name, String? imageUrl) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'name': name,
        'imageUrl': imageUrl ?? "",
        'image_url': imageUrl ?? "", // Backend fallback
        'imagePath': imageUrl ?? "", // Backend fallback
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return CategoryModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create category');
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final isDemoMode = prefs.getBool('isDemoMode') ?? false;

    if (isDemoMode) {
      return DemoData.categories;
    }

    final token = await _getToken();
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CategoryModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get categories');
    }
  }

  Future<CategoryModel> updateCategory(String id, String name, String? imageUrl) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'name': name,
        'imageUrl': imageUrl ?? "",
        'image_url': imageUrl ?? "", // Backend fallback
        'imagePath': imageUrl ?? "", // Backend fallback
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return CategoryModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update category');
    }
  }

  Future<void> deleteCategory(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete category');
    }
  }
}
