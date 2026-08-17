import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  group('source-backed displayed readings samples', () {
    for (final sample in _sourceBackedSamples) {
      test(
        '${sample.region.code} ${sample.isoDate} ${sample.version.abbreviation} matches ${sample.source}',
        timeout: const Timeout(Duration(minutes: 2)),
        () async {
          final previousDebugPrint = debugPrint;
          debugPrint = (String? message, {int? wrapWidth}) {};
          try {
            final regionPrefs =
                await LiturgicalRegionPreferenceService.getInstance();
            await regionPrefs.setRegion(sample.region);

            final versionPrefs = await BibleVersionPreference.getInstance();
            await versionPrefs.setVersion(sample.version);
            await ReadingsService.instance.reloadForVersionChange();

            final readings = await ReadingsService.instance.getReadingsForDate(
              sample.date,
            );
            final hydrated = await ReadingFlowService.instance
                .hydrateReadingSet(date: sample.date, readings: readings);

            final displayedReferences = _referenceSet(hydrated.readings);
            expect(
              displayedReferences,
              containsAll(sample.expectedReferences),
              reason:
                  '${sample.source}\nExpected ${sample.expectedReferences}\n'
                  'Displayed $displayedReferences',
            );
            if (sample.expectedPsalmResponse != null) {
              final psalm = hydrated.readings.singleWhere(
                (reading) => reading.position == 'Responsorial Psalm',
              );
              expect(psalm.reading, sample.expectedPsalmReference);
              expect(psalm.psalmResponse, sample.expectedPsalmResponse);
            }

            for (final reading in hydrated.readings) {
              if (reading.position == 'Sequence') continue;
              final text = hydrated.readingTexts[reading.reading] ?? '';
              expect(
                text,
                isNot(startsWith('Reading text unavailable')),
                reason:
                    '${sample.isoDate} ${sample.region.code} '
                    '${reading.position}: ${reading.reading}',
              );
            }
          } finally {
            debugPrint = previousDebugPrint;
          }
        },
      );
    }
  });
}

Set<String> _referenceSet(List<DailyReading> readings) =>
    readings.map((reading) => reading.reading).toSet();

final _sourceBackedSamples = <_DisplayedReadingSample>[
  _DisplayedReadingSample(
    date: DateTime(2026, 8, 17),
    region: LiturgicalRegion.nigeria,
    version: BibleVersionType.rsvce,
    source: 'Nigeria weekday lectionary, Monday of Ordinary Time 20 Year II',
    expectedReferences: const {
      'Ezek 24:15-24',
      'Dt 32:18-19, 20, 21',
      'Matt 19:16-22',
    },
    expectedPsalmReference: 'Dt 32:18-19, 20, 21',
    expectedPsalmResponse: 'You forgot God who gave you birth.',
  ),
  _DisplayedReadingSample(
    date: DateTime(2026, 8, 16),
    region: LiturgicalRegion.unitedStates,
    version: BibleVersionType.nabre,
    source: 'USCCB daily readings, 2026-08-16',
    expectedReferences: const {
      'Isa 56:1, 6-7',
      'Ps 67:2-3, 5, 6, 8',
      'Rom 11:13-15, 29-32',
      'Matt 15:21-28',
    },
  ),
  _DisplayedReadingSample(
    date: DateTime(2026, 7, 15),
    region: LiturgicalRegion.englandWales,
    version: BibleVersionType.rsvce,
    source: 'local weekday extract, Wednesday of Ordinary Time 15',
    expectedReferences: const {
      'Isa 10:5-7, 13-16',
      'Ps 94:5-6, 7-8, 9-10, 14-15',
      'Matt 11:25-27',
    },
  ),
  _DisplayedReadingSample(
    date: DateTime(2026, 10, 1),
    region: LiturgicalRegion.nigeria,
    version: BibleVersionType.rsvce,
    source: 'Nigeria missal audit, Our Lady Queen of Nigeria',
    expectedReferences: const {
      'Isa 11:1-10',
      'Ps 72:1-2, 7-8, 12-13, 17',
      'Eph 2:13-22',
      'Matt 2:13-15, 19-23',
    },
  ),
  _DisplayedReadingSample(
    date: DateTime(2030, 12, 25),
    region: LiturgicalRegion.englandWales,
    version: BibleVersionType.rsvce,
    source: 'local solemnity extract, Christmas Day beyond 2026',
    expectedReferences: const {
      'Isa 52:7-10',
      'Ps 98:1, 2-3ab, 3cd-4, 5-6',
      'Heb 1:1-6',
      'John 1:1-18',
    },
  ),
];

class _DisplayedReadingSample {
  final DateTime date;
  final LiturgicalRegion region;
  final BibleVersionType version;
  final String source;
  final Set<String> expectedReferences;
  final String? expectedPsalmReference;
  final String? expectedPsalmResponse;

  const _DisplayedReadingSample({
    required this.date,
    required this.region,
    required this.version,
    required this.source,
    required this.expectedReferences,
    this.expectedPsalmReference,
    this.expectedPsalmResponse,
  });

  String get isoDate =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
