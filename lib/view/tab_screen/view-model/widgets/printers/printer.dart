import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:image/image.dart' as img_lib;
import 'package:http/http.dart' as http;
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
    if (logoUrl.isEmpty) return [];

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'printer_logo_${logoUrl.hashCode}.png';
      final file = File('${dir.path}/$fileName');

      img_lib.Image? image;

      // ✅ Offline-first: Try local cache
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          image = img_lib.decodeImage(bytes);
        } catch (e) {
          debugPrint("Failed to decode cached logo: $e");
          await file.delete(); // Delete corrupted file
        }
      }

      // 🌐 Download only if missing or decode failed
      if (image == null) {
        try {
          // Add timeout to prevent hanging the print process
          final response = await http.get(Uri.parse(logoUrl)).timeout(
                const Duration(seconds: 5),
              );

          if (response.statusCode == 200) {
            await file.writeAsBytes(response.bodyBytes);
            image = img_lib.decodeImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint("Logo download/decode failed: $e");
        }
      }

      if (image == null) return [];

      // Ensure width is compatible with thermal printers (multiple of 8)
      // We use a reasonable width for 58mm/80mm printers
      const targetWidth = 200;
      final int normalizedWidth = (targetWidth / 8).round() * 8;

      // Processing image for thermal printing
      final resized = img_lib.copyResize(image, width: normalizedWidth);
      final mono = img_lib.grayscale(resized);

      return generator.imageRaster(mono, align: PosAlign.center);
    } catch (e) {
      debugPrint("Logo processing failed: $e");
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
    String? employeeId,
    bool saveBill = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use provided receipt number or generate a new one
      String finalReceiptNo = receiptNo ?? generateReceiptNumber();

      if (saveBill) {
        finalReceiptNo = await saveBillData(
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
          employeeId: employeeId,
        );
      }

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

      // Header

      // Header logo
      if (logoUrl.isNotEmpty) {
        final logoBytes = await loadLogoOfflineSafe(logoUrl, generator);
        if (logoBytes.isNotEmpty) {
          bytes += logoBytes;
          bytes += generator.feed(is58mm ? 1 : 0);
        }
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
          '${rateValue.toStringAsFixed(1).padLeft(rate)}'
          '${amtValue.toStringAsFixed(1).padLeft(amt)}',
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

      bytes += generator.text('GRAND TOTAL'.padRight(totalCols - 8) + grandTotal.toStringAsFixed(1).padLeft(8),
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

      // Branding for free users
      final String planType = prefs.getString('subscriptionPlanType') ?? 'free';
      if (planType.toLowerCase() == 'free') {
        bytes += generator.feed(1);
        bytes += generator.text('Powered by Billing Sphere', styles: smallFontCenter);
      }

      bytes += generator.feed(3);
      // bytes += generator.cut(mode: PosCutMode.partial);

      final isConnected = await isOnline();

      // Send to printer
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      // We already called saveBillData at the top of this function!

      if (context.mounted) {
        SnackBarUtils.showSuccess(context, "Printed Successfully");
      }
    } catch (e) {
      debugPrint("Printing error: $e");
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Printing failed: $e');
      }
    }
  }

  Future<String> saveBillData({
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
    String? employeeId, // Added
  }) async {
    try {
      final now = DateTime.now();

      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'productId': item['productId'] ?? item['id'] ?? '',
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

      String finalReceiptNo = receiptNo;
      String? orderId;

      // 🔥 Try to create the order via OrderService first to get the backend-generated Bill Number
      try {
        final isOnlineStatus = await isOnline();
        if (isOnlineStatus) {
          final prefs = await SharedPreferences.getInstance();
          final businessCategory = prefs.getString('businessCategory') ?? 'Food';

          final order = await OrderService().createOrder(
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
            employeeId: employeeId, // Passed
            createKot:
                (businessCategory == 'Food' && (tableNumber == null || tableNumber == 'N/A' || tableNumber == '')),
          );
          if (order.billNumber.isNotEmpty) {
            finalReceiptNo = order.billNumber;
          }
          if (order.id != null) {
            orderId = order.id;
          }
        }
      } catch (e) {
        debugPrint('[SaveBillData] Failed to create order via OrderService: $e');
        // We don't rethrow here because we want to gracefully fallback to offline local saving
      }

      // Prepare bill data for SmartDatabaseService
      final billData = {
        'id': finalReceiptNo,
        'firebase_id': orderId,
        'customer_id': (customerId == null || customerId.isEmpty) ? null : customerId,
        'bill_date': now.millisecondsSinceEpoch,
        'items': jsonEncode(itemsData),
        'total_amount': finalTotal,
        'sub_total': subTotal,
        'table_number': tableNumber ?? 'N/A',
        'tax_enabled': taxEnabled ? 1 : 0,
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
      await _databaseService.saveBill(adminUid, billData);

      return finalReceiptNo;
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
      final prefs = await SharedPreferences.getInstance();
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

      // Branding for free users
      final String planType = prefs.getString('subscriptionPlanType') ?? 'free';
      if (planType.toLowerCase() == 'free') {
        bytes += generator.feed(1);
        bytes += generator.text('Powered by Billing Sphere', styles: smallFontCenter);
      }

      bytes += generator.feed(4);

      // ===== PRINT =====
      await PrinterManager.instance.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Customer report printed successfully');
      }
    } catch (e) {
      debugPrint('Customer print error: $e');
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Print failed: $e');
      }
    }
  }

  /// Check if device is currently online
  static Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity status: $e');
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
