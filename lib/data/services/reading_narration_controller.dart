import 'dart:async';

import 'package:flutter/foundation.dart';

import 'reading_narration_queue_builder.dart';
import 'speech_engine.dart';

enum NarrationStatus {
  idle,
  loading,
  playing,
  paused,
  stopped,
  completed,
  unavailable,
  error,
}

enum NarrationPlaybackMode { currentOnly, readAll }

class NarrationContext {
  final String dateKey;
  final String regionCode;
  final String bibleEditionId;
  final String psalmEditionId;
  final String alternativeKey;

  const NarrationContext({
    required this.dateKey,
    required this.regionCode,
    required this.bibleEditionId,
    required this.psalmEditionId,
    required this.alternativeKey,
  });

  @override
  bool operator ==(Object other) =>
      other is NarrationContext &&
      other.dateKey == dateKey &&
      other.regionCode == regionCode &&
      other.bibleEditionId == bibleEditionId &&
      other.psalmEditionId == psalmEditionId &&
      other.alternativeKey == alternativeKey;

  @override
  int get hashCode => Object.hash(
    dateKey,
    regionCode,
    bibleEditionId,
    psalmEditionId,
    alternativeKey,
  );
}

class ReadingNarrationState {
  final NarrationStatus status;
  final List<ReadingNarrationQueueItem> queue;
  final int currentIndex;
  final double progress;
  final int progressStart;
  final int progressEnd;
  final String? currentWord;
  final String? errorMessage;
  final NarrationPlaybackMode mode;
  final bool supportsNativePause;

  const ReadingNarrationState({
    this.status = NarrationStatus.idle,
    this.queue = const <ReadingNarrationQueueItem>[],
    this.currentIndex = 0,
    this.progress = 0,
    this.progressStart = 0,
    this.progressEnd = 0,
    this.currentWord,
    this.errorMessage,
    this.mode = NarrationPlaybackMode.currentOnly,
    this.supportsNativePause = false,
  });

  ReadingNarrationQueueItem? get currentItem =>
      currentIndex >= 0 && currentIndex < queue.length
      ? queue[currentIndex]
      : null;

  ReadingNarrationState copyWith({
    NarrationStatus? status,
    List<ReadingNarrationQueueItem>? queue,
    int? currentIndex,
    double? progress,
    int? progressStart,
    int? progressEnd,
    String? currentWord,
    String? errorMessage,
    bool clearCurrentWord = false,
    bool clearError = false,
    NarrationPlaybackMode? mode,
    bool? supportsNativePause,
  }) {
    return ReadingNarrationState(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      progress: progress ?? this.progress,
      progressStart: progressStart ?? this.progressStart,
      progressEnd: progressEnd ?? this.progressEnd,
      currentWord: clearCurrentWord ? null : currentWord ?? this.currentWord,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      mode: mode ?? this.mode,
      supportsNativePause: supportsNativePause ?? this.supportsNativePause,
    );
  }
}

class ReadingNarrationController extends ChangeNotifier {
  static const noVoiceMessage =
      'Install an offline text-to-speech voice in system settings.';
  static const noReadingMessage = 'No reading is available to narrate.';

  final SpeechEngine _engine;
  SpeechEngineSettings _settings;
  ReadingNarrationState _state;
  NarrationContext? _context;
  int _generation = 0;
  int _playbackCommandToken = 0;
  int _settingsCommandToken = 0;
  int _utteranceSequence = 0;
  int _spokenOffset = 0;
  int _resumeOffset = 0;
  String? _activeUtteranceId;
  bool _disposed = false;

  ReadingNarrationController({
    required SpeechEngine engine,
    SpeechEngineSettings settings = const SpeechEngineSettings(),
  }) : _engine = engine,
       _settings = settings,
       _state = ReadingNarrationState(
         supportsNativePause: engine.supportsNativePause,
       ) {
    _engine.setCallbacks(
      SpeechEngineCallbacks(
        onStart: _onStart,
        onContinue: _onStart,
        onCompletion: _onCompletion,
        onError: _onError,
        onProgress: _onProgress,
      ),
    );
  }

