import 'package:flutter/material.dart';

class BarcodeProvider with ChangeNotifier {
  bool _isProcessing = false;
  bool _isFlashOn = false;
  bool _isBackCamera = true;

  bool get isProcessing => _isProcessing;
  bool get isFlashOn => _isFlashOn;
  bool get isBackCamera => _isBackCamera;

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void toggleFlash() {
    _isFlashOn = !_isFlashOn;
    notifyListeners();
  }

  void toggleCamera() {
    _isBackCamera = !_isBackCamera;
    notifyListeners();
  }

  void reset() {
    _isProcessing = false;
    _isFlashOn = false;
    _isBackCamera = true;
    notifyListeners();
  }
}
