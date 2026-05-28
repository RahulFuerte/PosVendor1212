import 'dart:io';

void main() {
  String filePath = 'lib/view/home/screens/restaurant_screen.dart';
  File file = File(filePath);
  if (file.existsSync()) {
    String content = file.readAsStringSync();
    
    Map<String, String> replacements = {
      "'Placing order...'": "AppLocale.placingOrder.getString(context)",
      "'Order placed successfully!'": "AppLocale.orderPlacedSuccessfully.getString(context)",
      "'Failed to sync with server. Saved locally.'": "AppLocale.failedToSyncSavedLocally.getString(context)",
      "'Online'": "AppLocale.onlineStatus.getString(context)",
      "'Offline'": "AppLocale.offlineStatus.getString(context)"
    };

    replacements.forEach((key, value) {
      content = content.replaceAll(key, value);
    });

    file.writeAsStringSync(content);
  }
}
