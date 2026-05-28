import 'dart:io';

void main() {
  List<String> files = [
    'lib/view/home/widgets/dynamic_table_selector.dart'
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
    content = content.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*MyText\(\s*text:\s*AppLocale'), 'Center(child: MyText(text: AppLocale');
    content = content.replaceAll(RegExp(r'const\s+Center\(\s*child:\s*Text\(\s*AppLocale'), 'Center(child: Text(AppLocale');

    file.writeAsStringSync(content);
  }
}
