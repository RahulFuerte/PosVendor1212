// Dart imports:

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/core/widgets/text.dart';

// Package imports:
import 'package:pos/core/utils/offline_tts.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:pos/data/services/demo_data.dart';
import 'package:pos/view/home/widgets/my_choiceChip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports:

import '../../../data/datasources/local/sqlite_helper.dart';
import '../../../data/datasources/smart_database_service.dart';
import '../../tab_screen/view-model/constants/constants.dart';
import '../../tab_screen/view-model/widgets/printers/printer.dart';
import '../navigation.dart';
import '../../../data/providers/print_provider.dart';
import '../../../core/utils/price_utils.dart';
import '../printer_connectionDialog.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../receipt_preview.dart';
import 'package:showcaseview/showcaseview.dart';

/// Reusable Bill Cart Widget
/// Can be used across multiple pages for consistent cart functionality
class BillCart extends StatefulWidget {
  final VoidCallback? onCartCleared;
  final Function(List<Map<String, dynamic>>, double)? onCartUpdated;
  final Function() orderBottomSheet;
  final VoidCallback? onPlaceOrder;
  final bool? isRestaurantScreen;
  final bool? isContainerVisible;

  const BillCart({
    Key? key,
    this.onCartCleared,
    this.onCartUpdated,
    this.isContainerVisible,
    this.onPlaceOrder,
    this.isRestaurantScreen = false,
    required this.orderBottomSheet,
  }) : super(key: key);

  @override
  State<BillCart> createState() => _BillCartState();
}

class _BillCartState extends State<BillCart> {
  String phoneNo = '';
  String adminUid = '';
  String businessCategory = 'Food';

