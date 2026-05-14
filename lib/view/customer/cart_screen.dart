import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:pos/view/customer/customer_order_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartScreen extends StatefulWidget {
  final String adminId;
  const CartScreen({required this.adminId, super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _customerName = '';
  String _customerPhone = '';
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _loadCustomerInfo();
  }

  Future<void> _loadCustomerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customerName = prefs.getString('name') ?? '';
      _customerPhone = prefs.getString('phoneNumber') ?? '';
      _customerId = prefs.getString('_id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<PrintProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const MyText(text: 'My Cart', fontSize: 18, fontWeight: FontWeight.bold),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (cart.posts.isNotEmpty)
            TextButton(
              onPressed: () => _showClearConfirmation(context, cart),
              child: const MyText(
                text: 'Clear',
                color: Colors.red,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (cart.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const MyText(text: 'Your cart is empty', color: Colors.grey, fontSize: 16),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const MyText(text: 'Browse Menu', color: Colors.white),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.posts.length,
                  separatorBuilder: (context, index) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final item = cart.posts[index];
                    return _CartItemRow(item: item);
                  },
                ),
              ),
              _buildBottomSummary(cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomSummary(PrintProvider cart) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const MyText(text: 'Grand Total', fontSize: 18, fontWeight: FontWeight.bold),
                MyText(
                  text: '₹${cart.total.toStringAsFixed(2)}',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerOrderSummary(
                        items: List.from(cart.posts),
                        totalAmount: cart.total,
                        adminId: widget.adminId,
                        customerName: _customerName,
                        customerPhone: _customerPhone,
                        customerId: _customerId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const MyText(
                  text: 'Proceed to Checkout',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation(BuildContext context, PrintProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const MyText(text: 'Clear Cart?', fontWeight: FontWeight.bold, fontSize: 18),
        content: const MyText(
          text: 'Are you sure you want to remove all items from your cart?',
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const MyText(text: 'Cancel', color: Colors.grey),
          ),
          TextButton(
            onPressed: () {
              cart.clearCart();
              Navigator.pop(context);
            },
            child: const MyText(text: 'Clear All', color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<PrintProvider>(context, listen: false);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(text: item['name'], fontWeight: FontWeight.bold, fontSize: 16),
              const SizedBox(height: 4),
              MyText(text: '₹${item['price']}', color: Colors.grey.shade600),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove, size: 18, color: primaryColor),
                onPressed: () {
                  final items = List<Map<String, dynamic>>.from(cart.posts);
                  final index = items.indexWhere((i) => i['name'] == item['name']);
                  if (index != -1) {
                    if (items[index]['quantity'] > 1) {
                      items[index]['quantity']--;
                    } else {
                      items.removeAt(index);
                    }
                    final total = items.fold<double>(0, (sum, i) => sum + (i['price'] * i['quantity']));
                    cart.additem(items, total);
                  }
                },
              ),
              MyText(
                text: '${item['quantity']}',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add, size: 18, color: primaryColor),
                onPressed: () {
                  final items = List<Map<String, dynamic>>.from(cart.posts);
                  final index = items.indexWhere((i) => i['name'] == item['name']);
                  if (index != -1) {
                    items[index]['quantity']++;
                    final total = items.fold<double>(0, (sum, i) => sum + (i['price'] * i['quantity']));
                    cart.additem(items, total);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