  ReadingNarrationState get state => _state;

  Future<void> play(
    List<ReadingNarrationQueueItem> queue, {
    NarrationPlaybackMode mode = NarrationPlaybackMode.currentOnly,
    NarrationContext? context,
  }) async {
    if (_disposed) return;
    final command = ++_playbackCommandToken;
    final generation = ++_generation;
    _activeUtteranceId = null;
    _spokenOffset = 0;
    _resumeOffset = 0;
    if (_isActive(_state.status)) {
      try {
        await _engine.stop();
        if (!_isCurrentCommand(command, generation)) return;
      } catch (error) {
        if (_isCurrentCommand(command, generation)) _failOperation(error);
        return;
      }
    }
    if (queue.isEmpty) {
      _emit(
        ReadingNarrationState(
          status: NarrationStatus.unavailable,
          errorMessage: noReadingMessage,
          mode: mode,
          supportsNativePause: _engine.supportsNativePause,
        ),
      );
      return;
    }

    _context = context;
    _emit(
      ReadingNarrationState(
        status: NarrationStatus.loading,
        queue: List<ReadingNarrationQueueItem>.unmodifiable(queue),
        mode: mode,
        supportsNativePause: _engine.supportsNativePause,
      ),
    );

    try {
      await _engine.initialize();
      if (!_isCurrentCommand(command, generation)) return;
      final voices = await _engine.getVoices();
      if (!_isCurrentCommand(command, generation)) return;
      if (voices.isEmpty) {
        _emit(
          _state.copyWith(
            status: NarrationStatus.unavailable,
            errorMessage: noVoiceMessage,
          ),
        );
        return;
      }

      final selectedVoice = _selectVoice(voices, _settings);
      if (selectedVoice == null) {
        _emit(
          _state.copyWith(
            status: NarrationStatus.unavailable,
            errorMessage: noVoiceMessage,
          ),
        );
        return;
      }
      await _engine.configure(_settings.copyWith(voice: selectedVoice));
      if (!_isCurrentCommand(command, generation)) return;
      await _speakCurrent(command: command, generation: generation);
    } catch (error) {
      if (_isCurrentCommand(command, generation)) {
        _failOperation(error);
      }
    }
  }

  Future<void> updateSettings(SpeechEngineSettings settings) async {
    if (_disposed) return;
    final command = ++_settingsCommandToken;
    try {
      await _engine.configure(settings);
      if (_disposed || command != _settingsCommandToken) return;
      _settings = settings;
    } catch (error) {
      if (!_disposed && command == _settingsCommandToken) {
        _failOperation(error);
      }
    }
  }

  Future<void> pause() async {
    if (_disposed || _state.status != NarrationStatus.playing) return;
    final command = ++_playbackCommandToken;
    final generation = _generation;
    _resumeOffset = _state.progressStart.clamp(0, _currentText.length);
    final pausedId = _activeUtteranceId;
    _activeUtteranceId = null;
    try {
      if (_engine.supportsNativePause) {
        await _engine.pause();
      } else {
        await _engine.stop();
      }
      if (!_isCurrentCommand(command, generation)) return;
    } catch (error) {
      if (_engine.supportsNativePause) {
        try {
          await _engine.stop();
        } catch (_) {
          // The original pause error is the actionable failure.
        }
      }
      if (_isCurrentCommand(command, generation)) _failOperation(error);
      return;
    }
    if (_disposed || pausedId == null) return;
    _emit(_state.copyWith(status: NarrationStatus.paused, clearError: true));
  }

  Future<void> resume() async {
    if (_disposed || _state.status != NarrationStatus.paused) return;
    final command = ++_playbackCommandToken;
    final generation = _generation;
    await _speakCurrent(
      offset: _engine.supportsNativePause ? 0 : _resumeOffset,
      command: command,
      generation: generation,
    );
  }

