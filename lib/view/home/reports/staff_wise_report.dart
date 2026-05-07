import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/services/report_service.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/reports/widgets/report_nav_bar.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

class StaffWiseReportScreen extends StatefulWidget {
  final String uid;
  final String adminUid;

  const StaffWiseReportScreen({Key? key, required this.uid, required this.adminUid}) : super(key: key);

  @override
  State<StaffWiseReportScreen> createState() => _StaffWiseReportScreenState();
}

class _StaffWiseReportScreenState extends State<StaffWiseReportScreen> {
  DateTime? fromDate = DateTime.now();
  DateTime? toDate = DateTime.now();
  List<dynamic> staffReport = [];
  List<dynamic> orders = [];
  List<UserModel> staffList = [];
  String? selectedStaffId;
  bool isLoading = false;
  bool isInitialLoading = true;

  double totalSales = 0;
  int totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isInitialLoading = true);
    try {
      final staff = await UserService().getStaff(widget.adminUid);
      setState(() {
        staffList = staff;
        isInitialLoading = false;
      });
    } catch (e) {
      setState(() => isInitialLoading = false);
      SnackBarUtils.showError(context, 'Error loading staff: $e');
    }
  }

  Future<void> _fetchReport() async {
    if (fromDate == null || toDate == null) {
      SnackBarUtils.showWarning(context, 'Please select date range');
      return;
    }

    if (selectedStaffId == null || selectedStaffId!.isEmpty) {
      return;
    }

    setState(() => isLoading = true);
    try {
      final startDt = DateTime(fromDate!.year, fromDate!.month, fromDate!.day);
      final endDt = DateTime(toDate!.year, toDate!.month, toDate!.day, 23, 59, 59);

      final response = await ReportService().getStaffWiseReport(
        staffId: selectedStaffId,
        startDate: startDt,
        endDate: endDt,
      );

      final reportData = response['report'] ?? [];
      final ordersList = response['orders'] ?? [];

      double sales = 0;
      int ordersCount = 0;

      for (var item in reportData) {
        sales += (item['totalSales'] as num? ?? 0).toDouble();
        ordersCount += (item['totalOrders'] as num? ?? 0).toInt();
      }

      setState(() {
        staffReport = reportData;
        orders = ordersList;
        totalSales = sales;
        totalOrders = ordersCount;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      SnackBarUtils.showError(context, 'Error fetching report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const MyText(
          text: 'Staff Performance',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 22),
              onPressed: orders.isEmpty ? null : _saveAsPdf,
              tooltip: 'Export PDF',
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: MyDrawer(phoneNo: widget.uid, adminPhoneNo: widget.adminUid),
      body: Column(
        children: [
          ReportNavBar(currentReport: 'Staff-wise', uid: widget.uid, adminUid: widget.adminUid),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildFilterSection()),
                if (!isInitialLoading && selectedStaffId != null) ...[
                  SliverToBoxAdapter(
                    child: isLoading ? _buildSummaryShimmer() : _buildSummaryCards(),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const MyText(
                            text: 'Order History',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                          if (!isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: MyText(
                                text: '${orders.length} Orders',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isLoading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildOrderShimmer(),
                        childCount: 5,
                      ),
                    )
                  else if (orders.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: _emptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _orderTile(orders[index]),
                          childCount: orders.length,
                        ),
                      ),
                    ),
                ] else if (selectedStaffId == null && !isInitialLoading)
                  SliverFillRemaining(hasScrollBody: false, child: _noStaffSelectedState())
                else if (isInitialLoading)
                  SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: primaryColor, strokeWidth: 3)),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Select Filters',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          // Staff Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selectedStaffId,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                hint: const MyText(text: 'Choose a staff member', color: Color(0xFF64748B), fontSize: 14),
                items: staffList
                    .map((staff) => DropdownMenuItem(
                          value: staff.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: primaryColor.withOpacity(0.1),
                                child: MyText(
                                  text: staff.name[0].toUpperCase(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              MyText(text: staff.name, fontWeight: FontWeight.w600, fontSize: 14),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => selectedStaffId = val);
                  _fetchReport();
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Date Range
          Row(
            children: [
              Expanded(child: _dateTile('From Date', fromDate, true)),
              const SizedBox(width: 12),
              Expanded(child: _dateTile('To Date', toDate, false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime? date, bool isFrom) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: primaryColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            if (isFrom)
              fromDate = picked;
            else
              toDate = picked;
          });
          _fetchReport();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MyText(text: label, fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: primaryColor),
                const SizedBox(width: 8),
                MyText(
                  text: date == null ? 'Select' : DateFormat('dd MMM, yy').format(date),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _summaryCard(
            'Total Orders',
            totalOrders.toString(),
            Icons.shopping_cart_rounded,
            const Color(0xFF6366F1),
          ),
          const SizedBox(width: 16),
          _summaryCard(
            'Net Revenue',
            PriceUtils.formatPrice(totalSales),
            Icons.account_balance_wallet_rounded,
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 16),
            MyText(text: title, color: const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
            const SizedBox(height: 4),
            MyText(
              text: value,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: const Color(0xFF1E293B),
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTile(dynamic order) {
    final date = DateTime.parse(order['orderDate'].toString());
    final billNo = order['billNumber'] ?? 'N/A';
    final amount = (order['finalAmount'] ?? 0).toDouble();
    final customer = order['customerName'] ?? 'Walk-in';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Icon
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_rounded, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          // Middle: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: MyText(
                        text: '#$billNo',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MyText(
                  text: customer,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFF1E293B),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    MyText(
                      text: DateFormat('hh:mm a, dd MMM').format(date.toLocal()),
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MyText(
                text: PriceUtils.formatPrice(amount),
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: primaryColor,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const MyText(
                  text: 'Paid',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF166534),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Row(
          children: [
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
            const SizedBox(width: 16),
            Expanded(
                child: Container(
                    height: 120,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderShimmer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          height: 80,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 200,
            child: Lottie.asset('assets/lottie/bill2.json', repeat: true),
          ),
          const SizedBox(height: 16),
          const MyText(
            text: 'No orders found for this staff',
            color: Color(0xFF64748B),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          const MyText(
            text: 'Try selecting a different date range',
            color: Colors.grey,
            fontSize: 13,
          ),
        ],
      ),
    );
  }

  Widget _noStaffSelectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_outlined, size: 80, color: primaryColor.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const MyText(
            text: 'Select a Staff Member',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: MyText(
              text: 'Choose a staff member from the dropdown above to view their sales performance and order history.',
              textAlign: TextAlign.center,
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAsPdf() async {
    try {
      final pdf = pw.Document();
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shopName') ?? 'Shop Report';
      final staffName = staffList.firstWhere((s) => s.id == selectedStaffId).name;

      final regularFont = pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Regular.ttf'));
      final boldFont = pw.Font.ttf(await rootBundle.load('fonts/NotoSans-Bold.ttf'));

      pdf.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(
            base: regularFont,
            bold: boldFont,
          ),
          build: (context) => [
            pw.Center(child: pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
            pw.Center(child: pw.Text('Staff Performance Report', style: const pw.TextStyle(fontSize: 18))),
            pw.Center(child: pw.Text('Staff: $staffName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
            pw.Center(
                child: pw.Text(
                    'Period: ${DateFormat('dd/MM/yyyy').format(fromDate!)} - ${DateFormat('dd/MM/yyyy').format(toDate!)}')),
            pw.SizedBox(height: 20),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Orders:'),
                pw.Text(totalOrders.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Sales:'),
                pw.Text("\u20B9${totalSales.toStringAsFixed(2)}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Order History', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ['Bill #', 'Date', 'Customer', 'Amount'],
              data: orders
                  .map((order) => [
                        order['billNumber'],
                        DateFormat('dd/MM/yy hh:mm a').format(DateTime.parse(order['orderDate'].toString()).toLocal()),
                        order['customerName'] ?? 'Walk-in',
                        "\u20B9${(order['finalAmount'] ?? 0).toStringAsFixed(2)}"
                      ])
                  .toList(),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      SnackBarUtils.showError(context, 'PDF error: $e');
    }
  }

  Future<void> _printReport() async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    if (!printProvider.isConnected) {
      await showDialog(context: context, builder: (_) => const PrinterConnectionDialog());
      if (!printProvider.isConnected) return;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(printProvider.selectedPaperSize, profile);
      List<int> bytes = [];

      bytes += generator.text('STAFF PERFORMANCE REPORT',
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));

      final staffName = staffList.firstWhere((s) => s.id == selectedStaffId).name;
      bytes += generator.text('Staff: $staffName', styles: const PosStyles(align: PosAlign.center, bold: true));

      bytes += generator.text('From: ${DateFormat('dd/MM/yyyy').format(fromDate!)}',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('To: ${DateFormat('dd/MM/yyyy').format(toDate!)}',
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Summary', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Value', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Total Orders', width: 6),
        PosColumn(text: totalOrders.toString(), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Total Sales', width: 6),
        PosColumn(text: totalSales.toStringAsFixed(2), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr();
      bytes += generator.text('RECENT ORDERS', styles: const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'Bill #', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Date', width: 4, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Amount', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      for (var order in orders.take(20)) {
        final d = DateTime.parse(order['orderDate'].toString());
        bytes += generator.row([
          PosColumn(text: order['billNumber'].toString(), width: 4),
          PosColumn(text: DateFormat('dd/MM').format(d), width: 4, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(
              text: (order['finalAmount'] ?? 0).toStringAsFixed(2),
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      await PrinterManager.instance.send(type: printProvider.selectedPrinter!.typePrinter, bytes: bytes);
      SnackBarUtils.showSuccess(context, 'Report printed!');
    } catch (e) {
      SnackBarUtils.showError(context, 'Print error: $e');
    }
  }
}
