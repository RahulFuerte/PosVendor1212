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

class ItemwiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;

  const ItemwiseReportScreen({Key? key, required this.uid, required this.adminUid}) : super(key: key);

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
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const MyText(
          text: 'ITEMWISE REPORT',
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
            currentReport: 'Item-wise',
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
          if (itemsData.isNotEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _buildSummaryMiniCard(
                      'TOTAL ITEMS',
                      itemsData.length.toString(),
                      Icons.inventory_2_rounded,
                      Colors.indigo,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryMiniCard(
                      'TOTAL QTY',
                      totalQuantity.toStringAsFixed(1),
                      Icons.shopping_basket_rounded,
                      Colors.orange.shade800,
                    ),
                    const SizedBox(width: 10),
                    _buildSummaryMiniCard(
                      'NET SALES',
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
                : itemsData.isEmpty
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
                              child: Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade200),
                            ),
                            const SizedBox(height: 20),
                            MyText(
                              text: fromDate == null || toDate == null ? 'CHOOSE A DATE RANGE' : 'NO ITEMS FOUND',
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
                        itemCount: itemsData.length,
                        itemBuilder: (context, index) {
                          final item = itemsData[index];
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
                                // Item Header
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
                                        child: Icon(Icons.lunch_dining_rounded, color: primaryColor, size: 14),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MyText(
                                          text: item['name'].toString().toUpperCase(),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: primaryColor,
                                          letterSpacing: 0.5,
                                          maxLines: 1,
                                        ),
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
                                          _buildBadge('${item['quantity'].toStringAsFixed(1)} SOLD',
                                              Icons.shopping_cart_rounded, Colors.orange.shade800),
                                          const SizedBox(height: 12),
                                          MyText(
                                            text: 'QUANTITY METRIC',
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
                                            text: PriceUtils.formatPrice(item['amount']),
                                            color: const Color(0xFF10B981),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 24,
                                            letterSpacing: -1,
                                          ),
                                          MyText(
                                            text: 'TOTAL SALES',
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
                  enabled: itemsData.isNotEmpty,
                  onTap: _printReport,
                ),
                const SizedBox(width: 12),
                _actionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  label: "SAVE PDF",
                  color: primaryColor,
                  enabled: itemsData.isNotEmpty,
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
        await _fetchItemsData();
      }
    }
  }

  Future<void> _fetchItemsData() async {
    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: MyText(text: 'Please select both dates')),
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
      final startDt = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDt = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);

      final List<dynamic> report = await ReportService().getItemWiseReport(
        startDate: startDt,
        endDate: endDt,
      );

      double calculatedTotalAmount = 0;
      double calculatedTotalQuantity = 0;

      final processedData = report.map((item) {
        final name = item['itemName'] ?? item['name'] ?? item['_id']?.toString() ?? 'Unknown';
        final qty = (item['quantitySold'] ?? item['totalQuantity'] ?? item['quantity'] ?? 0).toDouble();
        final amt = (item['totalSales'] ?? item['totalAmount'] ?? item['amount'] ?? 0).toDouble();

        calculatedTotalAmount += amt;
        calculatedTotalQuantity += qty;

        return {
          'name': name,
          'quantity': qty,
          'amount': amt,
        };
      }).toList();

      setState(() {
        itemsData = processedData;
        totalAmount = calculatedTotalAmount;
        totalQuantity = calculatedTotalQuantity;
      });

      // Sort by amount descending
      itemsData.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    } catch (e) {
      if (mounted) {
        print('Error fetching items data from API: $e');
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

    try {
      PaperSize paperSize = printProvider.selectedPaperSize;
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      bool is58mm = paperSize == PaperSize.mm58;
      int totalCols = is58mm ? 32 : 48;
      String separator = '-' * totalCols;

      // SAFE amount formatter (NO ₹)
      String formatAmount(dynamic value) {
        final amount = (value ?? 0) as num;
        return amount.toStringAsFixed(2);
      }

      // ================= HEADER =================

      bytes += generator.text(
        'ITEM WISE REPORT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.feed(1);

      bytes += generator.text(
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text(separator);

      bytes += generator.text(
        'From: ${DateFormat('dd/MM/yy').format(fromDate!)}',
      );

      bytes += generator.text(
        'To  : ${DateFormat('dd/MM/yy').format(toDate!)}',
      );

      bytes += generator.text(separator);

      // ================= TABLE HEADER =================

      bytes += generator.row([
        PosColumn(
          text: 'Item',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Qty',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: 'Amt',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += generator.text(separator);

      // ================= ITEMS =================

      for (int i = 0; i < itemsData.length; i++) {
        final item = itemsData[i];

        bytes += generator.row([
          PosColumn(
            text: item['name'].toString(),
            width: 6,
          ),
          PosColumn(
            text: (item['quantity'] as num).toStringAsFixed(1),
            width: 3,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: formatAmount(item['amount']),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.text(separator);

      // ================= TOTAL =================

      bytes += generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: totalQuantity.toStringAsFixed(1),
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: formatAmount(totalAmount),
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);

      bytes += generator.text(separator);

      bytes += generator.feed(2);

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
    if (itemsData.isEmpty) {
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
        name: 'ItemwiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
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
                    'Item Wise Sales Report',
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
                    0: const pw.FixedColumnWidth(30),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    /// HEADER
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        _pdfHeaderCell('Sr.'),
                        _pdfHeaderCell('Item Name'),
                        _pdfHeaderCell('Qty'),
                        _pdfHeaderCell('Amount'),
                      ],
                    ),

                    /// DATA
                    ...List.generate(itemsData.length, (index) {
                      final item = itemsData[index];
                      return pw.TableRow(
                        children: [
                          _pdfCell((index + 1).toString()),
                          _pdfCell(item['name']?.toString() ?? ''),
                          _pdfCell(item['quantity'].toString()),
                          _pdfCell("₹${item['amount']}"),
                        ],
                      );
                    }),
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
                          pw.Text('Total Items: ${itemsData.length}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text('Total Qty: $totalQuantity', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
