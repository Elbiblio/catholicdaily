import 'dart:async';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/reading_session.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/data/services/reading_narration_queue_builder.dart';
import 'package:catholic_daily/data/services/narration_preferences.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:catholic_daily/ui/widgets/narration_mini_player.dart';
import 'package:catholic_daily/ui/widgets/reading_narration_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'app host appears after start and can stop, replay, and dismiss',
    (tester) async {
      final engine = _FakeSpeechEngine();
      final narration = ReadingNarrationSession(
        controller: ReadingNarrationController(engine: engine),
        queueBuilder: const ReadingNarrationQueueBuilder(
          composer: ReadingNarrationComposer(),
        ),
      );
      final reading = DailyReading(
        reading: 'Jn 1:1',
        position: 'Gospel',
        date: DateTime(2026, 8, 29),
      );
      final queue = narration.queueBuilder.buildCurrent(
        ReadingSession(
          readings: <DailyReading>[reading],
          readingTexts: const <String, String>{
            'Jn 1:1': '1 In the beginning was the Word.',
          },
          currentIndex: 0,
        ),
      );
      const context = NarrationContext(
        dateKey: '2026-08-29',
        regionCode: 'NG',
        bibleEditionId: 'rsvce',
        psalmEditionId: 'territory_lectionary',
        alternativeKey: 'primary',
      );

      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            builder: (context, child) => ReadingNarrationHost(child: child!),
            home: Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  narration.toggle(
                    queue,
                    mode: NarrationPlaybackMode.currentOnly,
                    context: context,
                  ),
                ),
                child: const Text('Start narration'),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(NarrationMiniPlayer.playerKey), findsNothing);

      await tester.tap(find.text('Start narration'));
      await tester.pumpAndSettle();
      expect(find.byKey(NarrationMiniPlayer.playerKey), findsOneWidget);
      expect(engine.spokenTexts, hasLength(1));

      await tester.tap(find.byTooltip('Stop reading'));
      await tester.pumpAndSettle();
      expect(narration.state.status, NarrationStatus.stopped);
      await tester.tap(find.byTooltip('Restart from position'));
      await tester.pumpAndSettle();
      expect(narration.state.status, NarrationStatus.playing);
      expect(engine.spokenTexts, hasLength(2));

      await tester.tap(find.byTooltip('Dismiss player'));
      await tester.pump();
      expect(find.byKey(NarrationMiniPlayer.playerKey), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets('unavailable voices are explained without showing the player', (
    tester,
  ) async {
    final engine = _FakeSpeechEngine(voices: const <SpeechVoice>[]);
    final narration = ReadingNarrationSession(
      controller: ReadingNarrationController(engine: engine),
      queueBuilder: const ReadingNarrationQueueBuilder(
        composer: ReadingNarrationComposer(),
      ),
    );
    final reading = DailyReading(
      reading: 'Jn 1:1',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
    );
    final queue = narration.queueBuilder.buildCurrent(
      ReadingSession(
        readings: <DailyReading>[reading],
        readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
        currentIndex: 0,
      ),
    );

    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          builder: (context, child) => ReadingNarrationHost(child: child!),
          home: Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                narration.toggle(
                  queue,
                  mode: NarrationPlaybackMode.currentOnly,
                  context: const NarrationContext(
                    dateKey: '2026-08-29',
                    regionCode: 'NG',
                    bibleEditionId: 'rsvce',
                    psalmEditionId: 'territory_lectionary',
                    alternativeKey: 'primary',
                  ),
                ),
              ),
              child: const Text('Start narration'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Start narration'));
    await tester.pumpAndSettle();

    expect(
      find.text(ReadingNarrationController.noVoiceMessage),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(ReadingNarrationController.noVoiceMessage),
      findsWidgets,
    );
    expect(find.byKey(NarrationMiniPlayer.playerKey), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets('hosted player follows live title progress and queue controls', (
    tester,
  ) async {
    final engine = _FakeSpeechEngine();
    final narration = ReadingNarrationSession(
      controller: ReadingNarrationController(engine: engine),
      queueBuilder: const ReadingNarrationQueueBuilder(
        composer: ReadingNarrationComposer(),
      ),
    );
    final readings = <DailyReading>[
      DailyReading(
        reading: 'Gen 1:1',
        position: 'First Reading',
        date: DateTime(2026, 8, 29),
      ),
      DailyReading(
        reading: 'Jn 1:1',
        position: 'Gospel',
        date: DateTime(2026, 8, 29),
      ),
    ];
    final queue = narration.queueBuilder.buildReadAll(
      ReadingSession(
        readings: readings,
        readingTexts: const <String, String>{
          'Gen 1:1': 'In the beginning God created heaven and earth.',
          'Jn 1:1': 'In the beginning was the Word.',
        },
        currentIndex: 0,
      ),
    );

    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          builder: (context, child) => ReadingNarrationHost(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await narration.playReadAll(
      queue,
      context: const NarrationContext(
        dateKey: '2026-08-29',
        regionCode: 'NG',
        bibleEditionId: 'rsvce',
        psalmEditionId: 'territory_lectionary',
        alternativeKey: 'primary',
      ),
    );
    await tester.pump();

    expect(find.text('First Reading'), findsOneWidget);
    var previous = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
    );
    expect(previous.onPressed, isNull);
    expect(find.byTooltip('Next reading'), findsOneWidget);

    engine.emitProgress(4, 18, 'beginning');
    await tester.pump();
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, greaterThan(0));

    engine.completeCurrent();
    await tester.pumpAndSettle();
    expect(find.text('Gospel'), findsOneWidget);
    previous = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
    );
    expect(previous.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets('failed speed persistence is caught and explained', (
    tester,
  ) async {
    final engine = _FakeSpeechEngine();
    final narration = ReadingNarrationSession(
      controller: ReadingNarrationController(engine: engine),
      queueBuilder: const ReadingNarrationQueueBuilder(
        composer: ReadingNarrationComposer(),
      ),
      preferences: _ThrowingNarrationPreferences(),
    );
    final reading = DailyReading(
      reading: 'Jn 1:1',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
    );
    final queue = narration.queueBuilder.buildCurrent(
      ReadingSession(
        readings: <DailyReading>[reading],
        readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
        currentIndex: 0,
      ),
    );
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          builder: (context, child) => ReadingNarrationHost(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await narration.toggle(
      queue,
      mode: NarrationPlaybackMode.currentOnly,
      context: const NarrationContext(
        dateKey: '2026-08-29',
        regionCode: 'NG',
        bibleEditionId: 'rsvce',
        psalmEditionId: 'territory_lectionary',
        alternativeKey: 'primary',
      ),
    );
    await tester.pump();

    await tester.tap(find.text('0.5×'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Unable to change speech speed.'), findsOneWidget);
    expect(narration.rate, 0.5);

    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets(
    'fallback stop state announces restart instead of a native pause',
    (tester) async {
      final engine = _FakeSpeechEngine();
      final narration = ReadingNarrationSession(
        controller: ReadingNarrationController(engine: engine),
        queueBuilder: const ReadingNarrationQueueBuilder(
          composer: ReadingNarrationComposer(),
        ),
      );
      final queue = narration.queueBuilder.buildCurrent(
        ReadingSession(
          readings: <DailyReading>[
            DailyReading(
              reading: 'Jn 1:1',
              position: 'Gospel',
              date: DateTime(2026, 8, 29),
            ),
          ],
          readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
          currentIndex: 0,
        ),
      );
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            builder: (context, child) => ReadingNarrationHost(child: child!),
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await narration.toggle(
        queue,
        mode: NarrationPlaybackMode.currentOnly,
        context: const NarrationContext(
          dateKey: '2026-08-29',
          regionCode: 'NG',
          bibleEditionId: 'rsvce',
          psalmEditionId: 'territory_lectionary',
          alternativeKey: 'primary',
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Stop and keep position'));
      await tester.pump();

      expect(find.bySemanticsLabel('Reading paused'), findsNothing);
      expect(
        find.bySemanticsLabel('Reading stopped. Restart from position.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets(
    'engine rate rejection keeps the old rate and is cleared by playback',
    (tester) async {
      final engine = _FakeSpeechEngine();
      final narration = ReadingNarrationSession(
        controller: ReadingNarrationController(engine: engine),
        queueBuilder: const ReadingNarrationQueueBuilder(
          composer: ReadingNarrationComposer(),
        ),
      );
      final queue = narration.queueBuilder.buildCurrent(
        ReadingSession(
          readings: <DailyReading>[
            DailyReading(
              reading: 'Jn 1:1',
              position: 'Gospel',
              date: DateTime(2026, 8, 29),
            ),
          ],
          readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
          currentIndex: 0,
        ),
      );
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            builder: (context, child) => ReadingNarrationHost(child: child!),
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await narration.toggle(
        queue,
        mode: NarrationPlaybackMode.currentOnly,
        context: const NarrationContext(
          dateKey: '2026-08-29',
          regionCode: 'NG',
          bibleEditionId: 'rsvce',
          psalmEditionId: 'territory_lectionary',
          alternativeKey: 'primary',
        ),
      );
      await tester.pump();

      engine.configureError = StateError('bad rate');
      await tester.tap(find.text('0.5×'));
      await tester.pumpAndSettle();
      expect(narration.rate, 0.5);
      expect(find.text('Unable to change speech speed.'), findsOneWidget);

      engine.configureError = null;
      await narration.controller.stop(clearQueue: false);
      await narration.togglePlayerPlayback();
      await tester.pumpAndSettle();
      expect(find.text('Unable to change speech speed.'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets(
    'rollback failure keeps UI aligned with the engine session rate',
    (tester) async {
      final engine = _FakeSpeechEngine();
      final preferences = _ThrowingNarrationPreferences();
      final narration = ReadingNarrationSession(
        controller: ReadingNarrationController(engine: engine),
        queueBuilder: const ReadingNarrationQueueBuilder(
          composer: ReadingNarrationComposer(),
        ),
        preferences: preferences,
      );
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            builder: (context, child) => ReadingNarrationHost(child: child!),
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      engine.configureOutcomes.addAll(<Object?>[
        null,
        StateError('rollback rejected'),
      ]);

      await narration.setRate(0.75);
      await tester.pumpAndSettle();

      expect(engine.currentRate, 0.75);
      expect(narration.rate, 0.75);
      expect(
        find.text('Speech speed changed for this session but was not saved.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets('overlapping rate changes serialize rollback before newer work', (
    tester,
  ) async {
    final engine = _FakeSpeechEngine();
    final firstWrite = Completer<void>();
    final preferences = _ControlledNarrationPreferences(firstWrite.future);
    final narration = ReadingNarrationSession(
      controller: ReadingNarrationController(engine: engine),
      queueBuilder: const ReadingNarrationQueueBuilder(
        composer: ReadingNarrationComposer(),
      ),
      preferences: preferences,
    );
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          builder: (context, child) => ReadingNarrationHost(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );

    final older = narration.setRate(0.75);
    await tester.pump();
    final newer = narration.setRate(1.0);
    await tester.pump();
    expect(engine.configuredRates, <double>[0.75]);

    firstWrite.completeError(StateError('disk unavailable'));
    await older;
    await newer;
    await tester.pumpAndSettle();

    expect(engine.configuredRates, <double>[0.75, 0.5, 1.0]);
    expect(engine.currentRate, 1.0);
    expect(narration.rate, 1.0);
    expect(preferences.savedRates, <double>[0.75, 1.0]);

    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets('announcements repeat after reset and suppress stale callbacks', (
    tester,
  ) async {
    final announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        if (message case <Object?, Object?>{
          'type': 'announce',
          'data': <Object?, Object?>{'message': final String value},
        }) {
          announcements.add(value);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    final engine = _FakeSpeechEngine();
    final narration = ReadingNarrationSession(
      controller: ReadingNarrationController(engine: engine),
      queueBuilder: const ReadingNarrationQueueBuilder(
        composer: ReadingNarrationComposer(),
      ),
    );
    final reading = DailyReading(
      reading: 'Jn 1:1',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
    );
    final queue = narration.queueBuilder.buildCurrent(
      ReadingSession(
        readings: <DailyReading>[reading],
        readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
        currentIndex: 0,
      ),
    );
    const context = NarrationContext(
      dateKey: '2026-08-29',
      regionCode: 'NG',
      bibleEditionId: 'rsvce',
      psalmEditionId: 'territory_lectionary',
      alternativeKey: 'primary',
    );
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          builder: (context, child) => ReadingNarrationHost(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await narration.toggle(
      queue,
      mode: NarrationPlaybackMode.currentOnly,
      context: context,
    );

    engine.failCurrent('same failure');
    await narration.controller.stop();
    await tester.pump();
    expect(announcements, isNot(contains('same failure')));

    for (var cycle = 0; cycle < 2; cycle++) {
      await narration.toggle(
        queue,
        mode: NarrationPlaybackMode.currentOnly,
        context: context,
      );
      engine.failCurrent('same failure');
      await tester.pump();
      await tester.pump();
      expect(
        announcements.where((message) => message == 'same failure'),
        hasLength(cycle + 1),
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });
}

class _FakeSpeechEngine implements SpeechEngine {
  final List<SpeechVoice> voices;
  SpeechEngineCallbacks? callbacks;
  final List<String> spokenTexts = <String>[];
  String? currentUtteranceId;
  Object? configureError;
  final List<Object?> configureOutcomes = <Object?>[];
  final List<double> configuredRates = <double>[];
  double currentRate = 0.5;

  _FakeSpeechEngine({
    this.voices = const <SpeechVoice>[
      SpeechVoice(name: 'Offline English', locale: 'en-US'),
    ],
  });

  @override
  bool get supportsNativePause => false;

  @override
  void setCallbacks(SpeechEngineCallbacks callbacks) {
    this.callbacks = callbacks;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SpeechVoice>> getVoices() async => voices;

  @override
  Future<void> configure(SpeechEngineSettings settings) async {
    configuredRates.add(settings.rate);
    if (configureOutcomes.isNotEmpty) {
      final outcome = configureOutcomes.removeAt(0);
      if (outcome case final error?) throw error;
    }
    if (configureError case final error?) throw error;
    currentRate = settings.rate;
  }

  @override
  Future<void> speak(String text, {required String utteranceId}) async {
    spokenTexts.add(text);
    currentUtteranceId = utteranceId;
    callbacks?.onStart(utteranceId);
  }

  void emitProgress(int start, int end, String word) {
    callbacks?.onProgress(currentUtteranceId!, start, end, word);
  }

  void completeCurrent() {
    callbacks?.onCompletion(currentUtteranceId!);
  }

  void failCurrent(String message) {
    callbacks?.onError(currentUtteranceId!, message);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    callbacks = null;
  }
}

class _ThrowingNarrationPreferences extends NarrationPreferences {
  @override
  Future<void> setRate(double rate) async {
    throw StateError('disk full');
  }
}

class _ControlledNarrationPreferences extends NarrationPreferences {
  final Future<void> firstWrite;
  final List<double> savedRates = <double>[];

  _ControlledNarrationPreferences(this.firstWrite);

  @override
  Future<void> setRate(double rate) async {
    savedRates.add(rate);
    if (savedRates.length == 1) await firstWrite;
  }
}
