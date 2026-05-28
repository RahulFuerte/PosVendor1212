import 'dart:io';

void main() {
  List<String> files = [
    'lib/view/home/screens/kot_management_screen.dart',
    'lib/view/home/screens/restaurant_screen.dart',
    'lib/view/home/screens/subscription_history_screen.dart',
    'lib/view/home/screens/subscription_plans_screen.dart',
    'lib/view/home/screens/table_management_screen.dart',
    'lib/view/home/screens/users_data_screen.dart',
    'lib/view/home/screens/Items/category_management_screen.dart',
    'lib/view/home/screens/Items/product_management_screen.dart',
    'lib/view/home/widgets/dynamic_table_selector.dart',
    'lib/view/staff/screens/staff_list_screen.dart',
    'lib/view/tab_screen/view-model/widgets/offline_bill_status_widget.dart',
    'lib/view/tab_screen/view-model/widgets/sync_progress_dialog.dart',
    'lib/view/tab_screen/view-model/widgets/sync_status_banner.dart'
  ];

  Map<String, String> replacements = {
    "'No Active KOTs'": "AppLocale.noActiveKOTs.getString(context)",
    "'No Transactions Yet'": "AppLocale.noTransactionsYet.getString(context)",
    "\"You haven't purchased any plans yet.\\nWhen you do, they'll appear here.\"": "AppLocale.noTransactionsMsg.getString(context)",
    "'Subscription Plans'": "AppLocale.subscriptionPlansTitle.getString(context)",
    "'PRICING PLANS'": "AppLocale.pricingPlans.getString(context)",
    "'Grow Your Business'": "AppLocale.growYourBusiness.getString(context)",
    "'Choose a plan that fits your restaurant scale.\\nSimple and transparent pricing.'": "AppLocale.pricingSubtitle.getString(context)",
    "'Expires on: \${_expiryDate!.day}/\${_expiryDate!.month}/\${_expiryDate!.year}'": "'\${AppLocale.expiresOnPrefix.getString(context)}\${_expiryDate!.day}/\${_expiryDate!.month}/\${_expiryDate!.year}'",
    "'Select a plan below to continue using premium features.'": "AppLocale.selectPlanPrompt.getString(context)",
    "'TRIAL'": "AppLocale.trial.getString(context)",
    "'MOST POPULAR'": "AppLocale.mostPopular.getString(context)",
    "'\${plan.durationInDays} Days access'": "'\${plan.durationInDays}\${AppLocale.daysAccess.getString(context)}'",
    "'Activate \${plan.name}'": "'\${AppLocale.activatePlan.getString(context)}\${plan.name}'",
    "'Are you sure you want to upgrade to the \${plan.name} plan for ₹\${plan.price.toStringAsFixed(0)}?'": "'\${AppLocale.areYouSureUpgrade.getString(context)}\${plan.name}\${AppLocale.planFor.getString(context)}\${plan.price.toStringAsFixed(0)}?'",
    "'Maybe Later'": "AppLocale.maybeLater.getString(context)",
    "'Yes, Upgrade'": "AppLocale.yesUpgrade.getString(context)",
    "'Subscription Active!'": "AppLocale.subscriptionActive.getString(context)",
    "'Welcome to the premium experience. All features are now unlocked for your restaurant.'": "AppLocale.subscriptionActiveMsg.getString(context)",
    "'Great!'": "AppLocale.great.getString(context)",
    "'\${table.tableNumber} Summary'": "'\${table.tableNumber}\${AppLocale.summary.getString(context)}'",
    "'Clear Table'": "AppLocale.clearTable.getString(context)",
    "'Clear Table?'": "AppLocale.clearTableQ.getString(context)",
    "'Are you sure you want to clear table \${table.tableNumber}? This will remove all items and mark it as available.'": "AppLocale.clearTableMsg.getString(context)",
    "'Clear'": "AppLocale.clear.getString(context)",
    "'Delete \"\${cat.name}\"?\\nProducts in this category may be affected.'": "AppLocale.deleteCategoryMsg.getString(context)",
    "'\${_categories.length} total'": "'\${_categories.length}\${AppLocale.totalItems.getString(context)}'",
    "'Add First Category'": "AppLocale.addFirstCategory.getString(context)",
    "'Delete \"\${p.name}\"?\\nThis action cannot be undone.'": "AppLocale.deleteProductMsg.getString(context)",
    "'\$count product\${count == 1 ? '' : 's'}'": "'\$count\${AppLocale.productCount.getString(context)}'",
    "'Code: \${p.foodCode}'": "'\${AppLocale.codePrefix.getString(context)}\${p.foodCode}'",
    "'Stock: \${p.stocks}'": "'\${AppLocale.stockPrefix.getString(context)}\${p.stocks}'",
    "'Add First Product'": "AppLocale.addFirstProduct.getString(context)",
    "'Select Table'": "AppLocale.selectTable.getString(context)",
    "'No tables found.'": "AppLocale.noTablesFound.getString(context)",
    "'Are you sure you want to delete \${staff.name}?'": "'\${AppLocale.areYouSureDeleteStaff.getString(context)}\${staff.name}?'",
    "'Sync Details'": "AppLocale.syncDetails.getString(context)",
    "'Synced Bills:'": "AppLocale.syncedBills.getString(context)",
    "'• ... and \${result.syncedBillIds.length - 5} more'": "'•\${AppLocale.andMore.getString(context)}\${result.syncedBillIds.length - 5}\${AppLocale.more.getString(context)}'",
    "'Failed Bills:'": "AppLocale.failedBills.getString(context)",
    "'• ... and \${result.failedBillIds.length - 3} more'": "'•\${AppLocale.andMore.getString(context)}\${result.failedBillIds.length - 3}\${AppLocale.more.getString(context)}'",
    "'\$_offlineBillsCount pending'": "'\$_offlineBillsCount\${AppLocale.pendingSuffix.getString(context)}'",
    "'Synced'": "AppLocale.synced.getString(context)",
    "'Sync Status'": "AppLocale.syncStatus.getString(context)",
    "'\$_offlineBillsCount bills pending sync'": "'\$_offlineBillsCount \${AppLocale.pendingSync.getString(context)}'",
    "'Error: \$_lastSyncError'": "'\${AppLocale.errorPrefix.getString(context)}\$_lastSyncError'",
    "'Last sync: \${_formatDateTime(_lastSyncTime!)}'": "'\${AppLocale.lastSync.getString(context)}\${_formatDateTime(_lastSyncTime!)}'",
    "'Sync Now'": "AppLocale.syncNow.getString(context)",
    "'\$_itemsSynced items synced'": "'\$_itemsSynced\${AppLocale.itemsSynced.getString(context)}'",
    "'Retry'": "AppLocale.retry.getString(context)",
    "'Sync Progress'": "AppLocale.syncProgress.getString(context)",
    "'No saved orders found'": "AppLocale.noSavedOrders.getString(context)",
    "'Order #\${order.billNumber}'": "'\${AppLocale.orderHash.getString(context)}\${order.billNumber}'",
    "'Total: ₹\${order.totalAmount}'": "'\${AppLocale.totalAmount.getString(context)}: ₹\${order.totalAmount}'",
    "'Occupied'": "AppLocale.occupied.getString(context)",
    "'Order deleted'": "AppLocale.orderDeleted.getString(context)",
  };

  for (String filePath in files) {
    File file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();
    
    replacements.forEach((key, value) {
      String target1 = 'const MyText(text: \$key';
      String target2 = 'const MyText(\\n              text: \$key';
      String target3 = 'const MyText(\\n                    text: \$key';
      String target4 = 'const MyText(\\n                          text: \$key';
      
      content = content.replaceAll(target1, 'MyText(text: \$value');
      content = content.replaceAll(target2, 'MyText(\\n              text: \$value');
      content = content.replaceAll(target3, 'MyText(\\n                    text: \$value');
      content = content.replaceAll(target4, 'MyText(\\n                          text: \$value');
      
      content = content.replaceAll(key, value);
    });

    content = content.replaceAll(RegExp(r'const\s+MyText\(\s*text:\s*AppLocale'), 'MyText(text: AppLocale');

    file.writeAsStringSync(content);
  }
}
