import 'dart:math'; // Import the 'dart:math' library for the Random class

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

class PrintProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _posts = [];
  double _total = 0;
  bool _isValueTrue = false;
  String _receiptNumber = '';

  // Printer connection state
  bool _isConnected = false;
  BluetoothPrinter? _selectedPrinter;
  PaperSize _selectedPaperSize = PaperSize.mm58;

  List<Map<String, dynamic>> get posts => _posts;
  double get total => _total;
  bool get isValueTrue => _isValueTrue;
  String get receiptNumber => _receiptNumber;
  bool get isConnected => _isConnected;
  BluetoothPrinter? get selectedPrinter => _selectedPrinter;
  PaperSize get selectedPaperSize => _selectedPaperSize;

  void additem(List<Map<String, dynamic>> products, double total) {
    _posts = products;
    _total = total;
    notifyListeners();
  }

  void changeBooleanValue() {
    _isValueTrue = !_isValueTrue;
    notifyListeners();
  }

  int generateRandomReceiptNumber() {
    final random = Random();
    return random.nextInt(99999999 - 10000000 + 1) + 10000000;
  }

  void storeReceiptNumber(String receiptNumber) {
    _receiptNumber = receiptNumber;
    notifyListeners();
  }

  void clearCart() {
    _posts = [];
    _total = 0;
    _receiptNumber = '';
    notifyListeners();
  }

  // Printer connection methods
  void setConnected(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void setSelectedPrinter(BluetoothPrinter? printer) {
    _selectedPrinter = printer;
    notifyListeners();
  }

  void setPaperSize(PaperSize paperSize) {
    _selectedPaperSize = paperSize;
    notifyListeners();
  }

  void disconnectPrinter() {
    _isConnected = false;
    _selectedPrinter = null;
    notifyListeners();
  }
}