  Future<void> stop({bool clearQueue = false}) async {
    if (_disposed) return;
    final command = ++_playbackCommandToken;
    final generation = ++_generation;
    _activeUtteranceId = null;
    if (clearQueue) {
      _emit(
        _state.copyWith(
          status: NarrationStatus.stopped,
          queue: const <ReadingNarrationQueueItem>[],
          currentIndex: 0,
          progress: 0,
          progressStart: 0,
          progressEnd: 0,
          clearCurrentWord: true,
          clearError: true,
        ),
      );
    }
    try {
      await _engine.stop();
    } catch (error) {
      if (_isCurrentCommand(command, generation)) _failOperation(error);
      return;
    }
    if (!_isCurrentCommand(command, generation)) return;
    if (clearQueue) return;
    _emit(
      _state.copyWith(
        status: NarrationStatus.stopped,
        queue: _state.queue,
        currentIndex: _state.currentIndex,
        progress: 0,
        progressStart: 0,
        progressEnd: 0,
        clearCurrentWord: true,
        clearError: true,
      ),
    );
  }

  Future<void> next() async {
    if (_disposed || _state.queue.isEmpty) return;
    final command = ++_playbackCommandToken;
    final target = _state.currentIndex + 1;
    if (target >= _state.queue.length) {
      await stop();
      return;
    }
    await _moveTo(target, command: command);
  }

  Future<void> previous() async {
    if (_disposed || _state.queue.isEmpty) return;
    final command = ++_playbackCommandToken;
    final target = (_state.currentIndex - 1).clamp(0, _state.queue.length - 1);
    await _moveTo(target, command: command);
  }

  Future<void> onAppPaused() async {
    if (_state.status == NarrationStatus.playing) await pause();
  }

  Future<void> onAppDetached() => stop();

  Future<void> invalidateForContext(NarrationContext context) async {
    if (_context == null || _context == context) {
      _context = context;
      return;
    }
    _context = context;
    await stop(clearQueue: true);
  }

  Future<void> onReadingExperienceExit({
    required bool deliberateNavigation,
  }) async {
    final preserve =
        _state.mode == NarrationPlaybackMode.readAll && deliberateNavigation;
    if (!preserve) await stop();
  }

  Future<void> _moveTo(int target, {required int command}) async {
    final generation = ++_generation;
    _activeUtteranceId = null;
    try {
      await _engine.stop();
    } catch (error) {
      if (_isCurrentCommand(command, generation)) _failOperation(error);
      return;
    }
    if (!_isCurrentCommand(command, generation)) return;
    _spokenOffset = 0;
    _resumeOffset = 0;
    _emit(
      _state.copyWith(
        status: NarrationStatus.loading,
        currentIndex: target,
        progress: 0,
        progressStart: 0,
        progressEnd: 0,
        clearCurrentWord: true,
        clearError: true,
      ),
    );
    await _speakCurrent(command: command, generation: generation);
  }

  String get _currentText => _state.currentItem?.narration.text ?? '';

  Future<void> _speakCurrent({
    int offset = 0,
    required int command,
    required int generation,
  }) async {
    if (_disposed || _currentText.isEmpty) return;
    _spokenOffset = offset.clamp(0, _currentText.length);
    final text = _currentText.substring(_spokenOffset);
    final id = 'narration-${_generation}-${++_utteranceSequence}';
    _activeUtteranceId = id;
    try {
      await _engine.speak(text, utteranceId: id);
    } catch (error) {
      if (_isCurrentCommand(command, generation) && _accepts(id)) {
        _onError(id, _messageFor(error));
      }
    }
  }

  void _onStart(String utteranceId) {
    if (!_accepts(utteranceId)) return;
    _emit(_state.copyWith(status: NarrationStatus.playing, clearError: true));
  }

