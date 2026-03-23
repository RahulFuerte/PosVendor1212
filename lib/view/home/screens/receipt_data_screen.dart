import 'package:flutter/material.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/view/home/navigation.dart';
import 'package:pos/view/home/screens/restaurant_screen.dart';
import 'package:pos/view/tab_screen/view-model/constants/constants.dart';
import 'package:pos/core/utils/price_utils.dart';
import 'package:provider/provider.dart';

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
  });

  @override
  State<ReceiptPreviewOnlyWidget> createState() => _ReceiptPreviewOnlyWidgetState();
}

class _ReceiptPreviewOnlyWidgetState extends State<ReceiptPreviewOnlyWidget> {
  @override
  Widget build(BuildContext context) {
    final cgstAmount = widget.taxEnabled ? widget.subTotal * (widget.cgstPercent / 100) : 0;
    final sgstAmount = widget.taxEnabled ? widget.subTotal * (widget.sgstPercent / 100) : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const MyText(
          text: "Receipt Preview",
          color: Colors.white,
        ),
        backgroundColor: appbar1,
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   backgroundColor: appbar1,
      //   foregroundColor: Colors.white,
      //   icon: const Icon(Icons.add),
      //   label: const MyText(text: "Receipt Preview"),
      //     "Add Item",
      //   ),
      //   onPressed: () async {
      //     final printProvider = Provider.of<PrintProvider>(context, listen: false);

      //     printProvider.setCart(
      //       widget.items,
      //       widget.subTotal,
      //       receiptNo: widget.receiptNo,
      //       isEdit: true,
      //     );
      //     await Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (_) => RestaurantScreen(
      //           phoneNo: widget.userPhoneNumber,
      //           isEditBill: true,
      //           receiptNo: widget.receiptNo,
      //         ),
      //       ),
      //     );

      //     // 👇 When coming back, Provider already updated
      //     setState(() {});
      //   },
      // ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// SHOP HEADER
              Center(
                child: Column(
                  children: [
                    MyText(
                      text: widget.shopName,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    const SizedBox(height: 4),
                    MyText(text: widget.address, textAlign: TextAlign.center),
                    MyText(text: "Contact: ${widget.contact}"),
                  ],
                ),
              ),

              const Divider(height: 30),

              /// BILL INFO
              _infoRow("Receipt No", widget.receiptNo),
              _infoRow("Order Type", widget.orderType),
              _infoRow("Payment", widget.paymentType),
              _infoRow(
                "Date",
                DateFormat('dd/MM/yyyy hh:mm a').format(widget.dateTime),
              ),

              const Divider(),

              /// CUSTOMER INFO
              if (widget.customerName != null && widget.customerName!.isNotEmpty) ...[
                _sectionTitle("Customer Details"),
                _infoRow("Name", widget.customerName!),
                if (widget.customerPhone != null) _infoRow("Phone", widget.customerPhone!),
                if (widget.customerGst != null && widget.customerGst!.isNotEmpty) _infoRow("GST", widget.customerGst!),
                if (widget.customerAddress != null && widget.customerAddress!.isNotEmpty)
                  _infoRow("Address", widget.customerAddress!),
                const Divider(),
              ],

              /// ITEMS
              _sectionTitle("Items"),
              _itemHeader(),
              ...widget.items.map(_itemRow),

              const Divider(height: 30),

              /// SUMMARY
              _sectionTitle("Summary"),
              _amountRow("Sub Total", widget.subTotal),
              if (widget.discountAmount > 0) _amountRow("Discount", -widget.discountAmount, color: Colors.red),
              if (widget.taxEnabled) ...[
                _amountRow("CGST (${widget.cgstPercent}%)", cgstAmount.toDouble()),
                _amountRow("SGST (${widget.sgstPercent}%)", sgstAmount.toDouble()),
              ],
              if (widget.roundOff != 0) _amountRow("Round Off", widget.roundOff),

              const Divider(thickness: 1.2),

              _amountRow(
                "TOTAL PAYABLE",
                widget.finalTotal,
                bold: true,
                color: Colors.green,
              ),

              if (widget.note != null && widget.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle("Note"),
                MyText(text: widget.note!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: MyText(
        text: title,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyText(text: label, color: Colors.black54),
          MyText(text: value, fontWeight: FontWeight.w600),
        ],
      ),
    );
  }

  Widget _itemHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      decoration: BoxDecoration(
        color: appbar1.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: MyText(text: "Item", fontWeight: FontWeight.bold)),
          const Expanded(child: MyText(text: "Qty", textAlign: TextAlign.center)),
          const Expanded(child: MyText(text: "Price", textAlign: TextAlign.center)),
          const Expanded(child: MyText(text: "Total", textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final qty = item['quantity'];
    final price = item['price'];
    final total = qty * price;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: MyText(text: item['name'])),
          Expanded(child: MyText(text: "$qty", textAlign: TextAlign.center)),
          Expanded(child: MyText(text: "${PriceUtils.formatPrice(price)}", textAlign: TextAlign.center)),
          Expanded(child: MyText(text: "${PriceUtils.formatPrice(total)}", textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _amountRow(String label, double amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MyText(
            text: label,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
          MyText(
            text: "${PriceUtils.formatPrice(amount)}",
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ],
      ),
    );
  }
}
