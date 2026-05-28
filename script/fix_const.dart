import 'dart:io';

void main() {
  List<String> files = [
    'lib/view/tab_screen/view-model/widgets/offline_bill_status_widget.dart',
    'lib/view/home/widgets/dynamic_table_selector.dart',
    'lib/view/home/screens/subscription_plans_screen.dart' // Just in case
  ];

  for (String filePath in files) {
    File file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();
    
    // add imports if not present
    if (!content.contains("import 'package:pos/l10n/app_locale.dart';")) {
      content = "import 'package:flutter_localization/flutter_localization.dart';\nimport 'package:pos/l10n/app_locale.dart';\n$content";
    }

    content = content.replaceAll(RegExp(r'const\s+MyText\(\s*text:\s*AppLocale'), 'MyText(text: AppLocale');
    content = content.replaceAll(RegExp(r'const\s+Text\(\s*AppLocale'), 'Text(AppLocale');
    
    // There could be nested const
    // e.g. const Center(child: Text(AppLocale...))
    // We can't regex that easily.
    // Let's replace 'const Center(child: Text(AppLocale' to 'Center(child: Text(AppLocale'
    content = content.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*MyText\(\s*text:\s*AppLocale'), 'Center(child: MyText(text: AppLocale');
    content = content.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*Text\(\s*AppLocale'), 'Center(child: Text(AppLocale');

    file.writeAsStringSync(content);
  }
}
