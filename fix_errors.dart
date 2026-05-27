import 'dart:io';

void main() {
  final file = File('lib/l10n/app_locale.dart');
  String content = file.readAsStringSync();
  
  // 1. Remove duplicate static const String editExpense
  int idx1 = content.indexOf("static const String editExpense = 'editExpense';");
  if (idx1 != -1) {
    int idx2 = content.indexOf("static const String editExpense = 'editExpense';", idx1 + 1);
    if (idx2 != -1) {
      content = content.replaceFirst("static const String editExpense = 'editExpense';", "", idx2);
    }
  }

  // Find all missing keys
  final missingKeys = {
    'noDataFound': 'No Data Found',
    'noDataToPrint': 'No data to print',
    'pleaseSelectAPrinterFirst': 'Please select a printer first',
    'noTransactionsFound': 'No transactions found',
    'totalPaid': 'Total Paid',
    'taxPaid': 'Tax Paid',
  };
  
  // Inject missing static const Strings
  final sb = StringBuffer();
  for (final key in missingKeys.keys) {
    if (!content.contains("static const String $key = '$key';")) {
      sb.writeln("  static const String $key = '$key';");
    }
  }
  
  content = content.replaceFirst(
    "static const String editExpense = 'editExpense';",
    "static const String editExpense = 'editExpense';\n${sb.toString()}"
  );
  
  // Inject to Maps
  final languages = ['EN', 'GU', 'HI', 'SD', 'MR', 'PA', 'BN', 'TA', 'TE', 'UR'];
  for (final lang in languages) {
    final searchPattern = RegExp('categoriesTab:\\s*\'[^\']*\',');
    final mapStartIdx = content.indexOf('static const Map<String, dynamic> $lang = {');
    if (mapStartIdx != -1) {
      final mapEndIdx = content.indexOf('};', mapStartIdx);
      if (mapEndIdx != -1) {
        String mapContent = content.substring(mapStartIdx, mapEndIdx);
        
        final mapSb = StringBuffer();
        for (final entry in missingKeys.entries) {
          if (!mapContent.contains("${entry.key}:")) {
            mapSb.writeln("    ${entry.key}: '${entry.value}',");
          }
        }
        
        // Remove duplicate editExpense in map
        int eIdx1 = mapContent.indexOf("editExpense: 'Edit Expense',");
        if (eIdx1 != -1) {
          int eIdx2 = mapContent.indexOf("editExpense: 'Edit Expense',", eIdx1 + 1);
          if (eIdx2 != -1) {
            mapContent = mapContent.replaceFirst("editExpense: 'Edit Expense',", "", eIdx2);
          }
        }
        
        final catMatch = searchPattern.firstMatch(mapContent);
        if (catMatch != null) {
           final replaceText = '${catMatch.group(0)}\n${mapSb.toString()}';
           mapContent = mapContent.replaceFirst(searchPattern, replaceText);
           content = content.substring(0, mapStartIdx) + mapContent + content.substring(mapEndIdx);
        }
      }
    }
  }
  
  file.writeAsStringSync(content);
  
  // Fix const error in customer_wise_report.dart
  final reportFile = File('lib/view/home/reports/customer_wise_report.dart');
  if (reportFile.existsSync()) {
    String rContent = reportFile.readAsStringSync();
    rContent = rContent.replaceAll("const Padding(\n                                  padding: EdgeInsets.symmetric(horizontal: 16),\n                                  child: Row(", 
                                   "Padding(\n                                  padding: const EdgeInsets.symmetric(horizontal: 16),\n                                  child: Row(");
    rContent = rContent.replaceAll("const Padding(\n                                  padding: EdgeInsets.symmetric", 
                                   "Padding(\n                                  padding: const EdgeInsets.symmetric");
    // Generic fix
    rContent = rContent.replaceAll("const Padding(", "Padding(");
    rContent = rContent.replaceAll("const Row(", "Row(");
    reportFile.writeAsStringSync(rContent);
  }
}
