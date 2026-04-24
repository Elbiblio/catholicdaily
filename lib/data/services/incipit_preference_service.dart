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
  static const String _localeKey = 'incipit_locale';
  static const bool _defaultShow = true;
  static const String _defaultLocale = 'en';

  bool? _cached;
  String? _cachedLocale;

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

  /// Locale for incipit rule selection. Rules in assets/incipit_rules.csv
  /// with a matching `locale` column will fire; rules with empty or matching
  /// locale fire. Default "en". Reserved for future per-region variants
  /// (en-US vs en-GB vs en-IE) — no UI yet.
  Future<String> getLocale() async {
    if (_cachedLocale != null) return _cachedLocale!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLocale = prefs.getString(_localeKey) ?? _defaultLocale;
      return _cachedLocale!;
    } catch (_) {
      _cachedLocale = _defaultLocale;
      return _defaultLocale;
    }
  }

  Future<void> setLocale(String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale);
      _cachedLocale = locale;
    } catch (_) {}
  }

  void resetCache() {
    _cached = null;
    _cachedLocale = null;
  }
}
