import 'dart:io';

void main() {
  final dir = Directory('lib/view');
  if (!dir.existsSync()) {
    print('Directory not found');
    return;
  }
  
  final regexes = [
    RegExp(r"MyText\(\s*text:\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]"),
    RegExp(r"Text\(\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]"),
    RegExp(r"hintText:\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]"),
    RegExp(r"labelText:\s*['" '"' r"]([^'" '"' r"]+)['" '"' r"]"),
  ];

  var filesWithStrings = <String, List<String>>{};

  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      final lines = content.split('\n');
      var matches = <String>[];
      
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('//')) continue;
        for (var regex in regexes) {
          for (var match in regex.allMatches(line)) {
            final str = match.group(1);
            if (str != null && str.trim().isNotEmpty && !str.startsWith('assets/') && !str.startsWith('AppLocale.')) {
              matches.add('Line ${i+1}: $str');
            }
          }
        }
      }
      if (matches.isNotEmpty) {
        filesWithStrings[entity.path] = matches;
      }
    }
  }

  for (var file in filesWithStrings.keys) {
    print('File: $file');
    for (var match in filesWithStrings[file]!) {
      print('  $match');
    }
  }
}
