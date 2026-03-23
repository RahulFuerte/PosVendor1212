import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/screens/receipt_data_screen.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/data/services/report_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  final String name;
  final String phoneNo;
  final String adminUid;
  const Dashboard({super.key, required this.phoneNo, required this.adminUid, required this.name});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Map<String, dynamic>> orders = [];
  bool isLoading = false;
  int selectedTab = 0;
  int totalBills = 0;
  int totalSales = 0;
  int totalExpenses = 0;

  late String monthKey;
  late String dateKey;

  DateTime selectedDate = DateTime.now();
  String selectedOrderType = 'all';

  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final ReportService _reportService = ReportService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    monthKey = DateFormat('yyyyMM').format(now);
    dateKey = DateFormat('yyyyMMdd').format(now);

    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      setState(() => isLoading = true);

      // Online-Only Fetch Logic
      final apiResponse = await _reportService.getDashboardReport(
        date: selectedDate,
        orderType: selectedOrderType == 'all' ? null : selectedOrderType,
      );

      if (apiResponse['success'] == true) {
        final data = apiResponse; // Fields are at top level
        final List<dynamic> apiOrders = data['orders'] ?? [];

        setState(() {
          orders = apiOrders.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          totalBills = (data['totalBills'] ?? apiOrders.length).toInt();
          totalSales = ((data['totalSales'] ?? 0) as num).toInt();
          totalExpenses = ((data['totalExpense'] ?? 0) as num).toInt();
        });
      } else {
        debugPrint('Dashboard API returned success: false');
        setState(() {
          orders = [];
          totalBills = 0;
          totalSales = 0;
          totalExpenses = 0;
        });
      }
    } catch (e) {
      debugPrint('Dashboard Fetch Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: MyText(text: 'Failed to fetch dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _orderTypeText(String type) {
    String t = type.toLowerCase();
    if (t == 'dinein') return 'DineIn';
    if (t == 'pickup') return 'PickUp';
    if (t == 'delivery') return 'Delivery';
    return type;
  }

  Color _orderTypeColor(String type) {
    String t = type.toLowerCase();
    if (t == 'dinein') return Colors.teal;
    if (t == 'pickup') return Colors.orange;
    if (t == 'delivery') return Colors.red;
    return Colors.grey;
  }

  Future<void> _handlePrint({
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required String customerName,
    required String customerPhone,
    required String customerGst,
    required String customerNote,
    required String customerAddress,
    required double discountAmount,
    required double discountPercent,
    required String receiptNo,
    required String orderType,
    required String paymentType,
  }) async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
      showDialog(
        context: context,
        builder: (context) => const PrinterConnectionDialog(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MyText(text: 'Please connect a printer first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: MyText(text: 'No items to print'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate sequential receipt number (returns 8-digit padded string like "00000001")
      String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);
      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last;
      String orderType = orderTypeProvider.orderType.toString().split('.').last;

      // Fetch shop data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String shopName = prefs.getString('shopName') ?? 'Shop Name';
      String contact = prefs.getString('contact') ?? 'Contact';
      String address = prefs.getString('address') ?? 'Address';
      String logoUrl = prefs.getString('logoUrl') ?? '';
      String upiId = prefs.getString('upiId') ?? "";

      if (!mounted) return;
      Navigator.pop(context);

      await DirectPrintHelper().printReceipt(
        adminUid: widget.phoneNo,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: items,
        subTotal: subTotal,
        shopName: shopName,
        contact: contact,
        address: address,
        logoUrl: logoUrl,
        upiId: upiId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerGst: customerGst,
        customerNote: customerNote,
        customerAddress: customerAddress,
        orderType: orderType,
        paymentType: paymentType,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        receiptNo: receiptNo,
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        saveBill: false,
      );

      if (!mounted) return;
      final isOnline = _databaseService.isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MyText(
                  text: isOnline
                      ? 'Printed & saved! Receipt: $generatedReceiptNo'
                      : 'Printed & saved offline! Receipt: $generatedReceiptNo',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error printing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: MyText(text: 'Printing failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Navigation(
                // phoneNo: widget.phoneNo,
                uId: widget.phoneNo,
              ),
            ),
          );
        },
        backgroundColor: appbar1,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(Icons.add_shopping_cart),
      ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MyText(
              text: widget.name,
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 22,
            ),
            MyText(
              text: widget.phoneNo,
              fontSize: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
      drawer: MyDrawer(
        phoneNo: widget.phoneNo,
        adminPhoneNo: widget.phoneNo,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: appbar1,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _InfoCard(
                        title: "Sales",
                        value: PriceUtils.formatPrice(totalSales),
                        icon: Icons.point_of_sale,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      _InfoCard(
                        title: "Total Bills",
                        value: numberFormat.format(totalBills),
                        icon: Icons.receipt,
                        color: appbar1,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      _InfoCard(
                        title: "Total Expenses",
                        value: PriceUtils.formatPrice(totalExpenses),
                        icon: Icons.trending_down,
                        color: Colors.red.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MyText(
                          text: 'Filter Orders',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            /// 📅 DATE FILTER
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2023),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                    fetchOrders();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: appbar1.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: appbar1.withOpacity(0.25)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month, color: appbar1),
                                      const SizedBox(width: 10),
                                      MyText(
                                        text: DateFormat('dd MMM yyyy').format(selectedDate),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            /// 🍽 ORDER TYPE FILTER
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedOrderType,
                                isDense: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: appbar1.withOpacity(0.08),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: MyText(text: 'All Orders'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DineIn',
                                    child: MyText(text: '🍽 Dine In'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'PickUp',
                                    child: MyText(text: '🛍 Pick Up'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Delivery',
                                    child: MyText(text: '🚚 Delivery'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => selectedOrderType = value!);
                                  fetchOrders();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TabButton(
                            title: 'Orders',
                            active: selectedTab == 0,
                            onTap: () => setState(() => selectedTab = 0),
                          ),
                        ),
                        Expanded(
                          child: _TabButton(
                            title: 'KOTS',
                            active: selectedTab == 1,
                            onTap: () => setState(() => selectedTab = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  const SizedBox(height: 15),
                  selectedTab == 0
                      ? orders.isEmpty
                          ? const Center(child: MyText(text: 'No Orders Found'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const MyText(
                                        text: "Recent Orders",
                                        fontSize: 20,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      const MyText(
                                        text: "",
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  ),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    final data = orders[index];
                                    final dateMs = data['bill_date'] ?? data['created_at'];
                                    String timeStr = DateFormat('dd/MM/yy hh:mm a').format(DateTime.now());
                                    if (dateMs != null) {
                                      try {
                                        final dt = dateMs is int
                                            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
                                            : DateTime.parse(dateMs.toString());
                                        timeStr = DateFormat('dd/MM/yy hh:mm a').format(dt);
                                      } catch (_) {}
                                    }

                                    return OrderTile(
                                      bill: data['billNumber'] ?? data['id'] ?? '0',
                                      amount: ((data['finalAmount'] ?? data['final_total'] ?? data['sub_total'] ?? 0)
                                              as num)
                                          .toInt(),
                                      time: timeStr,
                                      typeText: _orderTypeText(data['orderType'] ?? data['order_type'] ?? 'all'),
                                      typeColor: _orderTypeColor(data['orderType'] ?? data['order_type'] ?? 'all'),
                                      onTap: () async {
                                        final prefs = await SharedPreferences.getInstance();
                                        final items = (data['items'] as List<dynamic>? ?? [])
                                            .map((e) => Map<String, dynamic>.from(e as Map))
                                            .toList();
                                        // ignore: use_build_context_synchronously
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReceiptPreviewOnlyWidget(
                                              userPhoneNumber: widget.phoneNo,
                                              shopName: prefs.getString('shopName') ?? 'Shop Name',
                                              address: prefs.getString('address') ?? 'Address',
                                              contact: prefs.getString('contact') ?? 'Contact',
                                              receiptNo: (data['billNumber'] ?? '').toString(),
                                              dateTime: DateTime.fromMillisecondsSinceEpoch(
                                                  dateMs is int ? dateMs : int.tryParse(dateMs.toString()) ?? 0),
                                              items: items,
                                              subTotal: ((data['totalAmount'] ??
                                                      data['subTotal'] ??
                                                      data['sub_total'] ??
                                                      0) as num)
                                                  .toDouble(),
                                              finalTotal: ((data['finalAmount'] ??
                                                      data['final_total'] ??
                                                      data['sub_total'] ??
                                                      0) as num)
                                                  .toDouble(),
                                              discountAmount:
                                                  ((data['discount'] ?? data['discount_amount'] ?? 0) as num)
                                                      .toDouble(),
                                              roundOff: 0,
                                              taxEnabled: (data['tax'] ?? 0) > 0 || data['tax_enabled'] == 1,
                                              cgstPercent: ((data['cgst_percent'] ?? 0) as num).toDouble(),
                                              sgstPercent: ((data['sgst_percent'] ?? 0) as num).toDouble(),
                                              paymentType: data['payment_type'] ?? 'cash',
                                              orderType: _orderTypeText(data['orderType'] ?? data['order_type'] ?? ''),
                                              customerName: data['customer_name'],
                                              customerPhone: data['customer_phone'],
                                              customerGst: data['customer_gst'],
                                              customerAddress: data['customer_address'],
                                              note: data['customer_note'],
                                            ),
                                          ),
                                        );
                                      },
                                      onPrint: () {
                                        final rawItems = data['items'] as List<dynamic>? ?? [];
                                        final items = rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                                        _handlePrint(
                                          items: items,
                                          subTotal: ((data['totalAmount'] ?? data['subTotal'] ?? data['sub_total'] ?? 0)
                                                  as num)
                                              .toDouble(),
                                          customerName: data['customer_name'] ?? '',
                                          customerPhone: data['customer_phone'] ?? '',
                                          customerGst: data['customer_gst'] ?? '',
                                          customerNote: data['customer_note'] ?? '',
                                          customerAddress: data['customer_address'] ?? '',
                                          discountAmount:
                                              ((data['discount'] ?? data['discount_amount'] ?? 0) as num).toDouble(),
                                          discountPercent: ((data['discount_percent'] ?? 0) as num).toDouble(),
                                          receiptNo: data['billNumber']?.toString() ?? '',
                                          orderType: data['orderType'] ?? data['order_type'] ?? '',
                                          paymentType: data['payment_type'] ?? 'cash',
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 60),
                              ],
                            )
                      : ListView(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          children: const [
                            KOTTile(kotNo: 101, table: 'T1', items: 3),
                            KOTTile(kotNo: 102, table: 'T2', items: 5),
                            KOTTile(kotNo: 103, table: 'Parcel', items: 2),
                          ],
                        ),
                ],
              ),
            ),
    );
  }
}

/// INFO CARD
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          border: Border.all(color: color, width: 0.2),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MyText(text: title, color: color, fontWeight: FontWeight.w600, fontSize: 18),
                        Icon(icon, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MyText(
                      text: value,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TAB BUTTON
class _TabButton extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: active ? appbar1 : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.center,
        child: MyText(
          text: title,
          color: active ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }
}

/// ORDER TILE
class OrderTile extends StatelessWidget {
  final String bill;
  final int amount;
  final String time;
  final bool edited;
  final String typeText;
  final Color typeColor;
  final VoidCallback onPrint;
  final VoidCallback onTap;

  const OrderTile({
    super.key,
    required this.bill,
    required this.amount,
    required this.time,
    this.edited = false,
    required this.typeText,
    required this.typeColor,
    required this.onPrint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border(left: BorderSide(color: typeColor, width: 5)),
            boxShadow: [BoxShadow(blurRadius: 2, spreadRadius: 3, color: Colors.grey.shade100, offset: Offset(0, 3))]),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  MyText(text: '$bill', fontWeight: FontWeight.bold, fontSize: 15),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: MyText(
                      text: typeText,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                MyText(text: '$time${edited ? '  Edited' : ''}', fontSize: 13, color: Colors.grey),
              ]),
            ),
            Column(
              children: [
                MyText(text: '₹$amount', fontSize: 21, fontWeight: FontWeight.bold),
                IconButton(
                  onPressed: onPrint,
                  icon: Icon(Icons.local_print_shop_outlined, color: appbar1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// KOT TILE
class KOTTile extends StatelessWidget {
  final int kotNo;
  final String table;
  final int items;

  const KOTTile({
    super.key,
    required this.kotNo,
    required this.table,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: appbar1, width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          /// KOT NUMBER
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'KOT',
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              MyText(
                text: '#$kotNo',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),

          const SizedBox(width: 16),

          /// DIVIDER
          Container(
            height: 35,
            width: 1,
            color: Colors.grey.shade300,
          ),

          const SizedBox(width: 16),

          /// TABLE INFO
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'TABLE',
                fontSize: 11,
                color: Colors.grey,
              ),
              MyText(
                text: table,
                fontWeight: FontWeight.w600,
              ),
            ],
          ),

          const Spacer(),

          /// ITEMS COUNT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: appbar1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: MyText(
              text: '$items Items',
              fontWeight: FontWeight.w600,
              color: appbar1,
            ),
          ),
        ],
      ),
    );
  }
}
