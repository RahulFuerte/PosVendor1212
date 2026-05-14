import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/models/order_model.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/screens/receipt_data_screen.dart';
import 'package:pos/view/home/widgets/order_kot_widgets.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/core/utils/pdf_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderManagementScreen extends StatefulWidget {
  final String phoneNo;
  final String adminUid;
  final String? role;
  const OrderManagementScreen({super.key, required this.phoneNo, required this.adminUid, this.role});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  List<OrderModel> orders = [];
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  String selectedOrderType = 'all';
  String selectedPaymentMethod = 'all';

  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      setState(() => isLoading = true);

      // Calculate start and end of the selected day
      DateTime startDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      DateTime endDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);

      final fetchedOrders = await _orderService.getOrders(
        startDate: startDate,
        endDate: endDate,
        orderType: selectedOrderType == 'all' ? null : selectedOrderType,
        paymentMethod: selectedPaymentMethod == 'all' ? null : selectedPaymentMethod,
      );

      setState(() {
        orders = fetchedOrders;
      });
    } catch (e) {
      debugPrint('Order Fetch Error: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Color _orderTypeColor(String? type) {
    if (type == null) return Colors.grey;
    String t = type.toLowerCase();
    if (t == 'dinein') return Colors.teal;
    if (t == 'pickup') return Colors.orange;
    if (t == 'delivery') return Colors.red;
    return Colors.grey;
  }

  Future<void> _handlePrint({
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required String customerName,
    required String customerPhone,
    required String customerGst,
    required String customerNote,
    required String customerAddress,
    required double discountAmount,
    required double discountPercent,
    required String receiptNo,
    required String orderType,
    required String? paymentType,
  }) async {
    final printProvider = Provider.of<PrintProvider>(context, listen: false);

    if (!printProvider.isConnected || printProvider.selectedPrinter == null) {
      showDialog(
        context: context,
        builder: (context) => const PrinterConnectionDialog(),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // ignore: use_build_context_synchronously
      await DirectPrintHelper().printReceipt(
        adminUid: widget.phoneNo,
        context: context,
        printer: printProvider.selectedPrinter!,
        paperSize: printProvider.selectedPaperSize,
        items: items,
        subTotal: subTotal,
        shopName: prefs.getString('shopName') ?? 'Shop Name',
        contact: prefs.getString('contact') ?? 'Contact',
        address: prefs.getString('address') ?? 'Address',
        logoUrl: prefs.getString('logoUrl') ?? '',
        upiId: prefs.getString('upiId') ?? "",
        customerName: customerName,
        customerPhone: customerPhone,
        customerGst: customerGst,
        customerNote: customerNote,
        customerAddress: customerAddress,
        orderType: orderType,
        paymentType: paymentType,
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        receiptNo: receiptNo,
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        saveBill: false,
      );
    } catch (e) {
      debugPrint('Error printing: $e');
    }
  }

  Future<void> _handleWhatsapp({
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required double finalAmount,
    required String customerName,
    required String customerPhone,
    required String receiptNo,
    required String orderType,
    required String paymentType,
    required DateTime dateTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printProvider = Provider.of<PrintProvider>(context, listen: false);

      await PdfHelper.generateAndShareBillPdf(
        shopName: prefs.getString('shopName') ?? 'Shop Name',
        address: prefs.getString('address') ?? 'Address',
        contact: prefs.getString('contact') ?? 'Contact',
        receiptNo: receiptNo,
        dateTime: dateTime,
        items: items,
        subTotal: subTotal,
        finalTotal: finalAmount,
        paymentType: paymentType,
        orderType: orderType,
        customerName: customerName,
        customerPhone: customerPhone,
        taxEnabled: printProvider.taxEnabled,
        cgstPercent: printProvider.cgstPercent,
        sgstPercent: printProvider.sgstPercent,
        discountAmount: subTotal - finalAmount, // Simplistic discount calc
      );
    } catch (e) {
      debugPrint('Error sharing via WhatsApp: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const MyText(text: 'Order Management', fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      drawer: MyDrawer(
        phoneNo: widget.phoneNo,
        adminPhoneNo: widget.adminUid,
        role: widget.role,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: appbar1))
                : orders.isEmpty
                    ? const Center(child: MyText(text: 'No Orders Found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          String timeStr = order.orderDate != null
                              ? DateFormat('dd/MM/yy hh:mm a').format(order.orderDate!.toLocal())
                              : '---';

                          String customerName = order.customerName ?? "";
                          if (customerName.isEmpty && order.unknownCustomerId != null) {
                            customerName =
                                "Guest User"; // The model doesn't have the full object here based on OrderModel.fromJson
                          }
                          if (customerName.isEmpty) customerName = "Walk In";

                          return OrderTile(
                            bill: order.billNumber,
                            amount: order.finalAmount.toInt(),
                            time: timeStr,
                            customerName: customerName,
                            paymentStatus: order.paymentStatus ?? "Due",
                            status: order.status ?? "Pending",
                            typeText: order.orderType ?? 'all',
                            typeColor: _orderTypeColor(order.orderType),
                            onTap: () async {
                              final prefs = await SharedPreferences.getInstance();

                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReceiptPreviewOnlyWidget(
                                    orderId: order.id ?? '',
                                    initialPaymentStatus: order.paymentStatus ?? 'Due',
                                    isUnknownCustomer: order.unknownCustomerId != null,
                                    userPhoneNumber: widget.phoneNo,
                                    shopName: prefs.getString('shopName') ?? 'Shop Name',
                                    address: prefs.getString('address') ?? 'Address',
                                    contact: prefs.getString('contact') ?? 'Contact',
                                    receiptNo: order.billNumber,
                                    dateTime: order.orderDate ?? DateTime.now(),
                                    items: order.items.map((e) => e.toJson()).toList(),
                                    subTotal: order.totalAmount,
                                    finalTotal: order.finalAmount,
                                    discountAmount: order.discount ?? 0,
                                    roundOff: order.roundOff ?? 0,
                                    taxEnabled: (order.tax ?? 0) > 0,
                                    cgstPercent: 0, // Need to check if available in model
                                    sgstPercent: 0,
                                    paymentType: order.paymentMethod ?? 'cash',
                                    orderType: order.orderType ?? '',
                                    customerName: order.customerName,
                                    customerPhone: order.customerPhone,
                                    customerGst:
                                        null, // Model doesn't seem to have guest GST specifically in OrderModel directly
                                    customerAddress: null,
                                    note: order.notes,
                                  ),
                                ),
                              );
                            },
                            onPrint: () {
                              _handlePrint(
                                items: order.items.map((e) => e.toJson()).toList(),
                                subTotal: order.totalAmount,
                                customerName: order.customerName ?? '',
                                customerPhone: order.customerPhone ?? '',
                                customerGst: '',
                                customerNote: order.notes ?? '',
                                customerAddress: '',
                                discountAmount: order.discount ?? 0,
                                discountPercent: 0,
                                receiptNo: order.billNumber,
                                orderType: order.orderType ?? '',
                                paymentType: order.paymentMethod,
                              );
                            },
                            onWhatsapp: () {
                              _handleWhatsapp(
                                items: order.items.map((e) => e.toJson()).toList(),
                                subTotal: order.totalAmount,
                                finalAmount: order.finalAmount,
                                customerName: order.customerName ?? '',
                                customerPhone: order.customerPhone ?? '',
                                receiptNo: order.billNumber,
                                orderType: order.orderType ?? '',
                                paymentType: order.paymentMethod ?? 'Cash',
                                dateTime: order.orderDate ?? DateTime.now(),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(text: 'Filter Orders', fontSize: 16, fontWeight: FontWeight.w600),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                      fetchOrders();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: appbar1.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: appbar1.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: appbar1, size: 20),
                        const SizedBox(width: 8),
                        MyText(
                          text: DateFormat('dd MMM yyyy').format(selectedDate),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedOrderType,
                  isDense: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: appbar1.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: MyText(text: 'All Orders')),
                    DropdownMenuItem(value: 'DineIn', child: MyText(text: '🍽 Dine In')),
                    DropdownMenuItem(value: 'PickUp', child: MyText(text: '🛍 Pick Up')),
                    DropdownMenuItem(value: 'Delivery', child: MyText(text: '🚚 Delivery')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedOrderType = value!);
                    fetchOrders();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedPaymentMethod,
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: appbar1.withOpacity(0.08),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: appbar1.withOpacity(0.25)),
              ),
              prefixIcon: Icon(Icons.payment, color: appbar1, size: 20),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: MyText(text: 'All Payment Methods')),
              DropdownMenuItem(value: 'Cash', child: MyText(text: '💵 Cash')),
              DropdownMenuItem(value: 'Card', child: MyText(text: '💳 Card')),
              DropdownMenuItem(value: 'UPI', child: MyText(text: '📱 UPI')),
              DropdownMenuItem(value: 'Complementory', child: MyText(text: '🎁 Complementory')),
            ],
            onChanged: (value) {
              setState(() => selectedPaymentMethod = value!);
              fetchOrders();
            },
          ),
        ],
      ),
    );
  }
}
