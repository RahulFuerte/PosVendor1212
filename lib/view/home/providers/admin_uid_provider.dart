// Flutter imports:
import 'package:flutter/material.dart';

class AdminUidProvider extends ChangeNotifier {
  String adminUidValue = '';

 

  String get updateVehicleTypeValue => adminUidValue;



  void SetAdminUid(String newText) {
    adminUidValue = newText;
    notifyListeners();
  }
    void resetAdminUid() {
    adminUidValue = '';
    notifyListeners();
  }
}
