// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

// Package imports:
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos/data/services/report_service.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/view/home/reports/widgets/report_nav_bar.dart';

class DatewiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;

  const DatewiseReportScreen({Key? key, required this.uid, required this.adminUid}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const MyText(
          text: 'DATEWISE REPORT',
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
          letterSpacing: 1,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      drawer: MyDrawer(
        phoneNo: widget.uid,
        adminPhoneNo: widget.adminUid,
      ),
      body: Column(
        children: [
          ReportNavBar(
            currentReport: 'Date-wise',
            uid: widget.uid,
            adminUid: widget.adminUid,
          ),
          // Premium Date Selection
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            child: const Icon(Icons.history_toggle_off_rounded, color: Colors.red, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: 'FROM',
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                MyText(
                                  text: fromDate == null ? 'Select' : DateFormat('dd MMM yyyy').format(fromDate!),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            child: const Icon(Icons.history_toggle_off_rounded, color: Colors.blue, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: 'TO',
                                  fontSize: 10,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                MyText(
                                  text: toDate == null ? 'Select' : DateFormat('dd MMM yyyy').format(toDate!),
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
          ),

          // Summary Dashboard
          if (dateData.isNotEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _buildSummaryMiniCard(
                      'TOTAL DAYS',
                      dateData.length.toString(),
                      Icons.calendar_month_rounded,
                      Colors.indigo,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryMiniCard(
                      'TOTAL BILLS',
                      totalBills.toString(),
                      Icons.receipt_long_rounded,
                      Colors.orange.shade800,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryMiniCard(
                      'NET REVENUE',
                      PriceUtils.formatPrice(totalAmount),
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : dateData.isEmpty
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
                              child: Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade200),
                            ),
                            const SizedBox(height: 20),
                            MyText(
                              text: fromDate == null || toDate == null ? 'CHOOSE A DATE RANGE' : 'NO DATA FOUND',
                              color: Colors.grey[400],
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: dateData.length,
                        itemBuilder: (context, index) {
                          final date = dateData[index];
                          String displayDate = date['date']?.toString() ?? 'N/A';
                          try {
                            if (displayDate.contains('-')) {
                              DateTime dt = DateTime.parse(displayDate);
                              displayDate = DateFormat('dd MMM yyyy').format(dt);
                            } else if (displayDate.length == 8) {
                              final year = int.parse(displayDate.substring(0, 4));
                              final month = int.parse(displayDate.substring(4, 6));
                              final day = int.parse(displayDate.substring(6, 8));
                              displayDate = DateFormat('dd MMM yyyy').format(DateTime(year, month, day));
                            }
                          } catch (e) {}

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade300, width: 0.6),
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
                                // Date Header
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.04),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(Icons.event_note_rounded, color: primaryColor, size: 14),
                                      ),
                                      const SizedBox(width: 10),
                                      MyText(
                                        text: displayDate.toUpperCase(),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: primaryColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildBadge(
                                              '${date['totalBills']} BILLS', Icons.receipt_rounded, Colors.blue),
                                          const SizedBox(height: 12),
                                          MyText(
                                            text: 'DAILY SALES',
                                            color: Colors.grey[400],
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          MyText(
                                            text: PriceUtils.formatPrice(date['amount']),
                                            color: const Color(0xFF10B981),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 24,
                                            letterSpacing: -1,
                                          ),
                                          MyText(
                                            text: 'TOTAL COLLECTED',
                                            color: Colors.grey[400],
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ],
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

          // Action Section
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
                  label: "PRINT",
                  color: primaryColor,
                  enabled: dateData.isNotEmpty,
                  onTap: _printReport,
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: "SAVE PDF",
                  color: primaryColor,
                  enabled: dateData.isNotEmpty,
                  onTap: _downloadAndShareReport,
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
      initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
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
        const SnackBar(content: MyText(text: 'Please select both dates')),
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
      final startDt = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDt = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);

      final List<dynamic> report = await ReportService().getDateWiseReport(
        startDate: startDt,
        endDate: endDt,
      );

      double calculatedTotalAmount = 0;
      int calculatedTotalBills = 0;

      final processedData = report.map((item) {
        final amount = (item['totalSales'] ?? item['amount'] ?? 0).toDouble();
        final int bills = (item['count'] ?? item['totalBills'] ?? item['totalOrders'] ?? 0).toInt();

        calculatedTotalAmount += amount;
        calculatedTotalBills += bills;

        return {
          'date': item['_id'] ?? item['date'], // API usually groups by _id (date string)
          'totalBills': bills,
          'amount': amount,
        };
      }).toList();

      setState(() {
        dateData = processedData;
        totalAmount = calculatedTotalAmount;
        totalBills = calculatedTotalBills;
      });
    } catch (e) {
      if (mounted) {
        print('Error fetching date data from API: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: MyText(text: 'Error fetching data: $e')),
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
    final prefs = await SharedPreferences.getInstance();
    String shopName = prefs.getString('shopName') ?? 'Shop Name';

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
        PosColumn(text: 'Qty', width: 3, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Amount', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.text("-" * 32);

      // Data
      for (var date in dateData) {
        bytes += generator.row([
          PosColumn(text: date['date'].toString(), width: 6),
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
        PosColumn(text: 'Grand Total', width: 6, styles: const PosStyles(bold: true)),
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
      bytes += generator.text('Payment Summary', styles: const PosStyles(bold: true));
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
            content: MyText(text: 'Report printed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndShareReport() async {
    if (dateData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MyText(text: 'No data available. Please select dates and wait for data to load.'),
          backgroundColor: Colors.orange,
        ),
      );
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

      final regularFont = pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Regular.ttf'));
      final boldFont = pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Bold.ttf'));

      if (mounted) Navigator.of(context).pop();

      await Printing.layoutPdf(
        name: 'DatewiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
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
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                if (address.isNotEmpty) pw.Center(child: pw.Text(address, style: const pw.TextStyle(fontSize: 10))),
                if (contact.isNotEmpty)
                  pw.Center(child: pw.Text('Contact: $contact', style: const pw.TextStyle(fontSize: 10))),
                if (gstNo.isNotEmpty) pw.Center(child: pw.Text('GST: $gstNo', style: const pw.TextStyle(fontSize: 10))),

                pw.SizedBox(height: 10),
                pw.Divider(),

                /// REPORT TITLE
                pw.Center(
                  child: pw.Text(
                    'Date Wise Sales Report',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
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
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    /// HEADER
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _pdfHeaderCell('Date'),
                        _pdfHeaderCell('Total Bills'),
                        _pdfHeaderCell('Amount'),
                      ],
                    ),

                    /// DATA
                    ...dateData.map((date) {
                      String displayDate = '';
                      try {
                        final dateStr = date['date'].toString();
                        final year = dateStr.substring(0, 4);
                        final month = dateStr.substring(4, 6);
                        final day = dateStr.substring(6, 8);
                        displayDate = '$day/$month/${year.substring(2)}';
                      } catch (_) {
                        displayDate = date['date'].toString();
                      }

                      return pw.TableRow(
                        children: [
                          _pdfCell(displayDate),
                          _pdfCell(date['totalBills'].toString()),
                          _pdfCell("₹${date['amount']}"),
                        ],
                      );
                    }).toList(),
                  ],
                ),

                pw.SizedBox(height: 15),
                pw.Divider(),

                /// SUMMARY
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Days: ${dateData.length}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Total Bills: $totalBills', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Grand Total: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                          pw.Text(
                            "₹${totalAmount.toStringAsFixed(2)}",
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

                /// FOOTER
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
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: MyText(text: 'PDF generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MyText(text: 'Error creating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  Widget _buildSummaryMiniCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            MyText(
              text: value,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.9),
              letterSpacing: -0.5,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            MyText(
              text: label,
              fontSize: 9,
              color: Colors.grey[400],
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          MyText(
            text: label,
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ],
      ),
    );
  }

  Widget _miniDetail(String label, String value, {bool isRed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyText(
          text: label,
          fontSize: 9,
          color: Colors.grey[400],
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        const SizedBox(height: 4),
        MyText(
          text: value,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isRed ? Colors.red[700] : const Color(0xFF1F1F1F),
        ),
      ],
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
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: enabled ? color : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: enabled ? Colors.white : Colors.grey.shade400, size: 18),
                const SizedBox(width: 10),
                MyText(
                  text: label,
                  color: enabled ? Colors.white : Colors.grey.shade400,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
