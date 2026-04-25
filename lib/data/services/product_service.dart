import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../constants/api_constants.dart';
import 'demo_data.dart';

class ProductService {
  static const String baseUrl = ApiConstants.products;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<ProductModel> createProduct({
    required String name,
    required double price,
    String? description,
    required String categoryId,
    bool? isVeg,
    String? imageUrl,
    String? image_url, // Backend fallback
    List<dynamic>? addons,
    String? baseVariant,
    String? department,
    String? foodCode,
    String? imagePath,
    bool? isHot,
    double? price2,
    double? price3,
    String? priceType,
    int? stocks,
    String? tax,
    String? uid,
    List<dynamic>? variants,
  }) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'name': name,
        'price': price,
        'description': description ?? "",
        'categoryId': categoryId,
        'isVeg': isVeg ?? false,
        'imageUrl': imageUrl ?? "",
        'image_url': image_url ?? imageUrl ?? "",
        'addons': addons ?? [],
        'baseVariant': baseVariant ?? "",
        'department': department ?? "",
        'foodCode': foodCode ?? "",
        'imagePath': imagePath ?? imageUrl ?? "",
        'isHot': isHot ?? false,
        'price2': price2 ?? 0.0,
        'price3': price3 ?? 0.0,
        'priceType': priceType ?? "Fixed",
        'stocks': stocks ?? 0,
        'tax': tax ?? "",
        'uid': uid ?? "",
        'variants': variants ?? [],
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return ProductModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create product');
    }
  }

  Future<List<ProductModel>> getProducts({String? categoryId, String? foodCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final isDemoMode = prefs.getBool('isDemoMode') ?? false;

    if (isDemoMode) {
      return DemoData.products;
    }

    final token = await _getToken();

    final List<String> queryParams = [];
    if (categoryId != null) queryParams.add('categoryId=$categoryId');
    if (foodCode != null) queryParams.add('foodCode=$foodCode');

    final String queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

    final response = await http.get(
      Uri.parse('$baseUrl$queryString'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get products');
    }
  }

  Future<List<ProductModel>> getPublicProducts(String adminId, {String? categoryId}) async {
    String query = 'adminId=$adminId';
    if (categoryId != null) query += '&categoryId=$categoryId';

    final response = await http.get(
      Uri.parse('$baseUrl/public?$query'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ProductModel.fromJson(e)).toList();
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to get public products');
    }
  }

  Future<ProductModel> updateProduct(String id, Map<String, dynamic> updates) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode(updates),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return ProductModel.fromJson(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteProduct(String id) async {
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
      throw Exception(data['message'] ?? 'Failed to delete product');
    }
  }
}
