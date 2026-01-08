import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<CustomerModel> allCustomers = [];

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController gstCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();

  final FocusNode nameFocus = FocusNode();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode gstFocus = FocusNode();

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
    final snapshot = await FirebaseFirestore.instance
        .collection('AllAdmins')
        .doc(widget.adminUid)
        .collection('customer')
        .doc(widget.adminUid)
        .collection('myCustomers')
        .get();

    setState(() {
      allCustomers = snapshot.docs.map((doc) {
        final data = doc.data();

        return CustomerModel(
          name: data['name'] ?? '',
          phone: data['phone'] ?? doc.id,
          gstNo: (data['gstNo'] == null || data['gstNo'].toString().isEmpty) ? null : data['gstNo'],
          address: data['address'],
          createdAt: (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          isUploaded: true,
        );
      }).toList();

      debugPrint('These Are All Customers: ${allCustomers.length}');
    });
  }

  @override
  void initState() {
    super.initState();
    fetchCustomers();
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
            backgroundColor: Colors.white,
            bottomNavigationBar: Container(
              height: 160,
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
                  children: [
                    // Total Section
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: appbar1.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Text(
                            '₹${subtotal.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: appbar1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildIconButton(
                          imagePath: "assets/images/kot.png",
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/kot2.png",
                          onPressed: () {},
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/save.png",
                          onPressed: () async {
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
                                saveBill: false,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);

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
                        ),
                        const SizedBox(width: 10),
                        _buildIconButton(
                          imagePath: "assets/images/save2.png",

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
                                saveBill: true,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);

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

                          // onPressed: () => widget.orderBottomSheet.call(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            appBar: AppBar(
              title: const Text(
                'Save Receipt',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          width: double.infinity,
                          child: const OrderTypeSelector(),
                        ),
                        const SizedBox(height: 12),

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
                        const SizedBox(height: 30),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                'Add Customer Details',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: appbar1),
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
                          ],
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Text(
                            'Item List',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: appbar1),
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
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black38))),
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
                                              color: Colors.grey[200],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 22,
                                              color: appbar1,
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
                          height: 20,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget customerAutoCompleteField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    TextInputType keyboardType = TextInputType.text,
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
                title: Text(c.name),
                subtitle: Text('${c.phone} | ${c.gstNo ?? ''}'),
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
            decoration: InputDecoration(
              labelText: label,
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
    nameCtrl.text = customer.name;
    phoneCtrl.text = customer.phone;
    gstCtrl.text = customer.gstNo ?? '';
    addressCtrl.text = customer.address ?? '';

    FocusScope.of(context).unfocus();
  }

  Widget _buildIconButton({
    required String imagePath,
    required VoidCallback onPressed,
  }) {
    return Container(
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
      child: IconButton(
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
          Text(
            text ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign ?? TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: fontWeight ?? FontWeight.w500),
          ),
    );
  }
}
