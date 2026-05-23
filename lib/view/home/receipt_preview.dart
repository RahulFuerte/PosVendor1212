import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/core/utils/offline_tts.dart';
import 'package:pos/data/datasources/local/sqlite_helper.dart';
import 'package:pos/data/datasources/smart_database_service.dart';
import 'package:pos/data/models/customer_model.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/customer_service.dart';
import 'package:pos/data/services/user_service.dart';
import 'package:pos/data/models/user_model.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/home/widgets/my_choiceChip.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/data/providers/table_provider.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final String shopName;
  final String contact;
  final String address;
  final String adminUid;
  final String phoneNo;
  final String upiId;
  final String logoUrl;
  final String? tableNumber;

  const ReceiptPreviewScreen({
    Key? key,
    required this.shopName,
    required this.contact,
    required this.address,
    required this.phoneNo,
    required this.adminUid,
    required this.upiId,
    required this.logoUrl,
    this.tableNumber,
  }) : super(key: key);

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final SmartDatabaseService _databaseService = SmartDatabaseService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  final CustomerService _customerService = CustomerService();
  final UserService _userService = UserService();
  List<CustomerModel> allCustomers = [];
  List<UserModel> allStaff = [];
  String? customerId;
  String? selectedStaffId;
  CustomerModel? selectedCustomer;

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController gstCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController discountCtrl = TextEditingController();
  final TextEditingController discountRupeeCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();
  String businessCategory = 'Food';
  String userRole = 'admin';

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
    try {
      final customers = await _customerService.getCustomers();
      setState(() {
        allCustomers = customers;
        debugPrint('Fetched ${allCustomers.length} customers from API');
      });
    } catch (e) {
      developer.log('Failed to fetch customers from API: $e', name: 'ReceiptPreview');
      // No customers — autocomplete will just be empty
    }
  }

  Future<void> fetchStaff() async {
    try {
      final staff = await _userService.getStaff(widget.adminUid);
      if (mounted) {
        setState(() {
          allStaff = staff;
        });
      }
    } catch (e) {
      developer.log('Failed to fetch staff: $e', name: 'ReceiptPreview');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchCustomers();
    fetchStaff();
    _loadBusinessCategory();
  }

  Future<void> _loadBusinessCategory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        businessCategory = prefs.getString('businessCategory') ?? 'Food';
        userRole = prefs.getString('role') ?? 'admin';
      });
    }
  }

  Future<String?> _resolveLocalCustomerId() async {
    final String name = nameCtrl.text.trim();
    final String phone = phoneCtrl.text.trim();

    if (name.isEmpty && phone.isEmpty) {
      return customerId;
    }

    if (selectedCustomer != null &&
        selectedCustomer!.name.toLowerCase() == name.toLowerCase() &&
        selectedCustomer!.phone == phone) {
      return customerId; // Existing matched customer
    }

    if (name.isNotEmpty && phone.isNotEmpty) {
      try {
        final newCustomer = await _customerService.createCustomer(
          name: name,
          phoneNumber: phone,
          address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
          gstNo: gstCtrl.text.trim().isEmpty ? null : gstCtrl.text.trim(),
        );

        if (mounted) {
          setState(() {
            selectedCustomer = newCustomer;
            customerId = newCustomer.id;
          });
        }

        fetchCustomers().catchError((_) {});
        return newCustomer.id;
      } catch (e) {
        developer.log('Failed to auto-create customer natively: $e', name: 'ReceiptPreview');
      }
    }
    return customerId;
  }

  bool _isSaving = false;
  bool _isPrinting = false;

  /// Save bill with automatic online/offline handling
  /// Online: Saves to Firebase and local SQLite
  /// Offline: Saves to local SQLite, syncs when online

  Future<void> _handleSaveWithoutPrint() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool localLoading = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12),
                MyText(text: 'Confirm Action', fontSize: 20, fontWeight: FontWeight.bold),
              ],
            ),
            content: const MyText(
              text: 'Are you sure you want to save this bill without printing?',
              fontSize: 16,
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: localLoading ? null : () => Navigator.of(dialogContext).pop(false),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                child: const MyText(text: 'Cancel', fontSize: 16),
              ),
              ElevatedButton(
                onPressed: localLoading
                    ? null
                    : () async {
                        setDialogState(() {
                          localLoading = true;
                        });
                        // Perform the save operation right here to keep loader inside button
                        final success = await _executeSaveOperation();
                        if (success) {
                          Navigator.of(dialogContext).pop(true);
                        } else {
                          setDialogState(() {
                            localLoading = false;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: appbar1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(120, 45),
                ),
                child: localLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const MyText(text: 'Yes, Save', fontSize: 16, color: Colors.white),
              ),
            ],
          );
        });
      },
    );

    if (confirmed == true && mounted) {
      // Screen is already popped by _executeSaveOperation if successful
    }
  }

  Future<bool> _executeSaveOperation() async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    // Generate sequential receipt number
    String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);

    try {
      final bool taxEnabled = printProvider.taxEnabled;
      final double cgstPercent = printProvider.cgstPercent;
      final double sgstPercent = printProvider.sgstPercent;

      final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);
      String paymentType = orderTypeProvider.paymentType.toString().split('.').last;
      String orderType = orderTypeProvider.orderType.toString().split('.').last;

      final int amount = finalTotal.round();
      final String amountInWords = numberToWords(amount);

      await DirectPrintHelper().saveBillData(
        adminUid: widget.phoneNo,
        receiptNo: generatedReceiptNo,
        items: printProvider.posts,
        subTotal: printProvider.total,
        tableNumber: widget.tableNumber,
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
        orderType: orderType,
        customerId: await _resolveLocalCustomerId() ?? "",
        employeeId: selectedStaffId,
      );

      await OfflineTTS.speak("$amountInWords rupees");

      orderTypeProvider.reset();

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Bill Saved Successfully');
        printProvider.clearCart();

        final tableProvider = Provider.of<TableProvider>(context, listen: false);
        if (tableProvider.selectedTableId != null) {
          await tableProvider.clearTable(tableProvider.selectedTableId!);
        }

        Navigator.pop(context); // Pop the screen
      }
      return true;
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to save bill: $e');
      }
      return false;
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
        final bool taxEnabled = printProvider.taxEnabled;
        final double cgstPercent = printProvider.cgstPercent;
        final double sgstPercent = printProvider.sgstPercent;

        final double cgstAmount = taxEnabled ? subtotal * (cgstPercent / 100) : 0;

        final double sgstAmount = taxEnabled ? subtotal * (sgstPercent / 100) : 0;

        final double taxTotal = cgstAmount + sgstAmount;

        final double grossTotal = subtotal + taxTotal;
        final double payable = grossTotal - discountAmount;

        final double roundOff = 0; // No rounding applied to maintain precision

        finalTotal = payable;

        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(context);
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            bottomNavigationBar: Container(
              // height: 200,
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
                  mainAxisSize: MainAxisSize.min,
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
                          const MyText(
                            text: 'TOTAL',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                          MyText(
                            text: PriceUtils.formatPrice(finalTotal),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appbar1,
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
                          imagePath: "assets/images/save.png",
                          onPressed: _handleSaveWithoutPrint,
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/save2.png",
                          isLoading: _isPrinting,
                          onPressed: () async {
                            if (_isPrinting) return;
                            final printProvider = Provider.of<PrintProvider>(context, listen: false);

                            // ✅ 1. Printer check FIRST
                            if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
                              SnackBarUtils.showWarning(context, 'Please connect a printer first');
                              return;
                            }

                            setState(() => _isPrinting = true);

                            // ✅ 2. Generate receipt number
                            final String generatedReceiptNo = await _sqliteHelper.getNextReceiptNumber(widget.phoneNo);

                            // ✅ 3. Tax parameters
                            final bool taxEnabled = printProvider.taxEnabled;
                            final double cgstPercent = printProvider.cgstPercent;
                            final double sgstPercent = printProvider.sgstPercent;

                            // ✅ 4. Order & payment type
                            final orderTypeProvider = Provider.of<OrderTypeProvider>(context, listen: false);

                            final String paymentType = orderTypeProvider.paymentType.name;
                            final String orderType = orderTypeProvider.orderType.name;
                            final int amount = finalTotal.round();
                            final String amountInWords = numberToWords(amount);

                            try {
                              // ✅ 6. Print + Save
                              await DirectPrintHelper().printReceipt(
                                adminUid: widget.phoneNo,
                                context: context,
                                printer: printProvider.selectedPrinter!,
                                paperSize: printProvider.selectedPaperSize,
                                items: cartItems,
                                subTotal: subtotal,
                                shopName: widget.shopName,
                                logoUrl: widget.logoUrl,
                                contact: widget.contact,
                                address: widget.address,
                                upiId: widget.upiId,

                                // Customer
                                customerName: nameCtrl.text,
                                customerPhone: phoneCtrl.text,
                                customerGst: gstCtrl.text,
                                customerAddress: addressCtrl.text,
                                customerNote: noteCtrl.text,

                                // Discounts
                                discountPercent: discountPercent,
                                discountAmount: discountAmount,

                                // Order info
                                paymentType: paymentType,
                                orderType: orderType,
                                tableNumber: widget.tableNumber ?? "",

                                // Tax
                                taxEnabled: taxEnabled,
                                cgstPercent: cgstPercent,
                                sgstPercent: sgstPercent,
                                receiptNo: generatedReceiptNo,
                                customerId: await _resolveLocalCustomerId() ?? "",
                                employeeId: selectedStaffId, // Passed
                                saveBill: true,
                              );

                              if (!mounted) return;

                              await OfflineTTS.speak("$amountInWords rupees");

                              printProvider.clearCart();

                              final tableProvider = Provider.of<TableProvider>(context, listen: false);
                              if (tableProvider.selectedTableId != null) {
                                await tableProvider.clearTable(tableProvider.selectedTableId!);
                              }

                              orderTypeProvider.reset();
                              Navigator.pop(context); // Close screen after success
                            } catch (e) {
                              debugPrint('Printing failed: $e');
                              if (mounted) {
                                SnackBarUtils.showError(context, 'Printing failed: $e');
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isPrinting = false);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            appBar: AppBar(
              title: const MyText(
                text: 'Save Receipt',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: white,
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
                        MyText(
                          text: 'Cart is Empty',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        // Header

                        MyText(
                          text: widget.shopName,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: appbar1,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        MyText(
                          text: widget.address,
                          fontSize: 14,
                          color: Colors.grey[700],
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        MyText(
                          text: 'Contact: ${widget.contact}',
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 10),

                        if (businessCategory == 'Food')
                          Container(
                            height: 50,
                            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                            width: double.infinity,
                            child: const OrderTypeSelector(),
                          ),
                        const SizedBox(height: 12),

                        Center(
                          child: MyText(
                            text: 'Add Customer Details',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: appbar1,
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
                          maxLength: 10,
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

                        // Staff Selection Dropdown - Enhanced Premium UI (Only for Admin)
                        if (userRole == 'admin') ...[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: appbar1.withOpacity(0.2), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: appbar1.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: DropdownButtonFormField<String>(
                                value: selectedStaffId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: appbar1),
                                dropdownColor: Colors.white,
                                elevation: 8,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Select Staff / Salesperson',
                                  labelStyle: TextStyle(color: appbar1.withOpacity(0.8), fontSize: 14),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: appbar1.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.person_pin_rounded, color: appbar1, size: 24),
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                ),
                                items: allStaff.map((staff) {
                                  return DropdownMenuItem<String>(
                                    value: staff.id,
                                    child: MyText(
                                      text: staff.name,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedStaffId = value;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              MyText(
                                text: 'Item List',
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: appbar1,
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: appbar1, borderRadius: BorderRadius.circular(12)),
                                    child: const MyText(
                                      text: "Add Item",
                                      color: Colors.white,
                                    )),
                              )
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
                                decoration:
                                    const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black38))),
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
                                            child: const Icon(
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
                            MyText(
                              text: 'Discount',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: appbar1,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: discountCtrl,
                                maxLength: 3,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.black, fontSize: 15),
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

                                  discountRupeeCtrl.text = PriceUtils.formatPrice(discountAmount).substring(1);
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  counterText: "",
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 1, horizontal: 10),
                                  suffixIcon: Container(
                                    width: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                                      color: appbar1.withOpacity(0.8),
                                    ),
                                    child: const Icon(
                                      Icons.percent,
                                      color: Colors.white,
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
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                                      color: appbar1.withOpacity(0.8),
                                    ),
                                    child: const Icon(
                                      Icons.currency_rupee,
                                      color: Colors.white,
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
                        const SizedBox(height: 16),
                        MyText(
                          text: 'Bill Summary',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: appbar1,
                        ),
                        const SizedBox(height: 8),

                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              children: [
                                _billRow('Item Total', subtotal),
                                if (discountAmount > 0)
                                  _billRow(
                                    'Discount',
                                    -discountAmount,
                                    valueColor: Colors.red,
                                  ),
                                if (taxEnabled) ...[
                                  _billRow('CGST (${PriceUtils.formatPrice(cgstPercent).substring(1)}%)', cgstAmount),
                                  _billRow('SGST (${PriceUtils.formatPrice(sgstPercent).substring(1)}%)', sgstAmount)
                                ],
                                if (roundOff != 0)
                                  _billRow(
                                    'Round Off',
                                    roundOff,
                                    valueColor: Colors.orange,
                                  ),
                                const Divider(thickness: 1.2),
                                _billRow(
                                  'TO PAY',
                                  finalTotal,
                                  isBold: true,
                                  valueColor: Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ),
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
          MyText(
            text: title,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
          MyText(
            text: PriceUtils.formatPrice(amount),
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
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
    int? maxLength,
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
                title: MyText(text: c.name),
                subtitle: MyText(text: '${c.phone} | ${c.gstNo ?? ''}'),
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
            maxLength: maxLength,
            decoration: InputDecoration(
              labelText: label,
              counterText: '',
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
    setState(() {
      selectedCustomer = customer;
      customerId = customer.id.toString();
    });
    nameCtrl.text = customer.name;
    phoneCtrl.text = customer.phone;
    gstCtrl.text = customer.gstNo ?? '';
    addressCtrl.text = customer.address ?? '';

    FocusScope.of(context).unfocus();
  }

  Widget _buildIconButton({
    required String imagePath,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: 55,
      height: 55,
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
      child: isLoading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            )
          : IconButton(
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
          MyText(
            text: text ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign ?? TextAlign.center,
            fontSize: 14.5,
            fontWeight: fontWeight ?? FontWeight.w500,
          ),
    );
  }
}
