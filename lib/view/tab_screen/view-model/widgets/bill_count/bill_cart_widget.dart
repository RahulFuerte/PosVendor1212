import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:convert';

import '../../../../home/navigation.dart';
import '../../../../home/print_provider.dart';
import '../../../../home/printer_connectionDialog.dart';
import '../../../../home/receipt_preview.dart';
import '../../constants/constants.dart';
import '../printers/printer.dart';
import '../../backend/smart_database_service.dart';


/// Reusable Bill Cart Widget
/// Can be used across multiple pages for consistent cart functionality
class BillCartWidget extends StatefulWidget {
  final String adminUid;
  final String phoneNo;
  final VoidCallback? onCartCleared;
  final Function(List<Map<String, dynamic>>, double)? onCartUpdated;
  final Function() orderBottomSheet;

  const BillCartWidget({
    Key? key,
    required this.adminUid,
    required this.phoneNo,
    this.onCartCleared,
    this.onCartUpdated,
    required this.orderBottomSheet,
  }) : super(key: key);

  @override
  State<BillCartWidget> createState() => _BillCartWidgetState();
}

class _BillCartWidgetState extends State<BillCartWidget> {
  final ScrollController _listScrollController = ScrollController();
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  List<Map<String, dynamic>> selectedItemsDetails = [];
  double subtotal = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadCartData();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _databaseService.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _loadCartData() {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    setState(() {
      selectedItemsDetails = printProvider.posts;
      subtotal = printProvider.total;
    });
  }

  /// Save bill with automatic online/offline handling
  /// Online: Saves to Firebase and local SQLite
  /// Offline: Saves to local SQLite, syncs when online
  Future<void> saveBill({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
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

      // Prepare bill data for SmartDatabaseService
      // Note: items must be JSON encoded string for SQLite storage
      // Schema: id, admin_uid, customer_phone, items, total_amount, bill_date, created_at, updated_at, sync_status, firebase_id
      final billData = {
        'id': receiptNo,
        'bill_date': now.millisecondsSinceEpoch,
        'items': jsonEncode(itemsData), // Convert to JSON string for SQLite
        'total_amount': subTotal,
      };

      // Save using SmartDatabaseService (handles online/offline automatically)
      await _databaseService.saveBill(adminUid, billData);

      // If online, also save to Firebase for backward compatibility
      if (_databaseService.isOnline) {
        await _saveBillToFirebase(
          adminUid: adminUid,
          receiptNo: receiptNo,
          items: items,
          subTotal: subTotal,
        );
      }

      debugPrint('Bill saved successfully (${_databaseService.isOnline ? "online" : "offline"})');
    } catch (e) {
      debugPrint('Error saving bill: $e');
      rethrow;
    }
  }

  /// Save bill to Firebase (for online mode and backward compatibility)
  Future<void> _saveBillToFirebase({
    required String adminUid,
    required String receiptNo,
    required List<Map<String, dynamic>> items,
    required double subTotal,
  }) async {
    try {
      final now = DateTime.now();
      final monthDoc = DateFormat('yyyyMM').format(now);
      final dateDoc = DateFormat('yyyyMMdd').format(now);
      final dateString = DateFormat('MMM dd, yyyy').format(now);

      final List<Map<String, dynamic>> itemsData = items.map((item) {
        return {
          'name': item['name'] ?? '',
          'price': double.tryParse(item['price'].toString()) ?? 0.0,
          'quantity': int.tryParse(item['quantity'].toString()) ?? 1,
        };
      }).toList();

      await FirebaseFirestore.instance.collection('AllBills').doc(adminUid).collection('myBills').doc(monthDoc).collection(dateDoc).doc(receiptNo).set({
        'adminId': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
        'date': dateString,
        'items': itemsData,
        'receiptNo': receiptNo,
        'subTotal': subTotal,
      });

      debugPrint('Bill saved to Firebase successfully');
    } catch (e) {
      debugPrint('Error saving bill to Firebase: $e');
      // Don't rethrow - local save already succeeded
    }
  }

  void _updateCart() {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    printProvider.additem(selectedItemsDetails, subtotal);
    widget.onCartUpdated?.call(selectedItemsDetails, subtotal);
  }

  void _clearCart() {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    printProvider.clearCart();
    setState(() {
      selectedItemsDetails.clear();
      subtotal = 0.0;
    });
    widget.onCartCleared?.call();
  }

