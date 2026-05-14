import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class CloudinaryService {
  /// Uploads an image to Cloudinary using standard HTTP Multipart request.
  /// No external Cloudinary-specific dependencies required.
  Future<String?> uploadImage(File file, String folder) async {
    try {
      debugPrint('Cloudinary: Starting multipart upload of ${file.path} to folder: $folder');

      final url = Uri.parse('https://api.cloudinary.com/v1_1/${ApiConstants.cloudinaryCloudName}/image/upload');

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = ApiConstants.cloudinaryUploadPreset
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData);
        final secureUrl = jsonResponse['secure_url'];
        debugPrint('Cloudinary: Upload successful. URL: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Cloudinary: Upload failed with status ${response.statusCode}: $responseData');
        throw Exception('Cloudinary Upload Failed: $responseData');
      }
    } catch (e) {
      debugPrint('Error uploading image to Cloudinary: $e');
      throw Exception('Cloudinary Error: $e');
    }
  }

  /// Deletes an image (Ignored on client-side for security as it requires API Secret).
  Future<void> deleteImage(String imageUrl) async {
    debugPrint('Cloudinary: Delete requested for $imageUrl (ignored on client-side)');
  }
}
