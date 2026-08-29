import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResponsorialPsalmPreference extends ChangeNotifier {
  static const key = 'preferred_responsorial_psalm_edition';
  static const defaultEditionId = 'territory_lectionary';
  static ResponsorialPsalmPreference? _instance;

  final SharedPreferences _preferences;
  String _currentEditionId;

  ResponsorialPsalmPreference._(this._preferences)
    : _currentEditionId = _preferences.getString(key) ?? defaultEditionId;

  static Future<ResponsorialPsalmPreference> getInstance() async {
    return _instance ??= ResponsorialPsalmPreference._(
      await SharedPreferences.getInstance(),
    );
  }

  static void resetForTest() {
    _instance = null;
  }

  String get currentEditionId => _currentEditionId;

  Future<void> setEditionId(String editionId) async {
    if (editionId == _currentEditionId) return;
    final saved = await _preferences.setString(key, editionId);
    if (!saved) {
      throw StateError('Unable to save the responsorial psalm edition.');
    }
    _currentEditionId = editionId;
    notifyListeners();
  }
}
