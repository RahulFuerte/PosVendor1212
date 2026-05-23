import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:intl/intl.dart';
import 'package:pos/l10n/app_locale.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/models/order_model.dart';
import 'package:pos/data/services/order_service.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/printer_connectionDialog.dart';
import 'package:pos/view/home/screens/receipt_data_screen.dart';
import 'package:pos/view/home/widgets/order_kot_widgets.dart';
import 'package:pos/view/home/reports/widgets/report_skeleton.dart';
import 'package:pos/view/tab_screen/view-model/widgets/printers/printer.dart';
import 'package:pos/view/home/widgets/mydrawer.dart';
import 'package:pos/core/utils/pdf_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String phoneNo = '';
  String adminUid = '';

  List<OrderModel> orders = [];
  bool isLoading = false;
  DateTime selectedDate = DateTime.now();
  String selectedOrderType = 'all';
  String selectedPaymentMethod = 'all';
  String businessCategory = 'Food';

  final OrderService _orderService = OrderService();

  @override
  void initState() {
    super.initState();
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      phoneNo = prefs.getString('phoneNumber') ?? prefs.getString('phoneNo') ?? '';
      adminUid = prefs.getString('adminUid') ?? '';
      businessCategory = prefs.getString('businessCategory') ?? 'Food';
    });
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
      // Order Fetch Error
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

  String _orderTypeText(String? type) {
    if (type == null) return '';
    String t = type.toLowerCase();
    if (t == 'dinein') return businessCategory == 'Food' ? 'DineIn' : '';
    if (t == 'pickup') return businessCategory == 'Food' ? 'PickUp' : '';
    if (t == 'delivery') return 'Delivery';
    return type;
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
        adminUid: phoneNo,
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
      // Error printing
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
      final String cleanPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final prefs = await SharedPreferences.getInstance();
      final String shopName = prefs.getString('shopName') ?? 'Our Shop';

      // Construct a professional message
      String message = "🏪 *${shopName.toUpperCase()}* 🏪\n"
          "✨ *Bill Summary: #$receiptNo* ✨\n\n"
          "👤 *Customer:* ${customerName.isEmpty ? 'Guest' : customerName}\n"
          "📅 *Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(dateTime)}\n"
          "🍴 *Order Type:* $orderType\n"
          "💳 *Payment:* $paymentType\n\n"
          "*Items:*\n";

      for (var item in items) {
        message += "• ${item['name']} x ${item['quantity']} = ₹${item['price'] * item['quantity']}\n";
      }

      message += "\n💰 *Total Amount: ₹$finalAmount*\n\n"
          "Thank you for visiting *$shopName*! 🙏";

      if (cleanPhone.isNotEmpty) {
        String formattedPhone = cleanPhone;
        if (formattedPhone.length == 10) formattedPhone = "91$formattedPhone";

        final Uri whatsappUri = Uri.parse(
          "https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}",
        );

        if (await canLaunchUrl(whatsappUri)) {
          await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) SnackBarUtils.showError(context, "Could not launch WhatsApp");
        }
      } else {
        final Uri generalWhatsappUri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(generalWhatsappUri)) {
          await launchUrl(generalWhatsappUri, mode: LaunchMode.externalApplication);
        } else {
          final printProvider = Provider.of<PrintProvider>(context, listen: false);
          await PdfHelper.generateAndShareBillPdf(
            shopName: shopName,
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
            discountAmount: subTotal - finalAmount,
          );
        }
      }
    } catch (e) {
      if (mounted) SnackBarUtils.showError(context, "Error opening WhatsApp: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: MyText(text: AppLocale.orderManagement.getString(context), fontSize: 17, color: Colors.black, fontWeight: FontWeight.w600),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      drawer: MyDrawer(
        phoneNo: phoneNo,
        adminPhoneNo: adminUid,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: isLoading
                ? const ReportSkeleton(height: 120, itemCount: 6, padding: EdgeInsets.all(12))
                : RefreshIndicator(
                    onRefresh: () async {
                      await fetchOrders();
                    },
                    child: orders.isEmpty
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
                                typeText: _orderTypeText(order.orderType),
                                typeColor: _orderTypeColor(order.orderType),
                                onTap: () async {
                                  final prefs = await SharedPreferences.getInstance();

                                  if (!mounted) return;
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReceiptPreviewOnlyWidget(
                                        orderId: order.id ?? '',
                                        initialPaymentStatus: order.paymentStatus ?? 'Due',
                                        isUnknownCustomer: order.unknownCustomerId != null,
                                        userPhoneNumber: phoneNo,
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
                  items: [
                    const DropdownMenuItem(value: 'all', child: MyText(text: 'All Orders')),
                    if (businessCategory == 'Food') ...[
                      const DropdownMenuItem(value: 'DineIn', child: MyText(text: '🍽 Dine In')),
                      const DropdownMenuItem(value: 'PickUp', child: MyText(text: '🛍 Pick Up')),
                    ],
                    const DropdownMenuItem(value: 'Delivery', child: MyText(text: '🚚 Delivery')),
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
