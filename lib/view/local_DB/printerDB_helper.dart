// Package imports:
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

class PrinterDatabaseHelper {
  static final PrinterDatabaseHelper instance = PrinterDatabaseHelper._init();
  static Database? _database;

  PrinterDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('printer.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE printer_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_name TEXT,
        address TEXT,
        is_ble INTEGER,
        vendor_id INTEGER,
        product_id INTEGER,
        printer_type TEXT,
        paper_size TEXT,
        is_connected INTEGER,
        created_at TEXT
      )
    ''');
  }

  // Save printer configuration
  Future<int> savePrinterConfig({
    required String? deviceName,
    required String? address,
    required bool isBle,
    required String? vendorId,
    required String? productId,
    required PrinterType printerType,
    required PaperSize paperSize,
    required bool isConnected,
  }) async {
    final db = await database;

    // Delete any existing config (we only want one printer saved)
    await db.delete('printer_config');

    // Insert new config
    final data = {
      'device_name': deviceName,
      'address': address,
      'is_ble': isBle ? 1 : 0,
      'vendor_id': vendorId,
      'product_id': productId,
      'printer_type': printerType.toString(),
      'paper_size': paperSize.toString(),
      'is_connected': isConnected ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    return await db.insert('printer_config', data);
  }

  // Get saved printer configuration
  Future<Map<String, dynamic>?> getSavedPrinterConfig() async {
    final db = await database;
    final results = await db.query(
      'printer_config',
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Update connection status
  Future<int> updateConnectionStatus(bool isConnected) async {
    final db = await database;
    return await db.update(
      'printer_config',
      {'is_connected': isConnected ? 1 : 0},
    );
  }

  // Delete printer configuration
  Future<int> deletePrinterConfig() async {
    final db = await database;
    return await db.delete('printer_config');
  }

  // Convert saved data to BluetoothPrinter object
  BluetoothPrinter? mapToPrinter(Map<String, dynamic>? data) {
    if (data == null) return null;

    return BluetoothPrinter(
      deviceName: data['device_name'] as String?,
      address: data['address'] as String?,
      isBle: (data['is_ble'] as int) == 1,
      vendorId: data['vendor_id'],
      productId: data['product_id'],
      typePrinter: _stringToPrinterType(data['printer_type'] as String),
    );
  }

  // Convert saved data to PaperSize
  PaperSize mapToPaperSize(Map<String, dynamic>? data) {
    if (data == null) return PaperSize.mm58;

    final paperSizeStr = data['paper_size'] as String;
    return paperSizeStr.contains('mm80') ? PaperSize.mm80 : PaperSize.mm58;
  }

  // Helper to convert string to PrinterType
  PrinterType _stringToPrinterType(String type) {
    if (type.contains('bluetooth')) return PrinterType.bluetooth;
    if (type.contains('usb')) return PrinterType.usb;
    if (type.contains('network')) return PrinterType.network;
    return PrinterType.bluetooth;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
