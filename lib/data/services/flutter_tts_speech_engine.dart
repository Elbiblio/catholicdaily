import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'speech_engine.dart';

enum SpeechPlatform { android, ios, macos, windows, linux, web }

abstract class FlutterTtsDriver {
  Future<Object?> awaitSpeakCompletion(bool enabled);

  void setStartHandler(void Function() handler);

  void setContinueHandler(void Function() handler);

  void setCancelHandler(void Function() handler);

  void setCompletionHandler(void Function() handler);

  void setErrorHandler(void Function(String message) handler);

  void setProgressHandler(
    void Function(String text, int start, int end, String word) handler,
  );

  Future<Object?> getVoices();

  Future<bool> isLanguageInstalled(String language);

  Future<Object?> setLanguage(String language);

  Future<Object?> setSpeechRate(double rate);

  Future<Object?> setPitch(double pitch);

  Future<Object?> setVoice(Map<String, String> voice);

  Future<Object?> speak(String text);

  Future<Object?> pause();

  Future<Object?> stop();
}

class FlutterTtsSpeechEngine implements SpeechEngine {
  static const int maxChunkCodeUnits = 3500;

  final FlutterTtsDriver _driver;
  final SpeechPlatform _platform;
  SpeechEngineCallbacks? _callbacks;
  Future<void>? _initialization;
  Future<void> _nativeQueue = Future<void>.value();
  bool _handlersInstalled = false;
  bool _disposed = false;
  int _intent = 0;
  _LogicalSession? _activeSession;
  _CancellationFence? _cancelFence;

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
    final existing = _initialization;
    if (existing != null) return existing;
    late final Future<void> attempt;
    attempt = _initializeOnce().catchError((Object error, StackTrace stack) {
      if (identical(_initialization, attempt)) _initialization = null;
      Error.throwWithStackTrace(error, stack);
    });
    _initialization = attempt;
    return attempt;
  }

  Future<void> _initializeOnce() async {
    _installHandlersOnce();
    _requireSuccess(
      await _driver.awaitSpeakCompletion(false),
      'awaitSpeakCompletion',
    );
  }

  void _installHandlersOnce() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;
    _driver.setStartHandler(_handleStart);
    _driver.setContinueHandler(_handleContinue);
    _driver.setCancelHandler(_handleCancel);
    _driver.setCompletionHandler(_handleCompletion);
    _driver.setErrorHandler(_handleError);
    _driver.setProgressHandler(_handleProgress);
  }

  void _handleStart() {
    if (_cancelFence != null) return;
    final session = _activeSession;
    if (!_acceptsChunkCallback(session) || session!.chunkStarted) return;
    session.chunkStarted = true;
    if (!session.logicalStarted) {
      session.logicalStarted = true;
      _callbacks?.onStart(session.utteranceId);
    }
  }

  void _handleContinue() {
    if (_cancelFence != null) return;
    final session = _activeSession;
    if (!_acceptsChunkCallback(session) || !session!.resuming) return;
    session.resuming = false;
    session.paused = false;
    session.chunkStarted = true;
    _callbacks?.onContinue(session.utteranceId);
  }

  void _handleCancel() {
    _acknowledgeCancellation();
  }

  void _acknowledgeCancellation() {
    final fence = _cancelFence;
    if (fence != null &&
        fence.matchesInvalidatedSession &&
        !fence.acknowledged.isCompleted) {
      fence.acknowledged.complete();
    }
  }

  void _handleCompletion() {
    if (_cancelFence != null) {
      _acknowledgeCancellation();
      return;
    }
    final session = _activeSession;
    if (!_acceptsChunkCallback(session) || !session!.chunkStarted) return;
    session.acceptingCallbacks = false;
    session.chunkStarted = false;
    if (session.chunkIndex >= session.chunks.length - 1) {
      session.terminal = true;
      _activeSession = null;
      _callbacks?.onCompletion(session.utteranceId);
      return;
    }
    session.chunkIndex++;
    unawaited(
      _enqueueNative(() async {
        if (!_isActive(session)) return;
        await _speakCurrentChunk(session);
      }).catchError((Object error, StackTrace stack) {
        _terminateSessionWithError(session, error);
      }),
    );
  }

  void _handleError(String message) {
    if (_cancelFence != null) {
      _acknowledgeCancellation();
      return;
    }
    final session = _activeSession;
    if (!_acceptsChunkCallback(session)) return;
    session!.acceptingCallbacks = false;
    session.terminal = true;
    _activeSession = null;
    _callbacks?.onError(session.utteranceId, message);
  }

  void _handleProgress(String text, int start, int end, String word) {
    if (_cancelFence != null) return;
    final session = _activeSession;
    if (!_acceptsChunkCallback(session) || !session!.chunkStarted) return;
    final chunk = session.currentChunk;
    final chunkLength = chunk.text.length;
    final safeStart = start.clamp(0, chunkLength);
    final safeEnd = end.clamp(safeStart, chunkLength);
    _callbacks?.onProgress(
      session.utteranceId,
      chunk.offset + safeStart,
      chunk.offset + safeEnd,
      word,
    );
  }

  bool _acceptsChunkCallback(_LogicalSession? session) =>
      !_disposed &&
      session != null &&
      identical(_activeSession, session) &&
      !session.terminal &&
      session.acceptingCallbacks;

  bool _isActive(_LogicalSession session) =>
      !_disposed &&
      identical(_activeSession, session) &&
      !session.terminal &&
      session.intent == _intent;

  void _terminateSessionWithError(_LogicalSession session, Object error) {
    if (!_isActive(session)) return;
    session.acceptingCallbacks = false;
    session.terminal = true;
    _activeSession = null;
    _callbacks?.onError(session.utteranceId, _errorMessage(error));
  }

  static String _errorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
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
          isNetworkRequired: _networkRequired(item, _platform),
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
      _requireSuccess(await _driver.setLanguage(language), 'setLanguage');
    }
    _requireSuccess(
      await _driver.setSpeechRate(settings.rate.clamp(0.0, 1.0)),
      'setSpeechRate',
    );
    _requireSuccess(await _driver.setPitch(1), 'setPitch');
    final voice = settings.voice;
    if (voice != null) {
      _requireSuccess(
        await _driver.setVoice(<String, String>{
          'name': voice.name,
          'locale': voice.locale,
        }),
        'setVoice',
        allowNull: _platform == SpeechPlatform.web,
      );
    }
  }

  @override
  Future<void> speak(String text, {required String utteranceId}) {
    if (_disposed || text.trim().isEmpty) return Future<void>.value();
    final intent = ++_intent;
    final resumable = supportsNativePause && _activeSession?.paused == true;
    final oldSession = resumable ? null : _invalidateActiveSession();
    return _enqueueNative(() async {
      if (_disposed || intent != _intent) return;
      await initialize();
      if (_disposed || intent != _intent) return;
      if (resumable) {
        final session = _activeSession;
        if (session == null || session.terminal || !session.paused) return;
        session.intent = intent;
        session.utteranceId = utteranceId;
        session.resuming = true;
        session.acceptingCallbacks = true;
        _requireSuccess(
          await _driver.speak(session.currentChunk.text),
          'speak',
          allowNull: _platform == SpeechPlatform.web,
        );
        return;
      }
      if (oldSession != null) await _cancelNativeSession(oldSession);
      if (_disposed || intent != _intent) return;
      final session = _LogicalSession(
        intent: intent,
        utteranceId: utteranceId,
        chunks: _chunkText(text),
      );
      _activeSession = session;
      try {
        await _speakCurrentChunk(session);
      } catch (_) {
        if (identical(_activeSession, session)) _activeSession = null;
        session.terminal = true;
        rethrow;
      }
    });
  }

  Future<void> _speakCurrentChunk(_LogicalSession session) async {
    if (!_isActive(session)) return;
    session.acceptingCallbacks = true;
    session.chunkStarted = false;
    _requireSuccess(
      await _driver.speak(session.currentChunk.text),
      'speak',
      allowNull: _platform == SpeechPlatform.web,
    );
  }

  @override
  Future<void> pause() {
    if (_disposed) return Future<void>.value();
    if (!supportsNativePause) {
      return Future<void>.error(
        StateError('Native pause is not reliable on this platform.'),
      );
    }
    final session = _activeSession;
    return _enqueueNative(() async {
      if (!_isActiveOrPaused(session)) return;
      _requireSuccess(await _driver.pause(), 'pause');
      if (_isActiveOrPaused(session)) session!.paused = true;
    });
  }

  bool _isActiveOrPaused(_LogicalSession? session) =>
      !_disposed &&
      session != null &&
      identical(_activeSession, session) &&
      !session.terminal;

  @override
  Future<void> stop() {
    if (_disposed) return Future<void>.value();
    ++_intent;
    final cancelledSession = _invalidateActiveSession();
    return _enqueueNative(() => _cancelNativeSession(cancelledSession));
  }

  _LogicalSession? _invalidateActiveSession() {
    final session = _activeSession;
    _activeSession = null;
    if (session != null) {
      session.acceptingCallbacks = false;
      session.terminal = true;
    }
    return session;
  }

  Future<void> _cancelNativeSession(
    _LogicalSession? cancelledSession, {
    bool awaitAcknowledgement = true,
  }) async {
    final fence = cancelledSession == null
        ? null
        : _CancellationFence(
            intent: cancelledSession.intent,
            session: cancelledSession,
          );
    _cancelFence = fence;
    try {
      _requireSuccess(await _driver.stop(), 'stop');
      if (fence != null &&
          awaitAcknowledgement &&
          _usesTerminalCancellationCallback &&
          !fence.acknowledged.isCompleted) {
        await fence.acknowledged.future;
      }
    } finally {
      if (identical(_cancelFence, fence)) _cancelFence = null;
    }
  }

  bool get _usesTerminalCancellationCallback =>
      _platform == SpeechPlatform.android ||
      _platform == SpeechPlatform.ios ||
      _platform == SpeechPlatform.macos ||
      _platform == SpeechPlatform.windows ||
      _platform == SpeechPlatform.web;

  @override
  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    _disposed = true;
    ++_intent;
    _invalidateActiveSession();
    _callbacks = null;
    return _enqueueNative(
      () => _cancelNativeSession(null, awaitAcknowledgement: false),
    );
  }

  Future<T> _enqueueNative<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _nativeQueue = _nativeQueue.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static void _requireSuccess(
    Object? result,
    String operation, {
    bool allowNull = false,
  }) {
    final successful = switch (result) {
      null => allowNull,
      true => true,
      final num value => value > 0,
      final String value =>
        value.trim().toLowerCase() == 'true' || value.trim() == '1',
      _ => false,
    };
    if (!successful) throw SpeechEngineException(operation, result);
  }

  static List<_SpeechChunk> _chunkText(String text) {
    final chunks = <_SpeechChunk>[];
    var offset = 0;
    while (offset < text.length) {
      final hardEnd = math.min(offset + maxChunkCodeUnits, text.length);
      var end = hardEnd;
      if (hardEnd < text.length) {
        final candidate = text.substring(offset, hardEnd);
        final minimum = candidate.length ~/ 2;
        var boundary = candidate.lastIndexOf('\n\n');
        if (boundary >= minimum) boundary += 2;
        if (boundary < minimum) {
          final matches = RegExp(
            r'''[.!?][\)\]\}"'’”]*\s+''',
          ).allMatches(candidate);
          boundary = matches.isEmpty ? -1 : matches.last.end;
        }
        if (boundary < minimum) {
          boundary = candidate.lastIndexOf('\n');
          if (boundary >= minimum) boundary++;
        }
        if (boundary < minimum) {
          final whitespace = RegExp(r'\s+').allMatches(candidate);
          boundary = whitespace.isEmpty ? -1 : whitespace.last.end;
        }
        if (boundary > 0) end = offset + boundary;
      }
      if (end < text.length && _isHighSurrogate(text.codeUnitAt(end - 1))) {
        end--;
      }
      if (end <= offset) end = hardEnd;
      chunks.add(_SpeechChunk(text.substring(offset, end), offset));
      offset = end;
    }
    return chunks;
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  static bool _networkRequired(
    Map<dynamic, dynamic> value,
    SpeechPlatform platform,
  ) {
    final raw =
        value['network_required'] ??
        value['networkRequired'] ??
        value['isNetworkConnectionRequired'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw != null) {
      switch (raw.toString().trim().toLowerCase()) {
        case '1':
        case 'true':
          return true;
        case '0':
        case 'false':
          return false;
      }
    }
    final features = value['features'];
    if (features is Iterable) {
      final requiresNetwork = features.any(
        (feature) => feature.toString().toLowerCase().contains('network'),
      );
      if (requiresNetwork) return true;
    }
    return platform == SpeechPlatform.android;
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

class _CancellationFence {
  final int intent;
  final _LogicalSession session;
  final Completer<void> acknowledged = Completer<void>();

  _CancellationFence({required this.intent, required this.session});

  bool get matchesInvalidatedSession =>
      session.terminal && session.intent == intent;
}

class _LogicalSession {
  int intent;
  String utteranceId;
  final List<_SpeechChunk> chunks;
  int chunkIndex = 0;
  bool logicalStarted = false;
  bool chunkStarted = false;
  bool acceptingCallbacks = false;
  bool paused = false;
  bool resuming = false;
  bool terminal = false;

  _LogicalSession({
    required this.intent,
    required this.utteranceId,
    required this.chunks,
  });

  _SpeechChunk get currentChunk => chunks[chunkIndex];
}

class _SpeechChunk {
  final String text;
  final int offset;

  const _SpeechChunk(this.text, this.offset);
}

class _PluginFlutterTtsDriver implements FlutterTtsDriver {
  final FlutterTts _tts;

  _PluginFlutterTtsDriver(this._tts);

  @override
  Future<Object?> awaitSpeakCompletion(bool enabled) =>
      _tts.awaitSpeakCompletion(enabled);

  @override
  void setStartHandler(void Function() handler) =>
      _tts.setStartHandler(handler);

  @override
  void setContinueHandler(void Function() handler) =>
      _tts.setContinueHandler(handler);

  @override
  void setCancelHandler(void Function() handler) =>
      _tts.setCancelHandler(handler);

  @override
  void setCompletionHandler(void Function() handler) =>
      _tts.setCompletionHandler(handler);

  @override
  void setErrorHandler(void Function(String message) handler) {
    _tts.setErrorHandler((message) => handler(message.toString()));
  }

  @override
  void setProgressHandler(
    void Function(String text, int start, int end, String word) handler,
  ) => _tts.setProgressHandler(handler);

  @override
  Future<Object?> getVoices() async => await _tts.getVoices;

  @override
  Future<bool> isLanguageInstalled(String language) async {
    final result = await _tts.isLanguageInstalled(language);
    if (result is bool) return result;
    if (result is num) return result != 0;
    final normalized = result?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  @override
  Future<Object?> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<Object?> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<Object?> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<Object?> setVoice(Map<String, String> voice) => _tts.setVoice(voice);

  @override
  Future<Object?> speak(String text) => _tts.speak(text);

  @override
  Future<Object?> pause() => _tts.pause();

  @override
  Future<Object?> stop() => _tts.stop();
}
