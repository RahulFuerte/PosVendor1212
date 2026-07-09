import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/constants/api_constants.dart';
import 'package:pos/data/models/whatsapp_template_model.dart';

class WhatsappTemplateService {
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'Authorization': token ?? '',
  };

  Future<List<WhatsappTemplateModel>> getAll() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(ApiConstants.whatsappTemplates),
      headers: _headers(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return (data['data'] as List)
          .map((e) => WhatsappTemplateModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(data['message'] ?? 'Failed to load templates');
  }

  Future<WhatsappTemplateModel> create(String name, String message, {bool isDefault = false}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(ApiConstants.whatsappTemplates),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'message': message, 'isDefault': isDefault}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return WhatsappTemplateModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Failed to create template');
  }

  Future<WhatsappTemplateModel> update(
    String id,
    String name,
    String message, {
    bool isDefault = false,
  }) async {
    final token = await _getToken();
    final response = await http.put(
      Uri.parse('${ApiConstants.whatsappTemplates}/$id'),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'message': message, 'isDefault': isDefault}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return WhatsappTemplateModel.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Failed to update template');
  }

  Future<void> delete(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('${ApiConstants.whatsappTemplates}/$id'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Failed to delete template');
    }
  }
}
