// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/screens/search_receipt_screen.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';

class BillwiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;
  const BillwiseReportScreen({Key? key, required this.uid, required this.adminUid}) : super(key: key);

  @override
  State<BillwiseReportScreen> createState() => _BillwiseReportScreenState();
}

class _BillwiseReportScreenState extends State<BillwiseReportScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<Map<String, dynamic>> billsData = [];
  bool isLoading = false;
  bool showSummary = false;
  double totalAmount = 0;
  double totalItems = 0;

  @override
  void initState() {
    super.initState();
    _initializePrinterFromHive();
  }

  Future<void> _initializePrinterFromHive() async {
    try {
      final box = await Hive.openBox('printerSettings');
      final savedPrinterData = box.get('selectedPrinter');

      if (savedPrinterData != null && mounted) {
        final printProvider = Provider.of<PrintProvider>(context, listen: false);

        // Reconstruct BluetoothPrinter from saved data
        final savedPrinter = BluetoothPrinter(
          deviceName: savedPrinterData['deviceName'],
          address: savedPrinterData['address'],
          isBle: savedPrinterData['isBle'] ?? false,
          vendorId: savedPrinterData['vendorId'],
          productId: savedPrinterData['productId'],
          typePrinter: PrinterType.values[savedPrinterData['typePrinter'] ?? 0], // This is enum, OK
        );

        // ------------------------
        // FIX: PaperSize mapping
        // ------------------------
        final paperSizeValue = savedPrinterData['paperSize'] ?? 1;

        final paperSize = {
              1: PaperSize.mm58,
              2: PaperSize.mm72,
              3: PaperSize.mm80,
            }[paperSizeValue] ??
            PaperSize.mm58;

        // Update provider
        printProvider.setSelectedPrinter(savedPrinter);
        printProvider.setPaperSize(paperSize);

        // Try reconnecting
        await _reconnectPrinter(savedPrinter, printProvider);
      }
    } catch (e) {
      print('Error initializing printer from Hive: $e');
    }
  }

  Future<void> _reconnectPrinter(BluetoothPrinter printer, PrintProvider printProvider) async {
    try {
      final printerManager = PrinterManager.instance;

      switch (printer.typePrinter) {
        case PrinterType.usb:
          await printerManager.connect(
            type: printer.typePrinter,
            model: UsbPrinterInput(
              name: printer.deviceName,
              productId: printer.productId,
              vendorId: printer.vendorId,
            ),
          );
          printProvider.setConnected(true);
          break;
        case PrinterType.bluetooth:
          await printerManager.connect(
            type: printer.typePrinter,
            model: BluetoothPrinterInput(
              name: printer.deviceName,
              address: printer.address!,
              isBle: printer.isBle ?? false,
              autoConnect: true,
            ),
          );
          break;
        case PrinterType.network:
          await printerManager.connect(
            type: printer.typePrinter,
            model: TcpPrinterInput(ipAddress: printer.address!),
          );
          printProvider.setConnected(true);
          break;
        default:
      }
    } catch (e) {
      print('Error reconnecting printer: $e');
      printProvider.setConnected(false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          // Reset toDate if it's before fromDate
          if (toDate != null && toDate!.isBefore(fromDate!)) {
            toDate = null;
          }
        } else {
          toDate = picked;
        }
      });

      // Auto-fetch data if both dates are selected
      if (fromDate != null && toDate != null) {
        await _fetchBillsData();
      }
    }
  }

  Future<void> _fetchBillsData() async {
    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both dates')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      billsData.clear();
      totalAmount = 0;
      totalItems = 0;
    });

    try {
      // Normalize dates to start of day
      final startDate = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDate = DateTime(toDate!.year, toDate!.month, toDate!.day);

      // Get all unique months between fromDate and toDate
      Set<String> monthsToQuery = {};
      DateTime current = DateTime(startDate.year, startDate.month);
      DateTime end = DateTime(endDate.year, endDate.month);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        monthsToQuery.add(DateFormat('yyyyMM').format(current));
        current = DateTime(current.year, current.month + 1);
      }

      for (String month in monthsToQuery) {
        final collectionRef =
            FirebaseFirestore.instance.collection('AllBills').doc(widget.uid).collection('myBills').doc(month);

        // Iterate through each day in the range for this month
        DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);

        // If this is not the first month, start from day 1
        if (month != DateFormat('yyyyMM').format(startDate)) {
          int year = int.parse(month.substring(0, 4));
          int monthNum = int.parse(month.substring(4, 6));
          currentDate = DateTime(year, monthNum, 1);
        }

        // Determine the last day to check for this month
        DateTime lastDayOfMonth = DateTime(int.parse(month.substring(0, 4)), int.parse(month.substring(4, 6)) + 1, 0);
        DateTime lastDate = endDate;

        // If this is not the last month, go to end of month
        if (month != DateFormat('yyyyMM').format(endDate)) {
          lastDate = lastDayOfMonth;
        }

        while (currentDate.isBefore(lastDate) || currentDate.isAtSameMomentAs(lastDate)) {
          String dateStr = DateFormat('yyyyMMdd').format(currentDate);

          try {
            final dateCollectionRef = collectionRef.collection(dateStr);
            final snapshot = await dateCollectionRef.get();

            for (var doc in snapshot.docs) {
              final data = doc.data();
              final items = data['items'] as List<dynamic>? ?? [];
              final subTotal = (data['subTotal'] ?? 0).toDouble();

              billsData.add({
                'billNo': data['receiptNo'] ?? 'N/A',
                'totalItems': items.length.toDouble(),
                'totalAmount': subTotal,
                'orderDate': dateStr,
                'items': items,
                'fullData': data,
              });

              totalAmount += subTotal;
              totalItems += items.length;
            }
          } catch (e) {
            print('Error fetching date $dateStr: $e');
          }

          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      // Sort bills by date and bill number
      billsData.sort((a, b) {
        int dateCompare = b['orderDate'].compareTo(a['orderDate']);
        if (dateCompare != 0) return dateCompare;
        return b['billNo'].toString().compareTo(a['billNo'].toString());
      });
    } catch (e) {
      if (mounted) {
        print('Error fetching bills data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _printReport() async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
      // Show printer connection dialog
      await showDialog(
        context: context,
        builder: (context) => const PrinterConnectionDialog(),
      );

      // Save printer settings to Hive after connection
      if (printProvider.isConnected && printProvider.selectedPrinter != null) {
        await _savePrinterToHive(printProvider);
        await _printThermalReceipt();
      }
    } else {
      await _printThermalReceipt();
    }
  }

  Future<void> _savePrinterToHive(PrintProvider printProvider) async {
    try {
      final box = await Hive.openBox('printerSettings');
      final printer = printProvider.selectedPrinter!;

      await box.put('selectedPrinter', {
        'deviceName': printer.deviceName,
        'address': printer.address,
        'isBle': printer.isBle,
        'vendorId': printer.vendorId,
        'productId': printer.productId,
        'typePrinter': printer.typePrinter.index,
        'paperSize': printProvider.selectedPaperSize.value, // Save as value, not index
      });
    } catch (e) {
      print('Error saving printer to Hive: $e');
    }
  }

  Future<void> _printThermalReceipt() async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final printerManager = PrinterManager.instance;

    try {
      // Determine paper size based on saved setting
      PaperSize paperSize = printProvider.selectedPaperSize;

      // Create ESC/POS commands
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text('RICHEY RICH INFOTECH',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      bytes += generator.emptyLines(1);

      // Date and report info
      bytes += generator.text(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text('Bill Wise Sales Report', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Date range
      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yy').format(fromDate!)}     To: ${DateFormat('dd/MM/yy').format(toDate!)}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Table header
      bytes += generator.row([
        PosColumn(text: 'Bill', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Amount', width: 5, styles: const PosStyles(bold: true)),
      ]);
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Bills data
      for (var bill in billsData) {
        // Format date safely
        String dateDisplay = '';
        try {
          final dateStr = bill['orderDate'] as String;
          final year = dateStr.substring(0, 4);
          final month = dateStr.substring(4, 6);
          final day = dateStr.substring(6, 8);
          dateDisplay = '$day/$month/${year.substring(2)}';
        } catch (e) {
          dateDisplay = bill['orderDate'].toString();
        }

        bytes += generator.text(dateDisplay);
        bytes += generator.row([
          PosColumn(text: bill['billNo'].toString(), width: 4),
          PosColumn(text: bill['totalItems'].toStringAsFixed(1), width: 3),
          PosColumn(
              text: bill['totalAmount'].toStringAsFixed(2), width: 5, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Subtotal
      bytes += generator.row([
        PosColumn(text: 'Sub Total :', width: 6),
        PosColumn(text: totalAmount.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Additional charges
      bytes += generator.row([
        PosColumn(text: 'Packing Charges (+) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Service Charge (+) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.emptyLines(1);

      bytes += generator.row([
        PosColumn(text: 'Rounding Amt (+) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Rounding Amt (-) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Discount (-) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Cancel Amt (-) :', width: 9),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Net Amount
      bytes += generator.row([
        PosColumn(text: 'Net Amount :', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
            text: totalAmount.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));

      // Payment Summary
      bytes += generator.text('Payment Summary', styles: const PosStyles(bold: true));
      bytes += generator.text("-" * 32, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.row([
        PosColumn(text: 'CASH', width: 6),
        PosColumn(text: totalAmount.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      // Send to printer
      await printerManager.send(type: printProvider.selectedPrinter!.typePrinter, bytes: bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndShareReport() async {
    print('=== PDF Generation Started ===');
    print('Bills data length: ${billsData.length}');
    print('Total amount: $totalAmount');

    // Check if data exists
    if (billsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available. Please select dates and wait for data to load.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Fetch shop details from Firestore
      String shopName = 'RICHEY RICH INFOTECH';
      String address = '';
      String contact = '';
      String gstNo = '';

      try {
        final doc = await FirebaseFirestore.instance
            .collection('AllAdmins')
            .doc(widget.adminUid)
            .collection('customer')
            .doc(widget.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            shopName = data['shopName'] ?? shopName;
            address = data['address'] ?? '';
            contact = data['contact'] ?? '';
            gstNo = data['gstNo'] ?? '';
            print('Shop details fetched: $shopName');
          }
        }
      } catch (e) {
        print('Error fetching shop details: $e');
      }

      if (mounted) Navigator.of(context).pop();

      // Generate PDF with callback function
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              margin: const pw.EdgeInsets.all(20),
              build: (pw.Context context) => [
                // Shop Header
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (address.isNotEmpty) pw.SizedBox(height: 4),
                if (address.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      address,
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                if (contact.isNotEmpty) pw.SizedBox(height: 2),
                if (contact.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'Contact: $contact',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                if (gstNo.isNotEmpty) pw.SizedBox(height: 2),
                if (gstNo.isNotEmpty)
                  pw.Center(
                    child: pw.Text(
                      'GST: $gstNo',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),

                // Report Details
                pw.Center(
                  child: pw.Text(
                    DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Bill Wise Sales Report',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ),

                pw.SizedBox(height: 8),

                // Date Range
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} to ${DateFormat('dd/MM/yyyy').format(toDate!)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 12),

                // Bills Table
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                  headers: ['Bill No', 'Total Items', 'Total Amount', 'Order Date'],
                  data: billsData.map((bill) {
                    // Format date safely
                    String dateDisplay = '';
                    try {
                      final dateStr = bill['orderDate'] as String;
                      final year = dateStr.substring(0, 4);
                      final month = dateStr.substring(4, 6);
                      final day = dateStr.substring(6, 8);
                      dateDisplay = '$day/$month/${year.substring(2)}';
                    } catch (e) {
                      dateDisplay = bill['orderDate'].toString();
                    }

                    return [
                      bill['billNo'].toString(),
                      bill['totalItems'].toString(),
                      'Rs ${bill['totalAmount'].toStringAsFixed(2)}',
                      dateDisplay,
                    ];
                  }).toList(),
                ),

                pw.SizedBox(height: 12),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 8),

                // Summary Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Bills: ${billsData.length}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.Text(
                            'Total Items: ${billsData.fold<double>(0, (sum, bill) => sum + (bill['totalItems'] as double? ?? 0)).toStringAsFixed(0)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Grand Total: ',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                          ),
                          pw.Text(
                            'Rs ${totalAmount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 16,
                              color: PdfColors.green900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Generated by POS System',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );

          return pdf.save();
        },
        name: 'BillwiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Close loading dialog if open
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('Error creating PDF: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Billwise report', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: MyDrawer(
        phoneNo: widget.uid,
        adminPhoneNo: widget.adminUid,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('From date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    fromDate == null ? 'Select date' : DateFormat('dd MMM yyyy').format(fromDate!),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    fromDate == null ? '' : DateFormat('hh:mm:ss a').format(fromDate!),
                                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('To date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    toDate == null ? 'Select date' : DateFormat('dd MMM yyyy').format(toDate!),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    toDate == null ? '' : DateFormat('hh:mm:ss a').format(toDate!),
                                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : billsData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              fromDate == null || toDate == null
                                  ? 'Please select date range'
                                  : 'No bills found for selected dates',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.black),
                                columns: const [
                                  DataColumn(
                                      label:
                                          Text('', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Bill No.',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Items',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Amount',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Order Date',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                ],
                                rows: billsData.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final bill = entry.value;

                                  // Parse date safely
                                  String displayDate = bill['orderDate'];
                                  try {
                                    final dateStr = bill['orderDate'] as String;
                                    final year = dateStr.substring(0, 4);
                                    final month = dateStr.substring(4, 6);
                                    final day = dateStr.substring(6, 8);
                                    displayDate = '$year-$month-$day';
                                  } catch (e) {
                                    print('Error formatting date: $e');
                                  }

                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${index + 1}')),
                                      DataCell(Text(bill['billNo'].toString())),
                                      DataCell(Text(bill['totalItems'].toStringAsFixed(1))),
                                      DataCell(Text(bill['totalAmount'].toStringAsFixed(1))),
                                      DataCell(Text(displayDate)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          Container(
            color: primaryColor,
            child: InkWell(
              onTap: () {
                setState(() {
                  showSummary = !showSummary;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('View Summary',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Icon(
                      showSummary ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showSummary)
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bills:', style: TextStyle(fontSize: 16)),
                      Text(billsData.length.toString(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Items:', style: TextStyle(fontSize: 16)),
                      Text(totalItems.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                      Text('₹${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.print_rounded,
                  label: "PRINT",
                  color: appbar1,
                  enabled: billsData.isNotEmpty,
                  onTap: _printReport,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.download_rounded,
                  label: "SAVE PDF",
                  color: appbar1,
                  enabled: billsData.isNotEmpty,
                  onTap: _downloadAndShareReport,
                ),
                const SizedBox(width: 10),
                _actionButton(
                  icon: Icons.search_rounded,
                  label: "SEARCH BILL",
                  color: appbar1,
                  enabled: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchReceiptScreen(
                          phoneNumber: widget.uid,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Container(
          //   padding: const EdgeInsets.all(16),
          //   color: Colors.white,
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: ElevatedButton.icon(
          //           icon: const Icon(Icons.print),
          //           label: const Text('PRINT REPORT'),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: primaryColor,
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(vertical: 16),
          //             textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          //           ),
          //           onPressed: billsData.isEmpty ? null : _printReport,
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: ElevatedButton.icon(
          //           icon: const Icon(Icons.share),
          //           label: const Text('DOWNLOAD & SHARE'),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: primaryColor,
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(vertical: 16),
          //             textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          //           ),
          //           onPressed: billsData.isEmpty ? null : _downloadAndShareReport,
          //         ),
          //       ),
          //       const SizedBox(width: 12),
          //       Expanded(
          //         child: ElevatedButton.icon(
          //           icon: const Icon(Icons.search),
          //           label: const Text('SEARCH BILL'),
          //           style: ElevatedButton.styleFrom(
          //             backgroundColor: primaryColor,
          //             foregroundColor: Colors.white,
          //             padding: const EdgeInsets.symmetric(vertical: 16),
          //             textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          //           ),
          //           onPressed: _printReport,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 50,
          decoration: BoxDecoration(
            color: enabled ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
