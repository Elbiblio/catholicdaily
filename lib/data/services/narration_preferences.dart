import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'speech_engine.dart';

class NarrationPreferences {
  static const storageKey = 'reading_narration_preferences_v1';
  static const legacyRateKey = 'tts_speech_rate';
  static const legacyLanguageKey = 'tts_language';
  static const legacyVoiceNameKey = 'tts_voice_name';
  static const legacyVoiceLocaleKey = 'tts_voice_locale';
  static const defaultRate = 0.5;
  static const defaultLanguage = 'en-US';
  static const _version = 1;

  static Future<bool> Function(String key, Future<bool> Function() write)?
  _writeInterceptor;

  final Future<SharedPreferences> Function() _preferences;

  NarrationPreferences({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  @visibleForTesting
  static void setWriteInterceptorForTesting(
    Future<bool> Function(String key, Future<bool> Function() write) value,
  ) {
    _writeInterceptor = value;
  }

  @visibleForTesting
  static void resetWriteInterceptorForTesting() {
    _writeInterceptor = null;
  }

  Future<SpeechEngineSettings> load() async {
    final preferences = await _preferences();
    await preferences.reload();
    final current = _decode(preferences.getString(storageKey));
    if (current != null) return current;

    final migrated = _legacySettings(preferences);
    if (migrated == null) return const SpeechEngineSettings();
    await _write(preferences, migrated);
    await _removeLegacy(preferences);
    return migrated;
  }

  Future<void> save(SpeechEngineSettings settings) async {
    _validate(settings);
    final preferences = await _preferences();
    await _write(preferences, settings);
  }

  Future<void> setRate(double rate) async {
    final current = await load();
    await save(current.copyWith(rate: rate));
  }

  Future<void> setLanguage(String language) async {
    final current = await load();
    await save(current.copyWith(language: language.trim()));
  }

  Future<void> setVoice(SpeechVoice? voice) async {
    final current = await load();
    await save(
      voice == null
          ? current.copyWith(clearVoice: true)
          : current.copyWith(voice: voice),
    );
  }

  Future<void> _write(
    SharedPreferences preferences,
    SpeechEngineSettings settings,
  ) async {
    _validate(settings);
    final encoded = jsonEncode(<String, Object?>{
      'version': _version,
      'rate': settings.rate,
      'language': settings.language.trim(),
      'voice': settings.voice == null
          ? null
          : <String, Object>{
              'name': settings.voice!.name,
              'locale': settings.voice!.locale,
              'networkRequired': settings.voice!.isNetworkRequired,
            },
    });
    final succeeded =
        await (_writeInterceptor?.call(
              storageKey,
              () => preferences.setString(storageKey, encoded),
            ) ??
            preferences.setString(storageKey, encoded));
    if (!succeeded) throw StateError('Unable to persist $storageKey');
  }

  static SpeechEngineSettings? _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['version'] != _version) {
        return null;
      }
      final rate = value['rate'];
      final language = value['language'];
      if (rate is! num ||
          rate < 0 ||
          rate > 1 ||
          language is! String ||
          language.trim().isEmpty) {
        return null;
      }
      SpeechVoice? voice;
      final rawVoice = value['voice'];
      if (rawVoice is Map<String, dynamic>) {
        final name = rawVoice['name'];
        final locale = rawVoice['locale'];
        if (name is String &&
            name.trim().isNotEmpty &&
            locale is String &&
            locale.trim().isNotEmpty) {
          voice = SpeechVoice(
            name: name.trim(),
            locale: locale.trim(),
            isNetworkRequired: rawVoice['networkRequired'] == true,
          );
        }
      }
      return SpeechEngineSettings(
        rate: rate.toDouble(),
        language: language.trim(),
        voice: voice,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  static SpeechEngineSettings? _legacySettings(SharedPreferences preferences) {
    final hasLegacy = <String>[
      legacyRateKey,
      legacyLanguageKey,
      legacyVoiceNameKey,
      legacyVoiceLocaleKey,
    ].any(preferences.containsKey);
    if (!hasLegacy) return null;

    final rawRate = preferences.get(legacyRateKey);
    final rate = rawRate is num && rawRate >= 0 && rawRate <= 1
        ? rawRate.toDouble()
        : defaultRate;
    final rawLanguage = preferences.getString(legacyLanguageKey)?.trim();
    final language = rawLanguage == null || rawLanguage.isEmpty
        ? defaultLanguage
        : rawLanguage;
    final voiceName = preferences.getString(legacyVoiceNameKey)?.trim() ?? '';
    final voiceLocale =
        preferences.getString(legacyVoiceLocaleKey)?.trim() ?? '';
    final voice = voiceName.isNotEmpty && voiceLocale.isNotEmpty
        ? SpeechVoice(name: voiceName, locale: voiceLocale)
        : null;
    return SpeechEngineSettings(rate: rate, language: language, voice: voice);
  }

  static Future<void> _removeLegacy(SharedPreferences preferences) async {
    for (final key in <String>[
      legacyRateKey,
      legacyLanguageKey,
      legacyVoiceNameKey,
      legacyVoiceLocaleKey,
    ]) {
      if (!preferences.containsKey(key)) continue;
      final removed = await preferences.remove(key);
      if (!removed) throw StateError('Unable to remove migrated $key');
    }
  }

  static void _validate(SpeechEngineSettings settings) {
    if (!settings.rate.isFinite || settings.rate < 0 || settings.rate > 1) {
      throw ArgumentError.value(
        settings.rate,
        'rate',
        'Speech rate must be between 0 and 1.',
      );
    }
    if (settings.language.trim().isEmpty) {
      throw ArgumentError.value(
        settings.language,
        'language',
        'Speech language cannot be empty.',
      );
    }
    final voice = settings.voice;
    if (voice != null &&
        (voice.name.trim().isEmpty || voice.locale.trim().isEmpty)) {
      throw ArgumentError.value(
        voice.id,
        'voice',
        'Voice name and locale cannot be empty.',
      );
    }
  }
}
