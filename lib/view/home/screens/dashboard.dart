import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
import 'package:provider/provider.dart';

class Dashboard extends StatefulWidget {
  final String name;
  final String phoneNo;
  final String adminUid;
  const Dashboard({super.key, required this.phoneNo, required this.adminUid, required this.name});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<QueryDocumentSnapshot> orders = [];
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

      final monthKey = DateFormat('yyyyMM').format(selectedDate);
      final dateKey = DateFormat('yyyyMMdd').format(selectedDate);
      final yearMonth = "${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}";

      final snapshot = await FirebaseFirestore.instance
          .collection('AllBills')
          .doc(widget.phoneNo)
          .collection('myBills')
          .doc(monthKey)
          .collection(dateKey)
          .orderBy('createdAt', descending: true)
          .get();

      final expensesnapshot = await FirebaseFirestore.instance
          .collection('AllExpense')
          .doc(widget.phoneNo)
          .collection('expenses')
          .doc(yearMonth)
          .collection('list')
          .where('date', isGreaterThanOrEqualTo: DateTime(selectedDate.year, selectedDate.month, selectedDate.day))
          .where('date', isLessThan: DateTime(selectedDate.year, selectedDate.month, selectedDate.day + 1))
          .get();

      List<QueryDocumentSnapshot> filtered = snapshot.docs;

      if (selectedOrderType != 'all') {
        filtered = filtered.where((doc) {
          return doc['orderType'] == selectedOrderType;
        }).toList();
      }

      int sales = 0;
      for (var doc in filtered) {
        sales += (doc['finalTotal'] as num).toInt();
      }

      int total = 0;
      for (var doc in expensesnapshot.docs) {
        total += (doc['amount'] as num).toInt();
      }

