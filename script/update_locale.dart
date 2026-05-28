import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('lib/l10n/app_locale.dart');
  var content = await file.readAsString();
  
  final jsonFile = File('translations.json');
  if (!jsonFile.existsSync()) return;
  
  final String jsonStr = await jsonFile.readAsString();
  final Map<String, dynamic> translations = jsonDecode(jsonStr);
  
  if (translations.isEmpty) return;
  
  final Map<String, Map<String, String>> langs = {
    'EN': {}, 'GU': {}, 'HI': {}, 'SD': {}, 'MR': {},
    'PA': {}, 'BN': {}, 'TA': {}, 'TE': {}, 'UR': {}
  };
  
  final List<String> newKeys = [];
  
  for (final key in translations.keys) {
    if (content.contains("static const String $key = '$key';")) {
      continue;
    }
    newKeys.add("  static const String $key = '$key';");
    final Map<String, dynamic> transMap = translations[key];
    langs.forEach((lang, map) {
      if (transMap.containsKey(lang)) {
        map[key] = transMap[lang].replaceAll("'", "\\'");
      } else {
        map[key] = transMap['EN']?.replaceAll("'", "\\'") ?? '';
      }
    });
  }
  
  if (newKeys.isEmpty) return;
  
  // Insert keys before `static const Map<String, dynamic> EN = {`
  final String keysStr = '${newKeys.join('\n')}\n\n';
  content = content.replaceFirst('  static const Map<String, dynamic> EN = {', '$keysStr  static const Map<String, dynamic> EN = {');
  
  // Insert translations into each map
  langs.forEach((lang, trans) {
    if (trans.isNotEmpty) {
      final String mapStart = 'static const Map<String, dynamic> $lang = {';
      final String transStr = '${trans.entries.map((e) => "    ${e.key}: '${e.value}',").join('\n')}\n';
      content = content.replaceFirst(mapStart, '$mapStart\n$transStr');
    }
  });
  
  await file.writeAsString(content);
  print('Translations injected successfully.');
}
