import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/kot_model.dart';
import '../constants/api_constants.dart';

class KotService {
  static const String baseUrl = ApiConstants.kot;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<KotModel>> getKots() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final List kotList = data['data'];
      return kotList.map((e) => KotModel.fromJson(e)).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch KOTs');
    }
  }

  Future<KotModel> getLatestKot() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/latest'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return KotModel.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch latest KOT');
    }
  }


  Future<KotModel> updateKotStatus(String id, String status) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({'status': status}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return KotModel.fromJson(data['data'] ?? data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update KOT status');
    }
  }
}