      setState(() {
        orders = filtered;
        totalBills = filtered.length;
        totalSales = sales;
        totalExpenses = total;
      });
    } catch (e) {
      debugPrint('Fetch Orders Error: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  String _orderTypeText(String type) {
    if (type == 'dineIn') return 'Dine In';
    if (type == 'pickUp') return 'Pick Up';
    if (type == 'delivery') return 'Delivery';
    return 'Order';
  }

  Color _orderTypeColor(String type) {
    if (type == 'dineIn') return Colors.teal;
    if (type == 'pickUp') return Colors.orange;
    if (type == 'delivery') return Colors.red;
    return Colors.grey;
  }

  Future<Map<String, String>> _getShopData() async {
    String shopName = 'N/A';
    String contact = 'N/A';
    String address = 'N/A';
    String logoUrl = '';

    try {
      // First try to get from local SQLite
      final localData = await _sqliteHelper.getUserData(widget.phoneNo);

      if (localData != null) {
        shopName = localData['shopName'] ?? 'N/A';
        contact = localData['shopContact'] ?? 'N/A';
        address = localData['address'] ?? 'N/A';
        logoUrl = localData['shopLogoUrl'] ?? '';
        debugPrint('Shop data loaded from local cache');
      } else {
        // Not found locally, fetch from Firebase
        final doc = await FirebaseFirestore.instance
            .collection('AllAdmins')
            .doc(widget.adminUid)
            .collection('customer')
            .doc(widget.phoneNo)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            shopName = data['shopName'] ?? 'N/A';
            contact = data['contact'] ?? 'N/A';
            address = data['address'] ?? 'N/A';

            // Save all fields to local SQLite for future use
            await _sqliteHelper.saveUserData({
              'phoneNumber': data['phoneNumber'] ?? widget.phoneNo,
              'adminUid': data['adminUid'] ?? widget.adminUid,
              'shopName': shopName,
              'contact': contact,
              'address': address,
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
    };
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
          content: Text('Please connect a printer first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items to print'),
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

      // Fetch shop data (local-first)
      final shopData = await _getShopData();
      String shopName = shopData['shopName']!;
      String contact = shopData['contact']!;
      String address = shopData['address']!;
      String logoUrl = shopData['logoUrl']!;
      String upiId = shopData['upiId']!;

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
                child: Text(
                  isOnline
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
          content: Text('Printing failed: $e'),
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
            Text(
              widget.name,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 22),
            ),
            Text(
              widget.phoneNo,
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
                        const Text(
                          'Filter Orders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
                                      Text(
                                        DateFormat('dd MMM yyyy').format(selectedDate),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
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
                                    child: Text('All Orders'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'dineIn',
                                    child: Text('🍽 Dine In'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'pickUp',
                                    child: Text('🛍 Pick Up'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'delivery',
                                    child: Text('🚚 Delivery'),
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
                          ? const Center(child: Text('No Orders Found'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 5.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Recent Orders",
                                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        "",
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.blue),
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

                                    return OrderTile(
                                      bill: int.tryParse(data['receiptNo'].toString()) ?? 0,
                                      amount: (data['finalTotal'] as num).toInt(),
                                      time: DateFormat('dd/MM/yy hh:mm a').format(data['createdAt'].toDate()),
                                      typeText: _orderTypeText(data['orderType']),
                                      typeColor: _orderTypeColor(data['orderType']),
                                      onTap: () async {
                                        final shopData = await _getShopData();
                                        final data = orders[index];

                                        // ignore: use_build_context_synchronously
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ReceiptPreviewOnlyWidget(
                                              userPhoneNumber: widget.phoneNo,
                                              shopName: shopData['shopName']!,
                                              address: shopData['address']!,
                                              contact: shopData['contact']!,
                                              receiptNo: data['receiptNo'].toString(),
                                              dateTime: data['createdAt'].toDate(),
                                              items: List<Map<String, dynamic>>.from(data['items']),
                                              subTotal: (data['subTotal'] as num).toDouble(),
                                              finalTotal: (data['finalTotal'] as num).toDouble(),
                                              discountAmount: (data['discountAmount'] ?? 0).toDouble(),
                                              roundOff: 0,
                                              taxEnabled: data['taxEnabled'] ?? false,
                                              cgstPercent: (data['cgstPercent'] ?? 0).toDouble(),
                                              sgstPercent: (data['sgstPercent'] ?? 0).toDouble(),
                                              paymentType: data['paymentType'],
                                              orderType: _orderTypeText(data['orderType']),
                                              customerName: data['customerName'],
                                              customerPhone: data['customerPhone'],
                                              customerGst: data['customerGst'],
                                              customerAddress: data['customerAddress'],
                                              note: data['customerNote'],
                                            ),
                                          ),
                                        );
                                      },
                                      onPrint: () {
                                        final rawItems = data['items'] as List<dynamic>;
                                        final items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();

                                        _handlePrint(
                                          items: items,
                                          subTotal: (data['subTotal'] as num).toDouble(),
                                          customerName: data['customerName'] ?? '',
                                          customerPhone: data['customerPhone'] ?? '',
                                          customerGst: data['customerGst'] ?? '',
                                          customerNote: data['customerNote'] ?? '',
                                          customerAddress: data['customerAddress'] ?? '',
                                          discountAmount: (data['discountAmount'] ?? 0).toDouble(),
                                          discountPercent: (data['discountPercent'] ?? 0).toDouble(),
                                          receiptNo: data['receiptNo'].toString(),
                                          orderType: data['orderType'],
                                          paymentType: data['paymentType'],
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
                        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 18)),
                        Icon(icon, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(value,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: color, overflow: TextOverflow.ellipsis)),
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
        child: Text(
          title,
          style: TextStyle(color: active ? Colors.white : Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
    );
  }
}

/// ORDER TILE
class OrderTile extends StatelessWidget {
  final int bill;
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
                  Text('Bill No. $bill', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(width: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      typeText,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('$time${edited ? '  Edited' : ''}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ]),
            ),
            Column(
              children: [
                Text('₹$amount', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
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
              const Text(
                'KOT',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '#$kotNo',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
              const Text(
                'TABLE',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                table,
                style: const TextStyle(fontWeight: FontWeight.w600),
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
            child: Text(
              '$items Items',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: appbar1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
