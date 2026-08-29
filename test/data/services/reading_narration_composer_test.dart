import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/reading_narration_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 8, 29);

  DailyReading reading({
    String reference = 'Gen 1:1-5',
    String position = 'First Reading',
    String? incipit,
    String? psalmResponse,
    String? gospelAcclamation,
    String? source,
  }) => DailyReading(
    reading: reference,
    position: position,
    date: date,
    incipit: incipit,
    psalmResponse: psalmResponse,
    gospelAcclamation: gospelAcclamation,
    source: source,
  );

  group('ReadingNarrationComposer', () {
    const composer = ReadingNarrationComposer();

    test('orders a natural reference, visible incipit, then exact body', () {
      final result = composer.compose(
        reading: reading(incipit: 'In the beginning, when God created'),
        displayedText:
            '1. In the beginning God created the heavens.\n'
            '2. The earth was without form.',
        showIncipit: true,
      );

      expect(result.isAvailable, isTrue);
      expect(
        result.segments.map((segment) => segment.kind),
        <NarrationSegmentKind>[
          NarrationSegmentKind.position,
          NarrationSegmentKind.reference,
          NarrationSegmentKind.incipit,
          NarrationSegmentKind.body,
        ],
      );
      expect(result.segments[0].text, 'First Reading.');
      expect(result.segments[1].text, 'Genesis, chapter 1, verses 1 to 5.');
      expect(result.segments[2].text, 'In the beginning, when God created.');
      expect(
        result.segments[3].text,
        '1. In the beginning God created the heavens.\n'
        '2. The earth was without form.',
      );
    });

    test('omits the incipit when it is not currently displayed', () {
      final result = composer.compose(
        reading: reading(incipit: 'A hidden incipit'),
        displayedText: 'The appointed text.',
        showIncipit: false,
      );

      expect(
        result.segments.where(
          (segment) => segment.kind == NarrationSegmentKind.incipit,
        ),
        isEmpty,
      );
    });

    test('speaks cross-chapter Easter Vigil references naturally', () {
      final result = composer.compose(
        reading: reading(reference: 'Gen 1:31-2:2'),
        displayedText: 'God saw everything that he had made.',
      );

      expect(
        result.segments[1].text,
        'Genesis, chapter 1, verse 31 to chapter 2, verse 2.',
      );
    });

    test('omits refrain notation and speaks psalm verse joins naturally', () {
      final result = composer.compose(
        reading: reading(
          reference: 'Ps 30.1+3, 4-5 (R.1a)',
          position: 'Responsorial Psalm',
        ),
        displayedText: 'I will extol you, O Lord.',
      );

      expect(
        result.segments[1].text,
        'Psalms, chapter 30, verses 1 and 3, 4 to 5.',
      );
    });

    test(
      'speaks a psalm response once and does not duplicate it from body',
      () {
        final result = composer.compose(
          reading: reading(
            reference: 'Ps 23:1-3',
            position: 'Responsorial Psalm',
            psalmResponse: 'R. The Lord is my shepherd.',
          ),
          displayedText:
              'R. The Lord is my shepherd.\n'
              '1. The Lord is my shepherd; I shall not want.\n'
              'R. The Lord is my shepherd.\n'
              '2. In green pastures he gives me rest.',
        );

        expect(
          result.segments
              .singleWhere(
                (segment) => segment.kind == NarrationSegmentKind.response,
              )
              .text,
          'Response. The Lord is my shepherd.',
        );
        expect(
          result.text.toLowerCase().split('the lord is my shepherd').length - 1,
          2,
          reason: 'one response plus the distinct first verse wording',
        );
        expect(result.segments.last.text, isNot(contains('R.')));
      },
    );

    test(
      'speaks the displayed acclamation verse and Alleluia before Gospel',
      () {
        final result = composer.compose(
          reading: reading(
            reference: 'Jn 6:51-58',
            position: 'Gospel',
            gospelAcclamation:
                'I am the living bread that came down from heaven.\n'
                'Alleluia, alleluia.',
          ),
          displayedText: 'Jesus said to the crowds, “I am the living bread.”',
        );

        final acclamationIndex = result.segments.indexWhere(
          (segment) => segment.kind == NarrationSegmentKind.acclamation,
        );
        final bodyIndex = result.segments.indexWhere(
          (segment) => segment.kind == NarrationSegmentKind.body,
        );
        expect(acclamationIndex, greaterThan(0));
        expect(acclamationIndex, lessThan(bodyIndex));
        expect(
          result.segments[acclamationIndex].text,
          'I am the living bread that came down from heaven.\n'
          'Alleluia, alleluia.',
        );
      },
    );

    test('drops UI source artifacts without rewriting Scripture', () {
      final result = composer.compose(
        reading: reading(
          reference: '2 Cor 8:9',
          position: 'Gospel Acclamation',
          gospelAcclamation:
              'Jesus Christ was rich but he became poor. TUESDAY 1563',
          source: 'weekday_b_full.txt | row 1563',
        ),
        displayedText: 'Jesus Christ was rich but he became poor. TUESDAY 1563',
      );

      expect(
        result.text,
        contains('Jesus Christ was rich but he became poor.'),
      );
      expect(result.text, isNot(contains('TUESDAY 1563')));
      expect(result.text, isNot(contains('weekday_b_full.txt')));
    });

    test('returns an unavailable result without speaking a placeholder', () {
      final result = composer.compose(
        reading: reading(reference: 'Jn 99:1'),
        displayedText: 'Reading text unavailable for Jn 99:1.',
      );

      expect(result.isAvailable, isFalse);
      expect(result.segments, isEmpty);
      expect(
        result.unavailableMessage,
        'This reading is not available to narrate.',
      );
    });
  });
}
