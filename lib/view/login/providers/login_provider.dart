// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginProvider extends ChangeNotifier {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  // final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  List<TextEditingController> controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool get _isAdmin => isAdmin;
  bool _isProcessing = false,
      _isVerified = false,
      _isVerifying = false,
      isAdmin = false;
  FocusNode lastFocusNode = FocusNode(), firstFocusNode = FocusNode();
  String? _verificationID, _phone, _smsCode = "", _employerName;

  init() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    try {
      isAdmin = sp.getBool("isAdmin") ?? false;
    } catch (e) {
      isAdmin = false;
    }
  }

  reset() {
    controllers = List.generate(6, (index) => TextEditingController());
    _verificationID = "";
    _phone = "";
    _smsCode = "";
    _employerName = "";
    _phone = "";
    isAdmin = false;
    _isProcessing = false;
    _isVerified = false;
    _isVerifying = false;
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

  toggleVerifying() {
    _isVerifying = !_isVerifying;
  }

  String get verificationID => _verificationID ?? '';
  String get smsCode => _smsCode ?? '';
  String get phone => _phone ?? '';
  String get employerName => _employerName ?? '';
  bool get isProcessing => _isProcessing;
  bool get isVerified => _isVerified;
  bool get isVerifying => _isVerifying;

  set setSmsCode(String value) {
    _smsCode = value;
    for (int i = 0; i < value.length; i++) {
      controllers[i].text = value[i];
    }
    lastFocusNode.requestFocus();
    notifyListeners();
  }

  set setSmsCodeManually(String value) {
    _smsCode = value;
    notifyListeners();
  }

  set setVerificationID(String value) {
    _verificationID = value;
    notifyListeners();
  }

  set setPhone(String value) {
    _phone = value;
    notifyListeners();
  }

  set setVerificationStatus(bool value) {
    _isVerified = value;
    notifyListeners();
  }

  set setEmployerName(String value) {
    _employerName = value;
    notifyListeners();
  }

  Future getDataFromFirestore(String phoneNumber) async {
    print("testing uid ");
    print(phoneNumber); // Use the phoneNumber parameter
    await _firebaseFirestore
        .collection("AllUsers")
        .doc(phoneNumber)
        .get()
        .then((DocumentSnapshot snapshot) {
      _employerName = snapshot['name'];
      _phone = snapshot['phone'];

      notifyListeners();
    });

    print(_employerName);
    print(_phone);
  }
}
