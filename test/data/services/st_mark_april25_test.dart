// Regression guard: April 25 must resolve to "Saint Mark, Evangelist" (Feast)
// with the proper missal readings — not the fallback Easter weekday.
//
// Originally broken by:
//   1. memorial_feasts.csv had 58 rows column-shifted (St. Mark's gospel
//      stored in the psalmResponse column).
//   2. _findCelebrationEntry matched empty-title CSV rows when the ordo
//      returned an empty celebrationTitle, returning null and skipping
//      the date-match fallback.
//   3. offline_ordo_lookup_service.dart was missing St. Mark and several
//      other major fixed-date Apostle/Evangelist feasts entirely, so the
//      feast reminder service never scheduled a notification for them.

import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/incipit_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test('Saint Mark (April 25): ordo title + rank set for notifications',
      () async {
    final dt = DateTime(2026, 4, 25);
    final day = OfflineOrdoLookupService.instance.resolve(dt);
    expect(day.title, 'Saint Mark, Evangelist');
    expect(day.rank, 'Feast');
  });

  test('Saint Mark (April 25): resolveDay returns the feast', () async {
    final dt = DateTime(2026, 4, 25);
    final resolved = await OrdoResolverService.instance.resolveDay(dt);
    expect(resolved.title, 'Saint Mark, Evangelist');
    expect(resolved.rank, 'Feast');
  });

  test('Saint Mark (April 25): readings come from feast, not Easter weekday',
      () async {
    final dt = DateTime(2026, 4, 25);
    final readings = await CsvReadingsResolverService.instance.resolve(dt);

    final first = readings.firstWhere((r) => r.position == 'First Reading');
    final psalm = readings.firstWhere(
      (r) => r.position == 'Responsorial Psalm',
    );
    final gospel = readings.firstWhere((r) => r.position == 'Gospel');

    expect(first.reading, contains('1 Pet'));
    expect(psalm.reading, contains('Ps 89'));
    expect(gospel.reading, contains('Mark 16:15-20'));
  });

  test('Saint Mark first reading: no leaked chapter:verse artifact',
      () async {
    final dt = DateTime(2026, 4, 25);
    final readings = await CsvReadingsResolverService.instance.resolve(dt);
    final first = readings.firstWhere((r) => r.position == 'First Reading');

    // Get RAW text (incipit toggle off → no processing).
    await IncipitPreferenceService().setShowIncipit(false);
    IncipitPreferenceService().resetCache();
    final rawText = await ReadingsService.instance.getReadingText(
      first.reading,
      incipit: first.incipit,
    );
    // ignore: avoid_print
    print('\nRAW TEXT (toggle OFF, first 200 chars):');
    // ignore: avoid_print
    print(rawText.length > 200 ? rawText.substring(0, 200) : rawText);

    // Get processed text (toggle ON → incipit prefix applied).
    await IncipitPreferenceService().setShowIncipit(true);
    IncipitPreferenceService().resetCache();
    final text = await ReadingsService.instance.getReadingText(
      first.reading,
      incipit: first.incipit,
    );
    // ignore: avoid_print
    print('\nPROCESSED TEXT (toggle ON, first 200 chars):');
    // ignore: avoid_print
    print(text.length > 200 ? text.substring(0, 200) : text);

    expect(text, isNot(matches(RegExp(r'\b\d+:\s*\d+[a-z]?\.\s'))),
        reason: 'Found chapter:verse artifact in rendered text');
  });

  test(
      'Memorial CSV: no row has gospel column empty while psalmResponse '
      'looks like a gospel ref (column-shift signature)', () async {
    final entries =
        await ReadingCatalogService.instance.loadMemorialEntries();
    final shifted = entries.where((e) {
      final pr = e.psalmResponse.trim();
      if (e.gospel.trim().isNotEmpty) return false;
      if (pr.isEmpty) return false;
      final firstWord = pr.split(RegExp(r'\s+')).first;
      const gospelBooks = {'Matt', 'Mark', 'Luke', 'John', 'Mt', 'Mk',
        'Lk', 'Jn'};
      return gospelBooks.contains(firstWord);
    }).toList();

    expect(shifted, isEmpty,
        reason: 'Found ${shifted.length} memorial rows with the column-shift '
            'bug. Run: python scripts/active/fix_memorial_csv_shift.py');
  });
}
