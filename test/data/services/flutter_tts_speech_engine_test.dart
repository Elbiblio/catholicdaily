import 'dart:async';

import 'package:catholic_daily/data/services/flutter_tts_speech_engine.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'installs native handlers and callback-authoritative mode exactly once',
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
      expect(driver.continueHandlerRegistrations, 1);
      expect(driver.cancelHandlerRegistrations, 1);
      expect(driver.completionHandlerRegistrations, 1);
      expect(driver.errorHandlerRegistrations, 1);
      expect(driver.progressHandlerRegistrations, 1);
      expect(driver.awaitCompletionValues, <bool>[false]);
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

  test('parses real Android network-required voice shapes fail-safe', () async {
    final driver = FakeFlutterTtsDriver()
      ..rawVoices = <Object?>[
        for (final entry in <(String, Object?)>[
          ('bool true', true),
          ('bool false', false),
          ('int one', 1),
          ('int zero', 0),
          ('string one', '1'),
          ('string zero', '0'),
          ('string true', 'true'),
          ('string false', 'false'),
          ('unknown', 'sometimes'),
        ])
          <String, Object?>{
            'name': entry.$1,
            'locale': 'en-US',
            'network_required': entry.$2,
          },
        <String, Object?>{'name': 'absent', 'locale': 'en-US'},
      ];
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.android,
    );

    final voices = <String, SpeechVoice>{
      for (final voice in await engine.getVoices()) voice.name: voice,
    };

    for (final name in <String>[
      'bool true',
      'int one',
      'string one',
      'string true',
      'unknown',
      'absent',
    ]) {
      expect(voices[name]?.isNetworkRequired, isTrue, reason: name);
    }
    for (final name in <String>[
      'bool false',
      'int zero',
      'string zero',
      'string false',
    ]) {
      expect(voices[name]?.isNetworkRequired, isFalse, reason: name);
    }
  });

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
    expect(driver.pitches, <double>[1]);
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
    'uses callbacks as authoritative and forwards callbacks with active id',
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
          onContinue: (id) => events.add('continue:$id'),
          onCompletion: (id) => events.add('complete:$id'),
          onError: (id, message) => events.add('error:$id:$message'),
          onProgress: (id, start, end, word) =>
              events.add('progress:$id:$start:$end:$word'),
        ),
      );
      await engine.initialize();

      await engine.speak('The word.', utteranceId: 'u1');
      driver.emitStart();
      driver.emitProgress('The word.', 4, 8, 'word');
      expect(events, <String>['start:u1', 'progress:u1:4:8:word']);

      driver.emitCompletion();

      expect(events.last, 'complete:u1');
    },
  );

  test('chunks a long Genesis narration into one logical utterance', () async {
    final driver = FakeFlutterTtsDriver();
    final events = <String>[];
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.android,
    );
    engine.setCallbacks(
      SpeechEngineCallbacks(
        onStart: (id) => events.add('start:$id'),
        onContinue: (id) => events.add('continue:$id'),
        onCompletion: (id) => events.add('complete:$id'),
        onError: (id, message) => events.add('error:$id:$message'),
        onProgress: (id, start, end, word) =>
            events.add('progress:$id:$start:$end:$word'),
      ),
    );
    final genesis = List<String>.filled(
      180,
      'And God saw that it was good. ',
    ).join();
    expect(genesis.length, greaterThan(4000));

    await engine.speak(genesis, utteranceId: 'genesis');
    driver.emitStart();
    driver.emitProgress(driver.spokenTexts.first, 4, 7, 'God');
    driver.emitCompletion();
    await Future<void>.delayed(Duration.zero);
    final secondChunkOffset = driver.spokenTexts.first.length;
    driver.emitStart();
    driver.emitProgress(driver.spokenTexts.last, 0, 3, 'And');
    while (events.where((event) => event == 'complete:genesis').isEmpty) {
      driver.emitCompletion();
      await Future<void>.delayed(Duration.zero);
      if (events.where((event) => event == 'complete:genesis').isEmpty) {
        driver.emitStart();
      }
    }

    expect(driver.spokenTexts.length, greaterThan(1));
    expect(
      driver.spokenTexts.every(
        (chunk) => chunk.length <= FlutterTtsSpeechEngine.maxChunkCodeUnits,
      ),
      isTrue,
    );
    expect(events.where((event) => event == 'start:genesis'), hasLength(1));
    expect(events.where((event) => event == 'complete:genesis'), hasLength(1));
    expect(
      events,
      contains(
        'progress:genesis:$secondChunkOffset:${secondChunkOffset + 3}:And',
      ),
    );
  });

  for (final throws in <bool>[false, true]) {
    test(
      'reports a later chunk ${throws ? 'throw' : 'non-success result'} once',
      () async {
        final driver = FakeFlutterTtsDriver()
          ..speakResults.addAll(<Object?>[true, throws ? _throwSpeak : 0]);
        final errors = <String>[];
        final engine = FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.android,
        );
        engine.setCallbacks(
          _callbacks(onError: (id, message) => errors.add('$id:$message')),
        );
        final text = List<String>.filled(
          180,
          'And God saw that it was good. ',
        ).join();

        await engine.speak(text, utteranceId: 'long');
        driver.emitStart();
        driver.emitCompletion();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(errors, hasLength(1));
        expect(errors.single, startsWith('long:'));
        driver.emitStart();
        driver.emitCompletion();
        expect(errors, hasLength(1));
      },
    );
  }

  test(
    'rejects non-success dynamic plugin results deterministically',
    () async {
      for (final failure in <Object?>[0, false, -1, 'failed']) {
        final languageDriver = FakeFlutterTtsDriver()
          ..setLanguageResult = failure;
        await expectLater(
          FlutterTtsSpeechEngine(
            driver: languageDriver,
            platform: SpeechPlatform.ios,
          ).configure(const SpeechEngineSettings()),
          throwsA(isA<SpeechEngineException>()),
          reason: 'setLanguage $failure',
        );
      }

      for (final operation in <String>[
        'voice',
        'rate',
        'pitch',
        'speak',
        'pause',
        'stop',
        'await',
      ]) {
        final driver = FakeFlutterTtsDriver();
        switch (operation) {
          case 'voice':
            driver.setVoiceResult = false;
            break;
          case 'rate':
            driver.setSpeechRateResult = 0;
            break;
          case 'pitch':
            driver.setPitchResult = 'failed';
            break;
          case 'speak':
            driver.speakResult = 0;
            break;
          case 'pause':
            driver.pauseResult = false;
            break;
          case 'stop':
            driver.stopResult = -1;
            break;
          case 'await':
            driver.awaitCompletionResult = 0;
            break;
        }
        final engine = FlutterTtsSpeechEngine(
          driver: driver,
          platform: SpeechPlatform.ios,
        );
        Future<void> action;
        switch (operation) {
          case 'voice':
            action = engine.configure(
              const SpeechEngineSettings(
                voice: SpeechVoice(name: 'Local', locale: 'en-US'),
              ),
            );
            break;
          case 'rate':
          case 'pitch':
            action = engine.configure(const SpeechEngineSettings());
            break;
          case 'speak':
            action = engine.speak('Text', utteranceId: 'u');
            break;
          case 'pause':
            await engine.speak('Text', utteranceId: 'pause-u');
            driver.emitStart();
            action = engine.pause();
            break;
          case 'stop':
            action = engine.stop();
            break;
          case 'await':
            action = engine.initialize();
            break;
          default:
            throw StateError(operation);
        }
        await expectLater(
          action,
          throwsA(isA<SpeechEngineException>()),
          reason: operation,
        );
      }
    },
  );

  test(
    'rate-only configuration does not touch language pitch or voice',
    () async {
      final driver = FakeFlutterTtsDriver()..setPitchResult = 0;
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );

      await engine.configureRate(
        const SpeechEngineSettings(
          rate: 0.75,
          language: 'en-US',
          voice: SpeechVoice(name: 'Offline English', locale: 'en-US'),
        ),
      );

      expect(driver.rates, <double>[0.75]);
      expect(driver.languages, isEmpty);
      expect(driver.pitches, isEmpty);
      expect(driver.voices, isEmpty);
    },
  );

  test('accepts platform success result shapes', () async {
    for (final success in <Object?>[1, true, '1', 'true']) {
      final driver = FakeFlutterTtsDriver()
        ..awaitCompletionResult = success
        ..setLanguageResult = success
        ..setSpeechRateResult = success
        ..setPitchResult = success
        ..setVoiceResult = success
        ..speakResult = success
        ..pauseResult = success
        ..stopResult = success;
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.ios,
      );

      await engine.initialize();
      await engine.configure(
        const SpeechEngineSettings(
          voice: SpeechVoice(name: 'Local', locale: 'en-US'),
        ),
      );
      await engine.speak('Text', utteranceId: 'u');
      await engine.pause();
      driver.emitCancel();
      await engine.stop();
    }
  });

  test('accepts the web plugin null speak success shape', () async {
    final driver = FakeFlutterTtsDriver()..speakResult = null;
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.web,
    );

    await engine.speak('Web text.', utteranceId: 'web');

    expect(driver.spokenTexts, <String>['Web text.']);
  });

  test('accepts the web plugin null setVoice success shape', () async {
    final driver = FakeFlutterTtsDriver()..setVoiceResult = null;
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.web,
    );

    await engine.configure(
      const SpeechEngineSettings(
        voice: SpeechVoice(name: 'Web English', locale: 'en-US'),
      ),
    );

    expect(driver.voices, hasLength(1));
  });

  test('failed initialization can be retried', () async {
    final driver = FakeFlutterTtsDriver()
      ..awaitCompletionResults.addAll(<Object?>[false, true]);
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.android,
    );

    await expectLater(
      engine.initialize(),
      throwsA(isA<SpeechEngineException>()),
    );
    await engine.initialize();

    expect(driver.awaitCompletionCalls, 2);
    expect(driver.startHandlerRegistrations, 1);
  });

  test('stop fences delayed callbacks before a new logical speak', () async {
    final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
    final events = <String>[];
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.android,
    );
    engine.setCallbacks(
      SpeechEngineCallbacks(
        onStart: (id) => events.add('start:$id'),
        onContinue: (id) => events.add('continue:$id'),
        onCompletion: (id) => events.add('complete:$id'),
        onError: (id, message) => events.add('error:$id:$message'),
        onProgress: (id, start, end, word) =>
            events.add('progress:$id:$start:$end:$word'),
      ),
    );
    await engine.speak('Old text.', utteranceId: 'old');
    driver.emitStart();

    final stop = engine.stop();
    var stopped = false;
    unawaited(stop.then((_) => stopped = true));
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    driver.emitCompletion();
    driver.emitProgress('Old text.', 0, 3, 'Old');
    driver.emitCancel();
    await stop;

    await engine.speak('New text.', utteranceId: 'new');
    driver.emitCompletion();
    driver.emitProgress('Old text.', 0, 3, 'Old');
    driver.emitStart();
    driver.emitProgress('New text.', 0, 3, 'New');
    driver.emitCompletion();

    expect(events, <String>[
      'start:old',
      'start:new',
      'progress:new:0:3:New',
      'complete:new',
    ]);
  });

  test(
    'new speak remains fenced beyond 100ms until cancel acknowledgement',
    () async {
      final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
      final events = <String>[];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );
      engine.setCallbacks(
        SpeechEngineCallbacks(
          onStart: (id) => events.add('start:$id'),
          onContinue: (id) => events.add('continue:$id'),
          onCompletion: (id) => events.add('complete:$id'),
          onError: (id, message) => events.add('error:$id:$message'),
          onProgress: (id, start, end, word) =>
              events.add('progress:$id:$word'),
        ),
      );
      await engine.speak('Old text.', utteranceId: 'old');
      driver.emitStart();

      final replacement = engine.speak('New text.', utteranceId: 'new');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      driver.emitCompletion();
      driver.emitStart();
      driver.emitProgress('Old text.', 0, 3, 'Old');

      expect(driver.spokenTexts, <String>['Old text.']);
      expect(events, <String>['start:old']);

      driver.emitCancel();
      await replacement;
      expect(driver.spokenTexts, <String>['Old text.', 'New text.']);
      driver.emitStart();
      driver.emitCompletion();
      expect(events, <String>['start:old', 'start:new', 'complete:new']);
    },
  );

  test('forwards native continue with the resumed utterance id', () async {
    final driver = FakeFlutterTtsDriver();
    final events = <String>[];
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.ios,
    );
    engine.setCallbacks(
      _callbacks(onContinue: (id) => events.add('continue:$id')),
    );
    await engine.initialize();

    await engine.speak('Original text.', utteranceId: 'original');
    driver.emitStart();
    await engine.pause();
    await engine.speak('Original text.', utteranceId: 'resumed');
    driver.emitContinue();

    expect(events, <String>['continue:resumed']);
    await engine.dispose();
  });

  test(
    'active web stop waits for its asynchronous terminal acknowledgement',
    () async {
      final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.web,
      );
      await engine.speak('Web text.', utteranceId: 'web');
      driver.emitStart();

      final stop = engine.stop();
      var stopped = false;
      unawaited(stop.then((_) => stopped = true));
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);

      driver.emitError('canceled');
      await stop.timeout(const Duration(milliseconds: 300));

      expect(driver.spokenTexts, <String>['Web text.']);
    },
  );

  test('web replacement cancels globally before the old onStart', () async {
    final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
    var globalCancels = 0;
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.web,
      cancelWebSpeech: () => globalCancels++,
    );
    await engine.speak('Queued old text.', utteranceId: 'old');

    final replacement = engine.speak('Replacement text.', utteranceId: 'new');
    await Future<void>.delayed(Duration.zero);
    expect(globalCancels, 1);
    expect(driver.spokenTexts, <String>['Queued old text.']);

    driver.emitStart();
    driver.emitError('canceled');
    await replacement.timeout(const Duration(milliseconds: 300));
    expect(driver.spokenTexts, <String>[
      'Queued old text.',
      'Replacement text.',
    ]);
  });

  test(
    'completion racing with stop acknowledges cancellation without leaking',
    () async {
      final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
      final events = <String>[];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.android,
      );
      engine.setCallbacks(
        _callbacks(onError: (id, message) => events.add('error:$id')),
      );
      await engine.speak('Nearly done.', utteranceId: 'old');
      driver.emitStart();

      final replacement = engine.speak('New text.', utteranceId: 'new');
      await Future<void>.delayed(Duration.zero);
      driver.emitCompletion();
      await replacement.timeout(const Duration(milliseconds: 300));

      expect(driver.spokenTexts, <String>['Nearly done.', 'New text.']);
      expect(events, isEmpty);
    },
  );

  test(
    'delayed web cancellation error cannot target its replacement',
    () async {
      final driver = FakeFlutterTtsDriver()..autoCancelOnStop = false;
      final errors = <String>[];
      final engine = FlutterTtsSpeechEngine(
        driver: driver,
        platform: SpeechPlatform.web,
      );
      engine.setCallbacks(
        _callbacks(onError: (id, message) => errors.add('$id:$message')),
      );
      await engine.speak('Old web text.', utteranceId: 'old');
      driver.emitStart();

      final replacement = engine.speak('New web text.', utteranceId: 'new');
      await Future<void>.delayed(Duration.zero);
      driver.emitStart();
      driver.emitError('canceled old utterance');
      expect(errors, isEmpty);
      await replacement.timeout(const Duration(milliseconds: 300));

      driver.emitStart();
      driver.emitError('new utterance failed');
      expect(errors, <String>['new:new utterance failed']);
    },
  );

  test('genuine web error before start reaches the active utterance', () async {
    final driver = FakeFlutterTtsDriver();
    final errors = <String>[];
    final engine = FlutterTtsSpeechEngine(
      driver: driver,
      platform: SpeechPlatform.web,
    );
    engine.setCallbacks(
      _callbacks(onError: (id, message) => errors.add('$id:$message')),
    );
    await engine.speak('Unsupported text.', utteranceId: 'current');

    driver.emitError('synthesis failed');

    expect(errors, <String>['current:synthesis failed']);
  });

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

      await engine.speak('Text', utteranceId: 'u2');
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
  void Function(String id)? onContinue,
  void Function(String id, String message)? onError,
}) {
  return SpeechEngineCallbacks(
    onStart: (_) {},
    onContinue: onContinue ?? (_) {},
    onCompletion: (_) {},
    onError: onError ?? (_, __) {},
    onProgress: (_, __, ___, ____) {},
  );
}

