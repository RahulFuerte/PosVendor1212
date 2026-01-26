// Dart imports:

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pos/core/utils/offline_tts.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/view/home/widgets/my_choiceChip.dart';
import 'package:provider/provider.dart';

// Project imports:

import '../../../data/datasources/local/sqlite_helper.dart';
import '../../../data/datasources/smart_database_service.dart';
import '../../tab_screen/view-model/constants/constants.dart';
import '../../tab_screen/view-model/widgets/printers/printer.dart';
import '../../tab_screen/view-model/widgets/table/table_number_bottom_sheet.dart';
import '../navigation.dart';
import '../../../data/providers/print_provider.dart';
import '../../../core/utils/price_utils.dart';
import '../printer_connectionDialog.dart';
import '../receipt_preview.dart';

/// Reusable Bill Cart Widget
/// Can be used across multiple pages for consistent cart functionality
class BillCart extends StatefulWidget {
  final String adminUid;
  final String phoneNo;
  final VoidCallback? onCartCleared;
  final Function(List<Map<String, dynamic>>, double)? onCartUpdated;
  final Function() orderBottomSheet;
  final bool? isRestaurantScreen;
  final bool? isContainerVisible;

  const BillCart({
    Key? key,
    required this.adminUid,
    required this.phoneNo,
    this.onCartCleared,
    this.onCartUpdated,
    this.isContainerVisible,
    this.isRestaurantScreen = false,
    required this.orderBottomSheet,
  }) : super(key: key);

  @override
  State<BillCart> createState() => _BillCartState();
}

class _BillCartState extends State<BillCart> {
  final ScrollController _listScrollController = ScrollController();
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
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

