import 'package:shared_preferences/shared_preferences.dart';

class MySharedPreferences {
  MySharedPreferences();
  final String _nameKey = "name",
      _isAdminKey = "isAdmin",
      _uIDKey = "uID",
      _employerUIDKey = "employerUID",
      _employerNameKey = "employerName",
      _emailKey = "email",
      _profileImageUrlKey = "profileImageUrl";

  String get nameKey => _nameKey;
  String get uIDKey => _uIDKey;
  String get emailKey => _emailKey;
  String get profileImageUrlKey => _profileImageUrlKey;
  String get isAdminKey => _isAdminKey;
  String get employerUidKey => _employerUIDKey;
  String get employerNameKey => _employerNameKey;

  setPreferences(Map<String, dynamic> map) async {
    SharedPreferences sp = await preferences;
    sp.setString(uIDKey, map["uID"]!);
    if (map[_isAdminKey] != null) {
      sp.setBool(isAdminKey, map[_isAdminKey]);
    }
    if (map[_nameKey] != null) {
      sp.setString(nameKey, map[_nameKey]!);
    }
    if (map[_emailKey] != null) {
      sp.setString(emailKey, map[_emailKey]!);
    }
    if (map[_profileImageUrlKey] != null) {
      sp.setString(profileImageUrlKey, map[_profileImageUrlKey]!);
    }
    if (map[_employerUIDKey] != null) {
      sp.setString(_employerUIDKey, map[_employerUIDKey]!);
    }
    if (map[_employerNameKey] != null) {
      sp.setString(_employerNameKey, map[_employerNameKey]!);
    }
  }

  clear() async {
    SharedPreferences sp = await SharedPreferences.getInstance();
    sp.clear();
  }

  setEmployerUID(String value) async {
    SharedPreferences sp = await preferences;
    sp.setString(employerUidKey, value);
  }

  setEmployerName(String value) async {
    SharedPreferences sp = await preferences;
    sp.setString(employerNameKey, value);
  }

  Future<SharedPreferences> get preferences async =>
      await SharedPreferences.getInstance();

  Future<bool> get isAdmin async {
    SharedPreferences sp = await preferences;
    try {
      return sp.getBool(isAdminKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<String> get employerUID async {
    SharedPreferences sp = await preferences;
    try {
      return sp.getString(employerUidKey) ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<String> get employerName async {
    SharedPreferences sp = await preferences;
    try {
      return sp.getString(_employerNameKey) ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<String> get employeeName async {
    SharedPreferences sp = await preferences;
    try {
      return sp.getString(_nameKey) ?? "";
    } catch (e) {
      return "";
    }
  }

  Future<String> get uID async {
    SharedPreferences sp = await preferences;
    try {
      return sp.getString(_uIDKey) ?? "";
    } catch (e) {
      return "";
    }
  }
}
