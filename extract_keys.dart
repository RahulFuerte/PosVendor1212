import 'dart:io';

void main() {
  final file = File('lib/l10n/app_locale.dart');
  final lines = file.readAsLinesSync();
  final regex = RegExp(r'static const String (\w+) =');
  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      print(match.group(1));
    }
  }
}
