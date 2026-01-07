import 'package:flutter/material.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/print_provider.dart';
import 'package:pos/view/home/screens/customer_list_screen.dart';
import 'package:pos/view/home/screens/order_type_selector.dart';
import 'package:pos/view/local_DB/customerDB_helper.dart';
import 'package:pos/view/local_DB/customer_model.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:provider/provider.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final String shopName;
  final String contact;
  final String address;
  final String adminUid;
  final String phoneNo;

  const ReceiptPreviewScreen({
    Key? key,
    required this.shopName,
    required this.contact,
    required this.address,
    required this.phoneNo,
    required this.adminUid,
  }) : super(key: key);

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
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

  void _showCustomerBottomSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final gstController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: appbar1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Customer Name
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Customer Name *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (value.length != 10) {
                      return 'Phone number must be 10 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // GST Number (Optional)
                TextFormField(
                  controller: gstController,
                  decoration: InputDecoration(
                    labelText: 'GST Number (Optional)',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          final customer = CustomerModel(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            gstNo: gstController.text.trim().isEmpty ? null : gstController.text.trim(),
                            createdAt: DateTime.now(),
                          );

                          await CustomerDatabase.instance.insertCustomer(customer);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Customer saved successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Navigate to customers list
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CustomersListScreen(
                                  phoneNo: widget.phoneNo,
                                  adminUid: widget.adminUid,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appbar1,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Customer',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrintProvider>(
      builder: (context, printProvider, child) {
        final cartItems = printProvider.posts;
        final subtotal = printProvider.total;

        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(context);
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: const Text(
                'Receipt Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: white),
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
            body: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: cartItems.isEmpty
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
                              Text(
                                'Cart is Empty',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            margin: const EdgeInsets.all(12),
                            padding: EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Header

                                Text(
                                  widget.shopName,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: appbar1,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Contact: ${widget.contact}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Divider(color: Colors.grey[400]),

                                Container(
                                  height: 50,
                                  margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                  width: double.infinity,
                                  child: const OrderTypeSelector(),
                                ),
                                // Items List
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                                  child: Column(
                                    children: [
                                      // Table Header
                                      const Row(
                                        children: [
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              'Item',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              'Price',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              'Qty',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(
                                            width: 55,
                                            child: Text(
                                              'Total',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          SizedBox(width: 30),
                                        ],
                                      ),
                                      Divider(
                                        color: Colors.grey[300],
                                        thickness: 1,
                                      ),
                                      const SizedBox(height: 8),

                                      // Items
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: cartItems.length,
                                        itemBuilder: (context, index) {
                                          final item = cartItems[index];
                                          final itemTotal = item['price'] * item['quantity'];

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey[200]!,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                // Item name
                                                Expanded(
                                                  flex: 4,
                                                  child: Text(
                                                    item['name'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),

                                                // Price
                                                SizedBox(
                                                  width: 50,
                                                  child: Text(
                                                    '₹${item['price']}',
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Quantity controls
                                                SizedBox(
                                                  width: 90,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      InkWell(
                                                        onTap: () => _updateQuantity(index, false, printProvider),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(3),
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey[200],
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Icon(
                                                            Icons.remove,
                                                            size: 25,
                                                            color: appbar1,
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                                        child: Text(
                                                          '${item['quantity']}',
                                                          style: const TextStyle(
                                                            fontSize: 18,
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
                                                            size: 25,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Item total
                                                SizedBox(
                                                  width: 55,
                                                  child: Text(
                                                    '₹$itemTotal',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Delete button
                                                InkWell(
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
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(height: 16),
                                      Divider(
                                        color: Colors.grey[400],
                                        thickness: 1.5,
                                      ),

                                      // Total Section
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Total Amount:',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '₹${subtotal.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: appbar1,
                                              ),
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
                        ),
                ),

                // Bottom Action Buttons (Sticky)
                Container(
                  padding: const EdgeInsets.all(12),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please connect a printer first'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                await DirectPrintHelper.printReceipt(
                                  adminUid: widget.phoneNo,
                                  context: context,
                                  printer: printProvider.selectedPrinter!,
                                  paperSize: printProvider.selectedPaperSize,
                                  items: cartItems,
                                  total: subtotal,
                                  shopName: widget.shopName,
                                  contact: widget.contact,
                                  address: widget.address,
                                  saveBill: true, // Save bill since it's not saved elsewhere
                                );

                                if (context.mounted) {
                                  Navigator.pop(context); // Close loading
                                  Navigator.pop(context); // Go back
                                  printProvider.clearCart();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Printing failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              Icons.print,
                              size: 20,
                              color: printProvider.isConnected ? Colors.green : Colors.white,
                            ),
                            label: const Text(
                              'Print Receipt',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appbar1,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
