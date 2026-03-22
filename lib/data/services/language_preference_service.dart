import 'package:shared_preferences/shared_preferences.dart';

class LanguagePreferenceService {
  static final LanguagePreferenceService _instance = LanguagePreferenceService._internal();
  factory LanguagePreferenceService() => _instance;
  LanguagePreferenceService._internal();

  static const String _preferredLanguageKey = 'preferred_prayer_language';
  static const String _defaultLanguage = 'en';
  
  // Language codes
  static const String english = 'en';
  static const String latin = 'la';
  
  // Display names
  static const Map<String, String> _languageNames = {
    english: 'English',
    latin: 'Latin',
  };

  String? _cachedLanguage;

  List<String> get availableLanguages => [english, latin];
  
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
    } catch (e) {
      _cachedLanguage = _defaultLanguage;
      return _defaultLanguage;
    }
  }

  Future<void> setPreferredLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredLanguageKey, language);
      _cachedLanguage = language;
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> toggleLanguage() async {
    final current = await getPreferredLanguage();
    final newLanguage = current == english ? latin : english;
    await setPreferredLanguage(newLanguage);
  }

  bool isValidLanguage(String language) {
    return availableLanguages.contains(language);
  }

  // Reset method for testing purposes
  void resetCache() {
    _cachedLanguage = null;
  }
}