  Future<void> _showTableNumberBottomSheet(BuildContext context) async {
    // Implement your table number bottom sheet logic here
    // This is a placeholder
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: const Text('Table Number Selection'),
      ),
    );
  }

  Future<void> _showSaveOrderBottomSheet() {
    return widget.orderBottomSheet.call();
  }

  Future<void> _handleSaveWithoutPrint() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
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
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
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

    if (confirmed == true) {
      Random random = Random();
      String generatedReceiptNo = '';
      for (int i = 0; i < 8; i++) {
        generatedReceiptNo += random.nextInt(10).toString();
      }

      try {
        await saveBill(
          adminUid: widget.phoneNo,
          receiptNo: generatedReceiptNo,
          items: selectedItemsDetails,
          subTotal: subtotal,
        );

        if (context.mounted) {
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
          _clearCart();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save bill: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handlePreview() async {
    if (selectedItemsDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items in cart'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('AllAdmins').doc(widget.adminUid).collection('customer').doc(widget.phoneNo).get();

    String shopName = 'N/A';
    String contact = 'N/A';
    String address = 'N/A';

    if (doc.exists) {
      final data = doc.data();
      if (data != null) {
        shopName = data['shopName'] ?? 'N/A';
        contact = data['contact'] ?? 'N/A';
        address = data['address'] ?? 'N/A';
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPreviewScreen(
          adminUid: widget.adminUid,
          shopName: shopName,
          contact: contact,
          address: address,
          phoneNo: widget.phoneNo,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        selectedItemsDetails = result['items'];
        subtotal = result['subtotal'];
        _updateCart();
      });
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

    if (selectedItemsDetails.isEmpty) {
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
      // Generate receipt number
      Random random = Random();
      String generatedReceiptNo = '';
      for (int i = 0; i < 8; i++) {
        generatedReceiptNo += random.nextInt(10).toString();
      }

      // Save bill to local database (and Firebase if online)
      await saveBill(
        adminUid: widget.phoneNo,
        receiptNo: generatedReceiptNo,
        items: selectedItemsDetails,
        subTotal: subtotal,
      );

      final doc = await FirebaseFirestore.instance.collection('AllAdmins').doc(widget.adminUid).collection('customer').doc(widget.phoneNo).get();

      String shopName = 'N/A';
      String contact = 'N/A';
      String address = 'N/A';

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          shopName = data['shopName'] ?? 'N/A';
          contact = data['contact'] ?? 'N/A';
          address = data['address'] ?? 'N/A';
        }
      }

      if (context.mounted) Navigator.pop(context);

      await DirectPrintHelper.printReceipt(
        adminUid: widget.phoneNo,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: selectedItemsDetails,
        total: subtotal,
        shopName: shopName,
        contact: contact,
        address: address,
      );

      _clearCart();
      
      if (context.mounted) {
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
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint('Error printing receipt: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Printing failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        // Update local state when provider changes
        if (printProvider.posts != selectedItemsDetails) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              selectedItemsDetails = printProvider.posts;
              subtotal = printProvider.total;
            });
          });
        }

        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              _buildHeader(printProvider),
              _buildItemsList(printProvider),
              _buildFooter(printProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: primaryColor, size: 20),
              Text(
                ' My Cart',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'tabfont',
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedItemsDetails.length} Items',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildIconButton(
                icon: MdiIcons.tableChair,
                onPressed: () async {
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

                  if (selectedItemsDetails.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No items in cart'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  await _showTableNumberBottomSheet(context);
                },
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: MdiIcons.printerOff,
                onPressed: _handleSaveWithoutPrint,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(PrintProvider printProvider) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.15,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        controller: _listScrollController,
        itemCount: selectedItemsDetails.length,
        itemBuilder: (context, index) {
          return _buildCartItem(index, printProvider);
        },
      ),
    );
  }

  Widget _buildCartItem(int index, PrintProvider printProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: appbar1,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedItemsDetails[index]['name'],
                  style: const TextStyle(
                    overflow: TextOverflow.ellipsis,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${selectedItemsDetails[index]['price']} × ${selectedItemsDetails[index]['quantity']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildQuantityControls(index, printProvider),
          const SizedBox(width: 8),
          _buildDeleteButton(index, printProvider),
        ],
      ),
    );
  }

  Widget _buildQuantityControls(int index, PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (selectedItemsDetails[index]['quantity'] > 1) {
                  selectedItemsDetails[index]['quantity']--;
                  subtotal -= selectedItemsDetails[index]['price'];
                } else {
                  subtotal -= selectedItemsDetails[index]['price'];
                  selectedItemsDetails.removeAt(index);
                }
                _updateCart();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.remove, color: appbar1, size: 18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "${selectedItemsDetails[index]['quantity']}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                selectedItemsDetails[index]['quantity']++;
                subtotal += selectedItemsDetails[index]['price'];
                _updateCart();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add, color: appbar1, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteButton(int index, PrintProvider printProvider) {
    return InkWell(
      onTap: () {
        setState(() {
          subtotal -= selectedItemsDetails[index]['price'] * selectedItemsDetails[index]['quantity'];
          selectedItemsDetails.removeAt(index);
          _updateCart();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
    );
  }

  Widget _buildFooter(PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "₹$subtotal",
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildIconButton(
                icon: Icons.receipt_long_outlined,
                onPressed: _handlePreview,
              ),
              const SizedBox(width: 10),
              _buildIconButton(
                icon: Icons.bookmark_outline,
                onPressed: () => widget.orderBottomSheet.call(),
              ),
              const SizedBox(width: 10),
              _buildPrintButton(printProvider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
        icon: Icon(icon, color: appbar1, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPrintButton(PrintProvider printProvider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [appbar1, appbar1.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: appbar1.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: IconButton(
        icon: Icon(
          Icons.print,
          color: printProvider.isConnected ? Colors.green : Colors.white,
          size: 24,
        ),
        onPressed: _handlePrint,
      ),
    );
  }
}

// Usage Example in your page:
/*
class YourPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Your other widgets
          BillCartWidget(
            adminUid: 'your_admin_uid',
            phoneNo: 'your_phone_no',
            onCartCleared: () {
              print('Cart cleared!');
            },
            onCartUpdated: (items, total) {
              print('Cart updated: $total');
            },
          ),
        ],
      ),
    );
  }
}
*/