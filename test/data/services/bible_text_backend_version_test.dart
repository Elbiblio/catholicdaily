import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'switching RSVCE to NABRE changes rendered verse text without changing reference',
    () async {
      final pref = await BibleVersionPreference.getInstance();
      final service = ReadingsService.instance;

      await pref.setVersion(BibleVersionType.rsvce);
      final rsvceText = await service.getReadingText('John 3:16');

      await pref.setVersion(BibleVersionType.nabre);
      await service.reloadForVersionChange();
      final nabreText = await service.getReadingText('John 3:16');

      expect(rsvceText, isNot(contains('Reading text unavailable')));
      expect(nabreText, isNot(contains('Reading text unavailable')));
      expect(rsvceText, isNot(equals(nabreText)));
    },
  );

  test('resolves edition-specific abbreviations to the same reading', () async {
    final pref = await BibleVersionPreference.getInstance();
    final service = ReadingsService.instance;
    final references = <List<String>>[
      ['Eccl 3:1', 'Eccles 3:1', 'Ecclesiastes 3:1'],
      ['Jdt 8:1', 'Jud 8:1', 'Judith 8:1'],
      ['Hag 1:1', 'Hagg 1:1', 'Haggai 1:1'],
      ['Jas 1:1', 'James 1:1'],
      ['Phlm 1:1', 'Philemon 1:1'],
      ['Phlm 7-20', 'Phlm 1:7-20'],
      ['Phlm 9-10, 12-17', 'Phlm 1:9-10, 12-17'],
    ];
    for (final version in [BibleVersionType.rsvce, BibleVersionType.nabre]) {
      await pref.setVersion(version);
      await service.reloadForVersionChange();
      for (final group in references) {
        final texts = <String>[];
        for (final reference in group) {
          final text = await service.getReadingText(reference);
          expect(
            text,
            isNot(contains('Reading text unavailable')),
            reason: '${version.name}: $reference',
          );
          texts.add(text);
        }
        expect(texts.toSet(), hasLength(1), reason: '${version.name}: $group');
      }
    }
  });

  test('loads the first reading for 12 November 2026', () async {
    final pref = await BibleVersionPreference.getInstance();
    final service = ReadingsService.instance;
    await pref.setVersion(BibleVersionType.rsvce);
    await service.reloadForVersionChange();
    final readings = await service.getReadingsForDate(DateTime(2026, 11, 12));
    final first = readings.firstWhere(
      (reading) => reading.position == 'First Reading',
    );
    expect(first.reading, 'Phlm 7-20');
    final text = await service.getReadingText(
      first.reading,
      incipit: first.incipit,
      readingType: first.position,
    );
    expect(text, isNot(contains('Reading text unavailable')));
    expect(text, contains('Onesimus'));
  });

  test('loads the first reading for 13 November 2026', () async {
    final pref = await BibleVersionPreference.getInstance();
    final service = ReadingsService.instance;
    for (final version in [BibleVersionType.rsvce, BibleVersionType.nabre]) {
      await pref.setVersion(version);
      await service.reloadForVersionChange();
      final readings = await service.getReadingsForDate(DateTime(2026, 11, 13));
      final first = readings.firstWhere(
        (reading) => reading.position == 'First Reading',
      );
      expect(first.reading, '2 John 4-9');
      final text = await service.getReadingText(
        first.reading,
        incipit: first.incipit,
        readingType: first.position,
      );
      final explicitText = await service.getReadingText('2 John 1:4-9');
      expect(
        text,
        isNot(contains('Reading text unavailable')),
        reason: version.name,
      );
      expect(text, explicitText, reason: version.name);
    }
  });
}
