import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/order_type_provider.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:pos/core/widgets/skeleton.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as developer;
import 'package:pos/core/utils/snackbar_utils.dart';

class CustomerOrderSummary extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double totalAmount;
  final String adminId;
  final String? customerId;
  final String customerName;
  final String customerPhone;

  const CustomerOrderSummary({
    Key? key,
    required this.items,
    required this.totalAmount,
    required this.adminId,
    this.customerId,
    required this.customerName,
    required this.customerPhone,
  }) : super(key: key);

  @override
  State<CustomerOrderSummary> createState() => _CustomerOrderSummaryState();
}

class _CustomerOrderSummaryState extends State<CustomerOrderSummary> {
  bool _isLoading = false;
  bool _isInitialLoading = true;
  late Razorpay _razorpay;
  String _paymentMethod = 'Cash'; // Default to Cash

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _simulationLoading();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _simulationLoading() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isInitialLoading = false);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _openCheckout() {
    final amountInPaise = (widget.totalAmount * 100).toInt();
    final options = {
      'key': 'rzp_test_XXXXXXXXXXXXXXXX',
      'amount': amountInPaise,
      'name': 'Restaurant POS',
      'description': 'Secure online payment',
      'prefill': {
        'contact': widget.customerPhone,
        'name': widget.customerName,
      },
      'theme': {'color': '#FF6E33'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      developer.log('Razorpay open error: $e', name: 'CustomerOrderSummary');
      if (mounted) {
        SnackBarUtils.showError(context, 'Could not start payment: $e');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    _placeOrder(paymentId: response.paymentId, paymentMethod: 'Razorpay');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    SnackBarUtils.showError(context, 'Payment failed: ${response.message}');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    SnackBarUtils.showInfo(context, 'External wallet selected: ${response.walletName}');
  }

  Future<void> _placeOrder({String? paymentId, String paymentMethod = 'Cash'}) async {
    setState(() => _isLoading = true);

    try {
      final orderService = OrderService();

      final formattedItems = widget.items.map((item) {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        return {
          'productId': item['productId']?.toString() ?? '',
          'name': item['name']?.toString() ?? '',
          'price': price,
          'quantity': qty,
          'total': (price * qty).toDouble(),
          'variant': item['variant']?.toString() ?? '',
          'taxAmount': 0.0,
        };
      }).toList();

      final double totalAmount = formattedItems.fold(0.0, (sum, item) => sum + (item['total'] as double));
      final double finalAmount = totalAmount;

      await orderService.createGuestOrder(
        adminId: widget.adminId,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
        customerId: (widget.customerId == null || widget.customerId!.isEmpty) ? null : widget.customerId,
        items: formattedItems,
        totalAmount: totalAmount,
        finalAmount: finalAmount,
        discount: 0.0,
        tax: 0.0,
        orderType: 'PickUp',
        paymentMethod: paymentMethod,
        paymentStatus: paymentId != null ? 'Paid' : 'Pending',
        billNumber: 'G-${DateTime.now().millisecondsSinceEpoch}', // More unique bill number
        unknownCustomerId: (widget.customerId == null || widget.customerId!.isEmpty) ? null : widget.customerId,
      );

      if (mounted) {
        // Success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _OrderSuccessDialog(),
        );

        Provider.of<PrintProvider>(context, listen: false).clearCart();
      }
    } catch (e) {
      developer.log('Order sync failed: $e', name: 'CustomerOrderSummary');
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: ${e.toString().replaceAll('Exception:', '')}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = NumberFormat('#,##0.00').format(widget.totalAmount);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const MyText(text: 'Checkout', fontWeight: FontWeight.w600, fontSize: 18),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant Info Mock
                  _sectionHeader('Order From'),
                  _infoCard(Icons.restaurant_rounded, 'Authentic Kitchen', 'Your delicious meal is just a click away.'),

                  const SizedBox(height: 24),
                  _sectionHeader('Itemized Receipt'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
                    ),
                    child: _isInitialLoading
                        ? ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: 3,
                            itemBuilder: (context, index) => const _ItemSkeleton(),
                          )
                        : Column(
                            children: [
                              ...widget.items.asMap().entries.map((entry) {
                                final item = entry.value;
                                final isLast = entry.key == widget.items.length - 1;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                                color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                                            child: const Center(
                                                child: Icon(Icons.fastfood_rounded, size: 20, color: Colors.black38)),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                MyText(text: item['name'], fontWeight: FontWeight.bold, fontSize: 15),
                                                const SizedBox(height: 4),
                                                MyText(
                                                    text: '${item['quantity']} x ₹${item['price']}',
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ],
                                            ),
                                          ),
                                          MyText(
                                            text:
                                                '₹${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast) const Divider(height: 1, indent: 20, endIndent: 20),
                                  ],
                                );
                              }),
                              _summarySection(formattedAmount),
                            ],
                          ),
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader('Payment Method'),
                  Row(
                    children: [
                      Expanded(
                        child: _selectablePaymentCard(
                          icon: Icons.money_rounded,
                          title: 'Pay at Counter',
                          subtitle: 'Cash or Card',
                          method: 'Cash',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _selectablePaymentCard(
                          icon: Icons.qr_code_rounded,
                          title: 'Pay Online',
                          subtitle: 'UPI, Card, NetBanking',
                          method: 'Online',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
          _bottomAction(formattedAmount),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: MyText(
          text: text.toUpperCase(),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade400,
          letterSpacing: 1.5),
    );
  }

  Widget _infoCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(text: title, fontWeight: FontWeight.bold, fontSize: 15),
                const SizedBox(height: 2),
                MyText(text: subtitle, color: Colors.grey, fontSize: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection(String total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _priceRow('Item Total', '₹$total'),
          const SizedBox(height: 8),
          _priceRow('Taxes & Charges', '₹0.00'),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const MyText(text: 'Grand Total', fontSize: 16, fontWeight: FontWeight.w900),
              MyText(text: '₹$total', fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MyText(text: label, fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        MyText(text: value, fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
      ],
    );
  }

  Widget _bottomAction(String total) {
    bool isOnline = _paymentMethod == 'Online';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MyText(text: 'Total to Pay', color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                MyText(text: '₹$total', fontSize: 22, fontWeight: FontWeight.w600, color: primaryColor),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (isOnline ? _openCheckout : () => _placeOrder(paymentMethod: 'Cash')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          MyText(
                              text: isOnline ? 'PAY ONLINE' : 'PLACE ORDER',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 1),
                          const SizedBox(width: 8),
                          Icon(isOnline ? Icons.payment_rounded : Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectablePaymentCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String method,
  }) {
    bool isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade100,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? primaryColor : Colors.grey, size: 20),
            ),
            const SizedBox(height: 12),
            MyText(text: title, fontWeight: FontWeight.bold, fontSize: 13, maxLines: 1),
            const SizedBox(height: 2),
            MyText(text: subtitle, color: Colors.grey, fontSize: 10, maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _OrderSuccessDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.done_all_rounded, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 24),
            const MyText(text: 'Order Received!', fontSize: 22, fontWeight: FontWeight.bold),
            const SizedBox(height: 12),
            const MyText(
              text: 'Your order has been placed successfully and payment has been received.',
              color: Colors.grey,
              textAlign: TextAlign.center,
              fontSize: 14,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const MyText(text: 'AWESOME!', color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemSkeleton extends StatelessWidget {
  const _ItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Skeleton(height: 40, width: 40, borderRadius: 12),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 18, width: 120),
                SizedBox(height: 6),
                Skeleton(height: 12, width: 60),
              ],
            ),
          ),
          const Skeleton(height: 18, width: 60),
        ],
      ),
    );
  }
}
