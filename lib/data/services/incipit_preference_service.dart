import 'package:shared_preferences/shared_preferences.dart';

import 'liturgical_region_preference_service.dart';

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
  static const String _useReadingIntroReplacementsKey =
      'use_reading_intro_replacements';
  static const String _localeKey = 'incipit_locale';
  static const bool _defaultShow = true;
  static const bool _defaultUseReadingIntroReplacements = true;
  static const String _defaultLocale = 'en';

  bool? _cachedShowIncipit;
  bool? _cachedUseReadingIntroReplacements;
  String? _cachedLocale;

  Future<bool> getShowIncipit() async {
    if (_cachedShowIncipit != null) return _cachedShowIncipit!;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedShowIncipit = prefs.getBool(_showIncipitKey) ?? _defaultShow;
      return _cachedShowIncipit!;
    } catch (_) {
      _cachedShowIncipit = _defaultShow;
      return _defaultShow;
    }
  }

  Future<void> setShowIncipit(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showIncipitKey, value);
      _cachedShowIncipit = value;
    } catch (_) {}
  }

  Future<bool> getUseReadingIntroReplacements() async {
    if (_cachedUseReadingIntroReplacements != null) {
      return _cachedUseReadingIntroReplacements!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUseReadingIntroReplacements =
          prefs.getBool(_useReadingIntroReplacementsKey) ??
          _defaultUseReadingIntroReplacements;
      return _cachedUseReadingIntroReplacements!;
    } catch (_) {
      _cachedUseReadingIntroReplacements = _defaultUseReadingIntroReplacements;
      return _defaultUseReadingIntroReplacements;
    }
  }

  Future<void> setUseReadingIntroReplacements(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useReadingIntroReplacementsKey, value);
      _cachedUseReadingIntroReplacements = value;
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
      final explicitLocale = prefs.getString(_localeKey);
      if (explicitLocale != null && explicitLocale.trim().isNotEmpty) {
        _cachedLocale = explicitLocale;
        return _cachedLocale!;
      }
      try {
        final regionPrefs =
            await LiturgicalRegionPreferenceService.getInstance();
        _cachedLocale = regionPrefs.currentRegion.defaultIncipitLocale;
      } catch (_) {
        _cachedLocale = _defaultLocale;
      }
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

  Future<void> clearLocaleOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localeKey);
    } catch (_) {}
    _cachedLocale = null;
  }

  void resetCache() {
    _cachedShowIncipit = null;
    _cachedUseReadingIntroReplacements = null;
    _cachedLocale = null;
  }
}
