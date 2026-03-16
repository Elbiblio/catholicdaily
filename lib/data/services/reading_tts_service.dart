import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'base_service.dart';

class ReadingTtsService extends BaseService<ReadingTtsService> {
  static const String _speechRatePreferenceKey = 'reading_tts_speech_rate';

  static ReadingTtsService get instance =>
      BaseService.init(() => ReadingTtsService._());

  ReadingTtsService._() {
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _flutterTts.setErrorHandler((_) {
      _isSpeaking = false;
    });
  }

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  double _speechRate = 0.44;

  bool get isSpeaking => _isSpeaking;
  double get speechRate => _speechRate;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedRate = prefs.getDouble(_speechRatePreferenceKey);
    if (savedRate != null) {
      _speechRate = savedRate.clamp(0.3, 0.7);
    }

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.awaitSpeakCompletion(true);
    _isInitialized = true;
  }

  Future<void> setSpeechRate(double value) async {
    final normalized = value.clamp(0.3, 0.7);
    _speechRate = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_speechRatePreferenceKey, normalized);
    await initialize();
    await _flutterTts.setSpeechRate(normalized);
  }

  Future<bool> speak({
    required String title,
    required String reference,
    required String content,
  }) async {
    final text = _composeUtterance(
      title: title,
      reference: reference,
      content: content,
    );
    if (text.isEmpty) {
      return false;
    }

    try {
      await initialize();
      await _flutterTts.stop();
      final result = await _flutterTts.speak(text);
      _isSpeaking = result == 1;
      return _isSpeaking;
    } catch (error, stackTrace) {
      debugPrint('TTS speak failed: $error\n$stackTrace');
      _isSpeaking = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } finally {
      _isSpeaking = false;
    }
  }

  String _composeUtterance({
    required String title,
    required String reference,
    required String content,
  }) {
    final cleanTitle = title.trim();
    final cleanReference = reference.trim();
    final cleanContent = _sanitizeForSpeech(content);

    return [cleanTitle, cleanReference, cleanContent]
        .where((value) => value.isNotEmpty)
        .join('. ');
  }

  String _sanitizeForSpeech(String content) {
    var result = content
        .replaceAll('\r\n', '\n')
        .replaceAll('R/.', 'Response.')
        .replaceAll('R/', 'Response ')
        .replaceAll(RegExp(r'\(\s*s\s*h\s*o\s*r\s*t?\s*e\s*r\s*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(\s*shorter\s*\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\{[^\}]*\}'), ' ')
        .replaceAll(RegExp(r'^\s*\d+[a-z]?\.\s*', multiLine: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*\d+[a-z]?\s+', multiLine: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*[•·▪◦]+\s*'), ' ')
        .replaceAll(RegExp(r'\s*[—–-]\s*'), ' ')
        .replaceAll(RegExp(r'\n{2,}'), '. ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    result = result
        .replaceAll(RegExp(r'\s+([,;:.!?])'), r'$1')
        .replaceAll(RegExp(r'([,;:.!?])(?=[A-Za-z])'), r'$1 ')
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return result;
  }
}
