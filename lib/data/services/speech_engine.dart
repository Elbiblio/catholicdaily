class SpeechVoice {
  final String name;
  final String locale;
  final bool isNetworkRequired;

  const SpeechVoice({
    required this.name,
    required this.locale,
    this.isNetworkRequired = false,
  });

  String get id => '$name|$locale';

  @override
  bool operator ==(Object other) =>
      other is SpeechVoice &&
      other.name == name &&
      other.locale == locale &&
      other.isNetworkRequired == isNetworkRequired;

  @override
  int get hashCode => Object.hash(name, locale, isNetworkRequired);
}

class SpeechEngineSettings {
  final double rate;
  final String language;
  final SpeechVoice? voice;

  const SpeechEngineSettings({
    this.rate = 0.5,
    this.language = 'en-US',
    this.voice,
  });

  SpeechEngineSettings copyWith({
    double? rate,
    String? language,
    SpeechVoice? voice,
    bool clearVoice = false,
  }) {
    return SpeechEngineSettings(
      rate: rate ?? this.rate,
      language: language ?? this.language,
      voice: clearVoice ? null : voice ?? this.voice,
    );
  }
}

class SpeechEngineCallbacks {
  final void Function(String utteranceId) onStart;
  final void Function(String utteranceId) onCompletion;
  final void Function(String utteranceId, String message) onError;
  final void Function(String utteranceId, int start, int end, String word)
  onProgress;

  const SpeechEngineCallbacks({
    required this.onStart,
    required this.onCompletion,
    required this.onError,
    required this.onProgress,
  });
}

abstract class SpeechEngine {
  bool get supportsNativePause;

  void setCallbacks(SpeechEngineCallbacks callbacks);

  Future<void> initialize();

  Future<List<SpeechVoice>> getVoices();

  Future<void> configure(SpeechEngineSettings settings);

  Future<void> speak(String text, {required String utteranceId});

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}
