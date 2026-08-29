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

    test('recognizes every backend unavailable placeholder prefix', () {
      for (final placeholder in <String>[
        'Reading text unavailable for Jn 99:1.',
        'Psalm text unavailable for Ps 999:1.',
        'Chapter text unavailable for John 99.',
      ]) {
        final result = composer.compose(
          reading: reading(reference: 'John 99'),
          displayedText: placeholder,
          isBibleChapter: true,
        );
        expect(result.isAvailable, isFalse, reason: placeholder);
      }
    });

    test(
      'does not hide legitimate Scripture that mentions unavailable text',
      () {
        final result = composer.compose(
          reading: reading(reference: 'Wis 2:1'),
          displayedText:
              'They reasoned unsoundly, speaking of things unavailable to them.',
        );

        expect(result.isAvailable, isTrue);
        expect(result.text, contains('things unavailable to them'));
      },
    );

    test(
      'naturalizes every canonical and deuterocanonical app abbreviation',
      () {
        const books = <String, String>{
          'Gen': 'Genesis',
          'Exod': 'Exodus',
          'Lev': 'Leviticus',
          'Num': 'Numbers',
          'Deut': 'Deuteronomy',
          'Josh': 'Joshua',
          'Judg': 'Judges',
          'Ruth': 'Ruth',
          '1 Sam': 'First Samuel',
          '2 Sam': 'Second Samuel',
          '1 Kgs': 'First Kings',
          '2 Kgs': 'Second Kings',
          '1 Chr': 'First Chronicles',
          '2 Chr': 'Second Chronicles',
          'Ezra': 'Ezra',
          'Neh': 'Nehemiah',
          'Tob': 'Tobit',
          'Jud': 'Judith',
          'Esth': 'Esther',
          '1 Macc': 'First Maccabees',
          '2 Macc': 'Second Maccabees',
          'Job': 'Job',
          'Ps': 'Psalms',
          'Prov': 'Proverbs',
          'Eccles': 'Ecclesiastes',
          'Song': 'Song of Songs',
          'Wis': 'Wisdom',
          'Sir': 'Sirach',
          'Isa': 'Isaiah',
          'Jer': 'Jeremiah',
          'Lam': 'Lamentations',
          'Bar': 'Baruch',
          'Ezek': 'Ezekiel',
          'Dan': 'Daniel',
          'Hos': 'Hosea',
          'Joel': 'Joel',
          'Amos': 'Amos',
          'Obad': 'Obadiah',
          'Jonah': 'Jonah',
          'Mic': 'Micah',
          'Nah': 'Nahum',
          'Hab': 'Habakkuk',
          'Zeph': 'Zephaniah',
          'Hagg': 'Haggai',
          'Zech': 'Zechariah',
          'Mal': 'Malachi',
          'Matt': 'Matthew',
          'Mark': 'Mark',
          'Luke': 'Luke',
          'John': 'John',
          'Acts': 'Acts of the Apostles',
          'Rom': 'Romans',
          '1 Cor': 'First Corinthians',
          '2 Cor': 'Second Corinthians',
          'Gal': 'Galatians',
          'Eph': 'Ephesians',
          'Phil': 'Philippians',
          'Col': 'Colossians',
          '1 Thess': 'First Thessalonians',
          '2 Thess': 'Second Thessalonians',
          '1 Tim': 'First Timothy',
          '2 Tim': 'Second Timothy',
          'Titus': 'Titus',
          'Phlm': 'Philemon',
          'Heb': 'Hebrews',
          'James': 'James',
          '1 Pet': 'First Peter',
          '2 Pet': 'Second Peter',
          '1 John': 'First John',
          '2 John': 'Second John',
          '3 John': 'Third John',
          'Jude': 'Jude',
          'Rev': 'Revelation',
        };

        for (final entry in books.entries) {
          final result = composer.compose(
            reading: reading(reference: '${entry.key} 1:1'),
            displayedText: 'Appointed text.',
          );
          expect(
            result.segments[1].text,
            '${entry.value}, chapter 1, verse 1.',
            reason: entry.key,
          );
        }
      },
    );

    test('naturalizes multi-chapter lists without embedded colons', () {
      final result = composer.compose(
        reading: reading(reference: '2 Sam 15:13-30, 16:5-13'),
        displayedText: 'Appointed text.',
      );

      expect(
        result.segments[1].text,
        'Second Samuel, chapter 15, verses 13 to 30; '
        'chapter 16, verses 5 to 13.',
      );
      expect(result.segments[1].text, isNot(contains(':')));
    });

    test('preserves verse suffixes across chapter lists', () {
      final result = composer.compose(
        reading: reading(reference: 'Isa 52:13a-15b, 53:1c-2'),
        displayedText: 'Appointed text.',
      );

      expect(
        result.segments[1].text,
        'Isaiah, chapter 52, verses 13a to 15b; '
        'chapter 53, verses 1c to 2.',
      );
    });
  });
}
