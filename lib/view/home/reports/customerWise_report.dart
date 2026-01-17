import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';

class CustomerWiseReport extends StatefulWidget {
  final String adminUid;
  const CustomerWiseReport({super.key, required this.adminUid});

  @override
  State<CustomerWiseReport> createState() => _CustomerWiseReportState();
}

class _CustomerWiseReportState extends State<CustomerWiseReport> {
  bool isLoading = false;
  DateTime? startDate = DateTime.now();
  DateTime? endDate = DateTime.now();

  List<CustomerModel> allCustomers = [];
  CustomerModel? selectedCustomer;

  Future<void> fetchCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AllAdmins')
        .doc(widget.adminUid)
        .collection('customer')
        .doc(widget.adminUid)
        .collection('myCustomers')
        .get();

    final customers = snapshot.docs.map((doc) {
      final data = doc.data();
      return CustomerModel(
        name: data['name'] ?? '',
        phone: data['phone'] ?? doc.id,
        gstNo: (data['gstNo'] == null || data['gstNo'].toString().isEmpty) ? null : data['gstNo'],
        address: data['address'],
        createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
        isUploaded: true,
      );
    }).toList();

    setState(() {
      allCustomers = customers;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  /// Selected Customer Summary (dummy)
  final Map<String, dynamic> customer = {
    "name": "Rahul Patel",
    "mobile": "9876543210",
    "orders": 3,
    "paid": 900.0,
    "due": 350.0,
  };

  /// Bills (dummy)
  final List<Map<String, dynamic>> bills = [
    {
      "billNo": "BILL-101",
      "time": "10:45 AM",
      "items": 5,
      "amount": 450.0,
    },
    {
      "billNo": "BILL-102",
      "time": "01:20 PM",
      "items": 3,
      "amount": 300.0,
    },
    {
      "billNo": "BILL-103",
      "time": "06:15 PM",
      "items": 6,
      "amount": 500.0,
    },
    {
      "billNo": "BILL-101",
      "time": "10:45 AM",
      "items": 5,
      "amount": 450.0,
    },
    {
      "billNo": "BILL-102",
      "time": "01:20 PM",
      "items": 3,
      "amount": 300.0,
    },
    {
      "billNo": "BILL-103",
      "time": "06:15 PM",
      "items": 6,
      "amount": 500.0,
    },
    {
      "billNo": "BILL-101",
      "time": "10:45 AM",
      "items": 5,
      "amount": 450.0,
    },
    {
      "billNo": "BILL-102",
      "time": "01:20 PM",
      "items": 3,
      "amount": 300.0,
    },
    {
      "billNo": "BILL-103",
      "time": "06:15 PM",
      "items": 6,
      "amount": 500.0,
    },
    {
      "billNo": "BILL-101",
      "time": "10:45 AM",
      "items": 5,
      "amount": 450.0,
    },
    {
      "billNo": "BILL-102",
      "time": "01:20 PM",
      "items": 3,
      "amount": 300.0,
    },
    {
      "billNo": "BILL-103",
      "time": "06:15 PM",
      "items": 6,
      "amount": 500.0,
    },
  ];

  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalAmount = (customer['paid'] ?? 0) + (customer['due'] ?? 0);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Customer Wise Report',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.share,
                color: appbar1,
              )),
          IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.print,
                color: appbar1,
              )),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
      body: Column(
        children: [
          /// Select Customer Dropdown
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _cardDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CustomerModel>(
                value: selectedCustomer,
                isExpanded: true,
                hint: const Text("Select Customer"),
                icon: const Icon(Icons.keyboard_arrow_down),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                items: allCustomers.map((customer) {
                  return DropdownMenuItem<CustomerModel>(
                    value: customer,
                    child: Text("${customer.name} (${customer.phone})"),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCustomer = value;
                  });
                },
              ),
            ),
          ),

          /// Start & End Date
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _dateField(
                    label: "Start Date",
                    date: startDate,
                    onTap: () => pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dateField(
                    label: "End Date",
                    date: endDate,
                    onTap: () => pickDate(false),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: EdgeInsets.symmetric(vertical: 15),
            margin: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: appbar1,
            ),
            child: const Center(
              child: Text(
                "Find Bills",
                style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appbar1,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                /// Top Row – Customer Info
                if (selectedCustomer != null)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Text(
                          selectedCustomer!.name.isNotEmpty ? selectedCustomer!.name[0].toUpperCase() : "?",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedCustomer!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              selectedCustomer!.phone,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${totalAmount.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${customer['orders']} orders",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),

                /// Bottom Row – Paid & Due
                Row(
                  children: [
                    Expanded(
                      child: _amountTile(
                        title: "Paid",
                        value: customer['paid'],
                        icon: Icons.check_circle,
                        color: Colors.lightGreenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _amountTile(
                        title: "Due",
                        value: customer['due'],
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// Bills Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.receipt_long, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Bills",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          /// Bills List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: bills.length,
              itemBuilder: (context, index) {
                final bill = bills[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bill['billNo'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "${bill['items']} items • ${bill['time']}",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "₹${bill['amount'].toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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

  /// Reusable Card Decoration
  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// Date Field Widget
  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              date == null ? "Select Date" : DateFormat('dd MMM yyyy').format(date),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountTile({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                "₹${value.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
