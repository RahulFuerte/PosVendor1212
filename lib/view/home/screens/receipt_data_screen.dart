import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/data/models/kot_model.dart';
import 'package:pos/core/utils/snackbar_utils.dart';

class ReceiptPreviewOnlyWidget extends StatefulWidget {
  final String shopName;
  final String address;
  final String contact;
  final String userPhoneNumber;

  final String? customerName;
  final String? customerPhone;
  final String? customerGst;
  final String? customerAddress;
  final String? note;

  final List<Map<String, dynamic>> items;

  final double subTotal;
  final bool taxEnabled;
  final double cgstPercent;
  final double sgstPercent;

  final double discountAmount;
  final double roundOff;
  final double finalTotal;

  final String paymentType;
  final String orderType;
  final String receiptNo;
  final DateTime dateTime;

  final String? orderId;
  final String? initialPaymentStatus;
  final bool? isUnknownCustomer;

  const ReceiptPreviewOnlyWidget({
    super.key,
    required this.shopName,
    required this.address,
    required this.contact,
    required this.items,
    required this.subTotal,
    required this.finalTotal,
    required this.paymentType,
    required this.orderType,
    required this.receiptNo,
    required this.dateTime,
    this.taxEnabled = false,
    this.cgstPercent = 0,
    this.sgstPercent = 0,
    this.discountAmount = 0,
    this.roundOff = 0,
    this.customerName,
    this.customerPhone,
    this.customerGst,
    this.customerAddress,
    this.note,
    required this.userPhoneNumber,
    this.orderId,
    this.initialPaymentStatus,
    this.isUnknownCustomer,
  });

  @override
  State<ReceiptPreviewOnlyWidget> createState() => _ReceiptPreviewOnlyWidgetState();
}

