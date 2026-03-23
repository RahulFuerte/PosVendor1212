// Dart imports:

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:pos/core/utils/offline_tts.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/view/home/widgets/my_choiceChip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      String shopName = prefs.getString('shopName') ?? 'Shop Name';
      String contact = prefs.getString('contact') ?? 'Contact';
      String address = prefs.getString('address') ?? 'Address';
      String logoUrl = prefs.getString('logoUrl') ?? '';
      String upiId = prefs.getString('upiId') ?? "";

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
        saveBill: true,
      );

      _clearCart();

      if (!mounted) return;
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: MyText(text: 'Dine-in receipt printed for Table $tableNumber'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(parentContext);
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: MyText(text: 'Printing failed: $e'),
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
          content: const MyText(text: 'No items in cart'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Fetch shop data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    String shopName = prefs.getString('shopName') ?? 'Shop Name';
    String contact = prefs.getString('contact') ?? 'Contact';
    String address = prefs.getString('address') ?? 'Address';
    String upiId = prefs.getString('upiId') ?? "";
    String logoUrl = prefs.getString('logoUrl') ?? "";

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
          logoUrl: logoUrl,
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
          content: const MyText(text: 'Please connect a printer first'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (selectedItemsDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const MyText(text: 'No items to print'),
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
        items: selectedItemsDetails,
        subTotal: subtotal,
        shopName: shopName,
        contact: contact,
        address: address,
        logoUrl: logoUrl,
        customerName: printProvider.customerName ?? "",
        customerPhone: printProvider.customerPhone ?? "",
        upiId: upiId,
        customerGst: printProvider.customerGst ?? "",
        orderType: orderType,
        paymentType: paymentType,
        tableNumber: "",
        discountAmount: 0,
        discountPercent: 0,
        customerNote: printProvider.customerNote ?? "",
        customerAddress: printProvider.customerAddress ?? "",
        receiptNo: generatedReceiptNo,
        customerId: printProvider.customerId,
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
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        // Always use provider values directly to stay in sync
        selectedItemsDetails = printProvider.posts;
        subtotal = printProvider.total;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull handle indicator
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
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
      height: 100, // Slightly taller for breathing room
      child: ListView.separated(
        controller: _listScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: selectedItemsDetails.length,
        separatorBuilder: (context, index) => const Divider(height: 16, color: Colors.black12),
        itemBuilder: (context, index) {
          return _buildCartItem(index, printProvider);
        },
      ),
    );
  }

  Widget _buildCartItem(int index, PrintProvider printProvider) {
    final item = selectedItemsDetails[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Item Info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: item['name'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                const SizedBox(height: 4),
                MyText(
                  text: "${PriceUtils.formatPrice(item['price'])} × ${item['quantity']}",
                  fontSize: 13,
                  color: appbar1.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
                if (item['addons'] != null && item['addons'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (item['addons'] as List).map((a) {
                        return MyText(
                          text: "+ ${a['name']} (${PriceUtils.formatPrice(a['price'])})",
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          /// Quantity Controls
          Expanded(
            flex: 2,
            child: _buildQuantityControls(index, printProvider),
          ),

          /// Delete Button
          SizedBox(
            width: 40,
            child: _buildDeleteButton(index, printProvider),
          ),
        ],
      ),
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
              child: MyText(
                text: "${selectedItemsDetails[index]['quantity']}",
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appbar1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: appbar1.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 14, color: appbar1),
                    const SizedBox(width: 6),
                    MyText(
                      text: '${selectedItemsDetails.length} Items',
                      color: appbar1,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              MyText(
                text: 'Total: ',
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 4),
              MyText(
                text: PriceUtils.formatPrice(subtotal),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: appbar1,
                letterSpacing: -0.5,
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                        content: const MyText(text: 'Please connect a printer first'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  if (selectedItemsDetails.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: const MyText(text: 'No items in cart'),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appbar1,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: appbar1.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
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
