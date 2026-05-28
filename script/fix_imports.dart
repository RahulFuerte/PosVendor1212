import 'dart:io';

void main() {
  List<String> files = [
    'lib/view/tab_screen/view-model/widgets/offline_bill_status_widget.dart',
    'lib/view/tab_screen/view-model/widgets/sync_progress_dialog.dart',
    'lib/view/tab_screen/view-model/widgets/sync_status_banner.dart'
  ];

  for (String filePath in files) {
    File file = File(filePath);
    if (!file.existsSync()) continue;
    String content = file.readAsStringSync();
    
    // add imports if not present
    if (!content.contains("import 'package:pos/l10n/app_locale.dart';")) {
      content = "import 'package:flutter_localization/flutter_localization.dart';\nimport 'package:pos/l10n/app_locale.dart';\n$content";
    }

    // replace any remaining 'const MyText(' with 'MyText(' if it contains AppLocale
    content = content.replaceAll(RegExp(r'const\s+MyText\(\s*text:\s*AppLocale'), 'MyText(text: AppLocale');

    // there could be const Text( as well
    content = content.replaceAll(RegExp(r'const\s+Text\(\s*AppLocale'), 'Text(AppLocale');

    file.writeAsStringSync(content);
  }
}
