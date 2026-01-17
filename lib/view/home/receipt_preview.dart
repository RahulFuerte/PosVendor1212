import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/my_choiceChip.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

class ReceiptPreviewScreen extends StatefulWidget {
  final String shopName;
  final String contact;
  final String address;
  final String adminUid;
  final String phoneNo;
  

  const ReceiptPreviewScreen({
    Key? key,
    required this.shopName,
    required this.contact,
    required this.address,
    required this.phoneNo,
    required this.adminUid,
  }) : super(key: key);

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  List<CustomerModel> allCustomers = [];

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController gstCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController discountCtrl = TextEditingController();
  final TextEditingController discountRupeeCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode gstFocus = FocusNode();

  double discountPercent = 0;
  double discountAmount = 0;
  double finalTotal = 0;

  void _updateQuantity(int index, bool increment, PrintProvider provider) {
    List<Map<String, dynamic>> items = List.from(provider.posts);
    double subtotal = provider.total;

    if (increment) {
      items[index]['quantity']++;
      subtotal += items[index]['price'];
    } else {
      if (items[index]['quantity'] > 1) {
        items[index]['quantity']--;
        subtotal -= items[index]['price'];
      } else {
        subtotal -= items[index]['price'];
        items.removeAt(index);
      }
    }

    provider.additem(items, subtotal);
  }

  void _removeItem(int index, PrintProvider provider) {
    List<Map<String, dynamic>> items = List.from(provider.posts);
    double subtotal = provider.total;

    subtotal -= items[index]['price'] * items[index]['quantity'];
    items.removeAt(index);

    provider.additem(items, subtotal);
  }

  Future<void> fetchCustomers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AllAdmins')
        .doc(widget.adminUid)
        .collection('customer')
        .doc(widget.adminUid)
        .collection('myCustomers')
        .get();

