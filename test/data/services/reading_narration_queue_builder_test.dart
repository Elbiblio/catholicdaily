import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/reading_session.dart';
import 'package:catholic_daily/data/models/resolved_responsorial_psalm.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:catholic_daily/data/services/reading_narration_queue_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 4, 4);

  DailyReading reading(String reference, String position) =>
      DailyReading(reading: reference, position: position, date: date);

  ReadingSession session(
    List<DailyReading> readings, {
    int currentIndex = 0,
    Map<String, ResolvedResponsorialPsalm> psalmSources =
        const <String, ResolvedResponsorialPsalm>{},
  }) {
    return ReadingSession(
      readings: readings,
      readingTexts: <String, String>{
        for (final item in readings) item.reading: 'Text for ${item.reading}',
      },
      psalmSources: psalmSources,
      currentIndex: currentIndex,
    );
  }

  group('ReadingNarrationQueueBuilder', () {
    const builder = ReadingNarrationQueueBuilder(
      composer: ReadingNarrationComposer(),
    );

    test('read-all contains primary appointed slots and no alternatives', () {
      final readings = <DailyReading>[
        reading('Acts 1:1-8', 'First Reading'),
        reading('Acts 2:1-11', 'First Reading (alternative)'),
        reading('Ps 104:1-2', 'Responsorial Psalm'),
        reading('Jn 20:19-23', 'Gospel'),
        reading('Jn 14:15-16', 'Gospel (alternative)'),
      ];

      final queue = builder.buildReadAll(session(readings));

      expect(queue.map((item) => item.reading.reading), <String>[
        'Acts 1:1-8',
        'Ps 104:1-2',
        'Jn 20:19-23',
      ]);
    });

    test('selected alternative replaces only its logical slot', () {
      final primary = reading('Acts 1:1-8', 'First Reading');
      final alternative = reading('Acts 2:1-11', 'First Reading (alternative)');
      final psalm = reading('Ps 104:1-2', 'Responsorial Psalm');

      final queue = builder.buildReadAll(
        session(<DailyReading>[primary, alternative, psalm]),
        selectedReadings: <DailyReading>[alternative],
      );

      expect(queue.map((item) => item.reading.reading), <String>[
        'Acts 2:1-11',
        'Ps 104:1-2',
      ]);
    });

    test('selected shorter form replaces the primary Gospel slot', () {
      final primary = reading('Mark 16:15-20', 'Gospel');
      final shorter = reading('Mark 16:15-18', 'Gospel (shorter form)');
      final psalm = reading('Ps 117:1-2', 'Responsorial Psalm');
      final readings = <DailyReading>[primary, shorter, psalm];

      expect(
        builder
            .buildReadAll(session(readings))
            .map((item) => item.reading.reading),
        <String>['Mark 16:15-20', 'Ps 117:1-2'],
      );

      expect(
        builder
            .buildReadAll(
              session(readings),
              selectedReadings: <DailyReading>[shorter],
            )
            .map((item) => item.reading.reading),
        <String>['Mark 16:15-18', 'Ps 117:1-2'],
      );
    });

    test('uses the response from the exact displayed psalm edition', () {
      final psalm = DailyReading(
        reading: 'Ps 23:1-3',
        position: 'Responsorial Psalm',
        date: date,
        psalmResponse: 'Response from the original lectionary row.',
      );
      final queue = builder.buildReadAll(
        session(
          <DailyReading>[psalm],
          psalmSources: <String, ResolvedResponsorialPsalm>{
            psalm.reading: const ResolvedResponsorialPsalm(
              text: 'The Lord is my shepherd.',
              responseText: 'The response in the selected edition.',
              requestedEditionId: 'selected',
              actualEditionId: 'selected',
              actualEditionName: 'Selected Edition',
              referenceNormalized: 'Ps 23:1-3',
              fallbackReason: PsalmFallbackReason.none,
              sourceUrl: 'asset://selected',
            ),
          },
        ),
      );

      expect(
        queue.single.narration.text,
        contains('The response in the selected edition.'),
      );
      expect(
        queue.single.narration.text,
        isNot(contains('Response from the original lectionary row.')),
      );
    });

    test(
      'keeps Easter Vigil after-reading psalm and prayer slots distinct',
      () {
        final readings = <DailyReading>[
          reading('Gen 1:1-2:2', 'First Reading'),
          reading('Ps 104:1-2', 'Responsorial Psalm after First Reading'),
          reading('vigil-prayer-1', 'Prayer after First Reading'),
          reading('Gen 22:1-18', 'Second Reading'),
          reading('Ps 16:5-11', 'Responsorial Psalm after Second Reading'),
          reading('vigil-prayer-2', 'Prayer after Second Reading'),
        ];

        final queue = builder.buildReadAll(session(readings));

        expect(queue, hasLength(6));
        expect(
          queue.map((item) => item.reading.position),
          readings.map((item) => item.position),
        );
      },
    );

    test(
      'selected after-reading psalm alternative replaces only that psalm',
      () {
        final firstPsalm = reading(
          'Ps 104:1-2',
          'Responsorial Psalm after First Reading',
        );
        final firstPsalmAlt = reading(
          'Ps 33:4-7',
          'Responsorial Psalm after First Reading (alternative)',
        );
        final seventhPsalm = reading(
          'Ps 42:3-5',
          'Responsorial Psalm after Seventh Reading',
        );

        final queue = builder.buildReadAll(
          session(<DailyReading>[firstPsalm, firstPsalmAlt, seventhPsalm]),
          selectedReadings: <DailyReading>[firstPsalmAlt],
        );

        expect(queue.map((item) => item.reading.reading), <String>[
          'Ps 33:4-7',
          'Ps 42:3-5',
        ]);
      },
    );

    test('Bible browsing narrates only the exact current chapter', () {
      final queue = builder.buildCurrentBibleChapter(
        reference: 'John 6',
        displayedText: '1. After this Jesus went to the other side.',
      );

      expect(queue, hasLength(1));
      expect(queue.single.reading.reading, 'John 6');
      expect(queue.single.narration.text, contains('chapter 6'));
      expect(queue.single.narration.text, contains('After this Jesus'));
    });

    test('unavailable current Bible chapter does not enter the queue', () {
      final queue = builder.buildCurrentBibleChapter(
        reference: 'John 99',
        displayedText: 'Chapter text unavailable for John 99.',
      );

      expect(queue, isEmpty);
    });
  });
}
