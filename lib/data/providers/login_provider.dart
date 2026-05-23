// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:pos/data/services/user_service.dart';

class LoginProvider extends ChangeNotifier {
  // Removed: FirebaseFirestore dependency

  final bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool get _isAdmin => isAdmin;
  bool _isProcessing = false, isAdmin = false;
  String? _phone, _smsCode = "", _employerName;

  init() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    try {
      isAdmin = sp.getBool("isAdmin") ?? false;
    } catch (e) {
      isAdmin = false;
    }
  }

  reset() {
    _phone = "";
    _smsCode = "";
    _employerName = "";
    isAdmin = false;
    _isProcessing = false;
    notifyListeners();
  }

  startProcessing() {
    _isProcessing = true;
    notifyListeners();
  }

  endProcessing() {
    _isProcessing = false;
    notifyListeners();
  }

  String get smsCode => _smsCode ?? '';
  String get phone => _phone ?? '';
  String get employerName => _employerName ?? '';
  bool get isProcessing => _isProcessing;

  set setSmsCodeManually(String value) {
    _smsCode = value;
    notifyListeners();
  }

  set setPhone(String value) {
    _phone = value;
    notifyListeners();
  }

  set setEmployerName(String value) {
    _employerName = value;
    notifyListeners();
  }

  /// Fetch user data from Node.js API instead of Firestore
  Future<void> getDataFromApi(String phoneNumber) async {
    try {
      final data = await UserService().getUserByPhone(phoneNumber);
      if (data != null) {
        _employerName = data['name'] as String?;
        _phone = data['phoneNumber'] as String? ?? data['phone'] as String? ?? phoneNumber;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('getDataFromApi error: $e');
    }
  }

  // Keep old name as alias for backward compatibility
  Future<void> getDataFromFirestore(String phoneNumber) => getDataFromApi(phoneNumber);
}
