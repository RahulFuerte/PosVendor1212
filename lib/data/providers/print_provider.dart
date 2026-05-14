// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

class PrintProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _posts = [];
  double _total = 0;
  bool _isValueTrue = false;
  String _receiptNumber = '';
  bool isEditBill = false;
  String? editingReceiptNo;
  String? _customerId;
  String? _customerName;
  String? _customerPhone;
  String? _customerGst;
  String? _customerAddress;
  String? _customerNote;
  bool _isCartExpanded = false;

  // Printer connection state
  bool _isConnected = false;
  BluetoothPrinter? _selectedPrinter;
  PaperSize _selectedPaperSize = PaperSize.mm58;

  // Tax settings
  bool _taxEnabled = false;
  double _cgstPercent = 2.5;
  double _sgstPercent = 2.5;

  List<Map<String, dynamic>> get posts => _posts;
  double get total => _total;
  bool get isValueTrue => _isValueTrue;
  String get receiptNumber => _receiptNumber;
  bool get isConnected => _isConnected;
  BluetoothPrinter? get selectedPrinter => _selectedPrinter;
  PaperSize get selectedPaperSize => _selectedPaperSize;

  // Tax getters
  bool get taxEnabled => _taxEnabled;
  double get cgstPercent => _cgstPercent;
  double get sgstPercent => _sgstPercent;
  String? get customerId => _customerId;
  String? get customerName => _customerName;
  String? get customerPhone => _customerPhone;
  String? get customerGst => _customerGst;
  String? get customerAddress => _customerAddress;
  String? get customerNote => _customerNote;
  bool get isCartExpanded => _isCartExpanded;

  PrintProvider() {
    _loadTaxSettings();
  }

  Future<void> _loadTaxSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _taxEnabled = prefs.getBool('taxEnabled') ?? false;
      _cgstPercent = prefs.getDouble('cgstPercent') ?? 2.5;
      _sgstPercent = prefs.getDouble('sgstPercent') ?? 2.5;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tax settings: $e');
    }
  }

  Future<void> setTaxEnabled(bool enabled) async {
    _taxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('taxEnabled', enabled);
    notifyListeners();
  }

  Future<void> setTaxRates(double cgst, double sgst) async {
    _cgstPercent = cgst;
    _sgstPercent = sgst;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('cgstPercent', cgst);
    await prefs.setDouble('sgstPercent', sgst);
    notifyListeners();
  }

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

  void setCart(
    List<Map<String, dynamic>> oldItems,
    double oldTotal, {
    String? receiptNo,
    bool isEdit = false,
  }) {
    _posts = List<Map<String, dynamic>>.from(oldItems);
    _total = oldTotal;
    isEditBill = isEdit;
    editingReceiptNo = receiptNo;
    notifyListeners();
  }

  void clearCart() {
    _posts = [];
    _total = 0;
    _receiptNumber = '';
    _customerId = null;
    _customerName = null;
    _customerPhone = null;
    _customerGst = null;
    _customerAddress = null;
    _customerNote = null;
    notifyListeners();
  }

  void setCustomerDetails({
    String? id,
    String? name,
    String? phone,
    String? gst,
    String? address,
    String? note,
  }) {
    _customerId = id;
    _customerName = name;
    _customerPhone = phone;
    _customerGst = gst;
    _customerAddress = address;
    _customerNote = note;
    notifyListeners();
  }

  void setCartExpanded(bool expanded) {
    _isCartExpanded = expanded;
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

  void reset() {
    _posts = [];
    _total = 0;
    _isValueTrue = false;
    _receiptNumber = '';
    isEditBill = false;
    editingReceiptNo = null;
    _customerId = null;
    _customerName = null;
    _customerPhone = null;
    _customerGst = null;
    _customerAddress = null;
    _customerNote = null;
    _isConnected = false;
    _selectedPrinter = null;
    notifyListeners();
  }
}
