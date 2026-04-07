import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// MIDI playback state
class HymnMidiState {
  final bool isPlaying;
  final String? currentFile;
  final int? positionMs;
  final bool isCalibrating;
  final int? detectedBpm;
  final List<DateTime> tapTimestamps;

  const HymnMidiState({
    this.isPlaying = false,
    this.currentFile,
    this.positionMs,
    this.isCalibrating = false,
    this.detectedBpm,
    this.tapTimestamps = const [],
  });

  HymnMidiState copyWith({
    bool? isPlaying,
    String? currentFile,
    int? positionMs,
    bool? isCalibrating,
    int? detectedBpm,
    List<DateTime>? tapTimestamps,
  }) {
    return HymnMidiState(
      isPlaying: isPlaying ?? this.isPlaying,
      currentFile: currentFile ?? this.currentFile,
      positionMs: positionMs ?? this.positionMs,
      isCalibrating: isCalibrating ?? this.isCalibrating,
      detectedBpm: detectedBpm ?? this.detectedBpm,
      tapTimestamps: tapTimestamps ?? this.tapTimestamps,
    );
  }
}

/// MIDI playback service for hymns
class HymnMidiService {
  static const MethodChannel _channel = MethodChannel('catholicdaily/midi');
  
  HymnMidiState _state = const HymnMidiState();
  final StreamController<HymnMidiState> _stateController = StreamController<HymnMidiState>.broadcast();
  Timer? _positionTimer;
  
  /// Current playback state
  HymnMidiState get state => _state;
  
  /// Stream of state changes
  Stream<HymnMidiState> get stateStream => _stateController.stream;

  bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Check if MIDI playback is supported on this platform
  Future<bool> isSupported() async {
    if (!isAvailable) {
      return false;
    }
    try {
      final supported = await _channel.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Play a MIDI file from assets
  Future<void> playAsset(String assetPath, {bool repeat = true}) async {
    if (!isAvailable) {
      throw UnsupportedError(
        'MIDI playback is unavailable on this platform.',
      );
    }
    
    try {
      await _channel.invokeMethod<void>('playAsset', {
        'assetPath': assetPath,
        'repeat': repeat,
      });
      
      _updateState(_state.copyWith(
        isPlaying: true,
        currentFile: assetPath,
        positionMs: 0,
      ));
      
      _startPositionTracking();
    } catch (e) {
      _updateState(_state.copyWith(isPlaying: false));
      rethrow;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    if (!isAvailable) {
      return;
    }
    
    try {
      await _channel.invokeMethod<void>('stop');
      _stopPositionTracking();
      _updateState(_state.copyWith(
        isPlaying: false,
        positionMs: 0,
      ));
    } catch (_) {
      // Ignore stop errors
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (!isAvailable) {
      return;
    }
    
    try {
      await _channel.invokeMethod<void>('pause');
      _stopPositionTracking();
      _updateState(_state.copyWith(isPlaying: false));
    } catch (_) {
      // Ignore pause errors
    }
  }

  /// Resume playback
  Future<void> resume() async {
    if (!isAvailable) {
      return;
    }
    
    try {
      await _channel.invokeMethod<void>('resume');
      _updateState(_state.copyWith(isPlaying: true));
      _startPositionTracking();
    } catch (_) {
      // Ignore resume errors
    }
  }

  /// Get current playback position in milliseconds
  Future<int?> getPosition() async {
    if (!isAvailable) {
      return null;
    }
    
    try {
      return await _channel.invokeMethod<int>('getPosition');
    } catch (_) {
      return null;
    }
  }

  void _updateState(HymnMidiState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _startPositionTracking() {
    _stopPositionTracking();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final position = await getPosition();
      if (position != null) {
        _updateState(_state.copyWith(positionMs: position));
      }
    });
  }

  void _stopPositionTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Start calibration mode for tap-to-tempo detection
  void startCalibration() {
    _updateState(_state.copyWith(
      isCalibrating: true,
      tapTimestamps: [],
      detectedBpm: null,
    ));
  }

  /// Stop calibration mode
  void stopCalibration() {
    _updateState(_state.copyWith(
      isCalibrating: false,
    ));
  }

  /// Record a tap during calibration
  void recordTap() {
    if (!_state.isCalibrating) return;

    final now = DateTime.now();
    final updatedTaps = [..._state.tapTimestamps, now];

    // Keep only last 10 taps for moving average
    if (updatedTaps.length > 10) {
      updatedTaps.removeAt(0);
    }

    // Calculate BPM from taps if we have at least 3
    int? newBpm = _state.detectedBpm;
    if (updatedTaps.length >= 3) {
      newBpm = _calculateBpmFromTaps(updatedTaps);
    }

    _updateState(_state.copyWith(
      tapTimestamps: updatedTaps,
      detectedBpm: newBpm,
    ));
  }

  /// Reset calibration data
  void resetCalibration() {
    _updateState(_state.copyWith(
      tapTimestamps: [],
      detectedBpm: null,
    ));
  }

  /// Calculate BPM from tap timestamps
  int? _calculateBpmFromTaps(List<DateTime> taps) {
    if (taps.length < 2) return null;

    // Calculate average interval between taps
    final intervals = <int>[];
    for (var i = 1; i < taps.length; i++) {
      final interval = taps[i].difference(taps[i - 1]).inMilliseconds;
      intervals.add(interval);
    }

    if (intervals.isEmpty) return null;

    final avgIntervalMs = intervals.reduce((a, b) => a + b) / intervals.length;
    
    // BPM = 60000 / average interval in ms
    final bpm = (60000 / avgIntervalMs).round();
    
    // Clamp to reasonable range (40-200 BPM)
    return bpm.clamp(40, 200);
  }

  /// Get the currently detected BPM from calibration
  int? get detectedBpm => _state.detectedBpm;

  /// Get the number of taps recorded
  int get tapCount => _state.tapTimestamps.length;

  /// Dispose resources
  void dispose() {
    _stopPositionTracking();
    _stateController.close();
  }
}
