import 'dart:async';

import 'package:catholic_daily/data/services/flutter_tts_speech_engine.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'installs native handlers and completion waiting exactly once',
    () async {
      final driver = FakeFlutterTtsDriver();
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );
      engine.setCallbacks(_callbacks());

      await engine.initialize();
      await engine.initialize();

      expect(driver.awaitCompletionCalls, 1);
      expect(driver.startHandlerRegistrations, 1);
      expect(driver.completionHandlerRegistrations, 1);
      expect(driver.errorHandlerRegistrations, 1);
      expect(driver.progressHandlerRegistrations, 1);
    },
  );

  test(
    'maps voices and orders installed offline voices before network voices',
    () async {
      final driver = FakeFlutterTtsDriver()
        ..rawVoices = <Object?>[
          <String, Object?>{
            'name': 'Cloud English',
            'locale': 'en-US',
            'network_required': true,
          },
          <String, Object?>{
            'name': 'Local English',
            'locale': 'en-GB',
            'network_required': false,
          },
        ];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );

      final voices = await engine.getVoices();

      expect(voices.map((voice) => voice.name), <String>[
        'Local English',
        'Cloud English',
      ]);
      expect(voices.first.isNetworkRequired, isFalse);
      expect(voices.last.isNetworkRequired, isTrue);
    },
  );

  test('applies installed language, rate, and selected voice', () async {
    final driver = FakeFlutterTtsDriver();
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.android,
    );

    await engine.configure(
      const SpeechEngineSettings(
        rate: 0.65,
        language: 'en-NG',
        voice: SpeechVoice(name: 'English NG', locale: 'en-NG'),
      ),
    );

    expect(driver.languages, <String>['en-NG']);
    expect(driver.rates, <double>[0.65]);
    expect(driver.voices, <Map<String, String>>[
      <String, String>{'name': 'English NG', 'locale': 'en-NG'},
    ]);
  });

  test(
    'rejects a language that is not installed without network work',
    () async {
      final driver = FakeFlutterTtsDriver()..languageInstalled = false;
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );

      await expectLater(
        engine.configure(const SpeechEngineSettings(language: 'fr-FR')),
        throwsA(isA<StateError>()),
      );
      expect(driver.languages, isEmpty);
    },
  );

  test(
    'does not call Android-only installed-language API on Apple platforms',
    () async {
      final driver = FakeFlutterTtsDriver()..languageInstalled = false;
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.ios,
      );

      await engine.configure(const SpeechEngineSettings(language: 'en-US'));

      expect(driver.languageInstallChecks, 0);
      expect(driver.languages, <String>['en-US']);
    },
  );

  test(
    'awaits speech completion and forwards callbacks with active id',
    () async {
      final driver = FakeFlutterTtsDriver();
      final events = <String>[];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );
      engine.setCallbacks(
        SpeechEngineCallbacks(
          onStart: (id) => events.add('start:$id'),
          onCompletion: (id) => events.add('complete:$id'),
          onError: (id, message) => events.add('error:$id:$message'),
          onProgress: (id, start, end, word) =>
              events.add('progress:$id:$start:$end:$word'),
        ),
      );
      await engine.initialize();

      final pending = engine.speak('The word.', utteranceId: 'u1');
      driver.emitStart();
      driver.emitProgress('The word.', 4, 8, 'word');
      expect(events, <String>['start:u1', 'progress:u1:4:8:word']);

      driver.completeSpeech();
      driver.emitCompletion();
      await pending;

      expect(events.last, 'complete:u1');
    },
  );

  test(
    'forwards active errors and safely ignores callbacks after dispose',
    () async {
      final driver = FakeFlutterTtsDriver();
      final events = <String>[];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );
      engine.setCallbacks(
        _callbacks(onError: (id, message) => events.add('$id:$message')),
      );
      await engine.initialize();

      unawaited(engine.speak('Text', utteranceId: 'u2'));
      driver.emitError('failure');
      expect(events, <String>['u2:failure']);

      await engine.dispose();
      driver.emitError('late');
      expect(events, <String>['u2:failure']);
    },
  );

  test(
    'native pause is reported only on platforms where plugin supports it',
    () {
      final driver = FakeFlutterTtsDriver();

      expect(
        FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.android,
        ).supportsNativePause,
        isFalse,
      );
      expect(
        FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.windows,
        ).supportsNativePause,
        isFalse,
      );
      expect(
        FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.ios,
        ).supportsNativePause,
        isTrue,
      );
      expect(
        FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.web,
        ).supportsNativePause,
        isTrue,
      );
    },
  );
}

SpeechEngineCallbacks _callbacks({
  void Function(String id, String message)? onError,
}) {
  return SpeechEngineCallbacks(
    onStart: (_) {},
    onCompletion: (_) {},
    onError: onError ?? (_, __) {},
    onProgress: (_, __, ___, ____) {},
  );
}

class FakeFlutterTtsDriver implements FlutterTtsDriver {
  int awaitCompletionCalls = 0;
  int startHandlerRegistrations = 0;
  int completionHandlerRegistrations = 0;
  int errorHandlerRegistrations = 0;
  int progressHandlerRegistrations = 0;
  bool languageInstalled = true;
  int languageInstallChecks = 0;
  List<Object?> rawVoices = <Object?>[];
  final List<String> languages = <String>[];
  final List<double> rates = <double>[];
  final List<Map<String, String>> voices = <Map<String, String>>[];
  Completer<void>? speechCompleter;
  void Function()? startHandler;
  void Function()? completionHandler;
  void Function(String message)? errorHandler;
  void Function(String text, int start, int end, String word)? progressHandler;

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    awaitCompletionCalls++;
  }

  @override
  void setStartHandler(void Function() handler) {
    startHandlerRegistrations++;
    startHandler = handler;
  }

  @override
  void setCompletionHandler(void Function() handler) {
    completionHandlerRegistrations++;
    completionHandler = handler;
  }

  @override
  void setErrorHandler(void Function(String message) handler) {
    errorHandlerRegistrations++;
    errorHandler = handler;
  }

  @override
  void setProgressHandler(
    void Function(String text, int start, int end, String word) handler,
  ) {
    progressHandlerRegistrations++;
    progressHandler = handler;
  }

  @override
  Future<Object?> getVoices() async => rawVoices;

  @override
  Future<bool> isLanguageInstalled(String language) async {
    languageInstallChecks++;
    return languageInstalled;
  }

  @override
  Future<void> setLanguage(String language) async {
    languages.add(language);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    voices.add(voice);
  }

  @override
  Future<void> speak(String text) {
    speechCompleter = Completer<void>();
    return speechCompleter!.future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    if (speechCompleter?.isCompleted == false) speechCompleter!.complete();
  }

  void completeSpeech() {
    if (speechCompleter?.isCompleted == false) speechCompleter!.complete();
  }

  void emitStart() => startHandler?.call();
  void emitCompletion() => completionHandler?.call();
  void emitError(String message) => errorHandler?.call(message);
  void emitProgress(String text, int start, int end, String word) =>
      progressHandler?.call(text, start, end, word);
}
