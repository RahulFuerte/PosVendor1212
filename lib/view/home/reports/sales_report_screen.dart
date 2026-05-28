// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/l10n/app_locale.dart';

// Package imports:
import 'package:intl/intl.dart';
import 'package:pos/data/services/report_service.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:shimmer/shimmer.dart';
import 'package:pos/view/home/reports/widgets/report_skeleton.dart';

// Project imports:
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/view/home/reports/report_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({Key? key}) : super(key: key);

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  String adminUid = '';
  String uid = '';

  DateTime selectedDate = DateTime.now();
  String selectedMonth = DateFormat('yyyyMM').format(DateTime.now());
  bool isLoading = true;
  double totalSales = 0.0;
  int totalOrders = 0;
  double totalDiscount = 0.0;
  double totalTax = 0.0;
  List<Map<String, dynamic>> productSales = [];
  final ReportService _reportService = ReportService();

  // Generate last 12 months for dropdown
  List<Map<String, String>> get monthsList {
    List<Map<String, String>> months = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      DateTime month = DateTime(now.year, now.month - i, 1);
      months.add({
        'value': DateFormat('yyyyMM').format(month),
        'label': DateFormat('MMMM yyyy').format(month),
      });
    }
    return months;
  }

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      uid = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
    });
    fetchSalesData();
  }

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final data = await _reportService.getSalesReport(date: selectedDate);
      setState(() {
        totalSales = (data['totalSales'] ?? 0.0).toDouble();
        totalOrders = (data['totalOrders'] ?? 0);
        totalDiscount = (data['totalDiscount'] ?? 0.0).toDouble();
        totalTax = (data['totalTax'] ?? 0.0).toDouble();

        // Support both topSellingItems and productSales from API
        final sales = (data['topSellingItems'] ?? data['productSales'])
                as List<dynamic>? ??
            [];
        productSales = sales.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          // Calculate price if missing
          if (map['price'] == null &&
              map['quantity'] != null &&
              (map['quantity'] as num) > 0) {
            map['price'] =
                (map['totalAmount'] ?? 0.0) / (map['quantity'] as num);
          }
          return map;
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sales data from API: $e');
      setState(() {
        isLoading = false;
      });
      SnackBarUtils.showError(context, 'Error: ${e.toString()}');
    }
  }

  void changeDate(int days) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
      // Update selected month if date changes month
      selectedMonth = DateFormat('yyyyMM').format(selectedDate);
    });
    fetchSalesData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: MyText(
          text: AppLocale.salesReport.getString(context),
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
            currentReport: 'Sales',
            uid: uid,
            adminUid: adminUid,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchSalesData,
              color: primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Date and Month Selector Card
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => changeDate(-1),
                                icon: const Icon(Icons.chevron_left, size: 28),
                                color: primaryColor,
                              ),
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: primaryColor.withOpacity(0.1)),
                                  ),
                                  child: Center(
                                    child: MyText(
                                      text: DateFormat('MMM dd, yyyy')
                                          .format(selectedDate),
                                      color: primaryColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: selectedDate.isBefore(DateTime.now()
                                        .subtract(const Duration(hours: 23)))
                                    ? () => changeDate(1)
                                    : null,
                                icon: const Icon(Icons.chevron_right, size: 28),
                                color: selectedDate.isBefore(DateTime.now()
                                        .subtract(const Duration(hours: 23)))
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                            ],
                          ),
                        ),

                        // Total Sales Card
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[400]!, primaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                               Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.account_balance_wallet,
                                      color: Colors.white, size: 28),
                                  const SizedBox(width: 8),
                                  MyText(
                                    text:
                                        AppLocale.totalSales.getString(context),
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              isLoading
                                  ? Shimmer.fromColors(
                                      baseColor: Colors.white.withOpacity(0.3),
                                      highlightColor:
                                          Colors.white.withOpacity(0.1),
                                      child: Container(
                                        height: 40,
                                        width: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: MyText(
                                        text:
                                            PriceUtils.formatPrice(totalSales),
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        // Summary Stats Row
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              _buildSummaryCard(
                                AppLocale.orders.getString(context),
                                totalOrders.toString(),
                                Icons.shopping_bag_outlined,
                                Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildSummaryCard(
                                AppLocale.discount.getString(context),
                                PriceUtils.formatPrice(totalDiscount),
                                Icons.local_offer_outlined,
                                Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              _buildSummaryCard(
                                AppLocale.tax.getString(context),
                                PriceUtils.formatPrice(totalTax),
                                Icons.receipt_long_outlined,
                                Colors.purple,
                              ),
                            ],
                          ),
                        ),

                        // Products List Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              const Icon(Icons.trending_up,
                                  color: Colors.blue, size: 24),
                              const SizedBox(width: 8),
                              MyText(
                                text: AppLocale.productSales.getString(context),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              const Spacer(),
                              if (!isLoading)
                                MyText(
                                  text:
                                      '${productSales.length} ${AppLocale.item.getString(context)}',
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: ReportSkeleton(height: 100, borderRadius: 16),
                      ),
                    )
                  else if (productSales.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            MyText(
                              text: AppLocale.noSalesDataAvailable
                                  .getString(context),
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final product = productSales[index];
                            final double maxQuantity = productSales.isNotEmpty
                                ? productSales
                                    .map((e) =>
                                        (e['quantity'] as num).toDouble())
                                    .reduce((a, b) => a > b ? a : b)
                                : 1.0;
                            final double quantity =
                                (product['quantity'] as num).toDouble();
                            final double percentage =
                                (quantity / maxQuantity * 100)
                                    .clamp(0, 100)
                                    .toDouble();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green[300]!,
                                              Colors.green[800]!
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: MyText(
                                            text: '#${index + 1}',
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            MyText(
                                              text: product['name'],
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              maxLines: 1,
                                            ),
                                            const SizedBox(height: 4),
                                            MyText(
                                              text:
                                                  '${PriceUtils.formatPrice(product['price'])} ${AppLocale.perUnit.getString(context)}',
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          MyText(
                                            text: PriceUtils.formatPrice(
                                                product['totalAmount']),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: MyText(
                                              text:
                                                  '${product['quantity']} ${AppLocale.sold.getString(context)}',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: percentage / 100,
                                        child: Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.green[400]!,
                                                Colors.green[800]!
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green
                                                    .withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  MyText(
                                    text:
                                        '${percentage.toStringAsFixed(1)}% ${AppLocale.ofTopSeller.getString(context)}',
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: productSales.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        height: 110, // Slightly reduced for better fit
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: MyText(
                text: value,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            MyText(
              text: title.toUpperCase(),
              color: Colors.grey[500],
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ],
        ),
      ),
    );
  }
}
