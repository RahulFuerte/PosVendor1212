import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:hive/hive.dart';
import 'package:pos/data/models/order_model.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:provider/provider.dart';
import 'package:pos/data/providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _phoneNo = '';
  String _adminId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNo = prefs.getString('phoneNumber') ?? '';
      _adminId = prefs.getString('adminUid') ?? '';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sub = context.watch<SubscriptionProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const MyText(text: 'Saved Orders'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      drawer: MyDrawer(phoneNo: _phoneNo, adminPhoneNo: _adminId),
      body: FutureBuilder<Box<OrderModel>>(
        future: Hive.openBox<OrderModel>('saved_orders'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: MyText(text: 'Error: ${snapshot.error}'));
          }

          final box = snapshot.data!;
          // Filter orders for this merchant
          final orders = box.values.where((order) => order.adminId == _adminId).toList();

          if (orders.isEmpty) {
            return const Center(child: MyText(text: 'No saved orders found'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: MyText(text: 'Order #${order.billNumber}'),
                subtitle: MyText(text: 'Total: ₹${order.totalAmount}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print, color: primaryColor),
                      onPressed: () {
                        context.read<PrintProvider>().printOrder(context, order);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final key = box.keys.elementAt(box.values.toList().indexOf(order));
                        await box.delete(key);
                        setState(() {});
                        if (mounted) {
                          SnackBarUtils.showSuccess(context, 'Order deleted');
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
