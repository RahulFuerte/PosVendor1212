import 'dart:io';

void main() {
  // 1. Fix app_locale.dart
  final localeFile = File('lib/l10n/app_locale.dart');
  String content = localeFile.readAsStringSync();
  
  content = content.replaceAll("static const String selectKey = 'selectKey';", "static const String select = 'select';");
  content = content.replaceAll("selectKey: 'Select',", "select: 'Select',");
  
  content = content.replaceAll("static const String printKey = 'printKey';", "static const String print = 'print';");
  content = content.replaceAll("printKey: 'Print',", "print: 'Print',");
  
  content = content.replaceAll("static const String ordersKey = 'ordersKey';", "static const String orders = 'orders';");
  content = content.replaceAll("ordersKey: 'orders',", "orders: 'orders',");
  
  // Add error key if missing
  if (!content.contains("static const String error = 'error';")) {
    content = content.replaceFirst("static const String select = 'select';", "static const String error = 'error';\n  static const String select = 'select';");
  }
  if (!content.contains("error: 'Error',")) {
    content = content.replaceAll("select: 'Select',", "error: 'Error',\n    select: 'Select',");
  }
  
  localeFile.writeAsStringSync(content);
  
  // 2. Add imports to screens
  final filesToFix = [
    'lib/view/home/screens/expense_main.dart',
    'lib/view/home/reports/bill_wise_report.dart',
    'lib/view/home/reports/customer_wise_report.dart',
    'lib/view/home/reports/date_wise_report.dart',
    'lib/view/home/reports/item_wise_report.dart',
    'lib/view/home/reports/report_nav_bar.dart',
    'lib/view/home/reports/sales_report_screen.dart',
    'lib/view/home/reports/staff_wise_report.dart',
  ];
  
  for (final path in filesToFix) {
    final file = File(path);
    if (file.existsSync()) {
      String fileContent = file.readAsStringSync();
      
      bool needsAppLocale = !fileContent.contains('package:pos/l10n/app_locale.dart');
      bool needsLocalization = !fileContent.contains('package:flutter_localization/flutter_localization.dart');
      
      String imports = '';
      if (needsAppLocale) {
        imports += "import 'package:pos/l10n/app_locale.dart';\n";
      }
      if (needsLocalization) {
        imports += "import 'package:flutter_localization/flutter_localization.dart';\n";
      }
      
      if (imports.isNotEmpty) {
        // Insert after the first import
        final firstImportMatch = RegExp(r'^import .*;', multiLine: true).firstMatch(fileContent);
        if (firstImportMatch != null) {
          final pos = firstImportMatch.end + 1;
          fileContent = fileContent.substring(0, pos) + imports + fileContent.substring(pos);
          file.writeAsStringSync(fileContent);
        }
      }
    }
  }
}
