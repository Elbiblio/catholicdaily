import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/liturgical_region.dart';

class LiturgicalRegionPreferenceService {
  static const _regionKey = 'liturgical_region';
  static const _autoDetectedKey = 'liturgical_region_auto_detected';

  static LiturgicalRegionPreferenceService? _instance;

  final SharedPreferences _prefs;

  LiturgicalRegionPreferenceService._(this._prefs);

  static Future<LiturgicalRegionPreferenceService> getInstance() async {
    _instance ??= LiturgicalRegionPreferenceService._(
      await SharedPreferences.getInstance(),
    );
    return _instance!;
  }

  LiturgicalRegion get currentRegion =>
      LiturgicalRegion.fromCode(_prefs.getString(_regionKey));

  bool get hasUserSelection =>
      _prefs.containsKey(_regionKey) &&
      !(_prefs.getBool(_autoDetectedKey) ?? false);

  bool get hasRegion => _prefs.containsKey(_regionKey);

  Future<void> setRegion(
    LiturgicalRegion region, {
    bool autoDetected = false,
  }) async {
    await _prefs.setString(_regionKey, region.code);
    await _prefs.setBool(_autoDetectedKey, autoDetected);
  }

  Future<LiturgicalRegion> detectAndSetIfUnset() async {
    if (hasRegion) return currentRegion;

    final detected = await _detectFromIp() ?? _detectFromLocale();
    await setRegion(detected, autoDetected: true);
    return detected;
  }

  Future<LiturgicalRegion?> _detectFromIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return LiturgicalRegion.fromCountryCode(
        decoded['country_code'] as String?,
      );
    } catch (e) {
      debugPrint('[LiturgicalRegion] IP country detection failed: $e');
      return null;
    }
  }

  LiturgicalRegion _detectFromLocale() {
    final locale = PlatformDispatcher.instance.locale;
    return LiturgicalRegion.fromCountryCode(locale.countryCode);
  }
}
