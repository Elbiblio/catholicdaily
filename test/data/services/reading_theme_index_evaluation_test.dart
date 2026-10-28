import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/hymn.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/reading_theme_index.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

// These anchors describe major themes of the specified Gospel passages; they
// are a small regression sample, not an exhaustive or expert-reviewed lectionary.
const _themeSamples =
    <({int year, int month, int day, String reference, Set<String> themes})>[
      (
        year: 2026,
        month: 2,
        day: 22,
        reference: 'Matt 4:1-11',
        themes: {'temptation', 'trust'},
      ),
      (
        year: 2026,
        month: 4,
        day: 5,
        reference: 'John 20:1-9',
        themes: {'resurrection'},
      ),
      (
        year: 2026,
        month: 8,
        day: 17,
        reference: 'Matt 19:16-22',
        themes: {'discipleship', 'detachment'},
      ),
      (
        year: 2026,
        month: 12,
        day: 25,
        reference: 'John 1:1-18',
        themes: {'incarnation'},
      ),
    ];

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);

  test('indexed core themes match Gospel references on sampled days', () async {
    final region = await LiturgicalRegionPreferenceService.getInstance();
    await region.setRegion(LiturgicalRegion.nigeria);
    final index = ReadingThemeIndex();
    for (final sample in _themeSamples) {
      final date = DateTime(sample.year, sample.month, sample.day);
      final readings = await ReadingsService.instance.getReadingsForDate(date);
      final selected = readings
          .where((r) => r.position == 'Gospel' && r.reading == sample.reference)
          .toList();
      expect(
        selected,
        hasLength(1),
        reason: 'Expected the sampled Gospel on $date',
      );
      final themes = index.themesFor(selected.single.reading);
      expect(
        themes.keys,
        containsAll(sample.themes),
        reason: 'Core themes for ${sample.reference}',
      );
      expect(themes.values.every((weight) => weight > 0), isTrue);
    }
  });

  test(
    'reference variations resolve while unrelated passages remain unindexed',
    () {
      final index = ReadingThemeIndex();
      expect(index.themesFor('Matthew 4:1–11'), index.themesFor('Matt 4:1-11'));
      expect(index.themesFor('Matthew 4:18-22'), isEmpty);
      expect(index.themesFor('John 10:11-18').keys, contains('shepherd'));
    },
  );

  test('a selected alternative Gospel contributes its themes', () {
    final index = ReadingThemeIndex();
    final readings = [
      DailyReading(
        date: DateTime(2026, 4, 5),
        position: 'Gospel (alternative)',
        reading: 'Luke 24:13-35',
      ),
    ];
    expect(index.themesForReadings(readings).keys, contains('resurrection'));
  });

  test('an unselected alternative does not add its distinct themes', () {
    final date = DateTime(2026, 4, 5);
    final themes = ReadingThemeIndex().themesForReadings([
      DailyReading(date: date, position: 'Gospel', reading: 'John 20:1-9'),
      DailyReading(
        date: date,
        position: 'Gospel (alternative)',
        reading: 'Luke 24:13-35',
      ),
    ]);
    expect(themes.keys, contains('resurrection'));
    expect(themes.keys, isNot(contains('breaking_bread')));
  });

  test('a theme match can connect different words without a generic match', () {
    final index = ReadingThemeIndex();
    final themes = index.themesFor('Matt 19:16-22');
    final related = Hymn(
      id: 1,
      title: 'A life of surrender',
      category: 'communion',
      lyrics: ['I surrender all'],
    );
    final unrelated = Hymn(
      id: 2,
      title: 'A beautiful life',
      category: 'communion',
      lyrics: ['The world is full of wonder'],
    );
    expect(
      index.hymnScore(related, themes),
      greaterThan(index.hymnScore(unrelated, themes)),
    );
    expect(index.hymnScore(unrelated, themes), 0);
  });
}
