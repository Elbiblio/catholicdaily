import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// MIDI playback state
class HymnMidiState {
  final bool isPlaying;
  final bool isPaused;
  final String? currentFile;
  final int? positionMs;

  const HymnMidiState({
    this.isPlaying = false,
    this.isPaused = false,
    this.currentFile,
    this.positionMs,
  });

  bool get hasActiveFile => currentFile != null;

  HymnMidiState copyWith({
    bool? isPlaying,
    bool? isPaused,
    String? currentFile,
    bool clearFile = false,
    int? positionMs,
  }) {
    return HymnMidiState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentFile: clearFile ? null : (currentFile ?? this.currentFile),
      positionMs: positionMs ?? this.positionMs,
    );
  }
}

/// MIDI playback service for hymns using audioplayers
class HymnMidiService {
  static final HymnMidiService instance = HymnMidiService._internal();
  factory HymnMidiService() => instance;

  HymnMidiService._internal() {
    _setupAudioPlayer();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  HymnMidiState _state = const HymnMidiState();
  final StreamController<HymnMidiState> _stateController = StreamController<HymnMidiState>.broadcast();
  StreamSubscription? _positionSubscription;

  /// Current playback state
  HymnMidiState get state => _state;

  /// Stream of state changes
  Stream<HymnMidiState> get stateStream => _stateController.stream;

  /// Check if MIDI playback is available (audioplayers works on all platforms)
  bool get isAvailable => true;

  void _setupAudioPlayer() {
    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      final isPlaying = state == PlayerState.playing;
      _updateState(_state.copyWith(isPlaying: isPlaying));
    });

    // Listen to position changes
    _audioPlayer.onPositionChanged.listen((Duration position) {
      _updateState(_state.copyWith(positionMs: position.inMilliseconds));
    });
  }

  /// Check if MIDI playback is supported on this platform
  Future<bool> isSupported() async {
    return true; // audioplayers supports all platforms
  }

  /// Play a MIDI file from assets
  Future<void> playAsset(String assetPath, {bool repeat = true}) async {
    try {
      // Set release mode based on repeat preference
      await _audioPlayer.setReleaseMode(
        repeat ? ReleaseMode.loop : ReleaseMode.release,
      );

      // Set volume
      await _audioPlayer.setVolume(0.8);

      // Play from assets
      await _audioPlayer.play(AssetSource(assetPath.replaceFirst('assets/', '')));

      _updateState(_state.copyWith(
        isPlaying: true,
        isPaused: false,
        currentFile: assetPath,
        positionMs: 0,
      ));
    } catch (e) {
      debugPrint('Error playing MIDI: $e');
      _updateState(_state.copyWith(isPlaying: false));
      rethrow;
    }
  }

  /// Stop playback and clear active file
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _updateState(_state.copyWith(
        isPlaying: false,
        isPaused: false,
        clearFile: true,
        positionMs: 0,
      ));
    } catch (_) {
      // Ignore stop errors
    }
  }

  /// Pause playback (keeps position for resume)
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _updateState(_state.copyWith(isPlaying: false, isPaused: true));
    } catch (_) {
      // Ignore pause errors
    }
  }

  /// Resume playback from paused position
  Future<void> resume() async {
    try {
      await _audioPlayer.resume();
      _updateState(_state.copyWith(isPlaying: true, isPaused: false));
    } catch (_) {
      // Ignore resume errors
    }
  }

  /// Get current playback position in milliseconds
  Future<int?> getPosition() async {
    try {
      final position = await _audioPlayer.getCurrentPosition();
      return position?.inMilliseconds;
    } catch (_) {
      return null;
    }
  }

  void _updateState(HymnMidiState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    _stateController.close();
  }
}
