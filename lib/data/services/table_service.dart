import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_model.dart';
import '../constants/api_constants.dart';

class TableService {
  static const String baseUrl = ApiConstants.tables;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<List<TableModel>> getTables() async {
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
      final List tablesList = data['data'];
      return tablesList.map((e) => TableModel.fromMap({
        ...e,
        'id': e['_id'],
        'tableNumber': e['tableNumber'],
        'isOccupied': e['status'] == 'Occupied' ? 1 : 0,
        'items': e['items'],
        'subtotal': e['subtotal'],
        'customerName': e['customerName'],
        'customerPhone': e['customerPhone'],
        'currentOrderId': e['currentOrderId'],
      })).toList();
    } else {
      throw Exception(data['message'] ?? 'Failed to get tables');
    }
  }

  Future<TableModel> addTable(String tableNumber, {int? capacity}) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'tableNumber': tableNumber,
        'capacity': capacity ?? 4,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      final e = data['data'];
      return TableModel.fromMap({
        ...e,
        'id': e['_id'],
        'tableNumber': e['tableNumber'],
        'isOccupied': e['status'] == 'Occupied' ? 1 : 0,
      });
    } else {
      throw Exception(data['message'] ?? 'Failed to add table');
    }
  }

  Future<TableModel> updateTableStatus(
    String id,
    String status, {
    List<Map<String, dynamic>>? items,
    double? subtotal,
    String? customerName,
    String? customerPhone,
    String? currentOrderId,
    bool createKot = true,
  }) async {
    final token = await _getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/$id/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
      body: jsonEncode({
        'status': status,
        if (items != null) 'items': items,
        if (subtotal != null) 'subtotal': subtotal,
        if (customerName != null) 'customerName': customerName,
        if (customerPhone != null) 'customerPhone': customerPhone,
        if (currentOrderId != null) 'currentOrderId': currentOrderId,
        'createKot': createKot,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      final e = data['data'];
      return TableModel.fromMap({
        ...e,
        'id': e['_id'],
        'tableNumber': e['tableNumber'],
        'isOccupied': e['status'] == 'Occupied' ? 1 : 0,
        'items': e['items'],
        'subtotal': e['subtotal'],
        'customerName': e['customerName'],
        'customerPhone': e['customerPhone'],
      });
    } else {
      throw Exception(data['message'] ?? 'Failed to update table');
    }
  }

  Future<void> deleteTable(String id) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete table');
    }
  }
}