  void _onProgress(String utteranceId, int start, int end, String word) {
    if (!_accepts(utteranceId)) return;
    final total = _currentText.length;
    final absoluteStart = (_spokenOffset + start).clamp(0, total);
    final absoluteEnd = (_spokenOffset + end).clamp(0, total);
    _resumeOffset = absoluteStart;
    _emit(
      _state.copyWith(
        status: NarrationStatus.playing,
        progressStart: absoluteStart,
        progressEnd: absoluteEnd,
        progress: total == 0 ? 0 : absoluteEnd / total,
        currentWord: word,
        clearError: true,
      ),
    );
  }

  void _onCompletion(String utteranceId) {
    if (!_accepts(utteranceId)) return;
    _activeUtteranceId = null;
    unawaited(_completeCurrent());
  }

  Future<void> _completeCurrent() async {
    if (_state.currentIndex < _state.queue.length - 1) {
      final nextIndex = _state.currentIndex + 1;
      _spokenOffset = 0;
      _resumeOffset = 0;
      _emit(
        _state.copyWith(
          status: NarrationStatus.loading,
          currentIndex: nextIndex,
          progress: 0,
          progressStart: 0,
          progressEnd: 0,
          clearCurrentWord: true,
          clearError: true,
        ),
      );
      final command = ++_playbackCommandToken;
      await _speakCurrent(command: command, generation: _generation);
      return;
    }
    _emit(
      _state.copyWith(
        status: NarrationStatus.completed,
        progress: 1,
        progressStart: _currentText.length,
        progressEnd: _currentText.length,
        clearCurrentWord: true,
        clearError: true,
      ),
    );
  }

  void _onError(String utteranceId, String message) {
    if (!_accepts(utteranceId)) return;
    ++_playbackCommandToken;
    ++_generation;
    _activeUtteranceId = null;
    _emit(
      _state.copyWith(
        status: NarrationStatus.error,
        errorMessage: message,
        clearCurrentWord: true,
      ),
    );
  }

  bool _accepts(String utteranceId) =>
      !_disposed && utteranceId == _activeUtteranceId;

  bool _isCurrentGeneration(int generation) =>
      !_disposed && generation == _generation;

  bool _isCurrentCommand(int command, int generation) =>
      !_disposed &&
      command == _playbackCommandToken &&
      _isCurrentGeneration(generation);

  void _failOperation(Object error) {
    if (_disposed) return;
    ++_playbackCommandToken;
    ++_generation;
    _activeUtteranceId = null;
    _emit(
      _state.copyWith(
        status: NarrationStatus.error,
        errorMessage: _messageFor(error),
        clearCurrentWord: true,
      ),
    );
  }

  void _emit(ReadingNarrationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  static bool _isActive(NarrationStatus status) =>
      status == NarrationStatus.loading ||
      status == NarrationStatus.playing ||
      status == NarrationStatus.paused;

  static SpeechVoice? _selectVoice(
    List<SpeechVoice> voices,
    SpeechEngineSettings settings,
  ) {
    final language = settings.language.trim().toLowerCase();
    final baseLanguage = language.split(RegExp('[-_]')).first;
    bool matchesLanguage(SpeechVoice voice) {
      final locale = voice.locale.trim().toLowerCase();
      return locale == language ||
          locale.split(RegExp('[-_]')).first == baseLanguage;
    }

    final selected = settings.voice;
    if (selected != null &&
        !selected.isNetworkRequired &&
        voices.contains(selected) &&
        matchesLanguage(selected)) {
      return selected;
    }
    final offline = voices.where(
      (voice) => !voice.isNetworkRequired && matchesLanguage(voice),
    );
    for (final voice in offline) {
      if (voice.locale.trim().toLowerCase() == language) return voice;
    }
    return offline.isEmpty ? null : offline.first;
  }

  static String _messageFor(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_playbackCommandToken;
    ++_settingsCommandToken;
    ++_generation;
    _activeUtteranceId = null;
    try {
      unawaited(_engine.dispose().catchError((Object _) {}));
    } catch (_) {
      // Disposal is best-effort and must never escape the widget lifecycle.
    }
    super.dispose();
  }
}
