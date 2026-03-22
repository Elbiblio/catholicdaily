import 'package:shared_preferences/shared_preferences.dart';

enum BibleVersionType {
  rsvce('rsvce', 'Revised Standard Version Catholic Edition', 'RSVCE'),
  nabre('nabre', 'New American Bible Revised Edition', 'NABRE');

  final String dbName;
  final String fullName;
  final String abbreviation;

  const BibleVersionType(this.dbName, this.fullName, this.abbreviation);

  static BibleVersionType fromDbName(String dbName) {
    return BibleVersionType.values.firstWhere(
      (v) => v.dbName == dbName,
      orElse: () => BibleVersionType.rsvce,
    );
  }
}

class BibleVersionPreference {
  static const String _key = 'preferred_bible_version';
  static BibleVersionPreference? _instance;
  
  final SharedPreferences _prefs;
  BibleVersionType _currentVersion = BibleVersionType.rsvce;

  BibleVersionPreference._(this._prefs) {
    final savedVersion = _prefs.getString(_key);
    if (savedVersion != null) {
      _currentVersion = BibleVersionType.fromDbName(savedVersion);
    }
  }

  static Future<BibleVersionPreference> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = BibleVersionPreference._(prefs);
    }
    return _instance!;
  }

  BibleVersionType get currentVersion => _currentVersion;

  Future<void> setVersion(BibleVersionType version) async {
    _currentVersion = version;
    await _prefs.setString(_key, version.dbName);
  }

  String get currentDbName => _currentVersion.dbName;
  String get currentFullName => _currentVersion.fullName;
  String get currentAbbreviation => _currentVersion.abbreviation;
}