    setState(() {
      allCustomers = snapshot.docs.map((doc) {
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

      debugPrint('These Are All Customers: ${allCustomers.length}');
    });
  }

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

/// Function to save new customer data to Firebase if not already stored
  Future<void> saveCustomerToFirebase(CustomerModel customer) async {
    try {
      // Check if customer already exists in Firebase
      final customerDoc = await FirebaseFirestore.instance
          .collection('AllAdmins')
          .doc(widget.adminUid)
          .collection('customer')
          .doc(widget.adminUid)
          .collection('myCustomers')
          .doc(customer.phone)
          .get();
      
      if (!customerDoc.exists) {
        // Customer doesn't exist, save it to Firebase
        await FirebaseFirestore.instance
            .collection('AllAdmins')
            .doc(widget.adminUid)
            .collection('customer')
            .doc(widget.adminUid)
            .collection('myCustomers')
            .doc(customer.phone)
            .set({
              'name': customer.name,
              'phone': customer.phone,
              'gstNo': customer.gstNo,
              'address': customer.address,
              'createdAt': Timestamp.fromDate(customer.createdAt),
              'isUploaded': customer.isUploaded,
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
        
        developer.log('Customer ${customer.name} saved to Firebase with phone ${customer.phone}', name: 'CustomerWiseReport');
        
        // Refresh the customer list to include the new customer
        fetchCustomers();
      } else {
        developer.log('Customer with phone ${customer.phone} already exists in Firebase', name: 'CustomerWiseReport');
      }
    } catch (e) {
      developer.log('Error saving customer to Firebase: $e', name: 'CustomerWiseReport');
      throw e; // Re-throw to handle at calling location
    }
  }

  /// Function to check if a customer exists in Firebase
  Future<bool> doesCustomerExistInFirebase(String phone) async {
    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection('AllAdmins')
          .doc(widget.adminUid)
          .collection('customer')
          .doc(widget.adminUid)
          .collection('myCustomers')
          .doc(phone)
          .get();
      
      return customerDoc.exists;
    } catch (e) {
      developer.log('Error checking if customer exists in Firebase: $e', name: 'CustomerWiseReport');
      return false;
    }
  }


  /// Save bill with automatic online/offline handling
  /// Online: Saves to Firebase and local SQLite
  /// Offline: Saves to local SQLite, syncs when online
  Future<void> saveBill({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    String? tableNumber,
    bool taxEnabled = false,
    double cgstPercent = 0.0,
    double sgstPercent = 0.0,
    String? customerName,
    String? customerPhone,
    String? customerGst,
    String? customerAddress,
    String? customerNote,
    double discountPercent = 0.0,
    double discountAmount = 0.0,
    String? paymentType,
  }) async {
    try {
      final now = DateTime.now();

      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'name': item['name'] ?? '',
          'price': double.tryParse(item['price'].toString()) ?? 0.0,
          'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
        };
      }).toList();

      // Calculate tax amounts if enabled
      double cgstAmount = 0.0;
      double sgstAmount = 0.0;
      double totalWithTax = subTotal;

      if (taxEnabled) {
        cgstAmount = subTotal * (cgstPercent / 100);
        sgstAmount = subTotal * (sgstPercent / 100);
        totalWithTax = subTotal + cgstAmount + sgstAmount;
      }
      
      // Calculate final total with discount
      double finalTotal = totalWithTax - discountAmount;

      // Prepare bill data for SmartDatabaseService
      // Note: items must be JSON encoded string for SQLite storage
      // Schema: id, admin_uid, customer_phone, items, total_amount, bill_date, created_at, updated_at, sync_status, firebase_id
      final billData = {
        'id': receiptNo,
        'bill_date': now.millisecondsSinceEpoch, // Store as integer for proper sorting
        'items': jsonEncode(itemsData), // Convert to JSON string for SQLite
        'total_amount': finalTotal,
        'sub_total': subTotal,
        'table_number': tableNumber ?? 'N/A',
        'tax_enabled': taxEnabled ? 1 : 0, // SQLite doesn't support bool, use int
        'cgst_percent': cgstPercent,
        'sgst_percent': sgstPercent,
        'cgst_amount': cgstAmount,
        'sgst_amount': sgstAmount,
        'customer_name': customerName ?? '',
        'customer_phone': customerPhone ?? '',
        'customer_gst': customerGst ?? '',
        'customer_address': customerAddress ?? '',
        'customer_note': customerNote ?? '',
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'final_total': finalTotal,
        'payment_type': paymentType ?? '',
      };

      // Save using SmartDatabaseService (handles online/offline automatically)
      // This already saves to Firebase when online, no need for separate Firebase call
      await _databaseService.saveBill(adminUid, billData);

      await saveCustomerToFirebase(CustomerModel(name: customerName ?? '', phone: customerPhone ?? '', createdAt: now, isUploaded: true, gstNo: customerGst ?? ''));

      debugPrint(
          '[ReceiptPreview] Bill saved successfully - receiptNo: $receiptNo (${_databaseService.isOnline ? "online" : "offline"})');
    } catch (e) {
      debugPrint('Error saving bill: $e');
      rethrow;
    }
  }

  Future<void> _handleSaveWithoutPrint() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Confirm Action', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to save this bill without printing?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: appbar1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Yes, Save', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    // Generate sequential receipt number (returns 8-digit padded string like "00000001")
    String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);

    try {
      // Get tax parameters (already have default values in PrintProvider)
      final bool taxEnabled = printProvider.taxEnabled;
      final double cgstPercent = printProvider.cgstPercent;
      final double sgstPercent = printProvider.sgstPercent;

      // Get payment type from OrderTypeProvider
      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last; // Convert enum to string
      
      await saveBill(
        adminUid: widget.phoneNo,
        receiptNo: generatedReceiptNo,
        items: printProvider.posts,
        subTotal: printProvider.total,
        taxEnabled: taxEnabled,
        cgstPercent: cgstPercent,
        sgstPercent: sgstPercent,
        customerName: nameCtrl.text,
        customerPhone: phoneCtrl.text,
        customerGst: gstCtrl.text,
        customerAddress: addressCtrl.text,
        customerNote: noteCtrl.text,
        discountPercent: discountPercent,
        discountAmount: discountAmount,
        paymentType: paymentType,
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
                      ? 'Bill saved! Receipt No: $generatedReceiptNo'
                      : 'Bill saved offline! Receipt No: $generatedReceiptNo (will sync when online)',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Clear cart after successful save
      printProvider.clearCart();
      
      // Navigate back to previous screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save bill: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        final cartItems = printProvider.posts;
        final subtotal = printProvider.total;

        if (discountCtrl.text.isEmpty && discountRupeeCtrl.text.isEmpty) {
          finalTotal = subtotal;
        }

        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(context);
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            bottomNavigationBar: Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: appbar1.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Text(
                            '₹${numberFormat.format(finalTotal)}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: appbar1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Consumer<OrderTypeProvider>(
                      builder: (context, provider, _) {
                        return MyChoiceChip(
                          options: const ['Cash', 'UPI', 'Debit', 'Complementory'],
                          selectedValue: provider.paymentType == PaymentType.cash
                              ? 'Cash'
                              : provider.paymentType == PaymentType.upi
                                  ? "UPI"
                                  : provider.paymentType == PaymentType.debit
                                      ? "Debit"
                                      : "Complementory",
                          onSelected: (value) {
                            provider.setPaymentType(
                              value == 'Cash'
                                  ? PaymentType.cash
                                  : value == 'UPI'
                                      ? PaymentType.upi
                                      : value == 'Debit'
                                          ? PaymentType.debit
                                          : PaymentType.complementory,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildIconButton(
                          imagePath: "assets/images/kot.png",
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/kot2.png",
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/save.png",
                          onPressed: _handleSaveWithoutPrint,
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/save2.png",

                          onPressed: () async {
                            if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please connect a printer first'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            try {
                              await DirectPrintHelper.printReceipt(
                                adminUid: widget.phoneNo,
                                context: context,
                                printer: printProvider.selectedPrinter!,
                                paperSize: printProvider.selectedPaperSize,
                                items: cartItems,
                                total: subtotal,
                                shopName: widget.shopName,
                                logoUrl: widget.shopName,
                                contact: widget.contact,
                                address: widget.address,
                                saveBill: true,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);

                                printProvider.clearCart();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Printing failed: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },

                          // onPressed: () => widget.orderBottomSheet.call(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            appBar: AppBar(
              title: const Text(
                'Save Receipt',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: white),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: appbar1,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Cart is Empty',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        // Header

                        Text(
                          widget.shopName,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appbar1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.address,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Contact: ${widget.contact}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          width: double.infinity,
                          child: const OrderTypeSelector(),
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: Text(
                            'Add Customer Details',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: appbar1),
                          ),
                        ),
                        const SizedBox(height: 20),
                        customerAutoCompleteField(
                          controller: nameCtrl,
                          focusNode: nameFocus,
                          label: 'Customer Name',
                          filter: (text) {
                            if (text.text.isEmpty) return const Iterable<CustomerModel>.empty();
                            return allCustomers.where(
                              (c) => c.name.toLowerCase().contains(text.text.toLowerCase()),
                            );
                          },
                          displayText: (c) => c.name,
                        ),
                        const SizedBox(height: 10),
                        customerAutoCompleteField(
                          controller: phoneCtrl,
                          focusNode: phoneFocus,
                          label: 'Phone Number',
                          keyboardType: TextInputType.phone,
                          filter: (text) {
                            if (text.text.isEmpty) return const Iterable<CustomerModel>.empty();
                            return allCustomers.where(
                              (c) => c.phone.contains(text.text),
                            );
                          },
                          displayText: (c) => c.phone,
                        ),
                        const SizedBox(height: 10),
                        customerAutoCompleteField(
                          controller: gstCtrl,
                          focusNode: gstFocus,
                          label: 'GST Number',
                          filter: (text) {
                            if (text.text.isEmpty) return const Iterable<CustomerModel>.empty();
                            return allCustomers.where(
                              (c) => (c.gstNo ?? '').toLowerCase().contains(text.text.toLowerCase()),
                            );
                          },
                          displayText: (c) => c.gstNo ?? '',
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: addressCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Item List',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: appbar1),
                              ),
                              Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: appbar1, borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    "Add Item",
                                    style: TextStyle(color: Colors.white),
                                  ))
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(2.4),
                            1: FlexColumnWidth(1.2), // Price
                            2: FlexColumnWidth(2.3), // Qty
                            3: FlexColumnWidth(1.2), // Total
                            4: FlexColumnWidth(0.9), // Total
                          },
                          children: [
                            // =======================
                            // Header Row
                            // =======================
                            TableRow(
                              decoration: BoxDecoration(color: appbar1.withOpacity(0.08)),
                              children: [
                                _buildCell(
                                  text: 'Item',
                                  fontWeight: FontWeight.bold,
                                  textAlign: TextAlign.left,
                                ),
                                _buildCell(
                                  text: 'Price',
                                  fontWeight: FontWeight.bold,
                                ),
                                _buildCell(
                                  text: 'Qty',
                                  fontWeight: FontWeight.bold,
                                ),
                                _buildCell(
                                  text: 'Total',
                                  fontWeight: FontWeight.bold,
                                ),
                                _buildCell(),
                              ],
                            ),

                            // =======================
                            // Item Rows
                            // =======================
                            ...List.generate(cartItems.length, (index) {
                              final item = cartItems[index];
                              final itemTotal = item['price'] * item['quantity'];

                              return TableRow(
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black38))),
                                children: [
                                  // Item Name
                                  _buildCell(
                                    text: item['name'],
                                    textAlign: TextAlign.left,
                                  ),

                                  // Price
                                  _buildCell(
                                    text: '₹${item['price']}',
                                  ),

                                  // Quantity Controls
                                  _buildCell(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        InkWell(
                                          onTap: () => _updateQuantity(index, false, printProvider),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: appbar1,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 22,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            '${item['quantity']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () => _updateQuantity(index, true, printProvider),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: appbar1,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 22,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Item Total
                                  _buildCell(
                                    text: '₹$itemTotal',
                                    fontWeight: FontWeight.bold,
                                  ),

                                  // Delete Button
                                  _buildCell(
                                    child: InkWell(
                                      onTap: () => _removeItem(index, printProvider),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),

                        const SizedBox(
                          height: 30,
                        ),
                        Row(
                          children: [
                            Text(
                              'Discount',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: appbar1),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: discountCtrl,
                                maxLength: 3,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: Colors.black, fontSize: 15),
                                onChanged: (value) {
                                  final subtotal = context.read<PrintProvider>().total;

                                  // When user clears %
                                  if (value.isEmpty) {
                                    discountPercent = 0;
                                    discountAmount = 0;
                                    finalTotal = subtotal;

                                    discountRupeeCtrl.clear(); // 🔥 clear rupees
                                    setState(() {});
                                    return;
                                  }

                                  final percent = double.tryParse(value) ?? 0;

                                  discountPercent = percent;
                                  discountAmount = (subtotal * percent) / 100;

                                  if (discountAmount > subtotal) {
                                    discountAmount = subtotal;
                                    discountPercent = 100;
                                  }

                                  finalTotal = subtotal - discountAmount;

                                  discountRupeeCtrl.text = discountAmount.toStringAsFixed(2);
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 1, horizontal: 10),
                                  suffixIcon: Container(
                                    width: 50,
                                    child: Icon(
                                      Icons.percent,
                                      color: Colors.white,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                                      color: appbar1.withOpacity(0.8),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: discountRupeeCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.black, fontSize: 15),
                                onChanged: (value) {
                                  final subtotal = context.read<PrintProvider>().total;

                                  // When user clears ₹
                                  if (value.isEmpty) {
                                    discountPercent = 0;
                                    discountAmount = 0;
                                    finalTotal = subtotal;

                                    discountCtrl.clear(); // 🔥 clear percent
                                    setState(() {});
                                    return;
                                  }

                                  final rupees = double.tryParse(value) ?? 0;

                                  discountAmount = rupees > subtotal ? subtotal : rupees;
                                  discountPercent = (discountAmount / subtotal) * 100;
                                  finalTotal = subtotal - discountAmount;

                                  discountCtrl.text = discountPercent.toStringAsFixed(1);
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 1, horizontal: 10),
                                  suffixIcon: Container(
                                    width: 50,
                                    child: const Icon(
                                      Icons.currency_rupee,
                                      color: Colors.white,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                                      color: appbar1.withOpacity(0.8),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 20,
                        ),

                        TextFormField(
                          controller: noteCtrl,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: Colors.black, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Enter Note",
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              'Bill Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: appbar1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  children: [
                                    _billRow('Item Total', 2),
                                    _billRow('Discount + Tax', 4),
                                    _billRow('Total Tax', 6),
                                    _billRow('Round Off', 7),
                                    const Divider(thickness: 1),
                                    _billRow(
                                      'TO PAY',
                                      8,
                                      isBold: true,
                                      valueColor: Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _billRow(
    String title,
    double amount, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            '₹ ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget customerAutoCompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    required Iterable<CustomerModel> Function(TextEditingValue text) filter,
    required String Function(CustomerModel c) displayText,
  }) {
    return RawAutocomplete<CustomerModel>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: filter,
      displayStringForOption: displayText,
      onSelected: _fillCustomerDetails,
      optionsViewBuilder: (context, onSelected, options) {
        return Material(
          elevation: 4,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final c = options.elementAt(index);
              return ListTile(
                title: Text(c.name),
                subtitle: Text('${c.phone} | ${c.gstNo ?? ''}'),
                onTap: () => onSelected(c),
              );
            },
          ),
        );
      },
      fieldViewBuilder: (context, ctrl, focusNode, _) {
        return TextField(
            controller: ctrl,
            focusNode: focusNode,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: label,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ));
      },
    );
  }

  void _fillCustomerDetails(CustomerModel customer) {
    nameCtrl.text = customer.name;
    phoneCtrl.text = customer.phone;
    gstCtrl.text = customer.gstNo ?? '';
    addressCtrl.text = customer.address ?? '';

    FocusScope.of(context).unfocus();
  }

  Widget _buildIconButton({
    required String imagePath,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appbar1,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset(
          imagePath,
          width: 35,
          height: 35,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildCell({
    String? text,
    FontWeight? fontWeight,
    TextAlign? textAlign,
    Widget? child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: child ??
          Text(
            text ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign ?? TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: fontWeight ?? FontWeight.w500),
          ),
    );
  }
}
