import 'package:catholic_daily/data/models/bible_book.dart';
import 'package:catholic_daily/data/services/lectionary_psalm_formatter.dart';
import 'package:catholic_daily/data/services/psalm_verse_splitter.dart';
import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses simple single-range reference', () {
    final ranges = ReadingReferenceParser.parse('Exod 17:3-7');

    expect(ranges, hasLength(1));
    expect(ranges.first.book, 'Exod');
    expect(ranges.first.startChapter, 17);
    expect(ranges.first.startVerse, 3);
    expect(ranges.first.endChapter, 17);
    expect(ranges.first.endVerse, 7);
  });

  test('parses comma-separated multi-chapter reference', () {
    final ranges = ReadingReferenceParser.parse('Acts 6:8-10, 7:54-59');

    expect(ranges, hasLength(2));
    expect(ranges[0].startChapter, 6);
    expect(ranges[0].startVerse, 8);
    expect(ranges[0].endVerse, 10);
    expect(ranges[1].startChapter, 7);
    expect(ranges[1].startVerse, 54);
    expect(ranges[1].endVerse, 59);
  });

  test('parses implicit chapter crossover reference', () {
    final ranges = ReadingReferenceParser.parse('Bar 3:9-15, 32-4:4');

    expect(ranges, hasLength(2));
    expect(ranges[1].startChapter, 3);
    expect(ranges[1].startVerse, 32);
    expect(ranges[1].endChapter, 4);
    expect(ranges[1].endVerse, 4);
  });

  test('parses semicolon and verse-suffix references', () {
    final ranges = ReadingReferenceParser.parse(
      'Tob 6:10-11; 7:1e, 9-17; 8:4-9',
    );

    expect(ranges, hasLength(4));
    expect(ranges[1].startChapter, 7);
    expect(ranges[1].startVerse, 1);
    expect(ranges[1].endVerse, 1);
    expect(ranges[2].startChapter, 7);
    expect(ranges[2].startVerse, 9);
    expect(ranges[2].endVerse, 17);
    expect(ranges[3].startChapter, 8);
  });

  test('parses multi-letter verse suffix references', () {
    final ranges = ReadingReferenceParser.parse('Matthew 11:29ab');

    expect(ranges, hasLength(1));
    expect(ranges.first.book, 'Matthew');
    expect(ranges.first.startChapter, 11);
    expect(ranges.first.startVerse, 29);
    expect(ranges.first.startVerseParts, 'ab');
    expect(ranges.first.endVerseParts, 'ab');
  });

  test('parses mixed-book references', () {
    final ranges = ReadingReferenceParser.parse('1 Sam 3:9, John 6:68');

    expect(ranges, hasLength(2));
    expect(ranges[0].book, '1 Sam');
    expect(ranges[1].book, 'John');
  });

  test('parses gospel acclamation multi-letter verse suffix references', () {
    final ranges = ReadingReferenceParser.parse('Matthew 11:29ab');

    expect(ranges, hasLength(1));
    expect(ranges.first.book, 'Matthew');
    expect(ranges.first.startChapter, 11);
    expect(ranges.first.startVerse, 29);
    expect(ranges.first.startVerseParts, 'ab');
    expect(ranges.first.endVerseParts, 'ab');
  });

  test('extracts combined verse parts for gospel acclamation suffixes', () {
    const verse =
        'Take my yoke upon you, and learn from me; for I am gentle and lowly in heart, and you will find rest for your souls.';

    expect(
      PsalmVerseSplitter.getVerseParts(verse, 'ab'),
      'Take my yoke upon you and learn from me',
    );
  });

  test('parses malformed cross-chapter end pattern used in source data', () {
    final ranges = ReadingReferenceParser.parse('Matt 9:35-10:1-8');

    expect(ranges, hasLength(1));
    expect(ranges.first.startChapter, 9);
    expect(ranges.first.startVerse, 35);
    expect(ranges.first.endChapter, 10);
    expect(ranges.first.endVerse, 8);
  });

  test('resolves common aliases to short names', () {
    final aliases = ReadingReferenceParser.buildBookAliasMap([
      Book(
        id: 1,
        name: 'Acts of the Apostles',
        shortName: 'Acts',
        chapterCount: 28,
      ),
      Book(id: 2, name: 'Ecclesiastes', shortName: 'Eccles', chapterCount: 12),
      Book(id: 3, name: 'I Peter', shortName: '1 Pet', chapterCount: 5),
    ]);

    expect(ReadingReferenceParser.resolveBookShortName('Act', aliases), 'Acts');
    expect(
      ReadingReferenceParser.resolveBookShortName('Ecclesiastes', aliases),
      'Eccles',
    );
    expect(
      ReadingReferenceParser.resolveBookShortName('1 Peter', aliases),
      '1 Pet',
    );
  });

  test('formats weekday responsorial psalm with dot separator and plus groups', () {
    final formatted = LectionaryPsalmFormatter.format(
      reference: 'Psalm 30.1+3, 4-5, 10+11a+12b (R.1a)',
      verses: {
        1: '1. I will extol you, Lord, for you drew me clear.',
        3: '3. O Lord, you brought me up from the netherworld.',
        4: '4. Sing praise to the Lord, you his faithful ones.',
        5: '5. For his anger lasts but a moment; a lifetime, his good will.',
        10: '10. Hear, O Lord, and have pity on me; O Lord, be my helper.',
        11: '11. You changed my mourning into dancing; you took off my sackcloth.',
        12: '12. O Lord, my God, forever will I give you thanks.',
      },
      refrain: 'I will praise you, Lord, for you have rescued me.',
      refrainVerse: '1a',
    );

    expect(formatted, contains('I will extol you, Lord'));
    expect(formatted, contains('for you drew me clear'));
    expect(formatted, contains('O Lord, you brought me up from the netherworld'));
    expect(formatted, contains('Sing praise to the Lord, you his faithful ones'));
    expect(formatted, contains('For his anger lasts but a moment'));
    expect(formatted, contains('Hear, O Lord'));
    expect(formatted, contains('and have pity on me'));
    expect(formatted, contains('You changed my mourning into dancing'));
  });

  test('formats weekday responsorial psalm with ampersand groups', () {
    final formatted = LectionaryPsalmFormatter.format(
      reference: 'Psalm 96.1-2, 3 & 10ac, 11-12, 13 (R. Isa 40.10a)',
      verses: {
        1: '1. Sing to the Lord a new song; sing to the Lord, all you lands.',
        2: '2. Sing to the Lord; bless his name. Announce his salvation, day after day.',
        3: '3. Tell his glory among the nations; among all peoples, his wondrous deeds.',
        10: '10. Say among the nations: The Lord is king. He has made the world firm, not to be moved. He governs the peoples with equity.',
        11: '11. Let the heavens be glad and the earth rejoice; let the sea and what fills it resound.',
        12: '12. Let the plains be joyful and all that is in them! Then shall all the trees of the forest exult.',
        13: '13. Before the Lord, for he comes; for he comes to rule the earth.',
      },
      refrain: 'The Lord our God comes in strength.',
      refrainVerse: '10a',
    );

    expect(formatted, contains('Tell his glory among the nations'));
    expect(formatted, contains('Say among the nations'));
    expect(formatted, contains('He governs the peoples with equity'));
    expect(formatted, contains('Let the heavens be glad and the earth rejoice'));
    expect(formatted, contains('Before the Lord'));
    expect(formatted, contains('for he comes'));
  });

}
