import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'demo_data.dart';

class ReportService {
  static const String baseUrl = ApiConstants.reports;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<Map<String, dynamic>> getSalesReport({DateTime? date, int? limit}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      return DemoData.salesReport;
    }
    final token = await _getToken();
    String query = '';
    if (date != null) query += 'date=${date.toIso8601String().split('T')[0]}&';
    if (limit != null) query += 'limit=$limit';

    final response = await http.get(
      Uri.parse('$baseUrl/sales?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get sales report');
    }
  }

  Future<List<dynamic>> getDateWiseReport({DateTime? startDate, DateTime? endDate}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      return DemoData.dateWiseReport;
    }
    final token = await _getToken();
    String query = '';
    if (startDate != null) query += 'startDate=${startDate.toIso8601String().split('T')[0]}&';
    if (endDate != null) query += 'endDate=${endDate.toIso8601String().split('T')[0]}';

    final response = await http.get(
      Uri.parse('$baseUrl/date-wise?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['report'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get date-wise report');
    }
  }

  Future<List<dynamic>> getBillWiseReport({DateTime? startDate, DateTime? endDate}) async {
    final token = await _getToken();
    String query = '';
    if (startDate != null) query += 'startDate=${startDate.toIso8601String().split('T')[0]}&';
    if (endDate != null) query += 'endDate=${endDate.toIso8601String().split('T')[0]}';

    final response = await http.get(
      Uri.parse('$baseUrl/bill-wise?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['report'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get bill-wise report');
    }
  }

  Future<List<dynamic>> getItemWiseReport({DateTime? startDate, DateTime? endDate}) async {
    final token = await _getToken();
    String query = '';
    if (startDate != null) query += 'startDate=${startDate.toIso8601String().split('T')[0]}&';
    if (endDate != null) query += 'endDate=${endDate.toIso8601String().split('T')[0]}';

    final response = await http.get(
      Uri.parse('$baseUrl/item-wise?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['report'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get item-wise report');
    }
  }

  Future<Map<String, dynamic>> getCustomerWiseReport({
    required String customerId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    String query = 'customerId=$customerId&';
    if (startDate != null) query += 'startDate=${startDate.toIso8601String().split('T')[0]}&';
    if (endDate != null) query += 'endDate=${endDate.toIso8601String().split('T')[0]}';

    final response = await http.get(
      Uri.parse('$baseUrl/customer-wise?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to get customer-wise report');
    }
  }

  Future<Map<String, dynamic>> getDashboardReport({DateTime? date, String? orderType}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isDemoMode') ?? false) {
      return DemoData.dashboardReport;
    }
    final token = await _getToken();
    String query = '';
    if (date != null) query += 'date=${date.toIso8601String().split('T')[0]}&';
    if (orderType != null) query += 'orderType=$orderType';

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard?$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token ?? "",
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get dashboard report');
    }
  }
}