class FakeFlutterTtsDriver implements FlutterTtsDriver {
  int awaitCompletionCalls = 0;
  int startHandlerRegistrations = 0;
  int continueHandlerRegistrations = 0;
  int cancelHandlerRegistrations = 0;
  int completionHandlerRegistrations = 0;
  int errorHandlerRegistrations = 0;
  int progressHandlerRegistrations = 0;
  bool languageInstalled = true;
  int languageInstallChecks = 0;
  List<Object?> rawVoices = <Object?>[];
  final List<String> languages = <String>[];
  final List<double> rates = <double>[];
  final List<double> pitches = <double>[];
  final List<Map<String, String>> voices = <Map<String, String>>[];
  final List<String> spokenTexts = <String>[];
  final List<bool> awaitCompletionValues = <bool>[];
  final List<Object?> awaitCompletionResults = <Object?>[];
  Object? awaitCompletionResult = true;
  Object? setLanguageResult = true;
  Object? setSpeechRateResult = true;
  Object? setPitchResult = true;
  Object? setVoiceResult = true;
  Object? speakResult = true;
  final List<Object?> speakResults = <Object?>[];
  Object? pauseResult = true;
  Object? stopResult = true;
  bool autoCancelOnStop = true;
  void Function()? startHandler;
  void Function()? continueHandler;
  void Function()? cancelHandler;
  void Function()? completionHandler;
  void Function(String message)? errorHandler;
  void Function(String text, int start, int end, String word)? progressHandler;

