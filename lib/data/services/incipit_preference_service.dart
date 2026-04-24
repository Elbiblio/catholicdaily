import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether readings show the liturgical incipit (e.g. "At that time,
/// Jesus said to his disciples…") or raw scripture text.
///
/// Default is ON — preserves existing behavior for every user.
class IncipitPreferenceService {
  static final IncipitPreferenceService _instance =
      IncipitPreferenceService._internal();
  factory IncipitPreferenceService() => _instance;
  IncipitPreferenceService._internal();

  static const String _showIncipitKey = 'show_liturgical_incipit';
  static const bool _defaultShow = true;

  bool? _cached;

  Future<bool> getShowIncipit() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cached = prefs.getBool(_showIncipitKey) ?? _defaultShow;
      return _cached!;
    } catch (_) {
      _cached = _defaultShow;
      return _defaultShow;
    }
  }

  Future<void> setShowIncipit(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showIncipitKey, value);
      _cached = value;
    } catch (_) {}
  }

  void resetCache() {
    _cached = null;
  }
}
