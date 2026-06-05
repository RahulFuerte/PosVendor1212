// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';

import 'package:pos/core/widgets/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Package imports:
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pos/data/services/report_service.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:printing/printing.dart';

// Project imports:
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/view/home/reports/report_nav_bar.dart';
import 'package:pos/view/home/reports/widgets/report_skeleton.dart';

class BillwiseReportScreen extends StatefulWidget {
  const BillwiseReportScreen({Key? key}) : super(key: key);

  @override
  State<BillwiseReportScreen> createState() => _BillwiseReportScreenState();
}

// ignore: unused_element
class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        );
      },
    );
  }
}

class _BillwiseReportScreenState extends State<BillwiseReportScreen> {
  String uid = '';
  String adminUid = '';

  DateTime? fromDate;
  DateTime? toDate;
  List<Map<String, dynamic>> billsData = [];
  bool isLoading = false;
  bool showSummary = false;
  double totalAmount = 0;
  double totalItems = 0;
  final ReportService _reportService = ReportService();

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _initializePrinterFromHive();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uid = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
    });
  }

  Future<void> _initializePrinterFromHive() async {
    try {
      final box = await Hive.openBox('printerSettings');
      final savedPrinterData = box.get('selectedPrinter');

      if (savedPrinterData != null && mounted) {
        final printProvider =
            Provider.of<PrintProvider>(context, listen: false);

        // Reconstruct BluetoothPrinter from saved data
        final savedPrinter = BluetoothPrinter(
          deviceName: savedPrinterData['deviceName'],
          address: savedPrinterData['address'],
          isBle: savedPrinterData['isBle'] ?? false,
          vendorId: savedPrinterData['vendorId'],
          productId: savedPrinterData['productId'],
          typePrinter: PrinterType
              .values[savedPrinterData['typePrinter'] ?? 0], // This is enum, OK
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

  Future<void> _reconnectPrinter(
      BluetoothPrinter printer, PrintProvider printProvider) async {
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
      }
    } catch (e) {
      print('Error reconnecting printer: $e');
      printProvider.setConnected(false);
    }
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
      SnackBarUtils.showWarning(
          context, AppLocale.pleaseSelectBothDates.getString(context));
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
      final startDate =
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDate = DateTime(toDate!.year, toDate!.month, toDate!.day);

      // Fetch bills from API via ReportService
      final allBills = await _reportService.getBillWiseReport(
        startDate: startDate,
        endDate: endDate,
      );

      for (final bill in allBills) {
        final subTotal = (bill['totalAmount'] ?? 0).toDouble();
        final finalAmt = (bill['finalAmount'] ?? subTotal).toDouble();
        final itemCount =
            (bill['totalItemCount'] ?? (bill['items'] as List?)?.length ?? 0)
                .toDouble();

        billsData.add({
          'billNo': bill['billNumber'] ??
              bill['receiptNo'] ??
              bill['billNo'] ??
              bill['id'] ??
              'N/A',
          'customerName': bill['customerName'] ?? 'Walk-in',
          'totalItems': itemCount,
          'totalAmount': subTotal,
          'discount': (bill['discount'] ?? 0).toDouble(),
          'tax': (bill['tax'] ?? 0).toDouble(),
          'finalAmount': finalAmt,
          'paymentMethod': bill['paymentMethod'] ?? 'Cash',
          'orderDate': bill['orderDate']?.toString() ??
              DateFormat('dd-MM-yyyy').format(DateTime.now()),
          'fullData': bill,
        });
        totalAmount += finalAmt;
        totalItems += itemCount;
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
        SnackBarUtils.showError(
            context, '${AppLocale.errorFetchingData.getString(context)}: $e');
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
        'paperSize':
            printProvider.selectedPaperSize.value, // Save as value, not index
      });
    } catch (e) {
      print('Error saving printer to Hive: $e');
    }
  }

  Future<void> _printThermalReceipt() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final printerManager = PrinterManager.instance;
    final prefs = await SharedPreferences.getInstance();
    String shopName = prefs.getString('shopName') ?? 'Shop Name';

    // 🔒 Safety checks
    if (billsData.isEmpty) {
      SnackBarUtils.showWarning(
          context, AppLocale.noDataToPrint.getString(context));
      return;
    }

    final printer = printProvider.selectedPrinter;
    if (printer == null) {
      SnackBarUtils.showWarning(
          context, AppLocale.pleaseSelectAPrinterFirst.getString(context));
      return;
    }

    try {
      // Printer-safe amount formatter (NO ₹ symbol)
      String formatForPrinter(dynamic amount) {
        final value = (amount ?? 0) as num;
        return value.toStringAsFixed(2);
      }

      PaperSize paperSize = printProvider.selectedPaperSize;

      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // ================= HEADER =================
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

      bytes += generator.text(
        'Bill Wise Sales Report',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.hr();

      // ================= DATE RANGE =================
      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yy').format(fromDate!)}   To: ${DateFormat('dd/MM/yy').format(toDate!)}',
      );

      bytes += generator.hr();

      // ================= TABLE HEADER =================
      bytes += generator.row([
        PosColumn(text: 'Bill', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Amount', width: 5, styles: const PosStyles(bold: true)),
      ]);

      bytes += generator.hr();

      // ================= BILL DATA =================
      for (var bill in billsData) {
        bytes += generator.text(bill['orderDate'].toString());

        bytes += generator.row([
          PosColumn(text: bill['billNo'].toString(), width: 4),
          PosColumn(
            text: ((bill['totalItems'] ?? 0) as num).toStringAsFixed(0),
            width: 3,
          ),
          PosColumn(
            text: formatForPrinter(bill['finalAmount']),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr();

      // ================= SUB TOTAL =================
      bytes += generator.row([
        PosColumn(text: 'Sub Total :', width: 6),
        PosColumn(
          text: formatForPrinter(totalAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr();

      // ================= NET AMOUNT =================
      bytes += generator.row([
        PosColumn(
          text: 'Net Amount :',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: formatForPrinter(totalAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      bytes += generator.hr();

      // ================= PAYMENT SUMMARY =================
      bytes += generator.text(
        'Payment Summary',
        styles: const PosStyles(bold: true),
      );

      bytes += generator.row([
        PosColumn(text: 'CASH', width: 6),
        PosColumn(
          text: formatForPrinter(totalAmount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.emptyLines(1);

      // Branding for free users
      final String planType = prefs.getString('subscriptionPlanType') ?? 'free';
      if (planType.toLowerCase() == 'free') {
        bytes += generator.text('Powered by Billing Sphere',
            styles: const PosStyles(align: PosAlign.center));
      }

      bytes += generator.emptyLines(3);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // ================= SEND TO PRINTER =================
      await printerManager.send(
        type: printer.typePrinter,
        bytes: bytes,
      );

      SnackBarUtils.showSuccess(
          context, AppLocale.reportPrintedSuccessfully.getString(context));
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      SnackBarUtils.showError(
          context, '${AppLocale.printError.getString(context)}: $e');
    }
  }

  Future<void> _downloadAndShareReport() async {
    if (billsData.isEmpty) {
      SnackBarUtils.showWarning(
          context, AppLocale.noDataAvailable.getString(context));
      return;
    }
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final prefs = await SharedPreferences.getInstance();
      String shopName = prefs.getString('shopName') ?? 'Shop Name';
      String address = prefs.getString('address') ?? '';
      String contact = prefs.getString('contact') ?? '';
      String gstNo = prefs.getString('gstNumber') ?? '';

      final regularFont =
          pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Regular.ttf'));
      final boldFont =
          pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Bold.ttf'));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      await Printing.layoutPdf(
        name:
            'BillwiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              margin: const pw.EdgeInsets.all(20),
              theme: pw.ThemeData.withFont(
                base: regularFont,
                bold: boldFont,
              ),
              build: (pw.Context context) => [
                /// SHOP HEADER
                pw.Center(
                  child: pw.Text(
                    shopName,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                if (address.isNotEmpty)
                  pw.Center(
                      child: pw.Text(address,
                          style: const pw.TextStyle(fontSize: 10))),

                if (contact.isNotEmpty)
                  pw.Center(
                      child: pw.Text('Contact: $contact',
                          style: const pw.TextStyle(fontSize: 10))),

                if (gstNo.isNotEmpty)
                  pw.Center(
                      child: pw.Text('GST: $gstNo',
                          style: const pw.TextStyle(fontSize: 10))),

                pw.SizedBox(height: 10),
                pw.Divider(),

                /// REPORT TITLE
                pw.Center(
                  child: pw.Text(
                    'Bill Wise Sales Report',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    DateFormat('dd MMM yyyy hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                pw.SizedBox(height: 10),

                /// DATE RANGE
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Text(
                    'Period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} to ${DateFormat('dd/MM/yyyy').format(toDate!)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),

                pw.SizedBox(height: 12),

                /// TABLE
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.3),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                    6: const pw.FlexColumnWidth(1.8),
                    7: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    /// HEADER
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _headerCell('Bill'),
                        _headerCell('Customer'),
                        _headerCell('Qty'),
                        _headerCell('Total'),
                        _headerCell('Disc'),
                        _headerCell('Tax'),
                        _headerCell('Final'),
                        _headerCell('Date'),
                      ],
                    ),

                    /// DATA
                    ...billsData.map((bill) {
                      return pw.TableRow(
                        children: [
                          _cell(bill['billNo'].toString()),
                          _cell(bill['customerName'].toString()),
                          _cell((bill['totalItems'] ?? 0).toString()),
                          _cell("\u20B9${bill['totalAmount']}"),
                          _cell("\u20B9${bill['discount']}"),
                          _cell("\u20B9${bill['tax']}"),
                          _cell("\u20B9${bill['finalAmount']}"),
                          _cell(bill['orderDate'].toString()),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 20),

                /// TOTAL SUMMARY
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Bills: ${billsData.length}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
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
                            "\u20B9${totalAmount.toStringAsFixed(2)}",
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
              ],
            ),
          );

          return pdf.save();
        },
      );
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      SnackBarUtils.showError(
          context, '${AppLocale.errorCreatingPdf.getString(context)}: $e');
    }
  }

  /// TABLE HEADER CELL
  pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// TABLE CELL
  pw.Widget _cell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: MyText(
          text: AppLocale.billwiseReport.getString(context),
          color: Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 17,
        ),
      ),
      drawer: MyDrawer(
        phoneNo: uid,
        adminPhoneNo: adminUid,
      ),
      body: Column(
        children: [
          ReportNavBar(
            currentReport: 'Bill-wise',
            uid: uid,
            adminUid: adminUid,
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.history_toggle_off_rounded,
                                    color: Colors.red,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MyText(
                                        text: AppLocale.from
                                            .getString(context)
                                            .toUpperCase(),
                                        fontSize: 10,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2),
                                    MyText(
                                      text: fromDate == null
                                          ? AppLocale.select.getString(context)
                                          : DateFormat('dd MMM yyyy')
                                              .format(fromDate!),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, false),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.history_toggle_off_rounded,
                                    color: Colors.blue,
                                    size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    MyText(
                                        text: AppLocale.to
                                            .getString(context)
                                            .toUpperCase(),
                                        fontSize: 10,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2),
                                    MyText(
                                      text: toDate == null
                                          ? AppLocale.select.getString(context)
                                          : DateFormat('dd MMM yyyy')
                                              .format(toDate!),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ],
                                ),
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
                ? const ReportSkeleton(height: 150, borderRadius: 24)
                : billsData.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.receipt_long_outlined,
                                  size: 80, color: Colors.grey.shade200),
                            ),
                            const SizedBox(height: 20),
                            MyText(
                              text: fromDate == null || toDate == null
                                  ? AppLocale.chooseADateRange
                                      .getString(context)
                                      .toUpperCase()
                                  : AppLocale.noTransactionsFound
                                      .getString(context)
                                      .toUpperCase(),
                              color: Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: billsData.length,
                        itemBuilder: (context, index) {
                          final bill = billsData[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.grey.shade300, width: 0.6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Top Highlight
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.04),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.confirmation_number_rounded,
                                            color: primaryColor,
                                            size: 14),
                                      ),
                                      const SizedBox(width: 10),
                                      MyText(
                                        text: bill['billNo'],
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: primaryColor,
                                        letterSpacing: 0.5,
                                      ),
                                      const Spacer(),
                                      MyText(
                                        text: bill['orderDate'],
                                        color: Colors.grey[500],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              MyText(
                                                text: bill['customerName']
                                                        ?.toString()
                                                        .toUpperCase() ??
                                                    AppLocale.walkIn
                                                        .getString(context)
                                                        .toUpperCase(),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                                color: const Color(0xFF1F1F1F),
                                                letterSpacing: -0.5,
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  _buildBadge(
                                                      bill['paymentMethod'] ??
                                                          'Cash',
                                                      Icons.credit_card_rounded,
                                                      Colors.blue),
                                                  const SizedBox(width: 8),
                                                  _buildBadge(
                                                      '${bill['totalItems'].toInt()} ${AppLocale.items.getString(context)}',
                                                      Icons
                                                          .shopping_bag_rounded,
                                                      Colors.orange),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              MyText(
                                                text: PriceUtils.formatPrice(
                                                    bill['finalAmount']),
                                                color: const Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 24,
                                                letterSpacing: -1,
                                              ),
                                              MyText(
                                                text: AppLocale.totalPaid
                                                    .getString(context)
                                                    .toUpperCase(),
                                                color: Colors.grey[400],
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9F9F9),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _miniDetail(
                                                AppLocale.subtotal
                                                    .getString(context)
                                                    .toUpperCase(),
                                                PriceUtils.formatPrice(
                                                    bill['totalAmount'])),
                                            _miniDetail(
                                                AppLocale.discount
                                                    .getString(context)
                                                    .toUpperCase(),
                                                PriceUtils.formatPrice(
                                                    bill['discount']),
                                                isRed: true),
                                            _miniDetail(
                                                AppLocale.taxPaid
                                                    .getString(context)
                                                    .toUpperCase(),
                                                PriceUtils.formatPrice(
                                                    bill['tax'])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 15,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.print_rounded,
                  label: AppLocale.print.getString(context).toUpperCase(),
                  color: primaryColor,
                  enabled: billsData.isNotEmpty,
                  onTap: _printReport,
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: AppLocale.savePdf.getString(context).toUpperCase(),
                  color: primaryColor,
                  enabled: billsData.isNotEmpty,
                  onTap: _downloadAndShareReport,
                ),
                // const SizedBox(width: 12),
                // _actionButton(
                //   icon: Icons.search,
                //   label: "SEARCH BILL",
                //   color: primaryColor,
                //   enabled: billsData.isNotEmpty,
                //   onTap: () {
                //     Navigator.push(
                //         context,
                //         MaterialPageRoute(
                //             builder: (context) => SearchReceiptScreen(
                //                   phoneNumber: uid,
                //                 )));
                //   },
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDetail(String label, String value, {bool isRed = false}) {
    return Column(
      children: [
        MyText(
          text: label,
          color: Colors.grey[400],
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
        const SizedBox(height: 6),
        MyText(
          text: value,
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: isRed ? Colors.red[700] : const Color(0xFF2D2D2D),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.8)),
          const SizedBox(width: 6),
          MyText(
            text: text.toUpperCase(),
            color: color.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSummaryMiniCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 75,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                MyText(
                  text: title,
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MyText(
                text: value,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ],
        ),
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
              MyText(
                text: label,
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
