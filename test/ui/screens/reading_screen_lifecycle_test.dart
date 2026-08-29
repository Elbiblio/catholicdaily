import 'dart:async';

import 'package:catholic_daily/core/latest_request_guard.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/reading_session.dart';
import 'package:catholic_daily/data/services/narration_preferences.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_preference.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:catholic_daily/data/services/reading_narration_controller.dart';
import 'package:catholic_daily/data/services/reading_narration_queue_builder.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/speech_engine.dart';
import 'package:catholic_daily/ui/screens/reading_screen.dart';
import 'package:catholic_daily/ui/widgets/read_aloud_icon.dart';
import 'package:catholic_daily/ui/widgets/gospel_acclamation_widget.dart';
import 'package:catholic_daily/ui/widgets/bible_version_switcher.dart';
import 'package:catholic_daily/ui/widgets/reading_narration_scope.dart';
import 'package:catholic_daily/ui/widgets/responsorial_psalm_edition_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('popping a reading invalidates work started by that route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final guard = LatestRequestGuard();
    final generation = guard.begin();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReadingScreen(
                      reference: 'Jn 1:1',
                      content: 'In the beginning',
                      onRouteDisposed: guard.begin,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(guard.isCurrent(generation), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(guard.isCurrent(generation), isFalse);
  });

  testWidgets(
    'reading app bar exposes one exact-text speaker and read-all menu',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final reading = DailyReading(
        reading: 'Jn 1:1-5',
        position: 'Gospel',
        date: DateTime(2026, 8, 29),
        incipit: 'In the beginning',
      );
      final readingSession = ReadingSession(
        readings: <DailyReading>[reading],
        readingTexts: const <String, String>{
          'Jn 1:1-5': '1 In the beginning was the Word.',
        },
        currentIndex: 0,
      );
      final engine = _FakeSpeechEngine();
      final narration = _narrationSession(engine);

      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            home: ReadingScreen(
              reference: reading.reading,
              content: '1 In the beginning was the Word.',
              readingData: reading,
              narrationSession: readingSession,
              sessionReadings: readingSession.readings,
              currentReadingIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadAloudIcon), findsOneWidget);
      expect(find.bySemanticsLabel('Read aloud'), findsOneWidget);
      await tester.tap(find.byType(ReadAloudIcon));
      await tester.pumpAndSettle();
      expect(engine.spokenTexts, hasLength(1));
      expect(
        engine.spokenTexts.single,
        contains('In the beginning was the Word.'),
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Read all appointed readings'), findsOneWidget);

      narration.dispose();
    },
  );

  testWidgets('popping current-only narration stops the app-scoped session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);

    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReadingScreen(
                    reference: 'Jn 1:1',
                    content: '1 In the beginning was the Word.',
                  ),
                ),
              ),
              child: const Text('Open narrated reading'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open narrated reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pumpAndSettle();
    expect(narration.state.status, NarrationStatus.playing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(narration.state.status, NarrationStatus.stopped);
    expect(engine.stopCalls, 1);

    narration.dispose();
  });

  testWidgets('deliberate next navigation preserves read-all playback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final readings = <DailyReading>[
      DailyReading(
        reading: 'Gen 1:1-3',
        position: 'First Reading',
        date: DateTime(2026, 8, 29),
      ),
      DailyReading(
        reading: 'Jn 1:1-5',
        position: 'Gospel',
        date: DateTime(2026, 8, 29),
      ),
    ];
    final readingSession = ReadingSession(
      readings: readings,
      readingTexts: const <String, String>{
        'Gen 1:1-3': '1 In the beginning God created.',
        'Jn 1:1-5': '1 In the beginning was the Word.',
      },
      currentIndex: 0,
    );
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    final queue = narration.queueBuilder.buildReadAll(readingSession);
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
    var nextCalls = 0;

    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReadingScreen(
                    reference: readings.first.reading,
                    content: '1 In the beginning God created.',
                    readingData: readings.first,
                    narrationSession: readingSession,
                    sessionReadings: readings,
                    currentReadingIndex: 0,
                    hasNext: true,
                    onNextReading: () => nextCalls++,
                  ),
                ),
              ),
              child: const Text('Open read-all'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open read-all'));
    await tester.pumpAndSettle();
    final next = find.text('Next').last;
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump(const Duration(milliseconds: 150));
    expect(nextCalls, 1);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(narration.state.status, NarrationStatus.playing);
    expect(engine.stopCalls, 0);

    narration.dispose();
  });

  testWidgets('covering a reading route stops current-only narration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          navigatorObservers: <NavigatorObserver>[
            readingNarrationRouteObserver,
          ],
          home: const ReadingScreen(
            reference: 'Jn 1:1',
            content: '1 In the beginning was the Word.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pumpAndSettle();
    expect(narration.state.status, NarrationStatus.playing);

    Navigator.of(tester.element(find.byType(ReadingScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
    );
    await tester.pumpAndSettle();

    expect(narration.state.status, NarrationStatus.stopped);
    expect(engine.stopCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets('Bible edition change invalidates before refresh awaits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.rsvce);
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: const MaterialApp(
          home: ReadingScreen(
            reference: 'Jn 1:1',
            content: '1 In the beginning was the Word.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pumpAndSettle();

    final switcher = tester.widget<BibleVersionSwitcher>(
      find.byType(BibleVersionSwitcher),
    );
    unawaited(switcher.onVersionChangeStarted!(BibleVersionType.nabre));
    await tester.pump();
    await preference.setVersion(BibleVersionType.nabre);
    await tester.pump();

    expect(narration.state.queue, isEmpty);
    expect(engine.stopCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
    await preference.setVersion(BibleVersionType.rsvce);
  });

  testWidgets(
    'Bible selection attempt invalidates narration before persistence',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final engine = _FakeSpeechEngine();
      final narration = _narrationSession(engine);
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            home: ReadingScreen(
              reference: 'Jn 1:1',
              content: '1 In the beginning was the Word.',
              readingData: DailyReading(
                reading: 'Jn 1:1',
                position: 'Gospel',
                date: DateTime(2026, 8, 29),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReadAloudIcon));
      await tester.pumpAndSettle();
      final switcher = tester.widget<BibleVersionSwitcher>(
        find.byType(BibleVersionSwitcher),
      );
      unawaited(switcher.onVersionChangeStarted!(BibleVersionType.nabre));
      await tester.pump();

      expect(narration.state.queue, isEmpty);
      expect(engine.stopCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets('psalm edition change invalidates before resolution awaits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ResponsorialPsalmPreference.resetForTest();
    final reading = DailyReading(
      reading: 'Ps 23:1-3',
      position: 'Responsorial Psalm',
      date: DateTime(2026, 8, 29),
      psalmResponse: 'The Lord is my shepherd.',
    );
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: ReadingScreen(
            reference: reading.reading,
            content: '1 The Lord is my shepherd.',
            readingData: reading,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pumpAndSettle();
    final preference = await ResponsorialPsalmPreference.getInstance();
    final selector = tester.widget<ResponsorialPsalmEditionSelector>(
      find.byType(ResponsorialPsalmEditionSelector),
    );
    unawaited(selector.onEditionChangeStarted!('test-selected-edition'));
    await tester.pump();
    await preference.setEditionId('test-selected-edition');

    unawaited(selector.onEditionChanged!());
    await tester.pump();

    expect(narration.state.queue, isEmpty);
    expect(engine.stopCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
    ResponsorialPsalmPreference.resetForTest();
  });

  testWidgets(
    'psalm selection attempt invalidates narration before persistence',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ResponsorialPsalmPreference.resetForTest();
      final reading = DailyReading(
        reading: 'Ps 23:1-3',
        position: 'Responsorial Psalm',
        date: DateTime(2026, 8, 29),
        psalmResponse: 'The Lord is my shepherd.',
      );
      final engine = _FakeSpeechEngine();
      final narration = _narrationSession(engine);
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            home: ReadingScreen(
              reference: reading.reading,
              content: '1 The Lord is my shepherd.',
              readingData: reading,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReadAloudIcon));
      await tester.pumpAndSettle();
      final selector = tester.widget<ResponsorialPsalmEditionSelector>(
        find.byType(ResponsorialPsalmEditionSelector),
      );
      unawaited(selector.onEditionChangeStarted!('local_rsvce'));
      await tester.pump();

      expect(narration.state.queue, isEmpty);
      expect(engine.stopCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
      ResponsorialPsalmPreference.resetForTest();
    },
  );

  testWidgets('narration uses the acclamation verse resolved for display', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final reading = DailyReading(
      reading: 'Jn 8:12',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
      gospelAcclamation: 'cf. Jn 8:12',
    );
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: ReadingScreen(
            reference: reading.reading,
            content: '1 Jesus spoke to them, saying, I am the light.',
            readingData: reading,
          ),
        ),
      ),
    );
    await tester.pump();
    const displayedVerse =
        'I am the light of the world, says the Lord; whoever follows me will have the light of life.';
    tester
        .widget<GospelAcclamationWidget>(find.byType(GospelAcclamationWidget))
        .onDisplayedAcclamationChanged!
        .call(displayedVerse);
    await tester.pump();
    await tester.tap(find.byType(ReadAloudIcon));
    await tester.pump(const Duration(milliseconds: 100));

    expect(engine.spokenTexts.single, contains(displayedVerse));
    expect(engine.spokenTexts.single, isNot(contains('cf. Jn 8:12')));
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets(
    'read all started on first reading pre-resolves the later Gospel acclamation',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final date = DateTime(2026, 8, 29);
      final readings = <DailyReading>[
        DailyReading(
          reading: 'Gen 1:1-3',
          position: 'First Reading',
          date: date,
        ),
        DailyReading(
          reading: 'Jn 8:12',
          position: 'Gospel',
          date: date,
          gospelAcclamation: 'cf. Jn 8:12',
        ),
      ];
      final hydrated = HydratedReadingSet(
        readings: readings,
        readingTitles: const <String, String>{},
        readingPreviews: const <String, String>{},
        readingTexts: const <String, String>{
          'Gen 1:1-3': 'In the beginning God created.',
          'Jn 8:12': 'Jesus said, I am the light of the world.',
        },
      );
      const displayed =
          'I am the light of the world, says the Lord; whoever follows me will have the light of life.';
      final engine = _FakeSpeechEngine();
      final narration = _narrationSession(engine);
      await tester.pumpWidget(
        ReadingNarrationScope(
          session: narration,
          child: MaterialApp(
            home: ReadingScreen(
              reference: readings.first.reading,
              content: 'In the beginning God created.',
              readingData: readings.first,
              narrationSession: ReadingSession(
                readings: readings,
                readingTexts: hydrated.readingTexts,
                currentIndex: 0,
              ),
              sessionReadings: readings,
              currentReadingIndex: 0,
              narrationHydrator: (_) async => hydrated,
              gospelAcclamationResolver: (_, _) async => displayed,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _chooseReadAll(tester);
      expect(engine.spokenTexts.single, contains('God created'));
      engine.completeCurrent();
      await tester.pumpAndSettle();

      expect(engine.spokenTexts, hasLength(2));
      expect(engine.spokenTexts.last, contains(displayed));
      expect(engine.spokenTexts.last, isNot(contains('cf. Jn 8:12')));

      await tester.pumpWidget(const SizedBox.shrink());
      narration.dispose();
    },
  );

  testWidgets('edition change fences a pending read-all hydration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final hydration = Completer<HydratedReadingSet>();
    final reading = DailyReading(
      reading: 'Jn 1:1',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
    );
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: ReadingScreen(
            reference: reading.reading,
            content: 'The original Word.',
            readingData: reading,
            narrationSession: ReadingSession(
              readings: <DailyReading>[reading],
              readingTexts: const <String, String>{
                'Jn 1:1': 'The original Word.',
              },
              currentIndex: 0,
            ),
            narrationHydrator: (_) => hydration.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _chooseReadAll(tester, settle: false);
    final switcher = tester.widget<BibleVersionSwitcher>(
      find.byType(BibleVersionSwitcher),
    );
    unawaited(switcher.onVersionChangeStarted!(BibleVersionType.nabre));
    await tester.pump();

    hydration.complete(
      HydratedReadingSet(
        readings: <DailyReading>[reading],
        readingTitles: const <String, String>{},
        readingPreviews: const <String, String>{},
        readingTexts: const <String, String>{'Jn 1:1': 'Stale hydrated Word.'},
      ),
    );
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });

  testWidgets('a newer read-all request supersedes older hydration', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = Completer<HydratedReadingSet>();
    final second = Completer<HydratedReadingSet>();
    var calls = 0;
    final reading = DailyReading(
      reading: 'Jn 1:1',
      position: 'Gospel',
      date: DateTime(2026, 8, 29),
    );
    final engine = _FakeSpeechEngine();
    final narration = _narrationSession(engine);
    await tester.pumpWidget(
      ReadingNarrationScope(
        session: narration,
        child: MaterialApp(
          home: ReadingScreen(
            reference: reading.reading,
            content: 'The Word.',
            readingData: reading,
            narrationSession: ReadingSession(
              readings: <DailyReading>[reading],
              readingTexts: const <String, String>{'Jn 1:1': 'The Word.'},
              currentIndex: 0,
            ),
            narrationHydrator: (_) =>
                calls++ == 0 ? first.future : second.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _chooseReadAll(tester, settle: false);
    await _chooseReadAll(tester, settle: false);
    second.complete(
      HydratedReadingSet(
        readings: <DailyReading>[reading],
        readingTitles: const <String, String>{},
        readingPreviews: const <String, String>{},
        readingTexts: const <String, String>{'Jn 1:1': 'Newest Word.'},
      ),
    );
    await tester.pumpAndSettle();
    first.complete(
      HydratedReadingSet(
        readings: <DailyReading>[reading],
        readingTitles: const <String, String>{},
        readingPreviews: const <String, String>{},
        readingTexts: const <String, String>{'Jn 1:1': 'Stale Word.'},
      ),
    );
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, hasLength(1));
    expect(engine.spokenTexts.single, contains('The Word.'));
    expect(engine.spokenTexts.single, isNot(contains('Stale Word.')));
    await tester.pumpWidget(const SizedBox.shrink());
    narration.dispose();
  });
}

Future<void> _chooseReadAll(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(find.byType(PopupMenuButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Read all appointed readings'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

ReadingNarrationSession _narrationSession(_FakeSpeechEngine engine) {
  return ReadingNarrationSession(
    controller: ReadingNarrationController(engine: engine),
    queueBuilder: const ReadingNarrationQueueBuilder(
      composer: ReadingNarrationComposer(),
    ),
    preferences: NarrationPreferences(),
  );
}

class _FakeSpeechEngine implements SpeechEngine {
  SpeechEngineCallbacks? callbacks;
  final List<String> spokenTexts = <String>[];
  int stopCalls = 0;
  String? currentUtteranceId;

  @override
  bool get supportsNativePause => false;

  @override
  void setCallbacks(SpeechEngineCallbacks callbacks) {
    this.callbacks = callbacks;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SpeechVoice>> getVoices() async => const <SpeechVoice>[
    SpeechVoice(name: 'Offline English', locale: 'en-US'),
  ];

  @override
  Future<void> configure(SpeechEngineSettings settings) async {}

  @override
  Future<void> configureRate(SpeechEngineSettings settings) =>
      configure(settings);

  @override
  Future<void> speak(String text, {required String utteranceId}) async {
    spokenTexts.add(text);
    currentUtteranceId = utteranceId;
    callbacks?.onStart(utteranceId);
  }

  void completeCurrent() {
    callbacks?.onCompletion(currentUtteranceId!);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    callbacks = null;
  }
}
