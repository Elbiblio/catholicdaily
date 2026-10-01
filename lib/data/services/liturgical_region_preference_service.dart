import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/liturgical_region.dart';

class LiturgicalRegionPreferenceService {
  static const _regionKey = 'liturgical_region';
  static const _autoDetectedKey = 'liturgical_region_auto_detected';

  static LiturgicalRegionPreferenceService? _instance;
  static Future<LiturgicalRegionPreferenceService>? _initialization;

  final SharedPreferences _prefs;

  LiturgicalRegionPreferenceService._(
    this._prefs, {
    LiturgicalRegion Function()? localeRegion,
  }) : _localeRegion = localeRegion ?? _detectFromPlatformLocale;

  static Future<LiturgicalRegionPreferenceService> getInstance() =>
      _initialization ??= _initialize();

  static Future<LiturgicalRegionPreferenceService> _initialize() async {
    final service = _instance ??= LiturgicalRegionPreferenceService._(
      await SharedPreferences.getInstance(),
    );
    await service.detectAndSetIfUnset();
    return service;
  }

  @visibleForTesting
  factory LiturgicalRegionPreferenceService.forTesting(
    SharedPreferences prefs, {
    required LiturgicalRegion Function() localeRegion,
  }) => LiturgicalRegionPreferenceService._(prefs, localeRegion: localeRegion);

  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance = null;
    _initialization = null;
  }

  final LiturgicalRegion Function() _localeRegion;

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
    if (hasUserSelection) return currentRegion;

    var detected = _localeRegion();
    try {
      // Many Nigerian phones use en_US. The device zone disambiguates the
      // automatic default without changing an explicitly selected calendar.
      if ((await FlutterTimezone.getLocalTimezone()).identifier ==
          'Africa/Lagos') {
        detected = LiturgicalRegion.nigeria;
      }
    } catch (_) {
      // Locale remains the fallback when the platform zone is unavailable.
    }
    await setRegion(detected, autoDetected: true);
    return detected;
  }

  static LiturgicalRegion _detectFromPlatformLocale() {
    final locale = PlatformDispatcher.instance.locale;
    return LiturgicalRegion.fromCountryCode(locale.countryCode);
  }
}
