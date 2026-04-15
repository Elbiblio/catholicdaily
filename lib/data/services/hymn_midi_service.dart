import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// MIDI playback state
class HymnMidiState {
  final bool isPlaying;
  final bool isPaused;
  final String? currentFile;
  final int? positionMs;
  final String? errorMessage;

  const HymnMidiState({
    this.isPlaying = false,
    this.isPaused = false,
    this.currentFile,
    this.positionMs,
    this.errorMessage,
  });

  bool get hasActiveFile => currentFile != null;

  HymnMidiState copyWith({
    bool? isPlaying,
    bool? isPaused,
    String? currentFile,
    bool clearFile = false,
    int? positionMs,
    String? errorMessage,
  }) {
    return HymnMidiState(
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentFile: clearFile ? null : (currentFile ?? this.currentFile),
      positionMs: positionMs ?? this.positionMs,
      errorMessage: errorMessage,
    );
  }
}

/// MIDI playback service for hymns
/// Note: MIDI playback is not supported on Windows with audioplayers
/// This service provides a stub implementation for Windows
class HymnMidiService {
  static final HymnMidiService instance = HymnMidiService._internal();
  factory HymnMidiService() => instance;

  HymnMidiService._internal() {
    _checkPlatformSupport();
  }

  HymnMidiState _state = const HymnMidiState();
  final StreamController<HymnMidiState> _stateController = StreamController<HymnMidiState>.broadcast();
  bool _isPlatformSupported = false;

  /// Current playback state
  HymnMidiState get state => _state;

  /// Stream of state changes
  Stream<HymnMidiState> get stateStream => _stateController.stream;

  /// Check if MIDI playback is available
  bool get isAvailable => _isPlatformSupported;

  void _checkPlatformSupport() {
    // MIDI playback is not supported on Windows with current implementation
    // audioplayers doesn't support MIDI format
    if (Platform.isWindows) {
      _isPlatformSupported = false;
      debugPrint('MIDI playback is not supported on Windows');
    } else {
      // For other platforms, we could potentially use a different library
      _isPlatformSupported = false; // Currently disabled for all platforms
    }
  }

  /// Check if MIDI playback is supported on this platform
  Future<bool> isSupported() async {
    return _isPlatformSupported;
  }

  /// Play a MIDI file from assets
  Future<void> playAsset(String assetPath, {bool repeat = true}) async {
    if (!_isPlatformSupported) {
      _updateState(_state.copyWith(
        isPlaying: false,
        errorMessage: 'MIDI playback is not supported on this platform',
      ));
      throw Exception('MIDI playback is not supported on this platform');
    }
    
    // Stub implementation for platforms that would support MIDI
    _updateState(_state.copyWith(
      isPlaying: true,
      isPaused: false,
      currentFile: assetPath,
      positionMs: 0,
      errorMessage: null,
    ));
  }

  /// Stop playback and clear active file
  Future<void> stop() async {
    _updateState(_state.copyWith(
      isPlaying: false,
      isPaused: false,
      clearFile: true,
      positionMs: 0,
      errorMessage: null,
    ));
  }

  /// Pause playback (keeps position for resume)
  Future<void> pause() async {
    if (!_isPlatformSupported) return;
    _updateState(_state.copyWith(isPlaying: false, isPaused: true));
  }

  /// Resume playback from paused position
  Future<void> resume() async {
    if (!_isPlatformSupported) return;
    _updateState(_state.copyWith(isPlaying: true, isPaused: false));
  }

  /// Get current playback position in milliseconds
  Future<int?> getPosition() async {
    return _state.positionMs;
  }

  void _updateState(HymnMidiState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }
}
