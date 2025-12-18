import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class ItemwiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;

  const ItemwiseReportScreen(
      {Key? key, required this.uid, required this.adminUid})
      : super(key: key);

  @override
  State<ItemwiseReportScreen> createState() => _ItemwiseReportScreenState();
}

class _ItemwiseReportScreenState extends State<ItemwiseReportScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<Map<String, dynamic>> itemsData = [];
  bool isLoading = false;
  double totalAmount = 0;
  double totalQuantity = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Itemwise report',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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
                              const Icon(Icons.calendar_today,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('From date:',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  Text(
                                    fromDate == null
                                        ? 'Select date'
                                        : DateFormat('dd MMM yyyy')
                                            .format(fromDate!),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    fromDate == null
                                        ? ''
                                        : DateFormat('hh:mm:ss a')
                                            .format(fromDate!),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blue),
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
                              const Icon(Icons.calendar_today,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('To date:',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  Text(
                                    toDate == null
                                        ? 'Select date'
                                        : DateFormat('dd MMM yyyy')
                                            .format(toDate!),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    toDate == null
                                        ? ''
                                        : DateFormat('hh:mm:ss a')
                                            .format(toDate!),
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blue),
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
                : itemsData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              fromDate == null || toDate == null
                                  ? 'Please select date range'
                                  : 'No items found for selected dates',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor:
                                MaterialStateProperty.all(Colors.black),
                            columns: const [
                              DataColumn(
                                  label: Text('',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Name',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Items sold',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Amount',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: itemsData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(item['name'].toString())),
                                  DataCell(Text(
                                      item['quantity'].toStringAsFixed(1))),
                                  DataCell(
                                      Text(item['amount'].toStringAsFixed(2))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('PRINT REPORT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: itemsData.isEmpty ? null : _printReport,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('DOWNLOAD & SHARE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed:
                        itemsData.isEmpty ? null : _downloadAndShareReport,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (fromDate ?? DateTime.now())
          : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          if (toDate != null && toDate!.isBefore(fromDate!)) {
            toDate = null;
          }
        } else {
          toDate = picked;
        }
      });

      if (fromDate != null && toDate != null) {
        await _fetchItemsData();
      }
    }
  }

  Future<void> _fetchItemsData() async {
    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both dates')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      itemsData.clear();
      totalAmount = 0;
      totalQuantity = 0;
    });

    try {
      // Map to aggregate items by name
      Map<String, Map<String, dynamic>> itemsMap = {};

      final startDate =
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDate = DateTime(toDate!.year, toDate!.month, toDate!.day);

      Set<String> monthsToQuery = {};
      DateTime current = DateTime(startDate.year, startDate.month);
      DateTime end = DateTime(endDate.year, endDate.month);

      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        monthsToQuery.add(DateFormat('yyyyMM').format(current));
        current = DateTime(current.year, current.month + 1);
      }

      for (String month in monthsToQuery) {
        final collectionRef = FirebaseFirestore.instance
            .collection('AllBills')
            .doc(widget.uid)
            .collection('myBills')
            .doc(month);

        DateTime currentDate =
            DateTime(startDate.year, startDate.month, startDate.day);

        if (month != DateFormat('yyyyMM').format(startDate)) {
          int year = int.parse(month.substring(0, 4));
          int monthNum = int.parse(month.substring(4, 6));
          currentDate = DateTime(year, monthNum, 1);
        }

        DateTime lastDayOfMonth = DateTime(int.parse(month.substring(0, 4)),
            int.parse(month.substring(4, 6)) + 1, 0);
        DateTime lastDate = endDate;

        if (month != DateFormat('yyyyMM').format(endDate)) {
          lastDate = lastDayOfMonth;
        }

        while (currentDate.isBefore(lastDate) ||
            currentDate.isAtSameMomentAs(lastDate)) {
          String dateStr = DateFormat('yyyyMMdd').format(currentDate);

          try {
            final dateCollectionRef = collectionRef.collection(dateStr);
            final snapshot = await dateCollectionRef.get();

            for (var doc in snapshot.docs) {
              final data = doc.data();
              final items = data['items'] as List<dynamic>? ?? [];

              // Process each item in the bill
              for (var item in items) {
                final itemName = item['name'] as String? ?? 'Unknown';
                final quantity = (item['quantity'] ?? 0).toDouble();
                final price = (item['price'] ?? 0).toDouble();
                final amount = quantity * price;

                if (itemsMap.containsKey(itemName)) {
                  itemsMap[itemName]!['quantity'] += quantity;
                  itemsMap[itemName]!['amount'] += amount;
                } else {
                  itemsMap[itemName] = {
                    'name': itemName,
                    'quantity': quantity,
                    'amount': amount,
                  };
                }
              }
            }
          } catch (e) {
            print('Error fetching date $dateStr: $e');
          }

          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      // Convert map to list
      itemsData = itemsMap.values.toList();

      // Calculate totals
      for (var item in itemsData) {
        totalQuantity += item['quantity'];
        totalAmount += item['amount'];
      }

      // Sort by amount descending
      itemsData.sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    } catch (e) {
      if (mounted) {
        print('Error fetching items data: $e');
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
      await showDialog(
        context: context,
        builder: (context) => const PrinterConnectionDialog(),
      );

      if (printProvider.isConnected && printProvider.selectedPrinter != null) {
        await _printThermalReceipt();
      }
    } else {
      await _printThermalReceipt();
    }
  }

  Future<void> _printThermalReceipt() async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final printerManager = PrinterManager.instance;

    try {
      PaperSize paperSize = printProvider.selectedPaperSize;

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

      bytes += generator.text(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text('Item Wise Sales Report',
          styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('${"-" * 32}',
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yy').format(fromDate!)}     To: ${DateFormat('dd/MM/yy').format(toDate!)}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text('${"-" * 32}',
          styles: const PosStyles(align: PosAlign.center));

      // Table header
      bytes += generator.row([
        PosColumn(
            text: 'SR ITEM', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'QTY', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'AMOUNT', width: 3, styles: const PosStyles(bold: true)),
      ]);
      bytes += generator.text('${"-" * 32}',
          styles: const PosStyles(align: PosAlign.center));

      // Items data
      for (int i = 0; i < itemsData.length; i++) {
        final item = itemsData[i];
        bytes += generator.row([
          PosColumn(text: '${i + 1}  ${item['name']}', width: 6),
          PosColumn(text: item['quantity'].toStringAsFixed(1), width: 3),
          PosColumn(
              text: item['amount'].toStringAsFixed(2),
              width: 3,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.text('${"-" * 32}',
          styles: const PosStyles(align: PosAlign.center));

      // Total
      bytes += generator.row([
        PosColumn(
            text:
                'ITEM: ${itemsData.length} QTY: ${totalQuantity.toStringAsFixed(1)}',
            width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(text: 'AMOUNT:', width: 3),
        PosColumn(
            text: totalAmount.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.text('${"-" * 32}',
          styles: const PosStyles(align: PosAlign.center));

      bytes += generator.text('TOTAL AMOUNT',
          styles: const PosStyles(align: PosAlign.left, bold: true));
      bytes += generator.row([
        PosColumn(text: '', width: 6),
        PosColumn(text: ':', width: 3),
        PosColumn(
            text: totalAmount.toStringAsFixed(2),
            width: 3,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.emptyLines(3);
      bytes += generator.cut();

      await printerManager.send(
          type: printProvider.selectedPrinter!.typePrinter, bytes: bytes);

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
    print('Items data length: ${itemsData.length}');
    print('Total amount: $totalAmount');
    print('Total quantity: $totalQuantity');

    if (itemsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No data available. Please select dates and wait for data to load.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
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

      final pdf = pw.Document();

      // Prepare table data as strings
      final List<List<String>> tableData = [];
      for (int i = 0; i < itemsData.length; i++) {
        final item = itemsData[i];

        String srNo = (i + 1).toString();
        String itemName = item['name']?.toString() ?? '';
        String quantity = '0.0';
        String amount = '₹ 0.00';

        try {
          final qtyValue = item['quantity'];
          if (qtyValue != null) {
            quantity = double.parse(qtyValue.toString()).toStringAsFixed(1);
          }
        } catch (e) {
          print('Error parsing quantity for item $i: $e');
        }

        try {
          final amtValue = item['amount'];
          if (amtValue != null) {
            amount =
                '₹ ${double.parse(amtValue.toString()).toStringAsFixed(2)}';
          }
        } catch (e) {
          print('Error parsing amount for item $i: $e');
        }

        tableData.add([srNo, itemName, quantity, amount]);
      }

      // Convert totals to strings
      String totalQtyStr = '0.0';
      String totalAmtStr = '0.00';

      try {
        totalQtyStr = double.parse(totalQuantity.toString()).toStringAsFixed(1);
      } catch (e) {
        print('Error parsing total quantity: $e');
      }

      try {
        totalAmtStr = double.parse(totalAmount.toString()).toStringAsFixed(2);
      } catch (e) {
        print('Error parsing total amount: $e');
      }

      // Build the PDF page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (pw.Context pdfContext) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Shop Header
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                if (address.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      address,
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (contact.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      'Contact: $contact',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
                if (gstNo.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      'GST: $gstNo',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1),

                // Report Details
                pw.Center(
                  child: pw.Text(
                    DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Item Wise Sales Report',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),

                pw.SizedBox(height: 8),

                // Date Range
                pw.Container(
                  padding: pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} to ${DateFormat('dd/MM/yyyy').format(toDate!)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),

                pw.SizedBox(height: 12),

                // Items Table
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                    width: 1,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: pw.TextStyle(fontSize: 10),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                  },
                  headers: ['Sr.', 'Item Name', 'Quantity', 'Amount'],
                  data: tableData,
                  cellPadding: pw.EdgeInsets.all(6),
                  oddRowDecoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                  ),
                ),

                pw.SizedBox(height: 12),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 8),

                // Summary Section
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Items: ${itemsData.length}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          pw.Text(
                            'Total Quantity: $totalQtyStr',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
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
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          pw.Text(
                            '₹ $totalAmtStr',
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

                pw.Spacer(),

                // Footer
                pw.Center(
                  child: pw.Text(
                    'Generated by POS System',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      print('PDF bytes generated: ${pdfBytes.length}');

      // Save to file
      final String fileName =
          'ItemwiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf';

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$fileName';
      final File file = File(filePath);

      // Write PDF to file
      await file.writeAsBytes(pdfBytes);
      print('PDF saved to: $filePath');

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Item Wise Sales Report',
        text:
            'Report for period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} to ${DateFormat('dd/MM/yyyy').format(toDate!)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generated and ready to share!'),
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
}
