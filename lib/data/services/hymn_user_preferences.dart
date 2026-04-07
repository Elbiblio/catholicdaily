import 'package:shared_preferences/shared_preferences.dart';

/// User preferences management for Catholic Daily hymn features
class HymnUserPreferences {
  static const String _keyProfessionalMode = 'hymn_professional_mode';
  static const String _keySingAlongEnabled = 'hymn_sing_along_enabled';
  static const String _keyDefaultFontSize = 'hymn_default_font_size';
  static const String _keyShowBpmSlider = 'hymn_show_bpm_slider';
  static const String _keyManualBpm = 'hymn_manual_bpm';

  static SharedPreferences? _prefs;

  /// Initialize preferences
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure preferences are initialized
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Display Preferences
  static bool get professionalMode => _prefs?.getBool(_keyProfessionalMode) ?? true;
  static Future<void> setProfessionalMode(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(_keyProfessionalMode, value);
  }

  static bool get singAlongEnabled => _prefs?.getBool(_keySingAlongEnabled) ?? false;
  static Future<void> setSingAlongEnabled(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(_keySingAlongEnabled, value);
  }

  static double get defaultFontSize => _prefs?.getDouble(_keyDefaultFontSize) ?? 20.0;
  static Future<void> setDefaultFontSize(double value) async {
    final prefs = await _instance;
    await prefs.setDouble(_keyDefaultFontSize, value);
  }

  static bool get showBpmSlider => _prefs?.getBool(_keyShowBpmSlider) ?? false;
  static Future<void> setShowBpmSlider(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(_keyShowBpmSlider, value);
  }

  static double get manualBpm => _prefs?.getDouble(_keyManualBpm) ?? 0.0;
  static Future<void> setManualBpm(double value) async {
    final prefs = await _instance;
    await prefs.setDouble(_keyManualBpm, value);
  }

  /// Reset hymn preferences to defaults
  static Future<void> resetToDefaults() async {
    final prefs = await _instance;
    await prefs.remove(_keyProfessionalMode);
    await prefs.remove(_keySingAlongEnabled);
    await prefs.remove(_keyDefaultFontSize);
    await prefs.remove(_keyShowBpmSlider);
    await prefs.remove(_keyManualBpm);
  }
}
