import 'package:community_material_icon/community_material_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos/core/utils/pdf_helper.dart';
import 'package:pos/core/utils/snackbar_utils.dart';
import 'package:pos/core/widgets/text.dart';
import 'package:pos/data/models/whatsapp_template_model.dart';
import 'package:pos/data/providers/print_provider.dart';
import 'package:pos/data/services/whatsapp_template_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsappHelper {
  static String fillTemplate(
    String template, {
    required String shopName,
    required String customerName,
    required String billNumber,
    required double amount,
    required DateTime dateTime,
    required String orderType,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) {
    final itemLines = items.map((e) {
      final qty = e['quantity'] ?? 1;
      final price = (e['price'] as num?) ?? 0;
      return "• ${e['name']} x $qty = ₹${(price * qty).toStringAsFixed(0)}";
    }).join('\n');

    return template
        .replaceAll('{shopName}', shopName.isEmpty ? 'Our Shop' : shopName)
        .replaceAll('{customerName}', customerName.isEmpty ? 'Guest' : customerName)
        .replaceAll('{billNumber}', billNumber)
        .replaceAll('{amount}', amount.toStringAsFixed(0))
        .replaceAll('{date}', DateFormat('dd MMM yyyy, hh:mm a').format(dateTime))
        .replaceAll('{orderType}', orderType)
        .replaceAll('{paymentMethod}', paymentMethod)
        .replaceAll('{items}', itemLines);
  }

  static Future<void> sendWhatsapp({
    required BuildContext context,
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
    final prefs = await SharedPreferences.getInstance();
    final shopName = prefs.getString('shopName') ?? 'Our Shop';
    final address = prefs.getString('address') ?? 'Address';
    final contact = prefs.getString('contact') ?? 'Contact';

    List<WhatsappTemplateModel> templates = [];
    try {
      templates = await WhatsappTemplateService().getAll();
    } catch (_) {}

    if (!context.mounted) return;

    String message;
    if (templates.isEmpty) {
      message = _buildDefaultMessage(
        shopName: shopName,
        customerName: customerName,
        receiptNo: receiptNo,
        dateTime: dateTime,
        orderType: orderType,
        paymentType: paymentType,
        items: items,
        finalAmount: finalAmount,
      );
    } else {
      final picked = await _showTemplatePicker(
        context: context,
        templates: templates,
        shopName: shopName,
        customerName: customerName,
        billNumber: receiptNo,
        amount: finalAmount,
        dateTime: dateTime,
        orderType: orderType,
        paymentMethod: paymentType,
        items: items,
      );
      if (picked == null) return;
      message = picked;
    }

    if (!context.mounted) return;
    await _launch(
      context: context,
      phone: customerPhone,
      message: message,
      shopName: shopName,
      address: address,
      contact: contact,
      items: items,
      subTotal: subTotal,
      finalAmount: finalAmount,
      receiptNo: receiptNo,
      dateTime: dateTime,
      paymentType: paymentType,
      orderType: orderType,
      customerName: customerName,
      customerPhone: customerPhone,
    );
  }

  static Future<String?> _showTemplatePicker({
    required BuildContext context,
    required List<WhatsappTemplateModel> templates,
    required String shopName,
    required String customerName,
    required String billNumber,
    required double amount,
    required DateTime dateTime,
    required String orderType,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
  }) {
    const green = Color(0xFF25D366);
    const darkGreen = Color(0xFF0C6B0F);
    const waBubble = Color(0xFFDCF8C6);

    final sorted = [...templates]..sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.90,
        minChildSize: 0.35,
        builder: (_, scrollCtrl) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // WhatsApp-style header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
                color: darkGreen,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CommunityMaterialIcons.whatsapp, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                              text: 'Choose Template', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          MyText(text: 'Tap a template to send', color: Colors.white70, fontSize: 12),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Scrollable template list
              Expanded(
                child: Container(
                  color: Colors.grey.shade50,
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    itemCount: sorted.length,
                    itemBuilder: (_, i) {
                      final t = sorted[i];
                      final filled = fillTemplate(
                        t.message,
                        shopName: shopName,
                        customerName: customerName,
                        billNumber: billNumber,
                        amount: amount,
                        dateTime: dateTime,
                        orderType: orderType,
                        paymentMethod: paymentMethod,
                        items: items,
                      );
                      return GestureDetector(
                        onTap: () => Navigator.pop(ctx, filled),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border(
                              left: BorderSide(
                                color: t.isDefault ? green : Colors.grey.shade200,
                                width: 3,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    t.isDefault ? green.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: const Icon(CommunityMaterialIcons.whatsapp, color: green, size: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MyText(
                                        text: t.name,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (t.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 12),
                                            SizedBox(width: 3),
                                            MyText(
                                                text: 'Default',
                                                fontSize: 10,
                                                color: green,
                                                fontWeight: FontWeight.bold),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Filled message bubble — real customer data, no raw placeholders
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: waBubble,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(10),
                                      topRight: Radius.circular(10),
                                      bottomLeft: Radius.circular(2),
                                      bottomRight: Radius.circular(10),
                                    ),
                                  ),
                                  child: MyText(
                                    text: filled,
                                    fontSize: 11.5,
                                    color: Colors.black87,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(Icons.send_rounded, size: 13, color: darkGreen),
                                    SizedBox(width: 4),
                                    MyText(
                                        text: 'Tap to send',
                                        fontSize: 11,
                                        color: darkGreen,
                                        fontWeight: FontWeight.w500),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildDefaultMessage({
    required String shopName,
    required String customerName,
    required String receiptNo,
    required DateTime dateTime,
    required String orderType,
    required String paymentType,
    required List<Map<String, dynamic>> items,
    required double finalAmount,
  }) {
    String msg = "🏪 *${shopName.toUpperCase()}* 🏪\n"
        "✨ *Bill Summary: #$receiptNo* ✨\n\n"
        "👤 *Customer:* ${customerName.isEmpty ? 'Guest' : customerName}\n"
        "📅 *Date:* ${DateFormat('dd MMM yyyy, hh:mm a').format(dateTime)}\n"
        "🍴 *Order Type:* $orderType\n"
        "💳 *Payment:* $paymentType\n\n"
        "*Items:*\n";
    for (final item in items) {
      msg += "• ${item['name']} x ${item['quantity']} = ₹${item['price'] * item['quantity']}\n";
    }
    msg += "\n💰 *Total Amount: ₹$finalAmount*\n\nThank you for visiting *$shopName*! 🙏";
    return msg;
  }

  static Future<void> _launch({
    required BuildContext context,
    required String phone,
    required String message,
    required String shopName,
    required String address,
    required String contact,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required double finalAmount,
    required String receiptNo,
    required DateTime dateTime,
    required String paymentType,
    required String orderType,
    required String customerName,
    required String customerPhone,
  }) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isNotEmpty) {
        String formatted = cleanPhone;
        if (formatted.length == 10) formatted = "91$formatted";
        final uri = Uri.parse("https://wa.me/$formatted?text=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      final generalUri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(generalUri)) {
        await launchUrl(generalUri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        final printProvider = Provider.of<PrintProvider>(context, listen: false);
        await PdfHelper.generateAndShareBillPdf(
          shopName: shopName,
          address: address,
          contact: contact,
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
    } catch (e) {
      if (context.mounted) SnackBarUtils.showError(context, "Error opening WhatsApp: $e");
    }
  }
}
