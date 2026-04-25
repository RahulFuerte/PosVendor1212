import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/order_model.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/core/widgets/skeleton.dart';

class CustomerOrdersScreen extends StatefulWidget {
  final String customerId;
  const CustomerOrdersScreen({required this.customerId, super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final OrderService _orderService = OrderService();
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _orderService.getGuestHistory(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const MyText(text: 'My Order History', fontWeight: FontWeight.bold, fontSize: 18),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => setState(() {
              _ordersFuture = _orderService.getGuestHistory(widget.customerId);
            }),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 5,
              itemBuilder: (context, index) => const _OrderCardSkeleton(),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                    ),
                    const SizedBox(height: 24),
                    const MyText(text: 'Oops! Something went wrong', fontWeight: FontWeight.bold, fontSize: 18),
                    const SizedBox(height: 8),
                    MyText(
                      text: snapshot.error.toString(),
                      color: Colors.grey,
                      textAlign: TextAlign.center,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {
                        _ordersFuture = _orderService.getGuestHistory(widget.customerId);
                      }),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                  ),
                  const SizedBox(height: 24),
                  const MyText(text: 'No orders yet', fontWeight: FontWeight.bold, fontSize: 20),
                  const SizedBox(height: 8),
                  const MyText(text: 'Your tasty treats will appear here!', color: Colors.grey),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const MyText(text: 'Browse Restaurants', color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            physics: const BouncingScrollPhysics(),
            itemCount: orders.length,
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        order.orderDate != null ? DateFormat('dd MMM yyyy • hh:mm a').format(order.orderDate!.toLocal()) : 'N/A';
    final statusColor = _getStatusColor(order.status ?? 'Pending');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(20),
          collapsedBackgroundColor: Colors.white,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(side: BorderSide.none),
          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: MyText(
                        text: '#${order.billNumber}', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
                  ),
                  _statusChip(order.status ?? 'Pending', statusColor),
                ],
              ),
              const SizedBox(height: 12),
              MyText(
                text: order.shopName ?? 'Restaurant Order',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  MyText(text: dateStr, fontSize: 13, color: Colors.grey.shade500),
                ],
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                const MyText(text: 'Amount: ', fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                MyText(
                  text: '₹${order.finalAmount.toStringAsFixed(2)}',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: MyText(
                    text: '${order.items.length} ${order.items.length == 1 ? 'Item' : 'Items'}',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(height: 1),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MyText(
                      text: 'ORDER DETAILS',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1.2),
                  const SizedBox(height: 16),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Center(
                                  child: MyText(
                                      text: '${item.quantity}',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: MyText(text: item.name, fontSize: 14, fontWeight: FontWeight.bold)),
                            MyText(
                                text: '₹${item.total.toStringAsFixed(2)}',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Payment', order.paymentMethod ?? 'Cash'),
                        const SizedBox(height: 8),
                        _detailRow('Order Type', order.orderType ?? 'PickUp'),
                        const SizedBox(height: 8),
                        _detailRow(
                          'Payment Status',
                          order.paymentStatus ?? 'Paid',
                          valueColor: order.paymentStatus?.toLowerCase() == 'due' ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          MyText(
            text: status.toUpperCase(),
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MyText(text: label, fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        MyText(text: value, fontSize: 13, fontWeight: FontWeight.bold, color: valueColor ?? Colors.black87),
      ],
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 18, width: 80, borderRadius: 8),
              Skeleton(height: 20, width: 70, borderRadius: 10),
            ],
          ),
          SizedBox(height: 12),
          Skeleton(height: 22, width: 180),
          SizedBox(height: 8),
          Skeleton(height: 16, width: 130),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 20, width: 100),
              Skeleton(height: 20, width: 60),
            ],
          ),
        ],
      ),
    );
  }
}