  /// Fetch shop data with local-first approach
  /// First checks SQLite, then Firebase if not found locally
  Future<Map<String, String>> _getShopData() async {
    String shopName = 'N/A';
    String contact = 'N/A';
    String address = 'N/A';
    String logoUrl = '';
    String upiId = '';

    try {
      // First try to get from local SQLite
      final localData = await _sqliteHelper.getUserData(widget.phoneNo);

      if (localData != null) {
        shopName = localData['shopName'] ?? 'N/A';
        contact = localData['shopContact'] ?? 'N/A';
        address = localData['address'] ?? 'N/A';
        logoUrl = localData['shopLogoUrl'] ?? '';
        upiId = localData['upiId'] ?? '';
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
            upiId = data['upiId'] ?? '';

            // Save all fields to local SQLite for future use
            await _sqliteHelper.saveUserData({
              'phoneNumber': data['phoneNumber'] ?? widget.phoneNo,
              'adminUid': data['adminUid'] ?? widget.adminUid,
              'shopName': shopName,
              'contact': contact,
              'address': address,
              'upiId': upiId,
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
      'upiId': upiId,
    };
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

  Future<void> _showTableNumberBottomSheet(BuildContext parentContext) async {
    final printProvider = Provider.of<PrintProvider>(parentContext, listen: false);

    final tableNumber = await TableNumberBottomSheet.show(
      context: parentContext,
      primaryColor: appbar1,
      confirmButtonText: 'Print Receipt',
    );

    if (tableNumber == null || !mounted) return; // User cancelled or widget unmounted

    // Show loading dialog
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate sequential receipt number (returns 8-digit padded string like "00000001")
      String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);

      // Get tax parameters (already have default values in PrintProvider)

      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last;
      String orderType = orderTypeProvider.orderType.toString().split('.').last;

      // Fetch shop data (local-first)
      final shopData = await _getShopData();
      String shopName = shopData['shopName']!;
      String contact = shopData['contact']!;
      String address = shopData['address']!;
      String logoUrl = shopData['logoUrl']!;
      String upiId = shopData['upiId'] ?? "";

      if (!mounted) return;
      Navigator.pop(parentContext);

      // Print dine-in receipt with table number
      await DirectPrintHelper().printReceipt(
        adminUid: widget.phoneNo,
        context: parentContext,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: selectedItemsDetails,
        subTotal: subtotal,
        shopName: shopName,
        contact: contact,
        address: address,
        logoUrl: logoUrl,
        upiId: upiId,
        tableNumber: tableNumber,
        receiptNo: generatedReceiptNo,
        customerName: "",
        customerPhone: "",
        customerGst: "",
        orderType: orderType,

        paymentType: paymentType,
        discountAmount: 0,
        discountPercent: 0,
        customerNote: "",
        customerAddress: "",
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        saveBill: false, // Bill already saved via SmartDatabaseService
      );

      _clearCart();

      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Dine-in receipt printed for Table $tableNumber'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(parentContext);
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text('Printing failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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

    // Fetch shop data (local-first)
    final shopData = await _getShopData();
    if (!mounted) return;

    String shopName = shopData['shopName']!;
    String contact = shopData['contact']!;
    String address = shopData['address']!;
    String upiId = shopData['upiId'] ?? "";

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPreviewScreen(
          adminUid: widget.adminUid,
          shopName: shopName,
          contact: contact,
          address: address,
          upiId: upiId,
          phoneNo: widget.phoneNo,
        ),
      ),
    );

    if (!mounted) return;
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
      // Generate sequential receipt number (returns 8-digit padded string like "00000001")
      String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);
      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last;
      String orderType = orderTypeProvider.orderType.toString().split('.').last;
      final int amount = subtotal.round();
      final String amountInWords = numberToWords(amount);

      // Fetch shop data (local-first)
      final shopData = await _getShopData();
      String shopName = shopData['shopName']!;
      String contact = shopData['contact']!;
      String address = shopData['address']!;
      String logoUrl = shopData['logoUrl']!;
      String upiId = shopData['upiId'] ?? "";

      if (!mounted) return;
      Navigator.pop(context);

      await DirectPrintHelper().printReceipt(
        adminUid: widget.phoneNo,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: selectedItemsDetails,
        subTotal: subtotal,
        shopName: shopName,
        contact: contact,
        address: address,
        logoUrl: logoUrl,
        customerName: "",
        customerPhone: "",
        upiId: upiId,
        customerGst: "",
        orderType: orderType,
        paymentType: paymentType,
        tableNumber: "",
        discountAmount: 1,
        discountPercent: 0,
        customerNote: "",
        customerAddress: "",
        receiptNo: generatedReceiptNo,
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        saveBill: true,
      );

      await OfflineTTS.speak(
        "$amountInWords rupees",
      );

      _clearCart();

      orderTypeProvider.reset();

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
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        // Always use provider values directly to stay in sync
        selectedItemsDetails = printProvider.posts;
        subtotal = printProvider.total;

        return Container(
          color: white,
          margin: const EdgeInsets.only(top: 5, bottom: 5),
          child: Column(
            children: [
              _buildItemsList(printProvider),
              _buildFooter(printProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsList(PrintProvider printProvider) {
    return SizedBox(
      height: 120,
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
    final item = selectedItemsDetails[index];

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            /// Item Name
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "${PriceUtils.formatPrice(item['price'])} × ${item['quantity']}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item['addons'] != null && item['addons'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (item['addons'] as List).map((a) {
                          return Text(
                            "${a['name']} (${PriceUtils.formatPrice(a['price'])})",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            /// Quantity Buttons
            _buildQuantityControls(index, printProvider),

            /// Delete Button
            Center(
              child: _buildDeleteButton(index, printProvider),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityControls(int index, PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (selectedItemsDetails[index]['quantity'] > 1) {
                    selectedItemsDetails[index]['quantity']--;
                    subtotal -= (selectedItemsDetails[index]['price'] as num).toDouble();
                  } else {
                    subtotal -= (selectedItemsDetails[index]['price'] as num).toDouble();

                    selectedItemsDetails.removeAt(index);
                  }
                  _updateCart();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: appbar1, borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.remove, color: white, size: 25),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "${selectedItemsDetails[index]['quantity']}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedItemsDetails[index]['quantity']++;
                  subtotal += (selectedItemsDetails[index]['price'] as num).toDouble();

                  _updateCart();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: appbar1, borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.add, color: white, size: 25),
              ),
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
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(Icons.delete, color: Colors.red, size: 22),
      ),
    );
  }

  Widget _buildFooter(PrintProvider printProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
      color: Colors.grey.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              const Spacer(),
              Text(
                'Grand Total :',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Text(
                PriceUtils.formatPrice(subtotal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconButton(
                icon: Icons.table_bar,
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
              _buildIconButton(icon: Icons.person, onPressed: () => widget.orderBottomSheet.call()),
              _buildIconButton(imagePath: "assets/images/kot2.png", onPressed: () {}),
              _buildIconButton(imagePath: "assets/images/save.png", onPressed: _handlePreview),
              _buildIconButton(imagePath: "assets/images/save2.png", onPressed: _handlePrint),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    IconData? icon,
    String? imagePath,
    required VoidCallback onPressed,
    double size = 35,
  }) {
    assert(icon != null || imagePath != null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appbar1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GestureDetector(
        onTap: onPressed,
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: size,
                  color: Colors.white,
                )
              : Image.asset(
                  imagePath!,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }

  // Widget _buildIconButton({required IconData icon, required VoidCallback onPressed}) {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.grey.withOpacity(0.3),
  //           blurRadius: 4,
  //           offset: const Offset(0, 2),
  //         )
  //       ],
  //     ),
  //     child: IconButton(
  //       icon: Icon(icon, color: appbar1, size: 24),
  //       onPressed: onPressed,
  //     ),
  //   );
  // }
}
