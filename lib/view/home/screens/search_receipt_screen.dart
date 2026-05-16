import 'dart:convert';
// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

// Project imports:
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:pos/core/widgets/access_denied_widget.dart';

class SearchReceiptScreen extends StatefulWidget {
  final String phoneNumber;

  const SearchReceiptScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<SearchReceiptScreen> createState() => _SearchReceiptScreenState();
}

class _SearchReceiptScreenState extends State<SearchReceiptScreen> {
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  String receiptNo = '';
  String adminUid = '';
  TextEditingController receiptNoController = TextEditingController();
  DateTime? selectedDate;
  bool isTapped = false;
  bool isLoading = false;
  bool hasSearched = false;
  Map<String, dynamic>? foundBill;

  Future<String> fetchAdminUid() async {
    try {
      // Try SQLite cache first
      final sqliteHelper = SQLiteHelper();
      final cachedUid = await sqliteHelper.getAdminUid(widget.phoneNumber);
      if (cachedUid != null && cachedUid.isNotEmpty) {
        setState(() => adminUid = cachedUid);
        return cachedUid;
      }
      // Fallback to phoneNumber as adminUid
      setState(() => adminUid = widget.phoneNumber);
      return widget.phoneNumber;
    } catch (e) {
      print('Error fetching adminUid: $e');
      setState(() => adminUid = widget.phoneNumber);
      return widget.phoneNumber;
    }
  }

  Future<void> _searchReceipt() async {
    if (receiptNo.isEmpty || selectedDate == null) return;
    setState(() {
      isLoading = true;
      foundBill = null;
    });
    try {
      final dayStart = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day).millisecondsSinceEpoch;
      final dayEnd = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day)
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final db = (await _sqliteHelper.database);
      // Try bills table
      List<Map<String, dynamic>> results = [];
      try {
        results = await db.query(
          'bills',
          where: 'admin_uid = ? AND (receipt_no = ? OR id = ?) AND bill_date BETWEEN ? AND ?',
          whereArgs: [widget.phoneNumber, receiptNo, receiptNo, dayStart, dayEnd],
          limit: 1,
        );
      } catch (_) {}
      // Fallback to orders table
      if (results.isEmpty) {
        try {
          results = await db.query(
            'orders',
            where: 'admin_uid = ? AND (receipt_no = ? OR id = ?) AND bill_date BETWEEN ? AND ?',
            whereArgs: [widget.phoneNumber, receiptNo, receiptNo, dayStart, dayEnd],
            limit: 1,
          );
        } catch (_) {}
      }
      setState(() {
        foundBill = results.isNotEmpty ? results.first : null;
        hasSearched = true;
      });
    } catch (e) {
      print('Search failed: $e');
      setState(() {
        foundBill = null;
        hasSearched = true;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  String getMonthDoc(DateTime date) {
    // Format: YYYYMM
    return '${date.year}${date.month.toString().padLeft(2, '0')}';
  }

  String getDateDoc(DateTime date) {
    // Format: YYYYMMDD
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        hasSearched = false; // Reset search when date changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    PrintProvider printProvider = Provider.of<PrintProvider>(context, listen: false);
    DateTime? currentBackPressTime;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const MyText(
              text: 'Search Receipt',
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ],
        ),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subProvider, _) {
          if (!subProvider.hasPermission("Reports", checkView: true)) {
            return const AccessDeniedWidget(feature: "Reports");
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header Section with Lottie Animation
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height / 5,
                        child: Lottie.asset(
                          "$lottiePath/search.json",
                          fit: BoxFit.contain,
                          frameRate: FrameRate(90),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: MyText(
                          text: 'Select date and enter receipt number to view details',
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Date Selection Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.15),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: selectedDate != null
                                      ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                      : 'Select bill date',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: selectedDate != null ? Colors.black87 : Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.grey[400],
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Search Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: receiptNoController,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search,
                              color: primaryColor,
                              size: 28,
                            ),
                            suffixIcon: receiptNoController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        receiptNoController.clear();
                                        receiptNo = '';
                                        hasSearched = false;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            hintText: 'Enter receipt number',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 15,
                              fontFamily: 'Outfit',
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            String enteredReceiptNo = receiptNoController.text.trim();

                            if (selectedDate == null) {
                              SnackBarUtils.showWarning(context, 'Please select a bill date first!');
                              return;
                            }

                            if (enteredReceiptNo.isEmpty) {
                              SnackBarUtils.showError(context, 'Please enter a valid receipt number!');
                              return;
                            }

                            setState(() {
                              receiptNo = enteredReceiptNo;
                            });
                            await _searchReceipt();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: primaryColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 22),
                              SizedBox(width: 8),
                              const MyText(
                                text: 'Search Receipt',
                                fontSize: 16,
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Loading indicator when fetching adminUid
                if (isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: primaryColor,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        MyText(
                          text: 'Loading...',
                          color: Colors.grey[600],
                          fontFamily: 'Outfit',
                          fontSize: 14,
                        ),
                      ],
                    ),
                  ),

                // Results Section
                if (!isLoading && hasSearched)
                  Builder(
                    builder: (context) {
                      if (foundBill == null) return _buildEmptyState();
                      final data = foundBill!;
                      List<dynamic> items = [];
                      try {
                        final rawItems = data['items'];
                        if (rawItems is String && rawItems.isNotEmpty) {
                          try {
                            items = jsonDecode(rawItems);
                          } catch (e) {
                            items = [];
                          }
                        } else if (rawItems is List) {
                          items = rawItems;
                        }
                      } catch (_) {}
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                spreadRadius: 2,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.1),
                                      Colors.green.shade50,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        MyText(
                                          text: 'Receipt #$receiptNo',
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        const SizedBox(height: 4),
                                        MyText(
                                          text: '${items.length} items',
                                          fontFamily: 'Outfit',
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: green,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Column(
                                        children: [
                                          const MyText(
                                              text: 'Total', fontFamily: 'Outfit', color: Colors.white, fontSize: 12),
                                          const SizedBox(height: 2),
                                          MyText(
                                            text: '₹${data['sub_total'] ?? data['total_amount'] ?? 0}',
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const MyText(
                                        text: 'Items',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                    const SizedBox(height: 12),
                                    ...items.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      var item = entry.value as Map<String, dynamic>? ?? {};
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                  color: primaryColor.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8)),
                                              child: Center(
                                                child: MyText(
                                                  text: '${index + 1}',
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  MyText(
                                                    text: item['name']?.toString() ?? '',
                                                    fontFamily: 'Outfit',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  MyText(
                                                    text: 'Qty: ${item['quantity']}',
                                                    fontFamily: 'Outfit',
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            MyText(
                                              text: PriceUtils.formatPrice(item['price']),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: green,
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            MyText(
              text: 'Receipt Not Found $adminUid, ',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 10),
            MyText(
              text:
                  'Receipt #$receiptNo does not exist for the selected date.\nPlease check the details and try again.',
              textAlign: TextAlign.center,
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
