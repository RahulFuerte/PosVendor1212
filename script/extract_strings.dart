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

  final RegExp stringPattern = RegExp(r"MyText\(\s*text:\s*('[^']+'|\x22[^\x22]+\x22)");
  
  for (String filePath in files) {
    File file = File(filePath);
    if (!file.existsSync()) continue;
    
    String content = file.readAsStringSync();
    Iterable<Match> matches = stringPattern.allMatches(content);
    
    if (matches.isNotEmpty) {
      print('\n--- \$filePath ---');
      for (Match m in matches) {
        print(m.group(1));
      }
    }
  }
}
