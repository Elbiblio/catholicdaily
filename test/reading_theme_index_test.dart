import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/hymn.dart';
import 'package:catholic_daily/data/services/reading_theme_index.dart';
import 'package:catholic_daily/data/services/robust_hymn_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final index = ReadingThemeIndex();
  test('normalizes book aliases and preserves full verse range', () {
    expect(
      index.themesFor('Matthew 19:16–22').keys,
      containsAll(['discipleship', 'detachment']),
    );
    expect(index.themesFor('Mt 19:16-22'), index.themesFor('Matt 19:16-22'));
    expect(index.themesFor('Matt 19:16-20'), isEmpty);
    expect(index.themesFor('Matt 19:16-22, 27'), isEmpty);
  });
  test('never turns unrelated or unindexed passages into themes', () {
    expect(index.themesFor('John 3:16'), isEmpty);
    expect(index.themesFor(''), isEmpty);
  });
  test('gospel contributes more than a secondary reading', () {
    final date = DateTime(2026, 8, 17);
    final themes = index.themesForReadings([
      DailyReading(
        reading: 'John 10:11-18',
        date: date,
        position: 'First Reading',
      ),
      DailyReading(reading: 'Matt 19:16-22', date: date, position: 'Gospel'),
    ]);
    expect(themes['discipleship']!, greaterThan(themes['shepherd']!));
  });
  test(
    'selected alternative is indexed unless a primary Gospel is also present',
    () {
      final date = DateTime(2026, 4, 5);
      final alternative = DailyReading(
        reading: 'Luke 24:13-35',
        date: date,
        position: 'Gospel (alternative)',
      );
      expect(
        index.themesForReadings([alternative])['breaking_bread'],
        isNotNull,
      );
      final primary = DailyReading(
        reading: 'John 20:1-9',
        date: date,
        position: 'Gospel',
      );
      expect(
        index.themesForReadings([primary, alternative])['breaking_bread'],
        isNull,
      );
    },
  );
  test('indexed secondary passages do not count as an indexed Gospel', () {
    final date = DateTime(2026, 1, 15);
    final readings = [
      DailyReading(
        reading: 'John 10:11-18',
        date: date,
        position: 'First Reading',
      ),
      DailyReading(reading: 'Mark 1:21-28', date: date, position: 'Gospel'),
    ];
    expect(index.hasIndexedGospel(readings), isFalse);
  });
  test('Advent processionals can include hymns indexed for Advent', () async {
    final date = DateTime(2026, 12, 6);
    final hymns = await RobustHymnRecommendationService.instance
        .getRobustRecommendations(
          date,
          [],
          massPart: 'entrance',
          readingTexts: {},
          maxResults: 200,
        );
    expect(
      hymns.any((hymn) => hymn.title == 'Come Thou Long Expected Saviour'),
      isTrue,
    );
  });
  test(
    'Good Friday has no Mass-part recommendations, but Holy Saturday is unchanged',
    () async {
      final service = RobustHymnRecommendationService.instance;
      for (final date in [DateTime(2026, 4, 3, 15), DateTime(2027, 3, 26)]) {
        expect(
          await service.getMassPartRecommendations(date, [], readingTexts: {}),
          isEmpty,
        );
        expect(
          await service.getRobustRecommendations(
            date,
            [],
            massPart: 'entrance',
            readingTexts: {},
          ),
          isEmpty,
        );
      }
      final saturday = await service.getMassPartRecommendations(
        DateTime(2026, 4, 4),
        [],
        readingTexts: {},
      );
      expect(saturday.values.any((hymns) => hymns.isNotEmpty), isTrue);
    },
  );
  test('theme evidence requires distinctive language, not generic overlap', () {
    final unrelated = Hymn(
      id: 1,
      title: 'The Light of Life',
      category: 'general',
      lyrics: ['We live today'],
    );
    final related = Hymn(
      id: 2,
      title: 'Christ Is Risen',
      category: 'general',
      lyrics: ['Jesus rose from the dead'],
    );
    expect(index.hymnScore(unrelated, {'resurrection': 1}), 0);
    expect(index.hymnScore(related, {'resurrection': 1}), greaterThan(0));
  });
  test(
    'unindexed readings do not gain speculative keyword themes by default',
    () async {
      final date = DateTime(2026, 7, 15);
      final readings = [
        DailyReading(
          date: date,
          position: 'Gospel',
          reading: 'Matt 11:25-27',
          incipit: 'Come to me and find life',
        ),
      ];
      final service = RobustHymnRecommendationService.instance;
      final implicit = await service.getRobustRecommendations(
        date,
        readings,
        massPart: 'entrance',
        readingTexts: {},
      );
      final noThemes = await service.getRobustRecommendations(
        date,
        readings,
        massPart: 'entrance',
        readingTexts: {},
        partThemes: {},
      );
      expect(implicit.map((h) => h.id), noThemes.map((h) => h.id));
    },
  );
  test(
    'indexed Gospel themes influence real hymn rankings even without passage text',
    () async {
      final date = DateTime(2026, 1, 15);
      final hymns = await RobustHymnRecommendationService.instance
          .getRobustRecommendations(
            date,
            [
              DailyReading(
                reading: 'John 10:11-18',
                date: date,
                position: 'Gospel',
              ),
            ],
            massPart: 'communion',
            readingTexts: {},
            maxResults: 3,
          );
      expect(
        index.hymnScore(hymns.first, index.themesFor('John 10:11-18')),
        greaterThan(0),
      );
    },
  );
}
