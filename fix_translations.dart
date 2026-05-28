import 'dart:io';

void main() async {
  final baseDir = r"d:\Flutter\Projects\pos\pos23052026\Pos\Pos\lib\view\home\reports";
  final files = [
    "bill_wise_report.dart",
    "date_wise_report.dart",
    "item_wise_report.dart",
    "sales_report_screen.dart"
  ];

  final replacements = [
    [r"'Billwise report'", r"AppLocale.billWiseReport.getString(context)"],
    [r"'FROM'", r"AppLocale.from.getString(context).toUpperCase()"],
    [r"'TO'", r"AppLocale.to.getString(context).toUpperCase()"],
    [r"'CHOOSE A DATE RANGE'", r"AppLocale.pleaseSelectDateRange.getString(context).toUpperCase()"],
    [r"'NO TRANSACTIONS FOUND'", r"AppLocale.noTransactionsFound.getString(context).toUpperCase()"],
    [r"'WALK-IN'", r"AppLocale.walkIn.getString(context).toUpperCase()"],
    [r"'TOTAL PAID'", r"AppLocale.totalPaid.getString(context).toUpperCase()"],
    [r"'SUBTOTAL'", r"AppLocale.subTotal.getString(context).toUpperCase()"],
    [r"'DISCOUNT'", r"AppLocale.discount.getString(context).toUpperCase()"],
    [r"'TAX PAID'", r"AppLocale.taxPaid.getString(context).toUpperCase()"],
    [r'"PRINT"', r'AppLocale.print.getString(context).toUpperCase()'],
    [r'"SAVE PDF"', r'AppLocale.savePdf.getString(context).toUpperCase()'],

    [r"text:\s*'FROM'", r"text: AppLocale.from.getString(context).toUpperCase()"],
    [r"text:\s*'TO'", r"text: AppLocale.to.getString(context).toUpperCase()"],
    [r"text:\s*'CHOOSE A DATE RANGE'", r"text: AppLocale.pleaseSelectDateRange.getString(context).toUpperCase()"],
    [r"text:\s*'NO TRANSACTIONS FOUND'", r"text: AppLocale.noTransactionsFound.getString(context).toUpperCase()"],
    [r"text:\s*'WALK-IN'", r"text: AppLocale.walkIn.getString(context).toUpperCase()"],
    [r"text:\s*'TOTAL PAID'", r"text: AppLocale.totalPaid.getString(context).toUpperCase()"],
    [r"text:\s*'SUBTOTAL'", r"text: AppLocale.subTotal.getString(context).toUpperCase()"],
    [r"text:\s*'DISCOUNT'", r"text: AppLocale.discount.getString(context).toUpperCase()"],
    [r"text:\s*'TAX PAID'", r"text: AppLocale.taxPaid.getString(context).toUpperCase()"],

    [r"text:\s*'Total Sales'", r"text: AppLocale.totalSales.getString(context)"],
    [r"text:\s*'Sales Report'", r"text: AppLocale.salesReport.getString(context)"],
    [r"text:\s*'Item-wise Report'", r"text: AppLocale.itemWiseReport.getString(context)"],
    [r"text:\s*'Date-wise Report'", r"text: AppLocale.dateWiseReport.getString(context)"],
    [r"text:\s*'Bill-wise'", r"text: AppLocale.billWiseReport.getString(context)"],
    [r"text:\s*'Sales'", r"text: AppLocale.salesReport.getString(context)"],
    [r"text:\s*'Item-wise'", r"text: AppLocale.itemWiseReport.getString(context)"],
    [r"text:\s*'Date-wise'", r"text: AppLocale.dateWiseReport.getString(context)"],
  ];

  for (final filename in files) {
    final file = File('$baseDir\\$filename');
    if (await file.exists()) {
      var content = await file.readAsString();
      for (final rep in replacements) {
        content = content.replaceAll(RegExp(rep[0]), rep[1]);
      }
      await file.writeAsString(content);
      print("Fixed \$filename");
    }
  }
}
