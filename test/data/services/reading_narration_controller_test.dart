import 'dart:async';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/data/services/reading_narration_queue_builder.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ReadingNarrationQueueItem item(String id, String body) {
    final reading = DailyReading(
      reading: id,
      position: 'Reading',
      date: DateTime(2026, 8, 29),
    );
    return ReadingNarrationQueueItem(
      id: id,
      slotKey: id,
      reading: reading,
      narration: ReadingNarration(
        segments: <ReadingNarrationSegment>[
          ReadingNarrationSegment(kind: NarrationSegmentKind.body, text: body),
        ],
      ),
    );
  }

  late FakeSpeechEngine engine;
  late ReadingNarrationController controller;
  late List<ReadingNarrationQueueItem> queue;

  setUp(() {
    engine = FakeSpeechEngine();
    controller = ReadingNarrationController(engine: engine);
    queue = <ReadingNarrationQueueItem>[
      item('first', 'First reading text.'),
      item('second', 'Second reading text.'),
    ];
  });

  tearDown(() {
    controller.dispose();
  });

  test('starts idle and configures engine callbacks exactly once', () async {
    expect(controller.state.status, NarrationStatus.idle);
    expect(engine.callbackRegistrations, 1);

    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    await controller.stop();
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);

    expect(engine.callbackRegistrations, 1);
  });

  test(
    'moves loading to playing after engine initialization and start',
    () async {
      final initialization = Completer<void>();
      engine.initialization = initialization.future;

      final play = controller.play(queue);
      expect(controller.state.status, NarrationStatus.loading);

      initialization.complete();
      await play;

      expect(controller.state.status, NarrationStatus.playing);
      expect(controller.state.currentIndex, 0);
      expect(engine.spokenTexts.single, 'First reading text.');
    },
  );

  test('tracks word progress for the active utterance', () async {
    await controller.play(queue);
    final id = engine.lastUtteranceId!;

    engine.emitProgress(id, start: 6, end: 13, word: 'reading');

    expect(controller.state.progressStart, 6);
    expect(controller.state.progressEnd, 13);
    expect(controller.state.progress, closeTo(13 / 19, 0.001));
  });

  test('completion advances the queue then ends completed', () async {
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    final firstId = engine.lastUtteranceId!;

    engine.emitCompletion(firstId);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.currentIndex, 1);
    expect(controller.state.status, NarrationStatus.playing);
    final secondId = engine.lastUtteranceId!;

    engine.emitCompletion(secondId);
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.status, NarrationStatus.completed);
    expect(controller.state.progress, 1);
  });

  test(
    'rejects progress, completion, and errors from stale generations',
    () async {
      await controller.play(queue);
      final staleId = engine.lastUtteranceId!;
      await controller.play(<ReadingNarrationQueueItem>[queue.last]);
      final activeId = engine.lastUtteranceId!;

      engine.emitProgress(staleId, start: 0, end: 5, word: 'stale');
      engine.emitCompletion(staleId);
      engine.emitError(staleId, 'stale error');

      expect(engine.lastUtteranceId, activeId);
      expect(controller.state.status, NarrationStatus.playing);
      expect(controller.state.progress, 0);
      expect(controller.state.errorMessage, isNull);
    },
  );

  test(
    'pause and resume restart from progress when native pause is unsafe',
    () async {
      engine.nativePauseSupported = false;
      await controller.play(queue);
      final firstId = engine.lastUtteranceId!;
      engine.emitProgress(firstId, start: 6, end: 13, word: 'reading');

      await controller.pause();

      expect(controller.state.status, NarrationStatus.paused);
      expect(engine.stopCalls, 1);
      expect(engine.pauseCalls, 0);

      await controller.resume();

      expect(controller.state.status, NarrationStatus.playing);
      expect(engine.spokenTexts.last, 'reading text.');
      expect(engine.lastUtteranceId, isNot(firstId));
      engine.emitProgress(
        engine.lastUtteranceId!,
        start: 0,
        end: 7,
        word: 'reading',
      );
      expect(controller.state.progressStart, 6);
      expect(controller.state.progressEnd, 13);
    },
  );

  test(
    'uses native pause where supported and still resumes deliberately',
    () async {
      engine.nativePauseSupported = true;
      await controller.play(queue);
      final firstId = engine.lastUtteranceId!;
      engine.emitProgress(firstId, start: 6, end: 13, word: 'reading');

      await controller.pause();
      expect(engine.pauseCalls, 1);
      expect(controller.state.status, NarrationStatus.paused);

      await controller.resume();
      expect(engine.spokenTexts, hasLength(2));
      expect(engine.spokenTexts.last, 'First reading text.');
      expect(controller.state.status, NarrationStatus.playing);
      expect(engine.lastUtteranceId, isNot(firstId));

      engine.emitProgress(
        engine.lastUtteranceId!,
        start: 14,
        end: 18,
        word: 'text',
      );
      expect(controller.state.progressStart, 14);
      expect(controller.state.progressEnd, 18);
    },
  );

  test('stop, next, and previous update playback predictably', () async {
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    await controller.next();
    expect(controller.state.currentIndex, 1);
    expect(engine.spokenTexts.last, 'Second reading text.');

    await controller.previous();
    expect(controller.state.currentIndex, 0);
    expect(engine.spokenTexts.last, 'First reading text.');

    await controller.stop();
    expect(controller.state.status, NarrationStatus.stopped);
    expect(controller.state.progress, 0);
    expect(controller.state.queue, hasLength(2));
  });

  test('backgrounding pauses and detaching stops', () async {
    await controller.play(queue);

    await controller.onAppPaused();
    expect(controller.state.status, NarrationStatus.paused);

    await controller.onAppDetached();
    expect(controller.state.status, NarrationStatus.stopped);
  });

  test('active engine errors are exposed without throwing', () async {
    await controller.play(queue);

    engine.emitError(engine.lastUtteranceId!, 'voice failed');

    expect(controller.state.status, NarrationStatus.error);
    expect(controller.state.errorMessage, 'voice failed');
  });

  test(
    'pre-play stop failure becomes error and rejects old callbacks',
    () async {
      await controller.play(queue);
      final staleId = engine.lastUtteranceId!;
      engine.stopError = StateError('pre-play stop failed');

      await expectLater(
        controller.play(<ReadingNarrationQueueItem>[queue.last]),
        completes,
      );

      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.errorMessage, contains('pre-play stop failed'));
      engine.emitCompletion(staleId);
      expect(controller.state.status, NarrationStatus.error);
    },
  );

  test('pause and lifecycle pause failures do not escape callers', () async {
    await controller.play(queue);
    engine.pauseError = StateError('pause failed');
    engine.nativePauseSupported = true;

    await expectLater(controller.onAppPaused(), completes);

    expect(controller.state.status, NarrationStatus.error);
    expect(controller.state.errorMessage, contains('pause failed'));
  });

  test(
    'stop and lifecycle detach failures become deterministic errors',
    () async {
      await controller.play(queue);
      engine.stopError = StateError('stop failed');

      await expectLater(controller.onAppDetached(), completes);

      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.errorMessage, contains('stop failed'));
    },
  );

  test('next and previous stop failures do not move the queue', () async {
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    engine.stopError = StateError('navigation stop failed');

    await expectLater(controller.next(), completes);
    expect(controller.state.currentIndex, 0);
    expect(controller.state.status, NarrationStatus.error);

    engine.stopError = null;
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    await controller.next();
    engine.stopError = StateError('previous stop failed');

    await expectLater(controller.previous(), completes);
    expect(controller.state.currentIndex, 1);
    expect(controller.state.status, NarrationStatus.error);
  });

  test(
    'resume speak and settings failures become errors without throwing',
    () async {
      await controller.play(queue);
      await controller.pause();
      engine.speakError = StateError('resume failed');

      await expectLater(controller.resume(), completes);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.errorMessage, contains('resume failed'));

      engine.speakError = null;
      engine.configureError = StateError('settings failed');
      await expectLater(
        controller.updateSettings(const SpeechEngineSettings(rate: 0.7)),
        completes,
      );
      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.errorMessage, contains('settings failed'));
    },
  );

  test(
    'rejected settings preserve active playback and callback tracking',
    () async {
      await controller.play(queue);
      final utterance = engine.lastUtteranceId!;
      engine.configureError = StateError('settings failed');

      await expectLater(
        controller.updateSettings(const SpeechEngineSettings(rate: 0.7)),
        completes,
      );

      expect(controller.state.status, NarrationStatus.playing);
      expect(controller.state.errorMessage, contains('settings failed'));
      engine.emitProgress(utterance, start: 3, end: 7, word: 'word');
      expect(controller.state.progressStart, 3);
      engine.emitCompletion(utterance);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, NarrationStatus.playing);
      expect(controller.state.currentIndex, 1);
    },
  );

  test(
    'no installed voices produces an actionable unavailable state',
    () async {
      engine.voices = const <SpeechVoice>[];

      await controller.play(queue);

      expect(controller.state.status, NarrationStatus.unavailable);
      expect(
        controller.state.errorMessage,
        'Install an offline text-to-speech voice in system settings.',
      );
      expect(engine.spokenTexts, isEmpty);
    },
  );

  test('does not silently select a network-required voice', () async {
    engine.voices = const <SpeechVoice>[
      SpeechVoice(
        name: 'Cloud English',
        locale: 'en-US',
        isNetworkRequired: true,
      ),
    ];

    await controller.play(queue);

    expect(controller.state.status, NarrationStatus.unavailable);
    expect(
      controller.state.errorMessage,
      ReadingNarrationController.noVoiceMessage,
    );
    expect(engine.spokenTexts, isEmpty);
  });

  test('does not fall back to an unrelated offline language', () async {
    engine.voices = const <SpeechVoice>[
      SpeechVoice(name: 'Français local', locale: 'fr-FR'),
    ];

    await controller.play(queue);

    expect(controller.state.status, NarrationStatus.unavailable);
    expect(engine.spokenTexts, isEmpty);
  });

  test(
    'prefers exact locale then permits a base-language offline voice',
    () async {
      engine.voices = const <SpeechVoice>[
        SpeechVoice(name: 'English UK', locale: 'en-GB'),
        SpeechVoice(name: 'English Nigeria', locale: 'en-NG'),
      ];
      controller.dispose();
      controller = ReadingNarrationController(
        engine: engine,
        settings: const SpeechEngineSettings(language: 'en-NG'),
      );

      await controller.play(queue);
      expect(engine.configuredSettings.last.voice?.name, 'English Nigeria');

      engine.voices = const <SpeechVoice>[
        SpeechVoice(name: 'English UK', locale: 'en-GB'),
      ];
      await controller.play(queue);
      expect(engine.configuredSettings.last.voice?.name, 'English UK');
    },
  );

  test('a stop supersedes a play waiting for its pre-play stop', () async {
    await controller.play(queue);
    final spokenCount = engine.spokenTexts.length;
    final gate = Completer<void>();
    engine.stopGate = gate;
    final observedItems = <String?>[];
    controller.addListener(
      () => observedItems.add(controller.state.currentItem?.reading.reading),
    );

    final replacement = controller.play(<ReadingNarrationQueueItem>[
      queue.last,
    ]);
    final stop = controller.stop();
    gate.complete();
    await Future.wait<void>(<Future<void>>[replacement, stop]);

    expect(controller.state.status, NarrationStatus.stopped);
    expect(engine.spokenTexts, hasLength(spokenCount));
    expect(observedItems, isNot(contains('second')));
  });

  test('a stop supersedes next while its native stop is pending', () async {
    await controller.play(queue, mode: NarrationPlaybackMode.readAll);
    final spokenCount = engine.spokenTexts.length;
    final gate = Completer<void>();
    engine.stopGate = gate;

    final next = controller.next();
    final stop = controller.stop();
    gate.complete();
    await Future.wait<void>(<Future<void>>[next, stop]);

    expect(controller.state.status, NarrationStatus.stopped);
    expect(controller.state.currentIndex, 0);
    expect(engine.spokenTexts, hasLength(spokenCount));
  });

  test('a stop supersedes a delayed resume callback', () async {
    await controller.play(queue);
    await controller.pause();
    final gate = Completer<void>();
    engine.speakGate = gate;

    final resume = controller.resume();
    final stop = controller.stop();
    gate.complete();
    await Future.wait<void>(<Future<void>>[resume, stop]);

    expect(controller.state.status, NarrationStatus.stopped);
  });

  test('empty queues are unavailable rather than sent to the engine', () async {
    await controller.play(const <ReadingNarrationQueueItem>[]);

    expect(controller.state.status, NarrationStatus.unavailable);
    expect(engine.spokenTexts, isEmpty);
  });

  test(
    'edition, region, date, and alternative context changes invalidate queue',
    () async {
      const firstContext = NarrationContext(
        dateKey: '2026-08-29',
        regionCode: 'NG',
        bibleEditionId: 'rsvce',
        psalmEditionId: 'territory',
        alternativeKey: 'primary',
      );
      await controller.play(queue, context: firstContext);

      await controller.invalidateForContext(
        const NarrationContext(
          dateKey: '2026-08-29',
          regionCode: 'NG',
          bibleEditionId: 'nabre',
          psalmEditionId: 'territory',
          alternativeKey: 'primary',
        ),
      );

      expect(controller.state.status, NarrationStatus.stopped);
      expect(controller.state.queue, isEmpty);
    },
  );

  test(
    'context invalidation clears stale queue even when engine stop fails',
    () async {
      const firstContext = NarrationContext(
        dateKey: '2026-08-29',
        regionCode: 'NG',
        bibleEditionId: 'rsvce',
        psalmEditionId: 'territory',
        alternativeKey: 'primary',
      );
      await controller.play(
        queue,
        mode: NarrationPlaybackMode.readAll,
        context: firstContext,
      );
      final staleId = engine.lastUtteranceId!;
      final spokenCount = engine.spokenTexts.length;
      engine.emitProgress(staleId, start: 6, end: 13, word: 'reading');
      engine.stopError = StateError('context stop failed');

      await expectLater(
        controller.invalidateForContext(
          const NarrationContext(
            dateKey: '2026-08-30',
            regionCode: 'NG',
            bibleEditionId: 'nabre',
            psalmEditionId: 'grail',
            alternativeKey: 'alternate',
          ),
        ),
        completes,
      );

      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.errorMessage, contains('context stop failed'));
      expect(controller.state.queue, isEmpty);
      expect(controller.state.currentItem, isNull);
      expect(controller.state.currentIndex, 0);
      expect(controller.state.progress, 0);
      expect(controller.state.progressStart, 0);
      expect(controller.state.progressEnd, 0);
      expect(controller.state.currentWord, isNull);

      engine.emitProgress(staleId, start: 0, end: 5, word: 'stale');
      engine.emitCompletion(staleId);
      engine.emitError(staleId, 'stale error');
      await controller.next();
      await controller.previous();

      expect(controller.state.status, NarrationStatus.error);
      expect(controller.state.queue, isEmpty);
      expect(engine.spokenTexts, hasLength(spokenCount));
    },
  );

  test('same context does not interrupt playback', () async {
    const context = NarrationContext(
      dateKey: '2026-08-29',
      regionCode: 'NG',
      bibleEditionId: 'rsvce',
      psalmEditionId: 'territory',
      alternativeKey: 'primary',
    );
    await controller.play(queue, context: context);
    final stopCalls = engine.stopCalls;

    await controller.invalidateForContext(context);

    expect(controller.state.status, NarrationStatus.playing);
    expect(engine.stopCalls, stopCalls);
  });

  test(
    'route exit stops current-only but preserves deliberate read-all navigation',
    () async {
      await controller.play(queue, mode: NarrationPlaybackMode.currentOnly);
      await controller.onReadingExperienceExit(deliberateNavigation: true);
      expect(controller.state.status, NarrationStatus.stopped);

      await controller.play(queue, mode: NarrationPlaybackMode.readAll);
      await controller.onReadingExperienceExit(deliberateNavigation: true);
      expect(controller.state.status, NarrationStatus.playing);

      await controller.onReadingExperienceExit(deliberateNavigation: false);
      expect(controller.state.status, NarrationStatus.stopped);
    },
  );

  test('dispose stops speech and disconnects callbacks', () async {
    await controller.play(queue);
    controller.dispose();

    expect(engine.disposeCalls, 1);
    engine.emitCompletion(engine.lastUtteranceId!);
  });

  test('dispose absorbs asynchronous engine disposal failures', () async {
    final failingEngine = FakeSpeechEngine()
      ..disposeError = StateError('dispose failed');
    final disposable = ReadingNarrationController(engine: failingEngine);

    disposable.dispose();
    await Future<void>.delayed(Duration.zero);
  });
}