  final ScrollController _listScrollController = ScrollController();
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _loadCartData();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
        adminUid = prefs.getString('adminUid') ?? '';
        businessCategory = prefs.getString('businessCategory') ?? 'Food';
      });
    }
  }

  List<Map<String, dynamic>> selectedItemsDetails = [];
  double subtotal = 0.0;

  @override
  void didUpdateWidget(covariant BillCart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isContainerVisible == false && oldWidget.isContainerVisible == true) {
      // Auto-collapse when entering fullscreen mode to maximize product view
      Provider.of<PrintProvider>(context, listen: false).setCartExpanded(false);
    }
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

    if (selectedItemsDetails.isNotEmpty) {
      _checkCartTutorial();
    }
  }

  Future<void> _checkCartTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isDemoMode = prefs.getBool('isDemoMode') ?? false;
    final bool isMainFirstTime = prefs.getBool('is_first_time_main_tutorial') ?? true;
    final bool isDetailedFirstTime = prefs.getBool('is_first_time_detailed_tutorial') ?? true;

    // Only start if:
    // 1. In demo mode
    // 2. Main tour is already finished (isMainFirstTime == false)
    // 3. This detailed tour hasn't been shown yet
    if (isDemoMode && !isMainFirstTime && isDetailedFirstTime) {
      // Add a small delay to ensure the cart widget is fully rendered and stable
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final showcase = ShowCaseWidget.of(context);
      if (showcase != null) {
        Provider.of<PrintProvider>(context, listen: false).setCartExpanded(true);
        showcase.startShowCase([
          TourKeys.cartItemsKey,
          TourKeys.subtotalKey,
          TourKeys.cartSaveKey,
          TourKeys.cartPrintKey,
        ]);
        await prefs.setBool('is_first_time_detailed_tutorial', false);
      }
    }
  }

  void _updateCart() {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    printProvider.additem(selectedItemsDetails, subtotal);

    widget.onCartUpdated?.call(selectedItemsDetails, subtotal);

    if (selectedItemsDetails.isNotEmpty) {
      _checkCartTutorial();
    }
  }

  void _showQuantityDialog(int index) {
    final item = selectedItemsDetails[index];
    final TextEditingController controller = TextEditingController(
      text: item['quantity'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MyText(
                  text: "Set Quantity",
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: appbar1,
                ),
                const SizedBox(height: 8),
                MyText(
                  text: "Item: ${item['name']}",
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    hintText: "Enter amount",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.shopping_basket_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: MyText(text: "Cancel", color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final int? newQty = int.tryParse(controller.text);
                        if (newQty != null && newQty > 0) {
                          setState(() {
                            final oldQty = selectedItemsDetails[index]['quantity'];
                            final price = (selectedItemsDetails[index]['price'] as num).toDouble();

                            selectedItemsDetails[index]['quantity'] = newQty;
                            subtotal = subtotal - (oldQty * price) + (newQty * price);

                            _updateCart();
                          });
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appbar1,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const MyText(text: "Update", color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearCart({bool clearTableBackend = false}) {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);
    final tableProvider = Provider.of<TableProvider>(context, listen: false);

    if (clearTableBackend && tableProvider.selectedTableId != null) {
      tableProvider.clearTable(tableProvider.selectedTableId!);
    }

    printProvider.clearCart();
    setState(() {
      selectedItemsDetails.clear();
      subtotal = 0.0;
    });
    widget.onCartCleared?.call();
  }

  Future<void> _handlePreview() async {
    if (selectedItemsDetails.isEmpty) {
      SnackBarUtils.showWarning(context, 'No items in cart');
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

    final tableProvider = Provider.of<TableProvider>(context, listen: false);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptPreviewScreen(
          adminUid: adminUid,
          shopName: shopName,
          contact: contact,
          address: address,
          upiId: upiId,
          phoneNo: phoneNo,
          logoUrl: logoUrl,
          tableNumber: tableProvider.selectedTable?.tableNumber,
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
      SnackBarUtils.showWarning(context, 'Please connect a printer first');
      return;
    }

    if (selectedItemsDetails.isEmpty) {
      SnackBarUtils.showWarning(context, 'No items to print');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Generate sequential receipt number (returns 8-digit padded string like "00000001")
      String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(phoneNo);
      // ignore: use_build_context_synchronously
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

      // ignore: use_build_context_synchronously
      await DirectPrintHelper().printReceipt(
        adminUid: phoneNo,
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
        tableNumber: Provider.of<TableProvider>(context, listen: false).selectedTable?.tableNumber ?? "",
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

      _clearCart(clearTableBackend: true);

      orderTypeProvider.reset();

      if (!mounted) return;
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      if (mounted) {
        SnackBarUtils.showError(context, 'Printing failed: $e');
      }
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        // Always use provider values directly to stay in sync
        selectedItemsDetails = printProvider.posts;
        subtotal = printProvider.total;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
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
          child: RepaintBoundary(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Swipe/Tap to Toggle Cart
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity! < -100) {
                        // Swiped Up (threshold added)
                        if (!printProvider.isCartExpanded) {
                          printProvider.setCartExpanded(true);
                          HapticFeedback.mediumImpact();
                        }
                      } else if (details.primaryVelocity! > 100) {
                        // Swiped Down (threshold added)
                        if (printProvider.isCartExpanded) {
                          printProvider.setCartExpanded(false);
                          HapticFeedback.lightImpact();
                        }
                      }
                    },
                    onTap: () {
                      printProvider.setCartExpanded(!printProvider.isCartExpanded);
                      HapticFeedback.selectionClick();
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  // Pull handle
                                  Container(
                                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  Icon(
                                    printProvider.isCartExpanded
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.keyboard_arrow_up_rounded,
                                    color: Colors.grey.shade400,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!printProvider.isCartExpanded) _buildCollapsedSummary(printProvider),
                      ],
                    ),
                  ),
                  if (printProvider.isCartExpanded) ...[
                    Showcase(
                      key: TourKeys.cartItemsKey,
                      title: 'Review Cart',
                      description:
                          'See all items added to the current order. You can adjust quantities or remove items here.',
                      child: _buildItemsList(printProvider),
                    ),
                    Showcase(
                      key: TourKeys.subtotalKey,
                      title: 'Total Bill Amount',
                      description: 'This is the calculated total including all items and addons.',
                      child: _buildFooter(printProvider),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedSummary(PrintProvider printProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: appbar1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, size: 16, color: appbar1),
                const SizedBox(width: 6),
                MyText(
                  text: '${selectedItemsDetails.length} Items',
                  color: appbar1,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ],
            ),
          ),
          const Spacer(),
          MyText(
            text: 'Total: ',
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
          MyText(
            text: PriceUtils.formatPrice(subtotal),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: appbar1,
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _buildItemsList(PrintProvider printProvider) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 120,
        minHeight: 100,
      ),
      child: ListView.separated(
        controller: _listScrollController,
        shrinkWrap: true,
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
      padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Item Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: item['name'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                const SizedBox(height: 2),
                MyText(
                  text: PriceUtils.formatPrice(item['price']),
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                if (item['addons'] != null && item['addons'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (item['addons'] as List).map((a) {
                        return MyText(
                          text: "+ ${a['name']}",
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20), // Increased spacing to reduce name width

          /// Quantity Controls
          _buildQuantityControls(index, printProvider),

          /// Delete Button
          const SizedBox(width: 12), // Increased spacing
          _buildDeleteButton(index, printProvider),
        ],
      ),
    );
  }

  Widget _buildQuantityControls(int index, PrintProvider printProvider) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: appbar1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.remove, color: appbar1, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _showQuantityDialog(index),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: MyText(
                text: "${selectedItemsDetails[index]['quantity']}",
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              selectedItemsDetails[index]['quantity']++;
              subtotal += (selectedItemsDetails[index]['price'] as num).toDouble();
              _updateCart();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: appbar1.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.add, color: appbar1, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteButton(int index, PrintProvider printProvider) {
    return GestureDetector(
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
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
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
              Showcase(
                key: TourKeys.cartItemsKey,
                title: 'Cart Items',
                description: 'Review the list of items you have added to this order.',
                child: Container(
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
              ),
              const SizedBox(width: 8),
              if (widget.isRestaurantScreen == true && businessCategory == 'Food')
                Consumer<TableProvider>(
                  builder: (context, tableProvider, _) {
                    if (tableProvider.selectedTableId != null) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_bar_outlined, size: 14, color: Colors.orange),
                            const SizedBox(width: 6),
                            MyText(
                              text: tableProvider.selectedTable?.tableNumber ?? '',
                              color: Colors.orange.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              const Spacer(),
              MyText(
                text: 'Total: ',
                fontSize: 15,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              const SizedBox(width: 4),
              Showcase(
                key: TourKeys.subtotalKey,
                title: 'Order Total',
                description: 'The final amount calculated for all items in the cart.',
                child: MyText(
                  text: PriceUtils.formatPrice(subtotal),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: appbar1,
                  letterSpacing: -0.5,
                ),
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
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.isRestaurantScreen == true && businessCategory == 'Food')
                  _buildIconButton(
                    icon: Icons.table_bar,
                    onPressed: () async {
                      final tableProvider = Provider.of<TableProvider>(context, listen: false);
                      final printProvider = Provider.of<PrintProvider>(context, listen: false);

                      // Guard: a table must be selected
                      if (tableProvider.selectedTableId == null) {
                        SnackBarUtils.showWarning(context, 'Please select a table first');
                        return;
                      }

                      // Guard: cart must not be empty
                      if (printProvider.posts.isEmpty) {
                        SnackBarUtils.showWarning(context, 'Cart is empty — nothing to save');
                        return;
                      }

                      // Explicit save: commit current cart to the selected table
                      final savedTableNumber = tableProvider.selectedTable?.tableNumber ?? '';
                      await tableProvider.setTableCart(
                        tableProvider.selectedTableId!,
                        printProvider.posts,
                      );

                      printProvider.clearCart();
                      tableProvider.selectTable(null);

                      if (mounted) {
                        SnackBarUtils.showSuccess(context, 'Cart saved to Table $savedTableNumber ✓');
                        // Navigate to Table Management screen
                        final navigationState = context.findAncestorStateOfType<State<Navigation>>() as dynamic;
                        if (navigationState != null) {
                          navigationState.setState(() {
                            navigationState.currentIndex = 2;
                          });
                        }
                      }
                    },
                    iconColor: Colors.white,
                  ),
                Showcase(
                  key: TourKeys.cartSaveKey,
                  title: 'Save Order',
                  description: 'Saves the bill to print or preview later.',
                  child: _buildIconButton(imagePath: "assets/images/save.png", onPressed: _handlePreview),
                ),
                Showcase(
                  key: TourKeys.cartPrintKey,
                  title: 'Save + Print',
                  description: 'Saves the bill and instantly prints it.',
                  child: _buildIconButton(imagePath: "assets/images/save2.png", onPressed: _handlePrint),
                ),
              ],
            ),
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
    Color? iconColor,
  }) {
    assert(icon != null || imagePath != null);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 5),
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
                  color: iconColor ?? Colors.white,
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