  @override
  Future<Object?> awaitSpeakCompletion(bool enabled) async {
    awaitCompletionCalls++;
    awaitCompletionValues.add(enabled);
    if (awaitCompletionResults.isNotEmpty) {
      return awaitCompletionResults.removeAt(0);
    }
    return awaitCompletionResult;
  }

  @override
  void setStartHandler(void Function() handler) {
    startHandlerRegistrations++;
    startHandler = handler;
  }

  @override
  void setContinueHandler(void Function() handler) {
    continueHandlerRegistrations++;
    continueHandler = handler;
  }

  @override
  void setCancelHandler(void Function() handler) {
    cancelHandlerRegistrations++;
    cancelHandler = handler;
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
  Future<Object?> setLanguage(String language) async {
    languages.add(language);
    return setLanguageResult;
  }

  @override
  Future<Object?> setSpeechRate(double rate) async {
    rates.add(rate);
    return setSpeechRateResult;
  }

  @override
  Future<Object?> setPitch(double pitch) async {
    pitches.add(pitch);
    return setPitchResult;
  }

  @override
  Future<Object?> setVoice(Map<String, String> voice) async {
    voices.add(voice);
    return setVoiceResult;
  }

  @override
  Future<Object?> speak(String text) async {
    spokenTexts.add(text);
    if (speakResults.isNotEmpty) {
      final result = speakResults.removeAt(0);
      if (identical(result, _throwSpeak))
        throw StateError('later chunk failed');
      return result;
    }
    return speakResult;
  }

  @override
  Future<Object?> pause() async => pauseResult;

  @override
  Future<Object?> stop() async {
    if (autoCancelOnStop) emitCancel();
    return stopResult;
  }

  void emitStart() => startHandler?.call();
  void emitContinue() => continueHandler?.call();
  void emitCancel() => cancelHandler?.call();
  void emitCompletion() => completionHandler?.call();
  void emitError(String message) => errorHandler?.call(message);
  void emitProgress(String text, int start, int end, String word) =>
      progressHandler?.call(text, start, end, word);
}

const Object _throwSpeak = Object();
