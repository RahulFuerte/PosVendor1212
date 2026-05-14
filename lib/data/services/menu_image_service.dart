import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class MenuImageService {
  static const String uploadUrl = ApiConstants.menuUpload;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> uploadMenuImage(File imageFile) async {
    try {
      final token = await _getToken();

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Pass Token in Header
      request.headers.addAll({
        'Authorization': token ?? "",
      });

      // Pass Image as Key and attach Image
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Failed to upload image: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
