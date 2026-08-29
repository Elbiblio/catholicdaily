import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_engine.dart';

enum SpeechPlatform { android, ios, macos, windows, linux, web }

abstract class FlutterTtsDriver {
  Future<void> awaitSpeakCompletion(bool enabled);

  void setStartHandler(void Function() handler);

  void setCompletionHandler(void Function() handler);

  void setErrorHandler(void Function(String message) handler);

  void setProgressHandler(
    void Function(String text, int start, int end, String word) handler,
  );

  Future<Object?> getVoices();

  Future<bool> isLanguageInstalled(String language);

  Future<void> setLanguage(String language);

  Future<void> setSpeechRate(double rate);

  Future<void> setVoice(Map<String, String> voice);

  Future<void> speak(String text);

  Future<void> pause();

  Future<void> stop();
}

class FlutterTtsSpeechEngine implements SpeechEngine {
  final FlutterTtsDriver _driver;
  final SpeechPlatform _platform;
  SpeechEngineCallbacks? _callbacks;
  Future<void>? _initialization;
  bool _handlersInstalled = false;
  bool _disposed = false;
  String? _activeUtteranceId;

  FlutterTtsSpeechEngine({FlutterTtsDriver? driver, SpeechPlatform? platform})
    : _driver = driver ?? _PluginFlutterTtsDriver(FlutterTts()),
      _platform = platform ?? _currentPlatform();

  @override
  bool get supportsNativePause =>
      _platform == SpeechPlatform.ios ||
      _platform == SpeechPlatform.macos ||
      _platform == SpeechPlatform.web;

  @override
  void setCallbacks(SpeechEngineCallbacks callbacks) {
    if (_disposed) return;
    _callbacks = callbacks;
  }

  @override
  Future<void> initialize() {
    if (_disposed) return Future<void>.value();
    return _initialization ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    _installHandlersOnce();
    await _driver.awaitSpeakCompletion(true);
  }

  void _installHandlersOnce() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    _driver.setStartHandler(() {
      final id = _activeUtteranceId;
      if (!_disposed && id != null) _callbacks?.onStart(id);
    });
    _driver.setCompletionHandler(() {
      final id = _activeUtteranceId;
      if (!_disposed && id != null) _callbacks?.onCompletion(id);
      if (_activeUtteranceId == id) _activeUtteranceId = null;
    });
    _driver.setErrorHandler((message) {
      final id = _activeUtteranceId;
      if (!_disposed && id != null) _callbacks?.onError(id, message);
      if (_activeUtteranceId == id) _activeUtteranceId = null;
    });
    _driver.setProgressHandler((text, start, end, word) {
      final id = _activeUtteranceId;
      if (!_disposed && id != null) {
        _callbacks?.onProgress(id, start, end, word);
      }
    });
  }

  @override
  Future<List<SpeechVoice>> getVoices() async {
    final raw = await _driver.getVoices();
    if (raw is! Iterable) return const <SpeechVoice>[];
    final voices = <SpeechVoice>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = item['name']?.toString().trim() ?? '';
      final locale = item['locale']?.toString().trim() ?? '';
      if (name.isEmpty || locale.isEmpty) continue;
      voices.add(
        SpeechVoice(
          name: name,
          locale: locale,
          isNetworkRequired: _networkRequired(item),
        ),
      );
    }
    voices.sort((first, second) {
      final networkOrder = (first.isNetworkRequired ? 1 : 0).compareTo(
        second.isNetworkRequired ? 1 : 0,
      );
      if (networkOrder != 0) return networkOrder;
      final localeOrder = first.locale.compareTo(second.locale);
      return localeOrder != 0 ? localeOrder : first.name.compareTo(second.name);
    });
    return List<SpeechVoice>.unmodifiable(voices);
  }

  @override
  Future<void> configure(SpeechEngineSettings settings) async {
    if (_disposed) return;
    final language = settings.language.trim();
    if (language.isNotEmpty) {
      if (_platform == SpeechPlatform.android) {
        final installed = await _driver.isLanguageInstalled(language);
        if (!installed) {
          throw StateError('No installed text-to-speech voice for $language.');
        }
      }
      await _driver.setLanguage(language);
    }
    await _driver.setSpeechRate(settings.rate.clamp(0.0, 1.0));
    final voice = settings.voice;
    if (voice != null) {
      await _driver.setVoice(<String, String>{
        'name': voice.name,
        'locale': voice.locale,
      });
    }
  }

  @override
  Future<void> speak(String text, {required String utteranceId}) async {
    if (_disposed || text.trim().isEmpty) return;
    _activeUtteranceId = utteranceId;
    await initialize();
    if (_disposed || _activeUtteranceId != utteranceId) return;
    await _driver.speak(text);
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    if (!supportsNativePause) {
      throw StateError('Native pause is not reliable on this platform.');
    }
    await _driver.pause();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _activeUtteranceId = null;
    await _driver.stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _activeUtteranceId = null;
    _callbacks = null;
    await _driver.stop();
  }

  static bool _networkRequired(Map<dynamic, dynamic> value) {
    final raw =
        value['network_required'] ??
        value['networkRequired'] ??
        value['isNetworkConnectionRequired'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw != null) return raw.toString().toLowerCase() == 'true';
    final features = value['features'];
    if (features is Iterable) {
      return features.any(
        (feature) => feature.toString().toLowerCase().contains('network'),
      );
    }
    return false;
  }

  static SpeechPlatform _currentPlatform() {
    if (kIsWeb) return SpeechPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => SpeechPlatform.android,
      TargetPlatform.iOS => SpeechPlatform.ios,
      TargetPlatform.macOS => SpeechPlatform.macos,
      TargetPlatform.windows => SpeechPlatform.windows,
      TargetPlatform.linux => SpeechPlatform.linux,
      TargetPlatform.fuchsia => SpeechPlatform.linux,
    };
  }
}

class _PluginFlutterTtsDriver implements FlutterTtsDriver {
  final FlutterTts _tts;

  _PluginFlutterTtsDriver(this._tts);

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    await _tts.awaitSpeakCompletion(enabled);
  }

  @override
  void setStartHandler(void Function() handler) {
    _tts.setStartHandler(handler);
  }

  @override
  void setCompletionHandler(void Function() handler) {
    _tts.setCompletionHandler(handler);
  }

  @override
  void setErrorHandler(void Function(String message) handler) {
    _tts.setErrorHandler((message) => handler(message.toString()));
  }

  @override
  void setProgressHandler(
    void Function(String text, int start, int end, String word) handler,
  ) {
    _tts.setProgressHandler(handler);
  }

  @override
  Future<Object?> getVoices() async => await _tts.getVoices;

  @override
  Future<bool> isLanguageInstalled(String language) async {
    final result = await _tts.isLanguageInstalled(language);
    if (result is bool) return result;
    if (result is num) return result != 0;
    return result?.toString().toLowerCase() == 'true';
  }

  @override
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }
}
