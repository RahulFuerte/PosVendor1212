import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/data/datasources/unified_database_service.dart';
import 'package:pos/core/network/connection_monitor.dart';
import 'dart:developer' as developer;

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
  
  // Data services
  final UnifiedDatabaseService _databaseService = UnifiedDatabaseService();
  final ConnectionMonitor _connectionMonitor = ConnectionMonitor();
  
  // Customer transaction data
  List<Map<String, dynamic>> customerBills = [];
  double totalPaid = 0.0;
  double totalDue = 0.0;
  int totalOrders = 0;

  Future<void> fetchCustomers() async {
    setState(() => isLoading = true);
    
    try {
      // First try to get customers from local database
      final localCustomers = await _getCustomersFromLocal();
      
      if (localCustomers.isNotEmpty) {
        setState(() {
          allCustomers = localCustomers;
        });
        
        // If online, also fetch from Firebase to update local cache
        if (await _connectionMonitor.isConnected) {
          await _fetchCustomersFromFirebaseAndCache();
        }
      } else {
        // If no local customers, fetch from Firebase
        await _fetchCustomersFromFirebaseAndCache();
      }
    } catch (e) {
      developer.log('Error fetching customers: $e', name: 'CustomerWiseReport');
      // Show error but don't crash
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Future<List<CustomerModel>> _getCustomersFromLocal() async {
    try {
      // Get bills from local database using UnifiedDatabaseService
      final bills = await _databaseService.getBills(widget.adminUid);
      
      // Extract unique customers from bills
      final customerMap = <String, CustomerModel>{};
      
      for (final bill in bills) {
        final phone = bill['customer_phone']?.toString();
        final name = bill['customer_name']?.toString() ?? 'Unknown Customer';
        
        if (phone != null && phone.isNotEmpty && !customerMap.containsKey(phone)) {
          customerMap[phone] = CustomerModel(
            name: name,
            phone: phone,
            gstNo: bill['customerGst']?.toString().isEmpty ?? true ? null : bill['customer_gst'].toString(),
            address: bill['customerAddress']?.toString(),
            createdAt: DateTime.now(),
            isUploaded: true,
          );
        }
      }
      
      return customerMap.values.toList();
    } catch (e) {
      developer.log('Error getting customers from local: $e', name: 'CustomerWiseReport');
      return [];
    }
  }
  
  Future<void> _fetchCustomersFromFirebaseAndCache() async {
    try {
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
      
      // Cache customers locally if we have a way to store them
      // This would require adding a customers table to SQLite
    } catch (e) {
      developer.log('Error fetching customers from Firebase: $e', name: 'CustomerWiseReport');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
    fetchCustomers();
  }
  
  Future<void> _initializeServices() async {
    await _databaseService.initialize();
    await _connectionMonitor.initialize();
  }

  Future<void> fetchCustomerTransactions(CustomerModel customer) async {
    developer.log('Starting fetchCustomerTransactions', name: 'CustomerWiseReport');
    developer.log('Customer: ${customer.name}, Phone: ${customer.phone}', name: 'CustomerWiseReport');
    
    setState(() => isLoading = true);
    
    try {
      // Calculate date range
      DateTime? startDt, endDt;
      if (startDate != null && endDate != null) {
        startDt = DateTime(startDate!.year, startDate!.month, startDate!.day);
        endDt = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      }
      
      developer.log('Calculated date range: $startDt to $endDt', name: 'CustomerWiseReport');
      
      // Check connection status
      final isConnected = await _connectionMonitor.isConnected;
      developer.log('Connection status: $isConnected', name: 'CustomerWiseReport');
      
      // First try local database (LOCAL-FIRST STRATEGY)
      developer.log('LOCAL-FIRST DATA FETCH STARTED', name: 'CustomerWiseReport');
      developer.log('Attempting to fetch bills from local database...', name: 'CustomerWiseReport');
      List<Map<String, dynamic>> bills = await _getCustomerBillsFromLocal(
        customer.phone, 
        startDt, 
        endDt
      );
      
      developer.log('Bills from local: ${bills.length}', name: 'CustomerWiseReport');
      if (bills.isNotEmpty) {
        developer.log('Local bills sample: ${bills.take(2).toList()}', name: 'CustomerWiseReport');
        developer.log('SUCCESS: Found ${bills.length} bills in local database', name: 'CustomerWiseReport');
      } else {
        developer.log('WARNING: No bills found in local database', name: 'CustomerWiseReport');
      }
      
      // If no local data and online, fetch from Firebase
      if (bills.isEmpty && isConnected) {
        developer.log('FALLBACK: Local database empty (${bills.length} bills), connection available ($isConnected), fetching from Firebase...', name: 'CustomerWiseReport');
        bills = await _getCustomerBillsFromFirebase(
          customer.phone, 
          startDt, 
          endDt
        );
        
        developer.log('Bills from Firebase: ${bills.length}', name: 'CustomerWiseReport');
        if (bills.isNotEmpty) {
          developer.log('Firebase bills sample: ${bills.take(2).toList()}', name: 'CustomerWiseReport');
          developer.log('SUCCESS: Retrieved ${bills.length} bills from Firebase', name: 'CustomerWiseReport');
          
          // Cache Firebase data locally for future offline use
          developer.log('CACHING: Saving ${bills.length} bills to local database for offline access...', name: 'CustomerWiseReport');
          await _cacheBillsLocally(bills);
          developer.log('SUCCESS: Cached ${bills.length} bills locally', name: 'CustomerWiseReport');
        } else {
          developer.log('WARNING: No bills found in Firebase either', name: 'CustomerWiseReport');
        }
      } else {
        developer.log('SKIPPED: Firebase fetch - local bills: ${bills.isNotEmpty}, connected: $isConnected', name: 'CustomerWiseReport');
      }
      
      developer.log('LOCAL-FIRST DATA FETCH COMPLETED', name: 'CustomerWiseReport');
      
      developer.log('Total bills before processing: ${bills.length}', name: 'CustomerWiseReport');
      
      // Process bills for payment type categorization
      developer.log('Starting bill processing...', name: 'CustomerWiseReport');
      final processedData = _processBillsForPaymentTypes(bills);
      
      developer.log('Final processed data - Paid: ${processedData.totalPaid}, Due: ${processedData.totalDue}, Orders: ${processedData.totalOrders}', name: 'CustomerWiseReport');
      developer.log('Processed bills: ${processedData.bills.length}', name: 'CustomerWiseReport');
      if (processedData.bills.isNotEmpty) {
        developer.log('Sample processed bill: ${processedData.bills.first}', name: 'CustomerWiseReport');
      }
      
      setState(() {
        customerBills = processedData.bills;
        totalPaid = processedData.totalPaid;
        totalDue = processedData.totalDue;
        totalOrders = processedData.totalOrders;
      });
      
      developer.log('UI updated with ${customerBills.length} bills', name: 'CustomerWiseReport');
      developer.log('COMPLETED fetchCustomerTransactions', name: 'CustomerWiseReport');
      
    } catch (e) {
      developer.log('ERROR: Fetching customer transactions: $e', name: 'CustomerWiseReport');
      developer.log('ERROR DETAILS: Stack trace: ${StackTrace.current}', name: 'CustomerWiseReport');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading customer data: $e')),
      );
    } finally {
      setState(() => isLoading = false);
      developer.log('Loading state set to false', name: 'CustomerWiseReport');
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCustomerBillsFromLocal(
    String customerPhone,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      developer.log('STARTING local bill fetch', name: 'CustomerWiseReport');
      developer.log('Customer phone: $customerPhone, date range: $startDate to $endDate', name: 'CustomerWiseReport');
      
      // Use UnifiedDatabaseService to get bills
      developer.log('_databaseService.getBills with adminUid: ${widget.adminUid}', name: 'CustomerWiseReport');
      final bills = await _databaseService.getBills(widget.adminUid, startDate: startDate, endDate: endDate);
      
      developer.log('Total bills from UnifiedDatabaseService: ${bills.length}', name: 'CustomerWiseReport');
      if (bills.isNotEmpty) {
        developer.log('Sample of raw bills: ${bills.take(2).toList()}', name: 'CustomerWiseReport');
      }
      
      // Filter bills for the specific customer
      developer.log('Filtering bills for customer phone: $customerPhone', name: 'CustomerWiseReport');
      final filteredBills = bills.where((bill) {
        final billPhone = bill['customer_phone']?.toString();
        developer.log('Checking bill: ${bill['id'] ?? 'NO_ID'}, phone: $billPhone, matches: ${billPhone == customerPhone}', name: 'CustomerWiseReport');
        return billPhone == customerPhone;
      }).toList();
      
      developer.log('Filtered bills for customer $customerPhone: ${filteredBills.length}', name: 'CustomerWiseReport');
      filteredBills.forEach((bill) {
        developer.log('- Bill data: $bill', name: 'CustomerWiseReport');
        developer.log('  - customer_phone: ${bill['customer_phone']}', name: 'CustomerWiseReport');
        developer.log('  - total_amount: ${bill['total_amount']}', name: 'CustomerWiseReport');
        developer.log('  - final_total: ${bill['final_total']}', name: 'CustomerWiseReport');
        developer.log('  - payment_type: ${bill['payment_type']}', name: 'CustomerWiseReport');
        developer.log('  - amount fields: total_amount=${bill['total_amount']}, final_total=${bill['final_total']}, finalTotal=${bill['finalTotal']}, totalAmount=${bill['totalAmount']}', name: 'CustomerWiseReport');
      });
      
      developer.log('COMPLETED local bill fetch', name: 'CustomerWiseReport');
      return filteredBills;
    } catch (e) {
      developer.log('ERROR: Getting bills from local: $e', name: 'CustomerWiseReport');
      developer.log('ERROR DETAILS: Stack trace: ${StackTrace.current}', name: 'CustomerWiseReport');
      return [];
    }
  }
  
  Future<List<Map<String, dynamic>>> _getCustomerBillsFromFirebase(
    String customerPhone,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    try {
      developer.log('STARTING Firebase bill fetch', name: 'CustomerWiseReport');
      developer.log('Customer phone: $customerPhone', name: 'CustomerWiseReport');
      developer.log('Date range: $startDate to $endDate', name: 'CustomerWiseReport');
      developer.log('Admin UID: ${widget.adminUid}', name: 'CustomerWiseReport');
      
      final List<Map<String, dynamic>> allBills = [];
      
      // Reference to the main bills collection
      final billsRef = FirebaseFirestore.instance
          .collection('AllBills')
          .doc(widget.adminUid)
          .collection('myBills');
      
      developer.log('Firebase reference created: AllBills/${widget.adminUid}/myBills', name: 'CustomerWiseReport');
      
      // Iterate through each day in the date range
      DateTime current = startDate ?? DateTime.now();
      final endDateTime = endDate ?? DateTime.now();
      
      while (!current.isAfter(endDateTime)) {
        developer.log('Checking date: ${DateFormat('yyyy-MM-dd').format(current)}', name: 'CustomerWiseReport');
        
        final yearMonth = DateFormat('yyyyMM').format(current);
        final dateId = DateFormat('yyyyMMdd').format(current);
        
        developer.log('Checking year-month: $yearMonth, date: $dateId', name: 'CustomerWiseReport');

        try {
          // Direct access to the date collection
          final snapshot = await billsRef.doc(yearMonth).collection(dateId).get();
          developer.log('Found ${snapshot.size} bills for date $dateId', name: 'CustomerWiseReport');

          for (final doc in snapshot.docs) {
            final data = doc.data();
            developer.log('Processing bill ${doc.id}, data keys: ${data.keys.toList()}', name: 'CustomerWiseReport');

            // Check customer phone with multiple possible field names
            String billCustomerPhone = '';
            if (data.containsKey('customerPhone')) {
              billCustomerPhone = data['customerPhone']?.toString() ?? '';
            } else if (data.containsKey('customer_phone')) {
              billCustomerPhone = data['customer_phone']?.toString() ?? '';
            } else if (data.containsKey('phone')) {
              billCustomerPhone = data['phone']?.toString() ?? '';
            }
            
            developer.log('Bill customer phone: $billCustomerPhone, Looking for: $customerPhone, Match: ${billCustomerPhone == customerPhone}', name: 'CustomerWiseReport');

            if (billCustomerPhone == customerPhone) {
              developer.log('Found matching bill: ${doc.id}', name: 'CustomerWiseReport');
              allBills.add({
                ...data,
                'id': doc.id,
              });
            } else {
              developer.log('Skipping bill ${doc.id} - phone mismatch', name: 'CustomerWiseReport');
            }
          }
        } catch (e) {
          developer.log('Could not access date $dateId in year-month $yearMonth: $e', name: 'CustomerWiseReport');
        }

        current = current.add(const Duration(days: 1));
      }

      developer.log('COMPLETED Firebase bill fetch', name: 'CustomerWiseReport');
      developer.log('Total bills found in Firebase: ${allBills.length}', name: 'CustomerWiseReport');
      developer.log('Returning bills: ${allBills.map((b) => b['id']).toList()}', name: 'CustomerWiseReport');
      return allBills;
    } catch (e) {
      developer.log('ERROR: Getting bills from Firebase: $e', name: 'CustomerWiseReport');
      developer.log('ERROR DETAILS: Stack trace: ${StackTrace.current}', name: 'CustomerWiseReport');
      return [];
    }
  }
  

  
  Future<void> _cacheBillsLocally(List<Map<String, dynamic>> bills) async {
    try {
      developer.log('Caching ${bills.length} bills locally', name: 'CustomerWiseReport');
      
      // Save each bill to local database through UnifiedDatabaseService
      for (final bill in bills) {
        try {
          // Convert Firebase bill format to local database format
          final localBill = {
            'id': bill['id'],

            'customer_phone': bill['customerPhone'] ?? bill['customer_phone'] ?? '',
            'customer_name': bill['customerName'] ?? bill['customer_name'] ?? 'Unknown',
            'total_amount': bill['totalAmount'] ?? bill['total_amount'] ?? bill['finalTotal'] ?? bill['final_total'] ?? 0.0,
            'final_total': bill['finalTotal'] ?? bill['final_total'] ?? bill['totalAmount'] ?? bill['total_amount'] ?? 0.0,
            'payment_type': bill['paymentType'] ?? bill['payment_type'] ?? 'Cash',
            'bill_date': bill['billDate'] is Timestamp 
                ? (bill['billDate'] as Timestamp).millisecondsSinceEpoch 
                : bill['bill_date'] ?? DateTime.now().millisecondsSinceEpoch,
            'created_at': bill['createdAt'] is Timestamp 
                ? (bill['createdAt'] as Timestamp).millisecondsSinceEpoch 
                : bill['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'items': bill['items']?.toString() ?? '[]',
          };
          
          developer.log('Saving bill to local database: ${localBill['id']}', name: 'CustomerWiseReport');
          // Actually save the bill using UnifiedDatabaseService
          await _databaseService.saveBill(widget.adminUid, localBill);
          developer.log('Successfully saved bill ${localBill['id']} to local database', name: 'CustomerWiseReport');
          
        } catch (saveError) {
          developer.log('Error saving individual bill ${bill['id']}: $saveError', name: 'CustomerWiseReport');
        }
      }
      
      developer.log('Finished caching bills locally', name: 'CustomerWiseReport');
    } catch (e) {
      developer.log('ERROR: Caching bills locally: $e', name: 'CustomerWiseReport');
    }
  }
  
  ProcessedBillData _processBillsForPaymentTypes(List<Map<String, dynamic>> bills) {
    developer.log('STARTING bill processing', name: 'CustomerWiseReport');
    developer.log('Processing ${bills.length} bills for payment types', name: 'CustomerWiseReport');
    
    double paid = 0.0;
    double due = 0.0;
    int orders = bills.length;
    
    developer.log('Bill sample (first 2): ${bills.take(2).toList()}', name: 'CustomerWiseReport');
    
    final processedBills = bills.map((bill) {
      developer.log('Processing individual bill: $bill', name: 'CustomerWiseReport');
      
      // Extract payment type with comprehensive fallbacks
      String paymentType = 'cash'; // default
      if (bill['payment_type'] != null) {
        paymentType = bill['payment_type']?.toString().toLowerCase() ?? 'cash';
        developer.log('Using payment_type: $paymentType', name: 'CustomerWiseReport');
      } else if (bill['paymentType'] != null) {
        paymentType = bill['paymentType']?.toString().toLowerCase() ?? 'cash';
        developer.log('Using paymentType: $paymentType', name: 'CustomerWiseReport');
      } else {
        developer.log('No payment type found, using default: $paymentType', name: 'CustomerWiseReport');
      }
      
      // Extract amount with comprehensive fallbacks
      double amount = 0.0;
      if (bill['final_total'] != null) {
        amount = (bill['final_total'] as num?)?.toDouble() ?? 0.0;
        developer.log('Using final_total: $amount', name: 'CustomerWiseReport');
      } else if (bill['total_amount'] != null) {
        amount = (bill['total_amount'] as num?)?.toDouble() ?? 0.0;
        developer.log('Using total_amount: $amount', name: 'CustomerWiseReport');
      } else if (bill['finalTotal'] != null) {
        amount = (bill['finalTotal'] as num?)?.toDouble() ?? 0.0;
        developer.log('Using finalTotal: $amount', name: 'CustomerWiseReport');
      } else if (bill['totalAmount'] != null) {
        amount = (bill['totalAmount'] as num?)?.toDouble() ?? 0.0;
        developer.log('Using totalAmount: $amount', name: 'CustomerWiseReport');
      } else if (bill['amount'] != null) {
        amount = (bill['amount'] as num?)?.toDouble() ?? 0.0;
        developer.log('Using amount: $amount', name: 'CustomerWiseReport');
      } else {
        developer.log('No amount field found, keeping as 0', name: 'CustomerWiseReport');
      }
      
      developer.log('Amount before payment type processing: $amount, Payment type: $paymentType', name: 'CustomerWiseReport');
      
      // Payment type categorization
      if (paymentType == 'debit') {
        due += amount;
        developer.log('Adding $amount to due (debit), new due: $due', name: 'CustomerWiseReport');
      } else if (paymentType == 'cash' || paymentType == 'upi') {
        paid += amount;
        developer.log('Adding $amount to paid ($paymentType), new paid: $paid', name: 'CustomerWiseReport');
      } else {
        developer.log('Unknown payment type: $paymentType, not adding to totals', name: 'CustomerWiseReport');
      }
      
      // Parse bill date with fallbacks
      int billDateMs = DateTime.now().millisecondsSinceEpoch;
      if (bill['bill_date'] != null) {
        billDateMs = bill['bill_date'] as int;
        developer.log('Using bill_date: $billDateMs', name: 'CustomerWiseReport');
      } else if (bill['billDate'] != null) {
        billDateMs = (bill['billDate'] as Timestamp).millisecondsSinceEpoch;
        developer.log('Using billDate: $billDateMs', name: 'CustomerWiseReport');
      } else {
        developer.log('No date field found, using current time', name: 'CustomerWiseReport');
      }
      
      final billDate = DateTime.fromMillisecondsSinceEpoch(billDateMs);
      
      // Count items from JSON string
      int itemCount = 0;
      try {
        final itemsJson = bill['items']?.toString() ?? '{}';
        
        developer.log('Items JSON: $itemsJson', name: 'CustomerWiseReport'); // Debug log
        
        // If the items field is already a number, use it directly
        final numericValue = int.tryParse(itemsJson.trim());
        if (numericValue != null) {
          itemCount = numericValue;
          developer.log('Parsed as numeric: $itemCount', name: 'CustomerWiseReport');
        } else {
          // If it's a JSON string, count the actual items
          if (itemsJson.startsWith('[') && itemsJson.endsWith(']')) {
            // Array format: count objects in the array
            // Simple approach: count '{' brackets that are not inside strings
            int objCount = 0;
            bool inString = false;
            
            for (int i = 0; i < itemsJson.length; i++) {
              if (itemsJson[i] == '"') {
                // Toggle string state, but ignore if escaped
                if (i == 0 || itemsJson[i-1] != '\\') {
                  inString = !inString;
                }
              } else if (itemsJson[i] == '{' && !inString) {
                objCount++;
              }
            }
            itemCount = objCount;
            developer.log('Parsed array format: $itemCount items', name: 'CustomerWiseReport');
          } else {
            // If it's an object format or other, default to 1
            itemCount = 1;
            developer.log('Default count: 1 item', name: 'CustomerWiseReport');
          }
        }
      } catch (e) {
        developer.log('Error parsing items: $e', name: 'CustomerWiseReport');
        itemCount = 1; // Default to 1 if parsing fails
      }
      
      // Make sure item count is not negative
      if (itemCount < 0) itemCount = 0;
      
      final processedBill = {
        'billNo': bill['id']?.toString() ?? 'N/A',
        'time': DateFormat('hh:mm a').format(billDate),
        'items': itemCount,
        'amount': amount,
        'paymentType': paymentType,
        'date': billDate,
      };
      
      developer.log('Processed bill result: $processedBill', name: 'CustomerWiseReport');
      return processedBill;
    }).toList();
    
    developer.log('Final totals - Paid: $paid, Due: $due, Orders: $orders', name: 'CustomerWiseReport');
    developer.log('Processed bills count: ${processedBills.length}', name: 'CustomerWiseReport');
    if (processedBills.isNotEmpty) {
      developer.log('First processed bill: ${processedBills.first}', name: 'CustomerWiseReport');
    }
    developer.log('COMPLETED bill processing', name: 'CustomerWiseReport');
    
    return ProcessedBillData(
      bills: processedBills,
      totalPaid: paid,
      totalDue: due,
      totalOrders: orders,
    );
  }

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

          GestureDetector(
            onTap: selectedCustomer != null ? () => fetchCustomerTransactions(selectedCustomer!) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: selectedCustomer != null ? appbar1 : Colors.grey[400],
              ),
              child: Center(
                child: isLoading
                    ? const CircularProgressIndicator(color: white)
                    : const Text(
                        "Find Bills",
                        style: TextStyle(color: white, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
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
                            "₹${(totalPaid + totalDue).toStringAsFixed(0)}",
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
            child: customerBills.isEmpty && !isLoading
                ? const Center(
                    child: Text(
                      'No transactions found for selected customer',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: customerBills.length,
                    itemBuilder: (context, index) {
                      final bill = customerBills[index];

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
                                color: _getPaymentColor(bill['paymentType']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _getPaymentIcon(bill['paymentType']),
                                color: _getPaymentColor(bill['paymentType']),
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
                                  Text(
                                    "Payment: ${_formatPaymentType(bill['paymentType'])}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getPaymentColor(bill['paymentType']),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "₹${bill['amount'].toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: bill['paymentType'] == 'debit' 
                                    ? Colors.orange 
                                    : Colors.green,
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
