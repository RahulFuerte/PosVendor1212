// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';

class DatewiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;

  const DatewiseReportScreen(
      {Key? key, required this.uid, required this.adminUid})
      : super(key: key);

  @override
  State<DatewiseReportScreen> createState() => _DatewiseReportScreenState();
}

class _DatewiseReportScreenState extends State<DatewiseReportScreen> {
  DateTime? fromDate;
  DateTime? toDate;
  List<Map<String, dynamic>> dateData = [];
  bool isLoading = false;
  bool showSummary = false;
  double totalAmount = 0;
  int totalBills = 0;
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  Future<Map<String, String>> _getShopData() async {
    String shopName = 'N/A';
    String contact = 'N/A';
    String address = 'N/A';
    String logoUrl = '';
    String upiId = '';

    try {
      // First try to get from local SQLite
      final localData = await _sqliteHelper.getUserData(widget.uid);

      if (localData != null) {
        shopName = localData['shopName'] ?? 'N/A';
        contact = localData['shopContact'] ?? 'N/A';
        address = localData['address'] ?? 'N/A';
        logoUrl = localData['shopLogoUrl'] ?? '';
        upiId = localData['upiId'] ?? '';
        debugPrint('Shop data loaded from local cache');
      } else {
        // Not found locally, fetch from Firebase
        final doc = await FirebaseFirestore.instance
            .collection('AllAdmins')
            .doc(widget.adminUid)
            .collection('customer')
            .doc(widget.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            shopName = data['shopName'] ?? 'N/A';
            contact = data['contact'] ?? 'N/A';
            address = data['address'] ?? 'N/A';
            upiId = data['upiId'] ?? '';

            // Save all fields to local SQLite for future use
            await _sqliteHelper.saveUserData({
              'phoneNumber': data['phoneNumber'] ?? widget.uid,
              'adminUid': data['adminUid'] ?? widget.adminUid,
              'shopName': shopName,
              'contact': contact,
              'address': address,
              'upiId': upiId,
              'logoUrl': data['logoUrl'],
              'name': data['name'],
              'email': data['email'],
              'customerCode': data['customerCode'],
              'gstNumber': data['gstNo'],
              'createdAt': data['createdAt'],
            });
            debugPrint('Shop data loaded from Firebase and saved locally');
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching shop data: $e');
    }

    return {
      'shopName': shopName,
      'contact': contact,
      'address': address,
      'logoUrl': logoUrl,
      'upiId': upiId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Datewise report',
            style: TextStyle(color: Colors.white)),
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
                : dateData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              fromDate == null || toDate == null
                                  ? 'Please select date range'
                                  : 'No data found for selected dates',
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
                                  label: Text('Date',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Total Bills',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('Amount',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: dateData.asMap().entries.map((entry) {
                              final index = entry.key;
                              final date = entry.value;

                              String displayDate = date['date'];
                              try {
                                final dateStr = date['date'] as String;
                                final year = dateStr.substring(0, 4);
                                final month = dateStr.substring(4, 6);
                                final day = dateStr.substring(6, 8);
                                displayDate =
                                    '$day/$month/${year.substring(2)}';
                              } catch (e) {
                                print('Error formatting date: $e');
                              }

                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(Text(displayDate)),
                                  DataCell(Text(date['totalBills'].toString())),
                                  DataCell(Text(
                                      PriceUtils.formatPrice(date['amount'])))
                                ],
                              );
                            }).toList(),
                          ),
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
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Icon(
                      showSummary
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
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
                      const Text('Total Days:', style: TextStyle(fontSize: 16)),
                      Text(dateData.length.toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bills:',
                          style: TextStyle(fontSize: 16)),
                      Text(totalBills.toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:',
                          style: TextStyle(fontSize: 16)),
                      Text('₹${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                ],
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
                    onPressed: dateData.isEmpty ? null : _printReport,
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
                        dateData.isEmpty ? null : _downloadAndShareReport,
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
        await _fetchDateData();
      }
    }
  }

  Future<void> _fetchDateData() async {
    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both dates')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      dateData.clear();
      totalAmount = 0;
      totalBills = 0;
    });

    try {
      Map<String, Map<String, dynamic>> datesMap = {};

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

            if (snapshot.docs.isNotEmpty) {
              double dayAmount = 0;
              int dayBills = snapshot.docs.length;

              for (var doc in snapshot.docs) {
                final data = doc.data();
                final subTotal = (data['subTotal'] ?? 0).toDouble();
                dayAmount += subTotal;
              }

              datesMap[dateStr] = {
                'date': dateStr,
                'totalBills': dayBills,
                'amount': dayAmount,
              };

              totalAmount += dayAmount;
              totalBills += dayBills;
            }
          } catch (e) {
            print('Error fetching date $dateStr: $e');
          }

          currentDate = currentDate.add(const Duration(days: 1));
        }
      }

      dateData = datesMap.values.toList();
      dateData.sort((a, b) => b['date'].compareTo(a['date']));
    } catch (e) {
      if (mounted) {
        print('Error fetching date data: $e');
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
    final shopData = await _getShopData();
    String shopName = shopData['shopName'] ?? '';

    try {
      PaperSize paperSize = printProvider.selectedPaperSize;

      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // 🔹 SAFE FORMAT FUNCTION (NO ₹ SYMBOL)
      String formatForPrinter(dynamic amount) {
        final value = (amount ?? 0) as num;
        return value.toStringAsFixed(2);
      }

      // Header
      bytes += generator.text(
        shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size1,
          width: PosTextSize.size2,
          bold: true,
        ),
      );

      bytes += generator.emptyLines(1);

      bytes += generator.text(
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text("-" * 32);

      bytes += generator.text(
        'Sales Summary',
        styles: const PosStyles(bold: true),
      );

      bytes += generator.text("-" * 32);

      bytes += generator.text(
        'From : ${DateFormat('dd/MM/yy').format(fromDate!)}   To : ${DateFormat('dd/MM/yy').format(toDate!)}',
      );

      bytes += generator.text("-" * 32);

      // Table Header
      bytes += generator.row([
        PosColumn(text: 'Date', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Qty',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(
            text: 'Amount',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.text("-" * 32);

      // Data
      for (var date in dateData) {
        String displayDate = '';
        try {
          final dateStr = date['date'] as String;
          final year = dateStr.substring(0, 4);
          final month = dateStr.substring(4, 6);
          final day = dateStr.substring(6, 8);
          displayDate = '$day/$month/${year.substring(2)}';
        } catch (e) {
          displayDate = date['date'].toString();
        }

        bytes += generator.row([
          PosColumn(text: displayDate, width: 6),
          PosColumn(
            text: date['totalBills'].toString(),
            width: 3,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: formatForPrinter(date['amount']),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.text("-" * 32);

      // Grand Total
      bytes += generator.row([
        PosColumn(
            text: 'Grand Total', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: totalBills.toString(),
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: formatForPrinter(totalAmount),
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += generator.text("-" * 32);

      // Payment Summary
      bytes += generator.text('Payment Summary',
          styles: const PosStyles(bold: true));
      bytes += generator.text("-" * 32);

      bytes += generator.row([
        PosColumn(text: 'CASH', width: 9),
        PosColumn(
          text: formatForPrinter(totalAmount), // ✅ FIXED HERE
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.text("-" * 32);

      bytes += generator.emptyLines(4);

      await printerManager.send(
        type: printProvider.selectedPrinter!.typePrinter,
        bytes: bytes,
      );

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
    print('Date data length: ${dateData.length}');
    print('Total amount: $totalAmount');
    print('Total bills: $totalBills');

    // Check if data exists
    if (dateData.isEmpty) {
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
            .doc(widget.uid)
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
          // Load font for Rupee symbol support
          final fontData = await rootBundle.load("fonts/Roboto-Regular.ttf");
          final ttf = pw.Font.ttf(fontData);

          final pdf = pw.Document(
            theme: pw.ThemeData.withFont(
              base: ttf,
              bold: ttf,
            ),
          );

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              margin: const pw.EdgeInsets.all(20),
              build: (pw.Context context) => [
                // Shop Header
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
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
                    'Date Wise Sales Report',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ),

                pw.SizedBox(height: 8),

                // Date Range
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} to ${DateFormat('dd/MM/yyyy').format(toDate!)}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 12),

                // Sales Table
                pw.Table.fromTextArray(
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 11),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                  },
                  headers: ['Date', 'Total Bills', 'Amount'],
                  data: dateData.map((date) {
                    String displayDate = '';
                    try {
                      final dateStr = date['date'] as String;
                      final year = dateStr.substring(0, 4);
                      final month = dateStr.substring(4, 6);
                      final day = dateStr.substring(6, 8);
                      displayDate = '$day/$month/${year.substring(2)}';
                    } catch (e) {
                      displayDate = date['date'].toString();
                    }

                    return [
                      displayDate,
                      date['totalBills'].toString(),
                      '${PriceUtils.formatPrice(date['amount'])}'
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
                            'Total Days: ${dateData.length}',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.Text(
                            'Total Bills: $totalBills',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 11),
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
                                fontWeight: pw.FontWeight.bold, fontSize: 14),
                          ),
                          pw.Text(
                            PriceUtils.formatPrice(totalAmount),
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

                pw.SizedBox(height: 12),

                // Payment Summary Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Summary',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Divider(),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('CASH:',
                              style: const pw.TextStyle(fontSize: 11)),
                          pw.Text(
                            PriceUtils.formatPrice(totalAmount),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 11),
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
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );

          return pdf.save();
        },
        name:
            'DatewiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
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
}
