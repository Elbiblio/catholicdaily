import 'dart:async';

import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/reading_session.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/data/services/reading_narration_queue_builder.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:catholic_daily/ui/widgets/narration_mini_player.dart';
import 'package:catholic_daily/ui/widgets/reading_narration_scope.dart';
import 'package:flutter/material.dart';
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
      await tester.tap(find.byTooltip('Resume reading'));
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
}

class _FakeSpeechEngine implements SpeechEngine {
  final List<SpeechVoice> voices;
  SpeechEngineCallbacks? callbacks;
  final List<String> spokenTexts = <String>[];

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
  Future<void> configure(SpeechEngineSettings settings) async {}

  @override
  Future<void> speak(String text, {required String utteranceId}) async {
    spokenTexts.add(text);
    callbacks?.onStart(utteranceId);
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
