import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/network/connection_monitor.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

class CustomerWiseReport extends StatefulWidget {
  final String adminUid;
  final String uid;
  const CustomerWiseReport({super.key, required this.adminUid, required this.uid});

  @override
  State<CustomerWiseReport> createState() => _CustomerWiseReportState();
}

class _CustomerWiseReportState extends State<CustomerWiseReport> {
  bool isLoading = false;
  bool hasSearched = false;
  DateTime? startDate = DateTime.now();
  DateTime? endDate = DateTime.now();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  List<CustomerModel> allCustomers = [];
  CustomerModel? selectedCustomer;

  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();

  // Customer transaction data
  List<Map<String, dynamic>> customerBills = [];
  double totalPaid = 0.0;
  double totalDue = 0.0;
  int totalOrders = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    fetchCustomers();
  }

  Future<void> _initializeServices() async {
    await _connectionMonitor.initialize();
  }

  /// Fetch all customers directly from Firebase
  Future<void> fetchCustomers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('AllAdmins')
          .doc(widget.adminUid)
          .collection('customer')
          .doc(widget.uid)
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
    } catch (e) {
      print('Error fetching customers from Firebase: $e');
    }
  }

  /// Fetch customer bills from Firebase only
  Future<void> fetchCustomerTransactions(CustomerModel customer) async {
    if (startDate == null || endDate == null) return;

    setState(() => isLoading = true);

    try {
      final startDt = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final endDt = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);

      final firebaseBills = await _getCustomerBillsFromFirebase(customer.phone, startDt, endDt);

      final processedData = _processBillsForPaymentTypes(firebaseBills);

      setState(() {
        customerBills = processedData.bills;
        totalPaid = processedData.totalPaid;
        totalDue = processedData.totalDue;
        totalOrders = processedData.totalOrders;
      });
    } catch (e) {
      print('ERROR: Fetching customer transactions: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Firebase bills fetching logic
  Future<List<Map<String, dynamic>>> _getCustomerBillsFromFirebase(
    String customerPhone,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final List<Map<String, dynamic>> allBills = [];
    try {
      final billsRef = FirebaseFirestore.instance.collection('AllBills').doc(widget.adminUid).collection('myBills');

      final yearMonths = _generateYearMonthsInRange(startDate, endDate);

      for (final yearMonth in yearMonths) {
        final yearMonthDocRef = billsRef.doc(yearMonth);
        final datesInMonth = _generateDatesInMonthRange(startDate, endDate, yearMonth);

        for (final dateStr in datesInMonth) {
          final dateCollectionRef = yearMonthDocRef.collection(dateStr);
          final snapshot = await dateCollectionRef.get();

          for (final billDoc in snapshot.docs) {
            final data = billDoc.data();
            final billCustomerPhone = data['customerPhone']?.toString();

            if (billCustomerPhone == customerPhone) {
              allBills.add(_mapFirebaseBillData(billDoc, data));
            }
          }
        }
      }

      // Deduplicate by id/receiptNo
      final Map<String, Map<String, dynamic>> uniqueBills = {};
      for (var bill in allBills) {
        final id = '${bill['receiptNo'] ?? bill['id']}_${bill['bill_timestamp']}';
        uniqueBills[id] = bill;
      }

      return uniqueBills.values.toList();
    } catch (e) {
      print('ERROR: Fetching bills from Firebase failed: $e');
      return [];
    }
  }

  // Generate year-month strings
  List<String> _generateYearMonthsInRange(DateTime start, DateTime end) {
    final List<String> yearMonths = [];
    DateTime current = DateTime(start.year, start.month);

    while (!current.isAfter(end)) {
      yearMonths.add('${current.year}${current.month.toString().padLeft(2, '0')}');
      current = DateTime(current.year, current.month + 1);
    }
    return yearMonths;
  }

  // Generate all dates in a month that fall in range
  List<String> _generateDatesInMonthRange(DateTime start, DateTime end, String yearMonth) {
    final List<String> dates = [];
    final year = int.parse(yearMonth.substring(0, 4));
    final month = int.parse(yearMonth.substring(4, 6));

    DateTime d = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);

    while (!d.isAfter(lastDay)) {
      if (!d.isBefore(start) && !d.isAfter(end)) {
        dates.add(
            '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}');
      }
      d = d.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Map Firebase bill data to our format
  Map<String, dynamic> _mapFirebaseBillData(DocumentSnapshot doc, Map<String, dynamic> data) {
    final customerPhone =
        data['customerPhone']?.toString() ?? data['customer_phone']?.toString() ?? data['phone']?.toString() ?? '';

    // Use correct timestamp from Firebase
    final Timestamp? billTimestamp =
        data['bill_date'] as Timestamp? ?? data['createdAt'] as Timestamp? ?? data['updatedAt'] as Timestamp?;

    final billDate = billTimestamp?.toDate() ?? DateTime.now();

    return {
      'id': doc.id,
      'customer_phone': customerPhone,
      'customer_name': data['customerName']?.toString() ??
          data['customer_name']?.toString() ??
          data['name']?.toString() ??
          'Unknown',
      'total_amount': data['totalAmount'] ?? 0.0,
      'final_total': data['finalTotal'] ?? data['totalAmount'] ?? 0.0,
      'payment_type': data['paymentType']?.toString() ?? 'cash',
      'date': DateFormat('dd/MM/yy').format(billDate),
      'time': DateFormat('hh:mm a').format(billDate),
      'bill_timestamp': billDate.millisecondsSinceEpoch,
      'items': data['items'] ?? [],
    };
  }

  /// Process bills to calculate totals and map for UI
  ProcessedBillData _processBillsForPaymentTypes(List<Map<String, dynamic>> bills) {
    double paid = 0.0;
    double due = 0.0;
    int orders = bills.length;

    final processedBills = bills.map((bill) {
      final paymentType = (bill['payment_type'] ?? 'cash').toString().toLowerCase();
      final amount = (bill['final_total'] as num?)?.toDouble() ?? 0.0;

      if (paymentType == 'debit') {
        due += amount;
      } else {
        paid += amount;
      }

      final billDate = DateTime.fromMillisecondsSinceEpoch(
        (bill['bill_timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      );

      final itemCount = (bill['items'] as List<dynamic>?)?.length ?? 1;

      return {
        'billNo': bill['id']?.toString() ?? 'N/A',
        'time': DateFormat('hh:mm a').format(billDate),
        'items': itemCount,
        'allItems': bill['items'],
        'amount': amount,
        'paymentType': paymentType,
        'date': DateFormat('dd/MM/yy').format(billDate),
        'bill_timestamp': billDate.millisecondsSinceEpoch,
      };
    }).toList();

    // Sort **once** by bill_timestamp descending
    processedBills.sort((a, b) {
      final aDate = a['bill_timestamp'] as int? ?? 0;
      final bDate = b['bill_timestamp'] as int? ?? 0;
      return bDate.compareTo(aDate); // latest first
    });

    return ProcessedBillData(
      bills: processedBills,
      totalPaid: paid,
      totalDue: due,
      totalOrders: orders,
    );
  }

  /// Pick date
  Future<void> pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate ?? DateTime.now() : endDate ?? DateTime.now(),
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

  Future<void> _downloadAndShareReport() async {
    if (selectedCustomer == null || customerBills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available to generate report'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // ================== SHOP DATA (LOCAL FIRST) ==================
      final localData = await _sqliteHelper.getUserData(widget.adminUid);

      final shopName = localData?['shopName'] ?? '';
      final contact = localData?['phoneNumber'] ?? '';
      final address = localData?['address'] ?? '';

      if (!mounted) return;
      Navigator.pop(context);

      // ================== PDF GENERATION ==================
      await Printing.layoutPdf(
        name: 'CustomerWiseReport_${DateFormat('ddMMyyyy_HHmmss').format(DateTime.now())}.pdf',
        onLayout: (format) async {
          final pdf = pw.Document();

          pdf.addPage(
            pw.MultiPage(
              pageFormat: format,
              margin: const pw.EdgeInsets.all(20),
              build: (_) => [
                // ================= HEADER =================
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
                    child: pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
                  ),
                if (contact.isNotEmpty)
                  pw.Center(
                    child: pw.Text('Contact: $contact', style: const pw.TextStyle(fontSize: 10)),
                  ),

                pw.SizedBox(height: 10),
                pw.Divider(),

                // ================= CUSTOMER INFO =================
                pw.Text(
                  'Customer: ${selectedCustomer!.name}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Phone: ${selectedCustomer!.phone}'),
                if (selectedCustomer!.gstNo != null) pw.Text('GST: ${selectedCustomer!.gstNo}'),

                pw.SizedBox(height: 6),
                pw.Text(
                  'Period: ${DateFormat('dd/MM/yyyy').format(startDate!)} '
                  'to ${DateFormat('dd/MM/yyyy').format(endDate!)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),

                pw.SizedBox(height: 12),

                // ================= TABLE =================
                pw.Table.fromTextArray(
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerRight,
                    2: pw.Alignment.centerRight,
                    3: pw.Alignment.centerRight,
                    4: pw.Alignment.centerRight,
                  },
                  headers: ['Bill No', 'Date', 'Items', 'Mode', 'Amount'],
                  data: customerBills.map((bill) {
                    return [
                      bill['billNo'],
                      bill['date'],
                      bill['items'].toString(),
                      bill['paymentType'].toString().toUpperCase(),
                      '${bill['amount'].toStringAsFixed(2)}',
                    ];
                  }).toList(),
                ),

                pw.SizedBox(height: 12),
                pw.Divider(),

                // ================= SUMMARY =================
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Paid: ${totalPaid.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Total Due: ${totalDue.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Grand Total: ${(totalPaid + totalDue).toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.green900,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Generated by POS System',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
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
            content: Text('PDF generated successfully'),
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
          content: Text('PDF generation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePrint() async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String shopName = '';
    String contact = '';
    String address = '';
    final localData = await _sqliteHelper.getUserData(widget.adminUid);

    print("These Is The Local Data ...........$localData");

    // Fetch shop data (local-first)

    shopName = localData!['shopName'] ?? "";
    contact = localData['phoneNumber'] ?? "";
    address = localData['address'] ?? "";

    if (!mounted) return;
    Navigator.pop(context);

    await DirectPrintHelper.printCustomerWiseReport(
      context: context,
      printer: printProvider.selectedPrinter!,
      paperSize: printProvider.selectedPaperSize,
      shopName: shopName,
      contact: contact,
      address: address,
      customerName: selectedCustomer!.name,
      customerPhone: selectedCustomer!.phone,
      customerGST: selectedCustomer!.gstNo ?? "",
      fromDate: startDate!,
      toDate: endDate!,
      bills: customerBills,
      totalPaid: totalPaid,
      totalDue: totalDue,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.share, color: appbar1),
            onPressed: customerBills.isEmpty ? null : _downloadAndShareReport,
          ),
          IconButton(
            onPressed: customerBills.isEmpty ? null : _handlePrint,
            icon: Icon(Icons.print, color: appbar1),
          ),
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
                    hasSearched = false;
                    customerBills.clear();
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

          GestureDetector(
            onTap: selectedCustomer == null
                ? null
                : () {
                    setState(() {
                      hasSearched = true;
                    });
                    fetchCustomerTransactions(selectedCustomer!);
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: selectedCustomer != null ? appbar1 : Colors.grey[400],
              ),
              child: const Center(
                child: Text(
                  "Find Bills",
                  style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: selectedCustomer == null || !hasSearched
                ? const SizedBox()
                : isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: appbar1,
                        ),
                      )
                    : customerBills.isEmpty
                        ? const Center(
                            child: Text(
                              'No transactions found for selected customer',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : Column(
                            children: [
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
                                              selectedCustomer!.name.isNotEmpty
                                                  ? selectedCustomer!.name[0].toUpperCase()
                                                  : "?",
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
                                                "₹${numberFormat.format(totalPaid + totalDue)}",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "$totalOrders orders",
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
                                            value: totalPaid,
                                            icon: Icons.check_circle,
                                            color: Colors.lightGreenAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _amountTile(
                                            title: "Due",
                                            value: totalDue,
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
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
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
                                  itemCount: customerBills.length,
                                  itemBuilder: (context, index) {
                                    final bill = customerBills[index];
                                    final List items = bill['allItems'] ?? [];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: _cardDecoration(),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          dividerColor: Colors.transparent,
                                        ),
                                        child: ExpansionTile(
                                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          childrenPadding: const EdgeInsets.only(
                                            left: 16,
                                            right: 16,
                                            bottom: 12,
                                          ),
                                          leading: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: _getPaymentColor(bill['paymentType']).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getPaymentIcon(bill['paymentType']),
                                              color: _getPaymentColor(bill['paymentType']),
                                            ),
                                          ),

                                          title: Text(
                                            "Bill No: ${bill['billNo']}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),

                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "${bill['items']} items • ${bill['date']} ${bill['time']}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                "Payment: ${_formatPaymentType(bill['paymentType'])}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _getPaymentColor(bill['paymentType']),
                                                ),
                                              ),
                                            ],
                                          ),

                                          trailing: Text(
                                            "₹${numberFormat.format(bill['amount'])}",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: bill['paymentType'] == 'debit' ? Colors.orange : Colors.green,
                                            ),
                                          ),

                                          // 👇 Expanded item list
                                          children: items.map<Widget>((item) {
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 6),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 4,
                                                    child: Text(
                                                      item['name'],
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      "x${item['quantity']}",
                                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      "₹${item['price']}",
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
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
                "₹${numberFormat.format(value)}",
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

  // Helper methods for payment type visualization
  IconData _getPaymentIcon(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return Icons.money;
      case 'upi':
        return Icons.account_balance_wallet;
      case 'debit':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'upi':
        return Colors.blue;
      case 'debit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatPaymentType(String paymentType) {
    return paymentType.substring(0, 1).toUpperCase() + paymentType.substring(1).toLowerCase();
  }
}

// Helper class for processed bill data
class ProcessedBillData {
  final List<Map<String, dynamic>> bills;
  final double totalPaid;
  final double totalDue;
  final int totalOrders;

  ProcessedBillData({
    required this.bills,
    required this.totalPaid,
    required this.totalDue,
    required this.totalOrders,
  });
}






// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:pos/view/home/navigation.dart';
// import 'package:pos/data/models/customer_model.dart';
// import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
// import 'package:pos/data/datasources/unified_database_service.dart';
// import 'package:pos/core/network/connection_monitor.dart';

// class CustomerWiseReport extends StatefulWidget {
//   final String adminUid;
//   const CustomerWiseReport({super.key, required this.adminUid});

//   @override
//   State<CustomerWiseReport> createState() => _CustomerWiseReportState();
// }

// class _CustomerWiseReportState extends State<CustomerWiseReport> {
//   bool isLoading = false;
//   DateTime? startDate = DateTime.now();
//   DateTime? endDate = DateTime.now();

//   List<CustomerModel> allCustomers = [];
//   CustomerModel? selectedCustomer;
  
//   // Data services
//   final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();
//   final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
//   // Customer transaction data
//   List<Map<String, dynamic>> customerBills = [];
//   double totalPaid = 0.0;
//   double totalDue = 0.0;
//   int totalOrders = 0;

//   Future<void> fetchCustomers() async {
//     setState(() => isLoading = true);
    
//     try {
//       // First try to get customers from local database
//       final localCustomers = await _getCustomersFromLocal();
      
//       if (localCustomers.isNotEmpty) {
//         setState(() {
//           allCustomers = localCustomers;
//         });
        
//         // If online, also fetch from Firebase to update local cache
//         if (await _connectionMonitor.isConnected) {
//           await _fetchCustomersFromFirebaseAndCache();
//         }
//       } else {
//         // If no local customers, fetch from Firebase
//         await _fetchCustomersFromFirebaseAndCache();
//       }
//     } catch (e) {
//       print('Error fetching customers: $e');
//       // Show error but don't crash
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
  
//   Future<List<CustomerModel>> _getCustomersFromLocal() async {
//     try {
//       // Get bills from local database using UnifiedDatabaseService
//       final bills = await _databaseService.getBills(widget.adminUid);
      
//       // Extract unique customers from bills
//       final customerMap = <String, CustomerModel>{};
      
//       for (final bill in bills) {
//         final phone = bill['customer_phone']?.toString();
//         final name = bill['customer_name']?.toString() ?? 'Unknown Customer';
        
//         if (phone != null && phone.isNotEmpty && !customerMap.containsKey(phone)) {
//           customerMap[phone] = CustomerModel(
//             name: name,
//             phone: phone,
//             gstNo: bill['customer_gst']?.toString().isEmpty ?? true ? null : bill['customer_gst'].toString(),
//             address: bill['customer_address']?.toString(),
//             createdAt: DateTime.now(),
//             isUploaded: true,
//           );
//         }
//       }
      
//       return customerMap.values.toList();
//     } catch (e) {
//       print('Error getting customers from local: $e');
//       return [];
//     }
//   }
  
//   Future<void> _fetchCustomersFromFirebaseAndCache() async {
//     try {
//       final snapshot = await FirebaseFirestore.instance
//           .collection('AllAdmins')
//           .doc(widget.adminUid)
//           .collection('customer')
//           .doc(widget.adminUid)
//           .collection('myCustomers')
//           .get();

//       final customers = snapshot.docs.map((doc) {
//         final data = doc.data();
//         return CustomerModel(
//           name: data['name'] ?? '',
//           phone: data['phone'] ?? doc.id,
//           gstNo: (data['gstNo'] == null || data['gstNo'].toString().isEmpty) ? null : data['gstNo'],
//           address: data['address'],
//           createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
//           isUploaded: true,
//         );
//       }).toList();

//       setState(() {
//         allCustomers = customers;
//       });
      
//       // Cache customers locally if we have a way to store them
//       // This would require adding a customers table to SQLite
//     } catch (e) {
//       print('Error fetching customers from Firebase: $e');
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     _initializeServices();
//     fetchCustomers();
//   }
  
//   Future<void> _initializeServices() async {
//     await _databaseService.initialize();
//     await _connectionMonitor.initialize();
//   }

//   Future<void> fetchCustomerTransactions(CustomerModel customer) async {
//     print('=== DEBUG: Starting fetchCustomerTransactions ===');
//     print('Customer: ${customer.name}, Phone: ${customer.phone}');
    
//     setState(() => isLoading = true);
    
//     try {
//       // Calculate date range
//       DateTime? startDt, endDt;
//       if (startDate != null && endDate != null) {
//         startDt = DateTime(startDate!.year, startDate!.month, startDate!.day);
//         endDt = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
//       }
      
//       print('DEBUG: Calculated date range: $startDt to $endDt');
      
//       // Check connection status
//       final isConnected = await _connectionMonitor.isConnected;
//       print('DEBUG: Connection status: $isConnected');
      
//       // First try local database
//       print('DEBUG: Attempting to fetch bills from local database...');
//       List<Map<String, dynamic>> bills = await _getCustomerBillsFromLocal(
//         customer.phone, 
//         startDt, 
//         endDt
//       );
      
//       print('DEBUG: Bills from local: ${bills.length}');
//       if (bills.isNotEmpty) {
//         print('DEBUG: Local bills sample: ${bills.take(2).toList()}');
//       }
      
//       // If no local data and online, fetch from Firebase
//       if (bills.isEmpty && isConnected) {
//         print('DEBUG: No local bills found (${bills.length}), connection available ($isConnected), fetching from Firebase...');
//         bills = await _getCustomerBillsFromFirebase(
//           customer.phone, 
//           startDt, 
//           endDt
//         );
        
//         print('DEBUG: Bills from Firebase: ${bills.length}');
//         if (bills.isNotEmpty) {
//           print('DEBUG: Firebase bills sample: ${bills.take(2).toList()}');
//         }
        
//         // Cache Firebase data locally
//         await _cacheBillsLocally(bills);
//       } else {
//         print('DEBUG: Skipping Firebase fetch - local bills: ${bills.isNotEmpty}, connected: $isConnected');
//       }
      
//       print('DEBUG: Total bills before processing: ${bills.length}');
      
//       // Process bills for payment type categorization
//       print('DEBUG: Starting bill processing...');
//       final processedData = _processBillsForPaymentTypes(bills);
      
//       print('DEBUG: Final processed data - Paid: ${processedData.totalPaid}, Due: ${processedData.totalDue}, Orders: ${processedData.totalOrders}');
//       print('DEBUG: Processed bills: ${processedData.bills.length}');
//       if (processedData.bills.isNotEmpty) {
//         print('DEBUG: Sample processed bill: ${processedData.bills.first}');
//       }
      
//       setState(() {
//         customerBills = processedData.bills;
//         totalPaid = processedData.totalPaid;
//         totalDue = processedData.totalDue;
//         totalOrders = processedData.totalOrders;
//       });
      
//       print('DEBUG: UI updated with ${customerBills.length} bills');
//       print('=== DEBUG: Completed fetchCustomerTransactions ===');
      
//     } catch (e) {
//       print('ERROR: Fetching customer transactions: $e');
//       print('ERROR DETAILS: Stack trace: ${StackTrace.current}');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading customer data: $e')),
//       );
//     } finally {
//       setState(() => isLoading = false);
//       print('DEBUG: Loading state set to false');
//     }
//   }
  
//   Future<List<Map<String, dynamic>>> _getCustomerBillsFromLocal(
//     String customerPhone,
//     DateTime? startDate,
//     DateTime? endDate,
//   ) async {
//     try {
//       print('=== DEBUG: Starting local bill fetch ===');
//       print('Customer phone: $customerPhone, date range: $startDate to $endDate');
      
//       // Use UnifiedDatabaseService to get bills
//       print('DEBUG: Calling _databaseService.getBills with adminUid: ${widget.adminUid}');
//       final bills = await _databaseService.getBills(widget.adminUid, startDate: startDate, endDate: endDate);
      
//       print('DEBUG: Total bills from UnifiedDatabaseService: ${bills.length}');
//       if (bills.isNotEmpty) {
//         print('DEBUG: Sample of raw bills: ${bills.take(2).toList()}');
//       }
      
//       // Filter bills for the specific customer
//       print('DEBUG: Filtering bills for customer phone: $customerPhone');
//       final filteredBills = bills.where((bill) {
//         final billPhone = bill['customer_phone']?.toString();
//         print('DEBUG: Checking bill: ${bill['id'] ?? 'NO_ID'}, phone: $billPhone, matches: ${billPhone == customerPhone}');
//         return billPhone == customerPhone;
//       }).toList();
      
//       print('DEBUG: Filtered bills for customer $customerPhone: ${filteredBills.length}');
//       filteredBills.forEach((bill) {
//         print('DEBUG: - Bill data: $bill');
//         print('DEBUG:   - customer_phone: ${bill['customer_phone']}');
//         print('DEBUG:   - total_amount: ${bill['total_amount']}');
//         print('DEBUG:   - final_total: ${bill['final_total']}');
//         print('DEBUG:   - payment_type: ${bill['payment_type']}');
//         print('DEBUG:   - amount fields: total_amount=${bill['total_amount']}, final_total=${bill['final_total']}, finalTotal=${bill['finalTotal']}, totalAmount=${bill['totalAmount']}');
//       });
      
//       print('=== DEBUG: Completed local bill fetch ===');
//       return filteredBills;
//     } catch (e) {
//       print('ERROR: Getting bills from local: $e');
//       print('ERROR DETAILS: Stack trace: ${StackTrace.current}');
//       return [];
//     }
//   }
  
//   Future<List<Map<String, dynamic>>> _getCustomerBillsFromFirebase(
//     String customerPhone,
//     DateTime? startDate,
//     DateTime? endDate,
//   ) async {
//     try {
//       print('=== DEBUG: Starting Firebase bill fetch ===');
//       print('Customer phone: $customerPhone');
//       print('Date range: $startDate to $endDate');
//       print('Admin UID: ${widget.adminUid}');
      
//       final List<Map<String, dynamic>> allBills = [];
      
//       // Reference to the main bills collection
//       final billsRef = FirebaseFirestore.instance
//           .collection('AllBills')
//           .doc(widget.adminUid)
//           .collection('myBills');
      
//       print('Firebase reference created: AllBills/${widget.adminUid}/myBills');
      
//       // First, let's check what year-month collections exist
//       print('DEBUG: Checking available year-month collections...');
//       final topLevelDocs = await billsRef.get();
//       print('DEBUG: Found ${topLevelDocs.size} top-level year-month documents');
//       for (final doc in topLevelDocs.docs) {
//         print('DEBUG: Year-month doc: ${doc.id}');
        
//         // Check the subcollections of each year-month by trying to access them
//         try {
//           final dateDocs = await billsRef.doc(doc.id).collection(doc.id).get();
//           print('DEBUG: Date documents in collection ${doc.id}: ${dateDocs.size}');
//           for (final dateDoc in dateDocs.docs) {
//             print('DEBUG: Date doc: ${dateDoc.id}');
            
//             // Check bills in this date
//             try {
//               final bills = await dateDoc.reference.collection(dateDoc.id).get();
//               print('DEBUG: Bills in date ${dateDoc.id}: ${bills.size}');
//               for (final bill in bills.docs) {
//                 final billData = bill.data();
//                 print('DEBUG: Bill ${bill.id} customerPhone: ${billData['customerPhone']}, looking for: $customerPhone');
//               }
//             } catch (e) {
//               print('DEBUG: Could not access bills collection for date ${dateDoc.id}: $e');
//             }
//           }
//         } catch (e) {
//           print('DEBUG: Could not access date collection for ${doc.id}: $e');
//         }
//       }
      
//       // If we have a date range, we need to traverse the hierarchy
//       if (startDate != null && endDate != null) {
//         print('DEBUG: Using date range filtering');
//         // Generate year-month combinations for the date range
//         final yearMonths = _generateYearMonthsInRange(startDate, endDate);
//         print('DEBUG: Year-months to check: $yearMonths');
        
//         for (final yearMonth in yearMonths) {
//           print('DEBUG: Checking year-month: $yearMonth');
          
//           try {
//             // Get documents for this year-month
//             final yearMonthDocs = await billsRef.doc(yearMonth).collection(yearMonth).get();
//             print('DEBUG: Year-month $yearMonth has ${yearMonthDocs.size} date documents');
            
//             for (final dateDoc in yearMonthDocs.docs) {
//               final billDateStr = dateDoc.id; // This should be the date like '20260116'
//               print('DEBUG: Processing date document: $billDateStr');
              
//               // Parse the date string to check if it's in range
//               final billDate = _parseBillDateString(billDateStr);
//               print('DEBUG: Parsed date: $billDate');
              
//               if (billDate != null && billDate.isAfter(startDate.subtract(Duration(days: 1))) && 
//                   billDate.isBefore(endDate.add(Duration(days: 1)))) {
                
//                 print('DEBUG: Date $billDate is in range, fetching bills...');
                
//                 // Get all bills for this date - bills are stored in a collection named after the date
//                 final billDocs = await dateDoc.reference.collection(dateDoc.id).get();
//                 print('DEBUG: Found ${billDocs.size} bills for date $billDateStr');
                
//                 for (final billDoc in billDocs.docs) {
//                   final data = billDoc.data();
//                   print('DEBUG: Raw bill data for ${billDoc.id}: $data');
                  
//                   // Check different possible field names for customer phone
//                   String billCustomerPhone = '';
//                   if (data.containsKey('customerPhone')) {
//                     billCustomerPhone = data['customerPhone']?.toString() ?? '';
//                   } else if (data.containsKey('customer_phone')) {
//                     billCustomerPhone = data['customer_phone']?.toString() ?? '';
//                   } else if (data.containsKey('phone')) {
//                     billCustomerPhone = data['phone']?.toString() ?? '';
//                   }
//                   print('DEBUG: Bill customer phone: $billCustomerPhone, Looking for: $customerPhone, Match: ${billCustomerPhone == customerPhone}');
                  
//                   // Only include bills for the requested customer
//                   if (billCustomerPhone == customerPhone) {
//                     print('DEBUG: Found matching bill: ${billDoc.id}');
//                     print('DEBUG: Raw bill data before mapping: $data');
//                     final mappedBill = _mapFirebaseBillData(billDoc, data);
//                     print('DEBUG: Mapped bill data: $mappedBill');
//                     allBills.add(mappedBill);
//                   } else {
//                     print('DEBUG: Skipping bill ${billDoc.id} - phone mismatch');
//                   }
//                 }
//               } else {
//                 print('DEBUG: Date $billDate is NOT in range [$startDate, $endDate], skipping');
//               }
//             }
//           } catch (e) {
//             print('DEBUG: Error processing year-month $yearMonth: $e');
//           }
//         }
//       } else {
//         // No date filtering - scan all possible dates
//         print('DEBUG: No date range specified, scanning all bills');
        
//         // This is inefficient but necessary without knowing all possible dates
//         // In production, you might want to maintain an index or use a different structure
//         final now = DateTime.now();
//         final startDateScan = DateTime(now.year - 1, 1, 1); // Scan last year
//         final endDateScan = now;
        
//         final yearMonths = _generateYearMonthsInRange(startDateScan, endDateScan);
//         print('DEBUG: All year-months to scan: $yearMonths');
        
//         for (final yearMonth in yearMonths) {
//           try {
//             print('DEBUG: Scanning year-month: $yearMonth');
            
//             // First, check if the year-month collection exists
//             try {
//               final yearMonthCheck = await billsRef.doc(yearMonth).get();
//               if (!yearMonthCheck.exists) {
//                 print('DEBUG: Year-month $yearMonth does not exist as a document');
                
//                 // Try to get the collection directly
//                 final yearMonthDocs = await billsRef.doc(yearMonth).collection(yearMonth).get();
//                 print('DEBUG: Year-month $yearMonth collection has ${yearMonthDocs.size} date documents');
                
//                 for (final dateDoc in yearMonthDocs.docs) {
//                   print('DEBUG: Processing date document: ${dateDoc.id}');
//                   final billDocs = await dateDoc.reference.collection(dateDoc.id).get();
//                   print('DEBUG: Found ${billDocs.size} bills for date ${dateDoc.id}');
                  
//                   for (final billDoc in billDocs.docs) {
//                     final data = billDoc.data();
//                     print('DEBUG: Raw bill data for ${billDoc.id}: ${data.keys}');
                    
//                     // Check different possible field names for customer phone
//                     String billCustomerPhone = '';
//                     if (data.containsKey('customerPhone')) {
//                       billCustomerPhone = data['customerPhone']?.toString() ?? '';
//                     } else if (data.containsKey('customer_phone')) {
//                       billCustomerPhone = data['customer_phone']?.toString() ?? '';
//                     } else if (data.containsKey('phone')) {
//                       billCustomerPhone = data['phone']?.toString() ?? '';
//                     }
//                     print('DEBUG: Checking bill ${billDoc.id} - phone: $billCustomerPhone, looking for: $customerPhone, match: ${billCustomerPhone == customerPhone}');
                    
//                     if (billCustomerPhone == customerPhone) {
//                       print('DEBUG: Adding matching bill: ${billDoc.id}');
//                       final mappedBill = _mapFirebaseBillData(billDoc, data);
//                       print('DEBUG: Mapped bill: $mappedBill');
//                       allBills.add(mappedBill);
//                     }
//                   }
//                 }
//               } else {
//                 print('DEBUG: Year-month $yearMonth exists as a document');
                
//                 // Get date documents from the collection
//                 final yearMonthDocs = await billsRef.doc(yearMonth).collection(yearMonth).get();
//                 print('DEBUG: Year-month $yearMonth collection has ${yearMonthDocs.size} date documents');
                
//                 for (final dateDoc in yearMonthDocs.docs) {
//                   print('DEBUG: Processing date document: ${dateDoc.id}');
//                   final billDocs = await dateDoc.reference.collection(dateDoc.id).get();
//                   print('DEBUG: Found ${billDocs.size} bills for date ${dateDoc.id}');
                  
//                   for (final billDoc in billDocs.docs) {
//                     final data = billDoc.data();
//                     print('DEBUG: Raw bill data for ${billDoc.id}: ${data.keys}');
                    
//                     // Check different possible field names for customer phone
//                     String billCustomerPhone = '';
//                     if (data.containsKey('customerPhone')) {
//                       billCustomerPhone = data['customerPhone']?.toString() ?? '';
//                     } else if (data.containsKey('customer_phone')) {
//                       billCustomerPhone = data['customer_phone']?.toString() ?? '';
//                     } else if (data.containsKey('phone')) {
//                       billCustomerPhone = data['phone']?.toString() ?? '';
//                     }
//                     print('DEBUG: Checking bill ${billDoc.id} - phone: $billCustomerPhone, looking for: $customerPhone, match: ${billCustomerPhone == customerPhone}');
                    
//                     if (billCustomerPhone == customerPhone) {
//                       print('DEBUG: Adding matching bill: ${billDoc.id}');
//                       final mappedBill = _mapFirebaseBillData(billDoc, data);
//                       print('DEBUG: Mapped bill: $mappedBill');
//                       allBills.add(mappedBill);
//                     }
//                   }
//                 }
//               }
//             } catch (collectionError) {
//               print('DEBUG: Error accessing year-month $yearMonth as collection: $collectionError');
//             }
//           } catch (e) {
//             // Some year-month combinations might not exist, that's fine
//             print('DEBUG: Year-month $yearMonth not found or error: $e');
//           }
//         }
//       }
      
//       print('=== DEBUG: Completed Firebase bill fetch ===');
//       print('Total bills found in Firebase: ${allBills.length}');
//       print('DEBUG: Returning bills: ${allBills.map((b) => b['id']).toList()}');
//       return allBills;
//     } catch (e) {
//       print('ERROR: Getting bills from Firebase: $e');
//       print('ERROR DETAILS: Stack trace: ${StackTrace.current}');
//       return [];
//     }
//   }
  
//   // Helper method to generate year-month combinations in a date range
//   List<String> _generateYearMonthsInRange(DateTime start, DateTime end) {
//     final yearMonths = <String>[];
//     DateTime current = DateTime(start.year, start.month, 1);
    
//     while (current.isBefore(end) || 
//            (current.year == end.year && current.month == end.month)) {
//       final yearMonth = '${current.year}${current.month.toString().padLeft(2, '0')}';
//       yearMonths.add(yearMonth);
      
//       // Move to next month
//       if (current.month == 12) {
//         current = DateTime(current.year + 1, 1, 1);
//       } else {
//         current = DateTime(current.year, current.month + 1, 1);
//       }
//     }
    
//     return yearMonths.toSet().toList(); // Remove duplicates
//   }
  
//   // Helper method to parse bill date string (e.g., '20260116' -> DateTime)
//   DateTime? _parseBillDateString(String dateStr) {
//     try {
//       if (dateStr.length == 8) { // YYYYMMDD format
//         final year = int.parse(dateStr.substring(0, 4));
//         final month = int.parse(dateStr.substring(4, 6));
//         final day = int.parse(dateStr.substring(6, 8));
//         return DateTime(year, month, day);
//       }
//     } catch (e) {
//       print('Error parsing date string $dateStr: $e');
//     }
//     return null;
//   }
  
//   // Helper method to map Firebase bill data to our format
//   Map<String, dynamic> _mapFirebaseBillData(DocumentSnapshot doc, Map<String, dynamic> data) {
//     print('DEBUG: Mapping Firebase bill data for doc ${doc.id}: ${data.keys.toList()}');
    
//     // Check different possible field names for customer phone
//     String customerPhone = '';
//     if (data.containsKey('customerPhone')) {
//       customerPhone = data['customerPhone']?.toString() ?? '';
//       print('DEBUG: Found customerPhone field: $customerPhone');
//     } else if (data.containsKey('customer_phone')) {
//       customerPhone = data['customer_phone']?.toString() ?? '';
//       print('DEBUG: Found customer_phone field: $customerPhone');
//     } else if (data.containsKey('phone')) {
//       customerPhone = data['phone']?.toString() ?? '';
//       print('DEBUG: Found phone field: $customerPhone');
//     } else {
//       print('DEBUG: No customer phone field found in data: ${data.keys.toList()}');
//     }
    
//     return {
//       'id': doc.id,
//       'customer_phone': customerPhone,
//       'customer_name': data['customerName']?.toString() ?? data['customer_name']?.toString() ?? data['name']?.toString() ?? 'Unknown',
//       'total_amount': data['totalAmount'] ?? data['total_amount'] ?? 0.0,
//       'final_total': data['finalTotal'] ?? data['final_total'] ?? data['totalAmount'] ?? data['total_amount'] ?? 0.0,
//       'payment_type': data['paymentType']?.toString() ?? data['payment_type']?.toString() ?? 'Cash',
//       'bill_date': (data['billDate'] as Timestamp?)?.millisecondsSinceEpoch ?? 
//                  (data['bill_date'] as int?) ?? 
//                  DateTime.now().millisecondsSinceEpoch,
//       'created_at': (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 
//                   (data['created_at'] as int?) ?? 
//                   DateTime.now().millisecondsSinceEpoch,
//       'items': data['items']?.toString() ?? '[]',
//     };
//   }
  
//   Future<void> _cacheBillsLocally(List<Map<String, dynamic>> bills) async {
//     try {
//       // The UnifiedDatabaseService handles caching automatically
//       // when we call getBills with online connection
//       print('Bills will be cached automatically by UnifiedDatabaseService');
//     } catch (e) {
//       print('Error caching bills locally: $e');
//     }
//   }
  
//   ProcessedBillData _processBillsForPaymentTypes(List<Map<String, dynamic>> bills) {
//     print('=== DEBUG: Starting bill processing ===');
//     print('Processing ${bills.length} bills for payment types');
    
//     double paid = 0.0;
//     double due = 0.0;
//     int orders = bills.length;
    
//     print('DEBUG: Bill sample (first 2): ${bills.take(2).toList()}');
    
//     final processedBills = bills.map((bill) {
//       print('DEBUG: Processing individual bill: $bill');
      
//       // Extract payment type with comprehensive fallbacks
//       String paymentType = 'cash'; // default
//       if (bill['payment_type'] != null) {
//         paymentType = bill['payment_type']?.toString().toLowerCase() ?? 'cash';
//         print('DEBUG: Using payment_type: $paymentType');
//       } else if (bill['paymentType'] != null) {
//         paymentType = bill['paymentType']?.toString().toLowerCase() ?? 'cash';
//         print('DEBUG: Using paymentType: $paymentType');
//       } else {
//         print('DEBUG: No payment type found, using default: $paymentType');
//       }
      
//       // Extract amount with comprehensive fallbacks
//       double amount = 0.0;
//       if (bill['final_total'] != null) {
//         amount = (bill['final_total'] as num?)?.toDouble() ?? 0.0;
//         print('DEBUG: Using final_total: $amount');
//       } else if (bill['total_amount'] != null) {
//         amount = (bill['total_amount'] as num?)?.toDouble() ?? 0.0;
//         print('DEBUG: Using total_amount: $amount');
//       } else if (bill['finalTotal'] != null) {
//         amount = (bill['finalTotal'] as num?)?.toDouble() ?? 0.0;
//         print('DEBUG: Using finalTotal: $amount');
//       } else if (bill['totalAmount'] != null) {
//         amount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
//         print('DEBUG: Using totalAmount: $amount');
//       } else if (bill['amount'] != null) {
//         amount = (bill['amount'] as num?)?.toDouble() ?? 0.0;
//         print('DEBUG: Using amount: $amount');
//       } else {
//         print('DEBUG: No amount field found, keeping as 0');
//       }
      
//       print('DEBUG: Amount before payment type processing: $amount, Payment type: $paymentType');
      
//       // Payment type categorization
//       if (paymentType == 'debit') {
//         due += amount;
//         print('DEBUG: Adding $amount to due (debit), new due: $due');
//       } else if (paymentType == 'cash' || paymentType == 'upi') {
//         paid += amount;
//         print('DEBUG: Adding $amount to paid ($paymentType), new paid: $paid');
//       } else {
//         print('DEBUG: Unknown payment type: $paymentType, not adding to totals');
//       }
      
//       // Parse bill date with fallbacks
//       int billDateMs = DateTime.now().millisecondsSinceEpoch;
//       if (bill['bill_date'] != null) {
//         billDateMs = bill['bill_date'] as int;
//         print('DEBUG: Using bill_date: $billDateMs');
//       } else if (bill['billDate'] != null) {
//         billDateMs = (bill['billDate'] as Timestamp).millisecondsSinceEpoch;
//         print('DEBUG: Using billDate: $billDateMs');
//       } else {
//         print('DEBUG: No date field found, using current time');
//       }
      
//       final billDate = DateTime.fromMillisecondsSinceEpoch(billDateMs);
      
//       // Count items from JSON string
//       int itemCount = 0;
//       try {
//         final itemsJson = bill['items']?.toString() ?? '{}';
        
//         print('DEBUG: Items JSON: $itemsJson'); // Debug log
        
//         // If the items field is already a number, use it directly
//         final numericValue = int.tryParse(itemsJson.trim());
//         if (numericValue != null) {
//           itemCount = numericValue;
//           print('DEBUG: Parsed as numeric: $itemCount');
//         } else {
//           // If it's a JSON string, count the actual items
//           if (itemsJson.startsWith('[') && itemsJson.endsWith(']')) {
//             // Array format: count objects in the array
//             // Simple approach: count '{' brackets that are not inside strings
//             int objCount = 0;
//             bool inString = false;
            
//             for (int i = 0; i < itemsJson.length; i++) {
//               if (itemsJson[i] == '"') {
//                 // Toggle string state, but ignore if escaped
//                 if (i == 0 || itemsJson[i-1] != '\\') {
//                   inString = !inString;
//                 }
//               } else if (itemsJson[i] == '{' && !inString) {
//                 objCount++;
//               }
//             }
//             itemCount = objCount;
//             print('DEBUG: Parsed array format: $itemCount items');
//           } else {
//             // If it's an object format or other, default to 1
//             itemCount = 1;
//             print('DEBUG: Default count: 1 item');
//           }
//         }
//       } catch (e) {
//         print('DEBUG: Error parsing items: $e');
//         itemCount = 1; // Default to 1 if parsing fails
//       }
      
//       // Make sure item count is not negative
//       if (itemCount < 0) itemCount = 0;
      
//       final processedBill = {
//         'billNo': bill['id']?.toString() ?? 'N/A',
//         'time': DateFormat('hh:mm a').format(billDate),
//         'items': itemCount,
//         'amount': amount,
//         'paymentType': paymentType,
//         'date': billDate,
//       };
      
//       print('DEBUG: Processed bill result: $processedBill');
//       return processedBill;
//     }).toList();
    
//     print('DEBUG: Final totals - Paid: $paid, Due: $due, Orders: $orders');
//     print('DEBUG: Processed bills count: ${processedBills.length}');
//     if (processedBills.isNotEmpty) {
//       print('DEBUG: First processed bill: ${processedBills.first}');
//     }
//     print('=== DEBUG: Completed bill processing ===');
    
//     return ProcessedBillData(
//       bills: processedBills,
//       totalPaid: paid,
//       totalDue: due,
//       totalOrders: orders,
//     );
//   }

//   Future<void> pickDate(bool isStart) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );

//     if (picked != null) {
//       setState(() {
//         if (isStart) {
//           startDate = picked;
//         } else {
//           endDate = picked;
//         }
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[100],
//       appBar: AppBar(
//         elevation: 0,
//         scrolledUnderElevation: 0,
//         backgroundColor: Colors.white,
//         title: const Text(
//           'Customer Wise Report',
//           style: TextStyle(
//             color: Colors.black87,
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//           ),
//         ),
//         actions: [
//           IconButton(
//               onPressed: () {},
//               icon: Icon(
//                 Icons.share,
//                 color: appbar1,
//               )),
//           IconButton(
//               onPressed: () {},
//               icon: Icon(
//                 Icons.print,
//                 color: appbar1,
//               )),
//           const SizedBox(
//             width: 10,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           /// Select Customer Dropdown
//           Container(
//             margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             decoration: _cardDecoration(),
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<CustomerModel>(
//                 value: selectedCustomer,
//                 isExpanded: true,
//                 hint: const Text("Select Customer"),
//                 icon: const Icon(Icons.keyboard_arrow_down),
//                 style: const TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black87,
//                 ),
//                 items: allCustomers.map((customer) {
//                   return DropdownMenuItem<CustomerModel>(
//                     value: customer,
//                     child: Text("${customer.name} (${customer.phone})"),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     selectedCustomer = value;
//                   });
//                 },
//               ),
//             ),
//           ),

//           /// Start & End Date
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: _dateField(
//                     label: "Start Date",
//                     date: startDate,
//                     onTap: () => pickDate(true),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _dateField(
//                     label: "End Date",
//                     date: endDate,
//                     onTap: () => pickDate(false),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 16),

//           GestureDetector(
//             onTap: selectedCustomer != null ? () => fetchCustomerTransactions(selectedCustomer!) : null,
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 15),
//               margin: const EdgeInsets.symmetric(horizontal: 12),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(25),
//                 color: selectedCustomer != null ? appbar1 : Colors.grey[400],
//               ),
//               child: Center(
//                 child: isLoading
//                     ? const CircularProgressIndicator(color: white)
//                     : const Text(
//                         "Find Bills",
//                         style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600),
//                       ),
//               ),
//             ),
//           ),

//           const SizedBox(height: 16),

//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 16),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: appbar1,
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Column(
//               children: [
//                 /// Top Row – Customer Info
//                 if (selectedCustomer != null)
//                   Row(
//                     children: [
//                       CircleAvatar(
//                         radius: 26,
//                         backgroundColor: Colors.white,
//                         child: Text(
//                           selectedCustomer!.name.isNotEmpty ? selectedCustomer!.name[0].toUpperCase() : "?",
//                           style: const TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.green,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               selectedCustomer!.name,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             Text(
//                               selectedCustomer!.phone,
//                               style: const TextStyle(
//                                 color: Colors.white70,
//                                 fontSize: 14,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             "₹${(totalPaid + totalDue).toStringAsFixed(0)}",
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           Text(
//                             "$totalOrders orders",
//                             style: const TextStyle(
//                               color: Colors.white70,
//                               fontSize: 13,
//                             ),
//                           ),
//                         ],
//                       )
//                     ],
//                   ),

//                 const SizedBox(height: 16),
//                 const Divider(color: Colors.white24),
//                 const SizedBox(height: 12),

//                 /// Bottom Row – Paid & Due
//                 Row(
//                   children: [
//                     Expanded(
//                       child: _amountTile(
//                         title: "Paid",
//                         value: totalPaid,
//                         icon: Icons.check_circle,
//                         color: Colors.lightGreenAccent,
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: _amountTile(
//                         title: "Due",
//                         value: totalDue,
//                         icon: Icons.warning_amber_rounded,
//                         color: Colors.orangeAccent,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 16),

//           /// Bills Header
//           const Padding(
//             padding: EdgeInsets.symmetric(horizontal: 16),
//             child: Row(
//               children: [
//                 Icon(Icons.receipt_long, color: Colors.blue),
//                 SizedBox(width: 8),
//                 Text(
//                   "Bills",
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 12),

//           /// Bills List
//           Expanded(
//             child: customerBills.isEmpty && !isLoading
//                 ? const Center(
//                     child: Text(
//                       'No transactions found for selected customer',
//                       style: TextStyle(color: Colors.grey, fontSize: 16),
//                     ),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     itemCount: customerBills.length,
//                     itemBuilder: (context, index) {
//                       final bill = customerBills[index];

//                       return Container(
//                         margin: const EdgeInsets.only(bottom: 12),
//                         padding: const EdgeInsets.all(16),
//                         decoration: _cardDecoration(),
//                         child: Row(
//                           children: [
//                             Container(
//                               width: 40,
//                               height: 40,
//                               decoration: BoxDecoration(
//                                 color: _getPaymentColor(bill['paymentType']).withOpacity(0.2),
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Icon(
//                                 _getPaymentIcon(bill['paymentType']),
//                                 color: _getPaymentColor(bill['paymentType']),
//                               ),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     bill['billNo'],
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15,
//                                     ),
//                                   ),
//                                   Text(
//                                     "${bill['items']} items • ${bill['time']}",
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                   Text(
//                                     "Payment: ${_formatPaymentType(bill['paymentType'])}",
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: _getPaymentColor(bill['paymentType']),
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             Text(
//                               "₹${bill['amount'].toStringAsFixed(0)}",
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: bill['paymentType'] == 'debit' 
//                                     ? Colors.orange 
//                                     : Colors.green,
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Reusable Card Decoration
//   BoxDecoration _cardDecoration() => BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       );

//   /// Date Field Widget
//   Widget _dateField({
//     required String label,
//     required DateTime? date,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//         decoration: _cardDecoration(),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               label,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               date == null ? "Select Date" : DateFormat('dd MMM yyyy').format(date),
//               style: const TextStyle(
//                 fontSize: 15,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _amountTile({
//     required String title,
//     required double value,
//     required IconData icon,
//     required Color color,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.15),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         children: [
//           Icon(icon, color: color, size: 22),
//           const SizedBox(width: 8),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: const TextStyle(
//                   color: Colors.white70,
//                   fontSize: 12,
//                 ),
//               ),
//               Text(
//                 "₹${value.toStringAsFixed(0)}",
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
  
//   // Helper methods for payment type visualization
//   IconData _getPaymentIcon(String paymentType) {
//     switch (paymentType.toLowerCase()) {
//       case 'cash':
//         return Icons.money;
//       case 'upi':
//         return Icons.account_balance_wallet;
//       case 'debit':
//         return Icons.credit_card;
//       default:
//         return Icons.payment;
//     }
//   }
  
//   Color _getPaymentColor(String paymentType) {
//     switch (paymentType.toLowerCase()) {
//       case 'cash':
//         return Colors.green;
//       case 'upi':
//         return Colors.blue;
//       case 'debit':
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }
  
//   String _formatPaymentType(String paymentType) {
//     return paymentType.substring(0, 1).toUpperCase() + paymentType.substring(1).toLowerCase();
//   }
// }

// // Helper class for processed bill data
// class ProcessedBillData {
//   final List<Map<String, dynamic>> bills;
//   final double totalPaid;
//   final double totalDue;
//   final int totalOrders;
  
//   ProcessedBillData({
//     required this.bills,
//     required this.totalPaid,
//     required this.totalDue,
//     required this.totalOrders,
//   });
// }