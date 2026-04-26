import 'package:shared_preferences/shared_preferences.dart';

class OrderOfMassPreferenceService {
  static final OrderOfMassPreferenceService _instance =
      OrderOfMassPreferenceService._internal();
  factory OrderOfMassPreferenceService() => _instance;
  OrderOfMassPreferenceService._internal();

  static const String _preferredLanguageKey = 'preferred_order_of_mass_language';
  static const String _defaultLanguage = 'en';
  static const String _showPrayerOfFaithfulKey = 'show_prayer_of_faithful';
  static const bool _defaultShowPrayerOfFaithful = false;

  // Language codes
  static const String english = 'en';
  static const String latin = 'la';
  static const String spanish = 'es';
  static const String portuguese = 'pt';
  static const String french = 'fr';
  static const String tagalog = 'tl';
  static const String italian = 'it';
  static const String polish = 'pl';
  static const String vietnamese = 'vi';
  static const String korean = 'ko';

  // Display names
  static const Map<String, String> _languageNames = {
    english: 'English',
    latin: 'Latin',
    spanish: 'Español',
    portuguese: 'Português',
    french: 'Français',
    tagalog: 'Tagalog',
    italian: 'Italiano',
    polish: 'Polski',
    vietnamese: 'Tiếng Việt',
    korean: '한국어',
  };

  String? _cachedLanguage;

  List<String> get availableLanguages => [
        english,
        latin,
        spanish,
        portuguese,
        french,
        tagalog,
        italian,
        polish,
        vietnamese,
        korean,
      ];

  String getLanguageDisplayName(String languageCode) {
    return _languageNames[languageCode] ?? languageCode;
  }

  Future<String> getPreferredLanguage() async {
    if (_cachedLanguage != null) {
      return _cachedLanguage!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLanguage = prefs.getString(_preferredLanguageKey) ?? _defaultLanguage;
      return _cachedLanguage!;
    } catch (_) {
      _cachedLanguage = _defaultLanguage;
      return _defaultLanguage;
    }
  }

  Future<void> setPreferredLanguage(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredLanguageKey, languageCode);
      _cachedLanguage = languageCode;
    } catch (_) {}
  }

  void resetCache() {
    _cachedLanguage = null;
  }

  Future<bool> getShowPrayerOfFaithful() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_showPrayerOfFaithfulKey) ?? _defaultShowPrayerOfFaithful;
    } catch (_) {
      return _defaultShowPrayerOfFaithful;
    }
  }

  Future<void> setShowPrayerOfFaithful(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_showPrayerOfFaithfulKey, value);
    } catch (_) {}
  }
}
