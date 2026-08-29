import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_source_registry.dart';

enum BibleVersionType {
  rsvce('rsvce'),
  nabre('nabre'),
  douayRheims('douay_rheims');

  final String dbName;

  const BibleVersionType(this.dbName);

  String get fullName =>
      BibleSourceRegistry.instance.requireById(dbName).displayName;

  String get abbreviation =>
      BibleSourceRegistry.instance.requireById(dbName).abbreviation;

  static BibleVersionType fromDbName(String dbName) {
    return BibleVersionType.values.firstWhere(
      (v) => v.dbName == dbName,
      orElse: () => BibleVersionType.rsvce,
    );
  }
}

class BibleVersionRecoveryPolicy {
  const BibleVersionRecoveryPolicy._();

  static BibleVersionType versionAfterFailure({
    required BibleVersionType failedVersion,
    required BibleVersionType currentVersion,
  }) {
    return currentVersion == failedVersion
        ? BibleVersionType.rsvce
        : currentVersion;
  }
}

class BibleVersionPreference extends ChangeNotifier {
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
    if (_currentVersion != version) {
      final saved = await _prefs.setString(_key, version.dbName);
      if (!saved) {
        throw StateError('Unable to save the Bible version preference.');
      }
      _currentVersion = version;
      notifyListeners();
    }
  }

  String get currentDbName => _currentVersion.dbName;
  String get currentFullName => _currentVersion.fullName;
  String get currentAbbreviation => _currentVersion.abbreviation;
}
