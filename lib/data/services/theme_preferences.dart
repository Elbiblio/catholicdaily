import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeStyle { standard, parchment }

class ThemePreferences {
  ThemePreferences._(this._prefs);

  static const _themeModeKey = 'app_theme_mode';
  static const _themeStyleKey = 'app_theme_style';

  final SharedPreferences _prefs;

  static Future<ThemePreferences> getInstance() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemePreferences._(prefs);
  }

  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeModeKey);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_themeModeKey, value);
  }

  AppThemeStyle getThemeStyle() {
    final value = _prefs.getString(_themeStyleKey);
    return value == 'parchment' ? AppThemeStyle.parchment : AppThemeStyle.standard;
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    final value = style == AppThemeStyle.parchment ? 'parchment' : 'standard';
    await _prefs.setString(_themeStyleKey, value);
  }
}