class _ReceiptPreviewOnlyWidgetState extends State<ReceiptPreviewOnlyWidget> {
  late String _currentPaymentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPaymentStatus = widget.initialPaymentStatus ?? 'Due';
  }

  Future<void> _updatePaymentStatus(String method) async {
    if (widget.orderId == null) return;

    setState(() => _isLoading = true);
    try {
      await OrderService().updateOrderStatus(
        widget.orderId!,
        paymentStatus: 'Paid',
        paymentMethod: method,
      );
      setState(() {
        _currentPaymentStatus = 'Paid';
        _isLoading = false;
      });
      if (mounted) SnackBarUtils.showSuccess(context, 'Payment Received Successfully!');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackBarUtils.showError(context, 'Failed to update payment: $e');
    }
  }

  Future<void> _cancelOrder(String reason) async {
    if (widget.orderId == null) return;

    setState(() => _isLoading = true);
    try {
      await OrderService().cancelOrder(widget.orderId!, reason);
      setState(() {
        _currentPaymentStatus = 'Cancelled';
        _isLoading = false;
      });
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Order Cancelled Successfully!');
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) SnackBarUtils.showError(context, 'Failed to cancel order: $e');
    }
  }

  void _showCancelDialog() {
    final TextEditingController reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const MyText(text: "Cancel Bill", fontWeight: FontWeight.bold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MyText(text: "Are you sure you want to cancel this bill? This will restore the stock."),
            const SizedBox(height: 15),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: "Reason for cancellation",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const MyText(text: "No"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(reasonCtrl.text.isEmpty ? "Mistake in bill" : reasonCtrl.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const MyText(text: "Yes, Cancel", color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showPaymentSelection() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: "Select Payment Method",
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 15),
            _paymentOptionTile(Icons.money, "Cash", "Cash"),
            _paymentOptionTile(Icons.qr_code, "UPI", "UPI"),
            _paymentOptionTile(Icons.credit_card, "Card", "Card"),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: appbar1),
      title: MyText(text: title, fontWeight: FontWeight.w500),
      onTap: () {
        Navigator.pop(context);
        _updatePaymentStatus(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cgstAmount = widget.taxEnabled ? widget.subTotal * (widget.cgstPercent / 100) : 0;
    final sgstAmount = widget.taxEnabled ? widget.subTotal * (widget.sgstPercent / 100) : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const MyText(
          text: "Order Details",
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.white,
      ),
      bottomNavigationBar: _currentPaymentStatus == 'Cancelled'
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentPaymentStatus != 'Paid') ...[
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _showPaymentSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appbar1,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const MyText(
                                text: "CONFIRM PAYMENT",
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _showCancelDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const MyText(
                        text: "CANCEL",
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          children: [
            /// PREMIUM RECEIPT CARD
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (_currentPaymentStatus == 'Cancelled')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: const Center(
                        child: MyText(
                          text: "CANCELLED BILL",
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),

                  /// SHOP INFO
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: appbar1.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.restaurant, color: appbar1, size: 30),
                        ),
                        const SizedBox(height: 15),
                        MyText(
                          text: widget.shopName.toUpperCase(),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        const SizedBox(height: 5),
                        MyText(
                          text: widget.address,
                          textAlign: TextAlign.center,
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        MyText(
                          text: "Tel: ${widget.contact}",
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  _dashedDivider(),
                  const SizedBox(height: 20),

                  /// ORDER STATUS & BADGES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text: "# ${widget.receiptNo}",
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            MyText(
                              text: DateFormat('MMM dd, yyyy • hh:mm a').format(widget.dateTime),
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _currentPaymentStatus == 'Paid'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: MyText(
                            text: _currentPaymentStatus.toUpperCase(),
                            color: _currentPaymentStatus == 'Paid' ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// QUICK INFO BARS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _tag(Icons.layers_outlined, widget.orderType),
                        const SizedBox(width: 10),
                        _tag(Icons.payment_outlined, widget.paymentType),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  /// CUSTOMER SECTION
                  if (widget.customerName != null && widget.customerName!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.person_outline, size: 16, color: appbar1),
                                SizedBox(width: 8),
                                MyText(text: "Customer Details", fontWeight: FontWeight.bold, fontSize: 13),
                              ],
                            ),
                            const Divider(height: 20, thickness: 0.5),
                            _infoRow("Name", widget.customerName!),
                            if (widget.customerPhone != null) _infoRow("Phone", widget.customerPhone!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  /// ITEMS TABLE
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MyText(text: "Orders Items", fontWeight: FontWeight.bold, fontSize: 15),
                        const SizedBox(height: 12),
                        ...widget.items.map(_itemRow),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  _dashedDivider(),
                  const SizedBox(height: 20),

                  /// TOTALS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _amountRow("Subtotal", widget.subTotal),
                        if (widget.discountAmount > 0) _amountRow("Discount", -widget.discountAmount, isNegative: true),
                        if (widget.taxEnabled) ...[
                          _amountRow("CGST (${widget.cgstPercent}%)", cgstAmount.toDouble()),
                          _amountRow("SGST (${widget.sgstPercent}%)", sgstAmount.toDouble()),
                        ],
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: appbar1.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const MyText(text: "GRAND TOTAL", fontWeight: FontWeight.bold, fontSize: 16),
                              MyText(
                                text: PriceUtils.formatPrice(widget.finalTotal),
                                fontWeight: FontWeight.w600,
                                fontSize: 20,
                                color: appbar1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  MyText(
                    text: "Thank you for visiting!",
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================

  Widget _tag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          MyText(text: label, fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(decoration: BoxDecoration(color: Colors.grey.shade300)));
          }),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyText(text: label, color: Colors.grey.shade500, fontSize: 13),
          MyText(text: value, fontWeight: FontWeight.w600, fontSize: 13),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final qty = item['quantity'];
    final price = item['price'];
    final total = qty * price;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(text: item['name'], fontWeight: FontWeight.w600),
                MyText(
                  text: "${qty}x ${PriceUtils.formatPrice(price)}",
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
          ),
          MyText(
            text: PriceUtils.formatPrice(total),
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _kotSection(KotModel kot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appbar1.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appbar1.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              MyText(
                text: "KOT # ${kot.kotNumber}",
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: appbar1,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MyText(
                  text: kot.status.toUpperCase(),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: kot.status == 'Served' ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...kot.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    MyText(text: "${item.quantity}x ", fontWeight: FontWeight.bold, fontSize: 13),
                    MyText(text: item.name, fontSize: 13),
                    if (item.variant != null && item.variant!.isNotEmpty)
                      MyText(text: " (${item.variant})", fontSize: 11, color: Colors.grey),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyText(text: label, color: Colors.grey.shade600),
          MyText(
            text: PriceUtils.formatPrice(amount),
            fontWeight: FontWeight.w600,
            color: isNegative ? Colors.red : Colors.black,
          ),
        ],
      ),
    );
  }
}