class FakeSpeechEngine implements SpeechEngine {
  SpeechEngineCallbacks? callbacks;
  Future<void> initialization = Future<void>.value();
  List<SpeechVoice> voices = const <SpeechVoice>[
    SpeechVoice(name: 'Offline English', locale: 'en-US'),
  ];
  bool nativePauseSupported = false;
  int callbackRegistrations = 0;
  int stopCalls = 0;
  int pauseCalls = 0;
  int disposeCalls = 0;
  int utteranceCounter = 0;
  final List<String> spokenTexts = <String>[];
  String? lastUtteranceId;
  Object? stopError;
  Object? pauseError;
  Object? speakError;
  Object? configureError;
  Object? disposeError;
  bool nativePaused = false;
  Completer<void>? stopGate;
  Completer<void>? speakGate;
  final List<SpeechEngineSettings> configuredSettings =
      <SpeechEngineSettings>[];

  @override
  bool get supportsNativePause => nativePauseSupported;

  @override
  void setCallbacks(SpeechEngineCallbacks callbacks) {
    this.callbacks = callbacks;
    callbackRegistrations++;
  }

  @override
  Future<void> initialize() => initialization;

  @override
  Future<List<SpeechVoice>> getVoices() async => voices;

  @override
  Future<void> configure(SpeechEngineSettings settings) async {
    if (configureError != null) throw configureError!;
    configuredSettings.add(settings);
  }

  @override
  Future<void> speak(String text, {required String utteranceId}) async {
    if (speakError != null) throw speakError!;
    final pendingSpeak = speakGate;
    if (pendingSpeak != null) await pendingSpeak.future;
    spokenTexts.add(text);
    lastUtteranceId = utteranceId;
    if (nativePaused) {
      nativePaused = false;
      callbacks?.onContinue(utteranceId);
    } else {
      callbacks?.onStart(utteranceId);
    }
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (pauseError != null) throw pauseError!;
    nativePaused = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    if (stopError != null) throw stopError!;
    final pendingStop = stopGate;
    if (pendingStop != null) await pendingStop.future;
    nativePaused = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    callbacks = null;
    if (disposeError != null) throw disposeError!;
  }

  void emitProgress(
    String utteranceId, {
    required int start,
    required int end,
    required String word,
  }) {
    callbacks?.onProgress(utteranceId, start, end, word);
  }

  void emitCompletion(String utteranceId) {
    callbacks?.onCompletion(utteranceId);
  }

  void emitError(String utteranceId, String message) {
    callbacks?.onError(utteranceId, message);
  }
}
