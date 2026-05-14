import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class PdfHelper {
  static Future<void> generateAndShareBillPdf({
    required String shopName,
    required String address,
    required String contact,
    required String receiptNo,
    required DateTime dateTime,
    required List<Map<String, dynamic>> items,
    required double subTotal,
    required double finalTotal,
    required String paymentType,
    required String orderType,
    String? customerName,
    String? customerPhone,
    double discountAmount = 0,
    bool taxEnabled = false,
    double cgstPercent = 0,
    double sgstPercent = 0,
  }) async {
    final pdf = pw.Document();

    // Calculate taxes
    final double cgstAmount = taxEnabled ? subTotal * (cgstPercent / 100) : 0;
    final double sgstAmount = taxEnabled ? subTotal * (sgstPercent / 100) : 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(shopName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Contact: $contact", style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 10),
                    pw.Text("INVOICE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              pw.Divider(thickness: 1),

              // Order Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Bill No: #$receiptNo", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(DateFormat('dd/MM/yyyy hh:mm a').format(dateTime), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Text("Order Type: $orderType", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Payment: $paymentType", style: const pw.TextStyle(fontSize: 10)),

              if (customerName != null && customerName.isNotEmpty) ...[
                pw.SizedBox(height: 5),
                pw.Text("Customer: $customerName", style: const pw.TextStyle(fontSize: 10)),
                if (customerPhone != null && customerPhone.isNotEmpty)
                  pw.Text("Phone: $customerPhone", style: const pw.TextStyle(fontSize: 10)),
              ],

              pw.Divider(thickness: 1),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text("Item", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(flex: 1, child: pw.Text("Qty", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 1, child: pw.Text("Price", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text("Total", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items
              ...items.map((item) {
                final double price = double.tryParse(item['price'].toString()) ?? 0;
                final int qty = int.tryParse(item['quantity'].toString()) ?? 1;
                final double total = price * qty;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item['name'].toString(), style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 1, child: pw.Text(qty.toString(), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 1, child: pw.Text(price.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 1, child: pw.Text(total.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Subtotal:", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text(subTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (discountAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Discount:", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("-${discountAmount.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              if (taxEnabled) ...[
                if (cgstPercent > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("CGST ($cgstPercent%):", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(cgstAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                if (sgstPercent > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("SGST ($sgstPercent%):", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(sgstAmount.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
              ],
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("GRAND TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(finalTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.Divider(thickness: 1),

              // Footer
              pw.Center(
                child: pw.Text("Thank you! Visit Again", style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to a temporary file
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/bill_$receiptNo.pdf");
    await file.writeAsBytes(await pdf.save());

    // Share the PDF
    final XFile xFile = XFile(file.path);
    await Share.shareXFiles([xFile], text: 'Bill Copy - $shopName');
  }
}
