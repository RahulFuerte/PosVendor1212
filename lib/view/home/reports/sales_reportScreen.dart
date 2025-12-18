import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class SalesReportScreen extends StatefulWidget {
  final String adminUid;

  const SalesReportScreen({
    Key? key,
    required this.adminUid,
  }) : super(key: key);

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime selectedDate = DateTime.now();
  String selectedMonth = DateFormat('yyyyMM').format(DateTime.now());
  bool isLoading = true;
  double totalSales = 0.0;
  List<Map<String, dynamic>> productSales = [];

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
    fetchSalesData();
  }

  Future<void> fetchSalesData() async {
    setState(() {
      isLoading = true;
    });

    try {
      String dateDoc = DateFormat('yyyyMMdd').format(selectedDate);

      // Fetch all bills for the selected date
      final billsSnapshot = await FirebaseFirestore.instance
          .collection('AllBills')
          .doc(widget.adminUid)
          .collection('myBills')
          .doc(selectedMonth)
          .collection(dateDoc)
          .get();

      double total = 0.0;
      Map<String, Map<String, dynamic>> productsMap = {};

      // Process each bill
      for (var doc in billsSnapshot.docs) {
        final data = doc.data();
        total += (data['subTotal'] ?? 0.0) as double;

        // Process items
        List<dynamic> items = data['items'] ?? [];
        for (var item in items) {
          String productName = item['name'] ?? 'Unknown';
          int quantity = item['quantity'] ?? 0;
          double price = (item['price'] ?? 0.0) as double;

          if (productsMap.containsKey(productName)) {
            productsMap[productName]!['quantity'] += quantity;
            productsMap[productName]!['totalAmount'] += (price * quantity);
          } else {
            productsMap[productName] = {
              'name': productName,
              'quantity': quantity,
              'price': price,
              'totalAmount': price * quantity,
            };
          }
        }
      }

      // Convert to list and sort by quantity (descending)
      List<Map<String, dynamic>> products = productsMap.values.toList();
      products.sort((a, b) => b['quantity'].compareTo(a['quantity']));

      setState(() {
        totalSales = total;
        productSales = products;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching sales data: $e');
      setState(() {
        isLoading = false;
      });
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
        backgroundColor: Colors.white,
        title: const Text(
          'Sales Report',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
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
            child: Column(
              children: [
                // Month Dropdown
                // Container(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   decoration: BoxDecoration(
                //     color: Colors.grey[100],
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.grey[300]!),
                //   ),
                //   child: DropdownButtonHideUnderline(
                //     child: DropdownButton<String>(
                //       value: selectedMonth,
                //       isExpanded: true,
                //       icon:
                //           const Icon(Icons.calendar_month, color: Colors.blue),
                //       style: const TextStyle(
                //         fontSize: 16,
                //         fontWeight: FontWeight.w600,
                //         color: Colors.black87,
                //       ),
                //       items: monthsList.map((month) {
                //         return DropdownMenuItem<String>(
                //           value: month['value'],
                //           child: Text(month['label']!),
                //         );
                //       }).toList(),
                //       onChanged: (value) {
                //         if (value != null) {
                //           setState(() {
                //             selectedMonth = value;
                //             // Update selected date to first day of selected month
                //             DateTime newDate =
                //                 DateFormat('yyyyMM').parse(value);
                //             selectedDate = DateTime(
                //               newDate.year,
                //               newDate.month,
                //               selectedDate.day >
                //                       DateTime(newDate.year, newDate.month + 1,
                //                               0)
                //                           .day
                //                   ? DateTime(newDate.year, newDate.month + 1, 0)
                //                       .day
                //                   : selectedDate.day,
                //             );
                //           });
                //           fetchSalesData();
                //         }
                //       },
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 16),
                // Date Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => changeDate(-1),
                      icon: const Icon(Icons.chevron_left, size: 32),
                      color: Colors.blue,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        DateFormat('MMM dd, yyyy').format(selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: selectedDate.isBefore(DateTime.now())
                          ? () => changeDate(1)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 32),
                      color: selectedDate.isBefore(DateTime.now())
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ],
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Total Sales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '₹${totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Products List Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Product Sales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${productSales.length} items',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Products List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : productSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sales data available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: productSales.length,
                        itemBuilder: (context, index) {
                          final product = productSales[index];
                          final maxQuantity = productSales.first['quantity'];
                          final percentage =
                              (product['quantity'] / maxQuantity) * 100;

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
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '#${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '₹${product['price'].toStringAsFixed(2)} per unit',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${product['totalAmount'].toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${product['quantity']} sold',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // Progress Bar
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
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
                                              color:
                                                  Colors.blue.withOpacity(0.3),
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
                                Text(
                                  '${percentage.toStringAsFixed(1)}% of top seller',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
