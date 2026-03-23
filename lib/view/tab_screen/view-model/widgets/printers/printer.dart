import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:image/image.dart' as img_lib;
import 'package:http/http.dart' as http;
import 'package:pos/data/services/order_service.dart';

import '../../../../../core/network/connection_monitor.dart';
import '../../../../../data/datasources/offline_bill_manager.dart';

class DirectPrintHelper {
  // Generate 8-digit random receipt number

  static String generateReceiptNumber() {
    final random = Random();
    return (10000000 + random.nextInt(90000000)).toString();
  }

  final SmartDatabaseService _databaseService = SmartDatabaseService();
  static Future<List<int>> loadLogoOfflineSafe(
    String logoUrl,
    Generator generator,
  ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();

      // 🔥 URL-based filename
      final fileName = 'printer_logo_${logoUrl.hashCode}.png';
      final file = File('${dir.path}/$fileName');

      img_lib.Image? image;

      // ✅ Offline-first
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        image = img_lib.decodeImage(bytes);
      }

      // 🌐 Download only if missing
      if (image == null && logoUrl.isNotEmpty) {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes);
          image = img_lib.decodeImage(response.bodyBytes);
        }
      }

      if (image == null) return [];

      // Ensure width is a multiple of 8 for best thermal printer compatibility
      const targetWidth = 200;
      final int normalizedWidth = (targetWidth / 8).round() * 8;

      final resized = img_lib.copyResize(image, width: normalizedWidth);
      final mono = img_lib.grayscale(resized);

      return generator.imageRaster(mono, align: PosAlign.center);
    } catch (e) {
      debugPrint("Logo load failed: $e");
      return [];
    }
  }

  Future<void> printReceipt({
    required BuildContext context,
    required BluetoothPrinter printer,
    required PaperSize paperSize,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required String shopName,
    required String logoUrl,
    required String contact,
    required String address,
    required String adminUid,
    required String upiId,
    String? tableNumber,
    String? receiptNo,
    bool taxEnabled = false,
    double cgstPercent = 0.0,
    double sgstPercent = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerGst,
    String? customerAddress,
    String? customerNote,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    String? paymentType,
    String? orderType,
    String? customerId,
    bool saveBill = false,
  }) async {
    try {
      // Use provided receipt number or generate a new one
      final String finalReceiptNo = receiptNo ?? generateReceiptNumber();

      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final Generator generator = Generator(paperSize, profile);

      List<int> bytes = [];
      bytes += generator.setGlobalCodeTable('CP1252');

      List<String> splitTextByLength(String text, int maxLength) {
        List<String> lines = [];
        while (text.length > maxLength) {
          lines.add(text.substring(0, maxLength));
          text = text.substring(maxLength);
        }
        if (text.isNotEmpty) {
          lines.add(text);
        }
        return lines;
      }

      // Paper configuration
      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 32 : 48;
      String separator = '-' * totalCols;
      int totalQty = 0;
      double addonsTotal = 0;

      // Smart dynamic columns
      int desc = is58mm ? 13 : 22;
      int qty = is58mm ? 4 : 6;
      int rate = is58mm ? 6 : 8;
      int amt = is58mm ? 7 : 10;

      // Small font style
      const smallFontCenter = PosStyles(align: PosAlign.center);
      const smallFontLeft = PosStyles(align: PosAlign.left);
      final qrSize = is58mm ? QRSize.size2 : QRSize.size4;

      // Header

      if (logoUrl.isNotEmpty) {
        // final logoBytes = await _loadLogoForPrinter(logoUrl, generator);
        final logoBytes = await loadLogoOfflineSafe(logoUrl, generator);

        bytes += logoBytes;
        bytes += generator.feed(is58mm ? 2 : 0);
      }
      bytes += generator.feed(1);
      bytes += generator.text(shopName, styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.text(address, styles: smallFontCenter);
      bytes += generator.text("Mob.No : $contact", styles: smallFontCenter);
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        "Date : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}",
        styles: smallFontLeft,
      );
      bytes += generator.text(
        "Time : ${DateFormat('hh:mm a').format(DateTime.now())}",
        styles: smallFontLeft,
      );
      bytes += generator.text(
        "Receipt No : $finalReceiptNo",
        styles: smallFontLeft,
      );

      // // Table number (show N/A if not provided)
      if (tableNumber != null && tableNumber.isNotEmpty) {
        bytes += generator.text(
          'Table No: $tableNumber ',
          styles: smallFontLeft,
        );
      }
      if (customerName != null && customerName.isNotEmpty) bytes += generator.text(separator, styles: smallFontLeft);
      if (customerName != null && customerName.isNotEmpty) {
        bytes += generator.text(
          "Name :  $customerName",
          styles: smallFontLeft,
        );
      }

      if (customerPhone != null && customerPhone.isNotEmpty) {
        bytes += generator.text(
          "Phone : $customerPhone",
          styles: smallFontLeft,
        );
      }

      bytes += generator.text(separator, styles: smallFontLeft);

      // Table header
      bytes += generator.text(
        '${"Item".padRight(desc)}'
        '${"Qty".padLeft(qty)}'
        '${"Price".padLeft(rate)}'
        '${"Amt".padLeft(amt)}',
        styles: smallFontLeft,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      String fmt(num v) {
        if (v % 1 == 0) return v.toInt().toString();
        return v.toStringAsFixed(2);
      }

      // Items
      for (var item in items) {
        String name = item['name'].toString();
        List<String> nameLines = splitTextByLength(name, desc);

        int qtyValue = int.tryParse(item['quantity'].toString()) ?? 1;
        double rateValue = double.tryParse(item['price'].toString()) ?? 0;
        double amtValue = qtyValue * rateValue;
        totalQty += qtyValue;

        bytes += generator.text(
          '${nameLines.first.padRight(desc)}'
          '${"x ${qtyValue.toString()}".padLeft(qty)}'
          '${fmt(rateValue).padLeft(rate)}'
          '${amtValue.toString().padLeft(amt)}',
          styles: smallFontLeft,
        );

        for (int i = 1; i < nameLines.length; i++) {
          bytes += generator.text(
            '${nameLines[i].padRight(desc)}'
            '${"".padLeft(qty)}'
            '${"".padLeft(rate)}'
            '${"".padLeft(amt)}',
            styles: smallFontLeft,
          );
        }
        if (item['addons'] != null && (item['addons'] as List).isNotEmpty) {
          for (var addon in item['addons']) {
            String addonName = " ${addon['name']}";
            if (addonName.length > desc) {
              addonName = "${addonName.substring(0, desc - 3)}...";
            }

            double addonPrice = double.tryParse(addon['price'].toString()) ?? 0;
            addonsTotal += addonPrice * qtyValue;

            bytes += generator.text(
              '${addonName.padRight(desc)}'
              '${"".padLeft(qty)}'
              '${fmt(addonPrice).padLeft(rate)}'
              '${"".padLeft(amt)}',
              styles: smallFontLeft,
            );
          }
        }
      }

      // Calculate totals
      double subtotal = subTotal;
      double addons = addonsTotal;
      double taxTotal = 0;

      if (taxEnabled) {
        double cgst = subtotal * (cgstPercent / 100);
        double sgst = subtotal * (sgstPercent / 100);
        taxTotal = cgst + sgst;
      }

      double grandTotal = subtotal + addons + taxTotal - discountAmount;

      // Total Qty
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text(
        'TOTAL QTY'.padRight(totalCols - 8) + totalQty.toString().padLeft(8),
        styles: smallFontLeft,
      );

      // Subtotal
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text(
        'SUBTOTAL'.padRight(totalCols - 8) + subtotal.toStringAsFixed(2).padLeft(8),
        styles: smallFontLeft,
      );

      // Add-ons
      if (addonsTotal > 0) {
        bytes += generator.text('ADD-ONS'.padRight(totalCols - 8) + fmt(addonsTotal).padLeft(8));
      }

      // GST Lines (Only if enabled and > 0%)
      if (taxEnabled) {
        if (cgstPercent > 0) {
          double cgst = subtotal * (cgstPercent / 100);
          bytes += generator.text(
            'CGST (${cgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) + cgst.toStringAsFixed(2).padLeft(8),
            styles: smallFontLeft,
          );
        }

        if (sgstPercent > 0) {
          double sgst = subtotal * (sgstPercent / 100);
          bytes += generator.text(
            'SGST (${sgstPercent.toStringAsFixed(1)}%)'.padRight(totalCols - 8) + sgst.toStringAsFixed(2).padLeft(8),
            styles: smallFontLeft,
          );
        }
      }

      // Discount
      if (discountAmount > 0) {
        bytes += generator.text(
          'DISCOUNT'.padRight(totalCols - 8) + '-${discountAmount.toStringAsFixed(2)}'.padLeft(8),
          styles: smallFontLeft,
        );
      }
      // Grand Total
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text('GRAND TOTAL'.padRight(totalCols - 8) + fmt(grandTotal).padLeft(8),
          styles: const PosStyles(bold: true));
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text(
        "PAID [${paymentType!.toUpperCase()}]",
        styles: smallFontLeft,
      );

      if (customerNote != null && customerNote.isNotEmpty) {
        bytes += generator.text(separator, styles: smallFontLeft);

        bytes += generator.text(
          "CustomerNote :  $customerNote",
          styles: smallFontLeft,
        );
      }

      // String upiId = "richeyrichinfotech@icici";

      if (upiId.isNotEmpty) {
        String upiUrl = "upi://pay?pa=$upiId&pn=$shopName&am=${fmt(grandTotal)}&cu=INR";
        bytes += generator.feed(1);

        bytes += generator.qrcode(
          upiUrl,
          size: is58mm ? QRSize.size6 : QRSize.size3,
          align: PosAlign.center,
        );
        bytes += generator.feed(1);
      }

      // Footer
      bytes += generator.text(separator, styles: smallFontLeft);
      bytes += generator.text('Thank you! Visit Again', styles: smallFontCenter);
      bytes += generator.feed(3);
      // bytes += generator.cut(mode: PosCutMode.partial);

      final isConnected = await isOnline();

      // Send to printer
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      // Only save bill if saveBill flag is true (to avoid duplicate saves)
      // When called from bill_cart_widget.dart, bill is already saved via SmartDatabaseService

      if (saveBill) {
        await saveBillData(
          adminUid: adminUid,
          receiptNo: finalReceiptNo,
          items: items,
          subTotal: subTotal,
          tableNumber: tableNumber,
          taxEnabled: taxEnabled,
          cgstPercent: cgstPercent,
          sgstPercent: sgstPercent,
          customerName: customerName,
          customerPhone: customerPhone,
          customerGst: customerGst,
          customerAddress: customerAddress,
          customerNote: customerNote,
          discountPercent: discountPercent,
          discountAmount: discountAmount,
          paymentType: paymentType,
          orderType: orderType,
          customerId: customerId,
        );
      }

      if (context.mounted) {
        final message = isConnected
            ? 'Receipt printed & saved online! Receipt No: $receiptNo'
            : 'Receipt printed & saved offline! Will sync when online. Receipt No: $receiptNo';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: message),
            backgroundColor: isConnected ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Receipt printed! Receipt No: $finalReceiptNo'),
        //     backgroundColor: Colors.green,
        //     duration: const Duration(seconds: 2),
        //   ),
        // );
      }
    } catch (e) {
      debugPrint("Printing error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Printing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> saveBillData({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    String? tableNumber,
    bool taxEnabled = false,
    double cgstPercent = 0.0,
    double sgstPercent = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerGst,
    String? customerAddress,
    String? customerNote,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    String? paymentType,
    String? orderType,
    String? customerId,
  }) async {
    try {
      final now = DateTime.now();

      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'productId': item['productId'] ?? '',
          'name': item['name'] ?? '',
          'price': double.tryParse(item['price'].toString()) ?? 0.0,
          'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
        };
      }).toList();

      // Calculate tax amounts if enabled
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      double totalWithTax = subTotal;

      if (taxEnabled) {
        cgstAmount = subTotal * (cgstPercent / 100);
        sgstAmount = subTotal * (sgstPercent / 100);
        totalWithTax = subTotal + cgstAmount + sgstAmount;
      }

      // Calculate final total with discount
      double finalTotal = totalWithTax - discountAmount;

      // Prepare bill data for SmartDatabaseService
      // Note: items must be JSON encoded string for SQLite storage
      // Schema: id, admin_uid, customer_phone, items, total_amount, bill_date, created_at, updated_at, sync_status, firebase_id
      final billData = {
        'id': receiptNo,
        'customer_id': (customerId == null || customerId.isEmpty) ? null : customerId,
        'bill_date': now.millisecondsSinceEpoch, // Store as integer for proper sorting
        'items': jsonEncode(itemsData), // Convert to JSON string for SQLite
        'total_amount': finalTotal,
        'sub_total': subTotal,
        'table_number': tableNumber ?? 'N/A',
        'tax_enabled': taxEnabled ? 1 : 0, // SQLite doesn't support bool, use int
        'cgst_percent': cgstPercent,
        'sgst_percent': sgstPercent,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'customer_name': customerName ?? '',
        'customer_phone': customerPhone ?? '',
        'customer_gst': customerGst ?? '',
        'customer_address': customerAddress ?? '',
        'customer_note': customerNote ?? '',
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'final_total': finalTotal,
        'payment_type': paymentType ?? '',
        'order_type': orderType ?? '',
      };

      // Save using SmartDatabaseService (handles online/offline automatically)
      // This already saves to Firebase when online, no need for separate Firebase call
      await _databaseService.saveBill(adminUid, billData);

      // 🔥 Also create an order via OrderService
      try {
        await OrderService().createOrder(
          adminId: adminUid,
          billNumber: receiptNo,
          customerId: (customerId == null || customerId.isEmpty) ? null : customerId,
          customerName: customerName,
          customerPhone: customerPhone,
          items: itemsData,
          discount: discountAmount,
          tax: cgstAmount + sgstAmount,
          paymentMethod: paymentType,
          orderType: orderType,
          tableNumber: tableNumber,
          notes: customerNote,
          paymentStatus: 'Paid',
        );
        debugPrint('[ReceiptPreview] Order created successfully via OrderService');
      } catch (e) {
        debugPrint('[ReceiptPreview] Failed to create order via OrderService: $e');
        // We don't rethrow here because the bill is already saved locally/to Firebase DAO
        // The OrderService might be a separate API that is failing.
      }

      debugPrint(
          '[ReceiptPreview] Bill saved successfully - receiptNo: $receiptNo (${_databaseService.isOnline ? "online" : "offline"})');
    } catch (e) {
      debugPrint('Error saving bill: $e');
      rethrow;
    }
  }

  // static Future<void> saveBillToFirebase({
  //   required String adminUid,
  //   required String receiptNo,
  //   required List<Map<String, dynamic>> items,
  //   required double subTotal,
  //   required bool taxEnabled,
  //   required double cgstPercent,
  //   required double sgstPercent,
  //   required String customerName,
  //   required String customerPhone,
  //   required String customerGst,
  //   required String customerAddress,
  //   required String customerNote,
  //   required double discountPercent,
  //   required double discountAmount,
  //   required String paymentType,
  //   required String orderType,
  // }) async {
  //   try {
  //     // Check connectivity
  //     final connectionMonitor = ConnectionMonitor();
  //     await connectionMonitor.initialize();
  //     final isConnected = connectionMonitor.isConnected;

  //     final now = DateTime.now();
  //     final monthDoc = DateFormat('yyyyMM').format(now); // e.g., "202512"
  //     final dateDoc = DateFormat('yyyyMMdd').format(now); // e.g., "20251209"
  //     final dateString = DateFormat('MMM dd, yyyy').format(now); // e.g., "Dec 09, 2025"

  //     // Prepare items array - ensure each item has name, price, quantity
  //     final List<Map<String, dynamic>> itemsData = items.map((item) {
  //       return {
  //         'name': item['name'] ?? '',
  //         'price': double.tryParse(item['price'].toString()) ?? 0.0,
  //         'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
  //       };
  //     }).toList();

  //     final billData = {
  //       'id': receiptNo,
  //       'bill_date': now.millisecondsSinceEpoch, // Store as integer for proper sorting
  //       'items': itemsData,
  //       'total_amount': finalTotal,
  //       'sub_total': subTotal,
  //       'table_number': tableNumber ?? 'N/A',
  //       'tax_enabled': taxEnabled ? 1 : 0, // SQLite doesn't support bool, use int
  //       'cgst_percent': cgstPercent,
  //       'sgst_percent': sgstPercent,
  //       'cgst_amount': cgstAmount,
  //       'sgst_amount': sgstAmount,
  //       'customer_name': customerName ?? '',
  //       'customer_phone': customerPhone ?? '',
  //       'customer_gst': customerGst ?? '',
  //       'customer_address': customerAddress ?? '',
  //       'customer_note': customerNote ?? '',
  //       'discount_percent': discountPercent,
  //       'discount_amount': discountAmount,
  //       'final_total': finalTotal,
  //       'payment_type': paymentType ?? '',
  //       'order_type': orderType ?? '',
  //     };

  //     // Prepare bill data
  //     final billData = {
  //       'id': receiptNo,
  //       'adminId': adminUid,
  //       'date': dateString,
  //       'items': itemsData,
  //       'receiptNo': receiptNo,
  //       'subTotal': subTotal,
  //       'monthDoc': monthDoc,
  //       'dateDoc': dateDoc,
  //       'createdAt': now.toString(),
  //     };

  //     if (isConnected) {
  //       // Save to Firebase online
  //       await FirebaseFirestore.instance
  //           .collection('AllBills')
  //           .doc(adminUid)
  //           .collection('myBills')
  //           .doc(monthDoc)
  //           .collection(dateDoc)
  //           .doc(receiptNo)
  //           .set({
  //         'adminId': adminUid,
  //         'createdAt': FieldValue.serverTimestamp(),
  //         'date': dateString,
  //         'items': itemsData,
  //         'receiptNo': receiptNo,
  //         'subTotal': subTotal,
  //       });

  //       debugPrint('Bill saved to Firebase successfully (online)');
  //     } else {
  //       // Save offline using OfflineBillManager
  //       final offlineBillManager = OfflineBillManager();
  //       await offlineBillManager.initialize();
  //       await offlineBillManager.storeBillOffline(adminUid, billData);

  //       debugPrint('Bill saved offline successfully - will sync when online');
  //     }

  //     connectionMonitor.dispose();
  //   } catch (e) {
  //     debugPrint('Error saving bill: $e');

  //     // Fallback to offline storage if online save fails
  //     try {
  //       final now = DateTime.now();
  //       final dateString = DateFormat('MMM dd, yyyy').format(now);
  //       final monthDoc = DateFormat('yyyyMM').format(now);
  //       final dateDoc = DateFormat('yyyyMMdd').format(now);

  //       final itemsData = items.map((item) {
  //         return {
  //           'name': item['name'] ?? '',
  //           'price': double.tryParse(item['price'].toString()) ?? 0.0,
  //           'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
  //         };
  //       }).toList();

  //       final billData = {
  //         'id': receiptNo,
  //         'adminId': adminUid,
  //         'date': dateString,
  //         'items': itemsData,
  //         'receiptNo': receiptNo,
  //         'subTotal': subTotal,
  //         'monthDoc': monthDoc,
  //         'dateDoc': dateDoc,
  //         'createdAt': now.millisecondsSinceEpoch,
  //       };

  //       final offlineBillManager = OfflineBillManager();
  //       await offlineBillManager.initialize();
  //       await offlineBillManager.storeBillOffline(adminUid, billData);

  //       debugPrint('Bill saved offline as fallback after online failure');
  //     } catch (offlineError) {
  //       debugPrint('Failed to save bill offline: $offlineError');
  //       rethrow;
  //     }
  //   }
  // }

  /// Get offline bill statistics for display
  static Future<Map<String, dynamic>> getOfflineBillStats(String adminUid) async {
    try {
      final offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
      return await offlineBillManager.getDetailedOfflineBillStatistics(adminUid);
    } catch (e) {
      debugPrint('Error getting offline bill stats: $e');
      return {
        'error': e.toString(),
        'offlineBillsCount': 0,
      };
    }
  }

  /// Manually trigger sync of offline bills
  static Future<OfflineBillSyncResult> syncOfflineBills(String adminUid) async {
    try {
      final offlineBillManager = OfflineBillManager();
      await offlineBillManager.initialize();
      return await offlineBillManager.manualSyncOfflineBills(adminUid);
    } catch (e) {
      debugPrint('Error syncing offline bills: $e');
      return OfflineBillSyncResult(
        success: false,
        errorMessage: e.toString(),
        billsSynced: 0,
      );
    }
  }

  static Future<void> printCustomerWiseReport({
    required BuildContext context,
    required BluetoothPrinter printer,
    required PaperSize paperSize,
    required String shopName,
    required String contact,
    required String address,
    required String customerName,
    required String customerPhone,
    required String customerGST,
    required DateTime fromDate,
    required DateTime toDate,
    required List<Map<String, dynamic>> bills,
    required double totalPaid,
    required double totalDue,
  }) async {
    try {
      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      bytes += generator.setGlobalCodeTable('CP1252');
      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 32 : 48;
      String separator = '-' * totalCols;

      const smallFontCenter = PosStyles(align: PosAlign.center);
      const smallFontLeft = PosStyles(align: PosAlign.left);

      // ===== HEADER =====
      bytes += generator.text(shopName, styles: smallFontCenter);
      bytes += generator.text(address, styles: smallFontCenter);
      bytes += generator.text('Mob: $contact', styles: smallFontCenter);
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text(
        'CUSTOMER WISE REPORT',
        styles: smallFontCenter,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== DATE RANGE =====
      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yyyy').format(fromDate)}',
        styles: smallFontLeft,
      );
      bytes += generator.text(
        'To  : ${DateFormat('dd/MM/yyyy').format(toDate)}',
        styles: smallFontLeft,
      );

      bytes += generator.text(separator, styles: smallFontLeft);

      // ===== CUSTOMER INFO =====
      bytes += generator.text(
        'Name:  $customerName',
        styles: smallFontLeft,
      );
      bytes += generator.text(
        'Phone: $customerPhone',
        styles: smallFontLeft,
      );
      if (customerGST.isNotEmpty) {
        bytes += generator.text(
          'GST:  $customerGST',
          styles: smallFontLeft,
        );
      }

      bytes += generator.hr();

      // Table Header using Row for perfect alignment
      bytes += generator.row([
        PosColumn(text: 'Bill', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Date', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Amt', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.hr();

      // ===== BILLS =====
      for (final bill in bills) {
        bytes += generator.row([
          PosColumn(text: bill['billNo'].toString(), width: 4),
          PosColumn(text: bill['date'], width: 4),
          PosColumn(
            text: bill['amount'].toStringAsFixed(0),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        // Optional: Small line for Mode if needed, or just keep it simple
      }

      bytes += generator.hr();

      // ===== TOTALS =====
      double grandTotal = totalPaid + totalDue;

      bytes += generator.row([
        PosColumn(text: 'PAID', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: totalPaid.toStringAsFixed(2),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.row([
        PosColumn(text: 'DUE', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: totalDue.toStringAsFixed(2),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'GRAND TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size1)),
        PosColumn(
          text: grandTotal.toStringAsFixed(2),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1),
        ),
      ]);

      // ===== FOOTER =====
      bytes += generator.text(separator, styles: smallFontLeft);

      bytes += generator.text('Thank you!', styles: smallFontCenter);
      bytes += generator.feed(4);

      // ===== PRINT =====
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: MyText(text: 'Customer report printed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Customer print error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Print failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Check if device is currently online
  static Future<bool> isOnline() async {
    try {
      final connectionMonitor = ConnectionMonitor();
      await connectionMonitor.initialize();
      final isConnected = connectionMonitor.isConnected;
      connectionMonitor.dispose();
      return isConnected;
    } catch (e) {
      debugPrint('Error checking online status: $e');
      return false;
    }
  }
}

class BluetoothPrinter {
  int? id;
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  bool? isBle;

  PrinterType typePrinter;
  bool? state;

  BluetoothPrinter(
      {this.deviceName,
      this.address,
      this.port,
      this.state,
      this.vendorId,
      this.productId,
      this.typePrinter = PrinterType.bluetooth,
      this.isBle = false});
}
