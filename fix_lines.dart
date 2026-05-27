import 'dart:io';

void main() {
  final file = File('lib/l10n/app_locale.dart');
  final lines = file.readAsLinesSync();
  
  final linesToRemove = [1324, 1779, 2234, 2689, 3144, 3599, 4054, 4509, 4963];
  
  // Create a new list without these lines (adjusting for 1-based indexing)
  final newLines = <String>[];
  for (int i = 0; i < lines.length; i++) {
    if (!linesToRemove.contains(i + 1)) {
      newLines.add(lines[i]);
    }
  }
  
  file.writeAsStringSync(newLines.join('\n'));
}
