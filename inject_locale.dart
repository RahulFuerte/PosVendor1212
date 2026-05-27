import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, String> newKeys = {
    "unknown": "Unknown",
    "editCategory": "Edit Category",
    "enterCategoryName": "Enter category name",
    "categories": "Categories",
    "searchExpenses": "Search expenses",
    "noExpenses": "No expenses",
    "searchCategoryName": "Search category name",
    "noCategories": "No categories",
    "pleaseCreateACategoryFirst": "Please create a category first",
    "pleaseEnterAnAmount": "Please enter an amount",
    "pleaseSelectACategory": "Please select a category",
    "editExpense": "Edit Expense",
    "categoryAsterisk": "Category *",
    "selectCategory": "Select Category",
    "amountAsterisk": "Amount *",
    "note": "Note",
    "optionalNote": "Optional note",
    "date": "Date",
    "customerIdMissing": "Customer ID missing",
    "errorLoadingData": "Error loading data",
    "noDataAvailableToGenerateReport": "No data available to generate report",
    "pdfGeneratedSuccessfully": "PDF generated successfully",
    "pdfGenerationFailed": "PDF generation failed",
    "pleaseConnectAPrinterFirst": "Please connect a printer first",
    "printFailed": "Print failed",
    "customerWiseReport": "Customer wise Report",
    "selectCustomer": "Select Customer",
    "startDate": "Start Date",
    "endDate": "End Date",
    "findBills": "Find Bills",
    "noTransactionsFoundForSelectedCustomer": "No transactions found for selected customer",
    "ordersKey": "orders",
    "paid": "Paid",
    "due": "Due",
    "bills": "Bills",
    "billNo": "Bill No",
    "payment": "Payment",
    "selectDate": "Select Date",
    "dateWiseReport": "Date wise Report",
    "from": "From",
    "selectKey": "Select",
    "to": "To",
    "totalDays": "Total Days",
    "netRevenue": "Net Revenue",
    "chooseADateRange": "Choose A Date Range",
    "dailySales": "Daily Sales",
    "totalCollected": "Total Collected",
    "printKey": "Print",
    "savePdf": "Save PDF",
    "pleaseSelectBothDates": "Please select both dates",
    "errorFetchingData": "Error fetching data",
    "reportPrintedSuccessfully": "Report printed successfully!",
    "printError": "Print error",
    "errorCreatingPdf": "Error creating PDF",
    "itemWiseReport": "Item wise Report",
    "totalItems": "Total Items",
    "totalQty": "Total Qty",
    "netSales": "Net Sales",
    "noItemsFound": "No Items Found",
    "sold": "sold",
    "quantityMetric": "Quantity Metric",
    "totalSales": "Total Sales",
    "billWise": "Bill-wise",
    "itemWise": "Item-wise",
    "dateWise": "Date-wise",
    "customerWise": "Customer-wise",
    "staffWise": "Staff-wise",
    "discount": "Discount",
    "tax": "Tax",
    "productSales": "Product Sales",
    "noSalesDataAvailable": "No sales data available",
    "perUnit": "per unit",
    "ofTopSeller": "of top seller",
    "errorLoadingStaff": "Error loading staff",
    "pleaseSelectDateRange": "Please select date range",
    "errorFetchingReport": "Error fetching report",
    "staffPerformance": "Staff Performance",
    "orderHistory": "Order History",
    "selectFilters": "Select Filters",
    "chooseAStaffMember": "Choose a staff member",
    "fromDate": "From Date",
    "toDate": "To Date",
    "totalOrders": "Total Orders",
    "noOrdersFoundForThisStaff": "No orders found for this staff",
    "trySelectingADifferentDateRange": "Try selecting a different date range",
    "selectAStaffMember": "Select a Staff Member",
    "chooseAStaffMemberDesc": "Choose a staff member from the dropdown above to view their sales performance and order history.",
    "pdfError": "PDF error",
    "reportPrinted": "Report printed!"
  };

  final file = File('lib/l10n/app_locale.dart');
  String content = file.readAsStringSync();

  // 1. Append static const strings
  final sbConstants = StringBuffer();
  sbConstants.writeln();
  sbConstants.writeln('  // Expenses and Reports New Keys');
  for (final key in newKeys.keys) {
    sbConstants.writeln("  static const String $key = '$key';");
  }

  content = content.replaceFirst(
    "static const String categoriesTab = 'categoriesTab';",
    "static const String categoriesTab = 'categoriesTab';\n${sbConstants.toString()}"
  );

  // 2. Append to Maps
  // Find all languages: EN, GU, HI, SD, MR, PA, BN, TA, TE, UR
  final languages = ['EN', 'GU', 'HI', 'SD', 'MR', 'PA', 'BN', 'TA', 'TE', 'UR'];
  
  for (final lang in languages) {
    // Note: I will just put the English version for now. The user just asked to make it work.
    // Real translations can be done via another python script if needed.
    final sbMap = StringBuffer();
    sbMap.writeln();
    for (final entry in newKeys.entries) {
      // Escape single quotes if necessary
      final val = entry.value.replaceAll("'", "\\'");
      sbMap.writeln("    ${entry.key}: '$val',");
    }

    // Finding the end of the map: For each map, we look for `categoriesTab: '...',`
    // Then we append right after it.
    final regex = RegExp('categoriesTab:\\s*\'[^\']*\',');
    final matches = regex.allMatches(content).toList();
    if (matches.isNotEmpty) {
      // Because we want to replace only for the specific map, we could do it one by one, 
      // but replacing `categoriesTab: 'Categories',` in EN map will work if we do it sequentially.
      // Wait, let's just do a blanket replace for all occurrences of categoriesTab
      // Actually, categoriesTab has different values for different languages.
    }
  }

  // Safer replacement for maps:
  for (final lang in languages) {
    final searchPattern = RegExp('categoriesTab:\\s*\'[^\']*\',');
    // We can't just replace first, we need to locate the map.
    // The map starts with `static const Map<String, dynamic> $lang = {`
    final mapStartIdx = content.indexOf('static const Map<String, dynamic> $lang = {');
    if (mapStartIdx != -1) {
      final mapEndIdx = content.indexOf('};', mapStartIdx);
      if (mapEndIdx != -1) {
        String mapContent = content.substring(mapStartIdx, mapEndIdx);
        
        final sbMap = StringBuffer();
        sbMap.writeln();
        for (final entry in newKeys.entries) {
          final val = entry.value.replaceAll("'", "\\'");
          sbMap.writeln("    ${entry.key}: '$val',");
        }
        
        // Find categoriesTab line inside mapContent
        final catMatch = searchPattern.firstMatch(mapContent);
        if (catMatch != null) {
           final replaceText = '${catMatch.group(0)}\n${sbMap.toString()}';
           mapContent = mapContent.replaceFirst(searchPattern, replaceText);
           content = content.substring(0, mapStartIdx) + mapContent + content.substring(mapEndIdx);
        }
      }
    }
  }

  file.writeAsStringSync(content);
}
