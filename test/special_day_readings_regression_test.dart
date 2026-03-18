import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'helpers/test_helpers.dart';
import 'dart:io';

void main() {
  setupFlutterTestEnvironment();
  
  late Directory tempDocsDir;
  late Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_special_days_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  final backend = ReadingsBackendIo();
  final readingFlow = ReadingFlowService.instance;
  final alternateReadings = AlternateReadingsService.instance;

  group('Special day readings regression', () {
    test('Easter Vigil keeps liturgical sequence and psalm response attaches to psalm rows', () async {
      final date = DateTime(2026, 4, 4);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 17);
      expect(readings.first.reading, 'Gen 1:1-2:2');
      expect(readings.first.position, 'First Reading');

      expect(readings[1].reading, startsWith('Ps 104:'));
      expect(readings[1].position, 'Responsorial Psalm');
      expect(readings[1].psalmResponse, isNotNull);
      expect(
        readings[1].psalmResponse!.trim(),
        isNotEmpty,
      );

      expect(readings[2].reading, 'Gen 22:1-18');
      expect(readings[2].position, 'Second Reading');
      expect(
        readings[2].psalmResponse == null || readings[2].psalmResponse!.trim().isEmpty,
        isTrue,
      );

      expect(readings[14].reading, 'Rom 6:3-11');
      expect(readings[14].position, 'Reading 8');

      expect(readings[15].reading, startsWith('Ps 118:'));
      expect(readings[15].position, 'Responsorial Psalm');
      expect(readings[15].psalmResponse, isNotNull);

      expect(readings[16].position, 'Gospel');
      expect(readings[16].reading, anyOf('Matt 28:1-10', 'Mark 16:1-7', 'Luke 24:1-12'));
      expect(
        readings[16].gospelAcclamation == null || !readings[16].gospelAcclamation!.startsWith('Reading text unavailable'),
        isTrue,
      );
    });

    test('Christmas Eve displays three readings with psalm and gospel metadata on the correct rows', () async {
      final date = DateTime(2026, 12, 24);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;
      final gospel = readings.firstWhere(
        (reading) => (reading.position ?? '').toLowerCase() == 'gospel',
      );

      expect(readings.length, 3);

      expect(readings[0].position, 'First Reading');
      expect(readings[0].reading, '2 Sam 7:1-5, 8b-11, 14a, 16');
      expect(readings[0].psalmResponse, isNull);

      expect(readings[1].position, 'Responsorial Psalm');
      expect(readings[1].reading, 'Ps 89:2-3, 4-5, 27+29');
      expect(readings[1].psalmResponse, isNotNull);
      expect(
        readings[1].psalmResponse!.toLowerCase(),
        contains('for ever i will sing the goodness of the lord'),
      );

      expect(gospel.reading, 'Luke 1:67-79');
      expect(gospel.gospelAcclamation, isNotNull);
      expect(gospel.gospelAcclamation!.trim(), isNotEmpty);
      expect(
        gospel.gospelAcclamation!.toLowerCase(),
        contains('word of god became flesh'),
      );
    });

    test('Christmas Eve fallback acclamation resolves even when DB value is missing', () async {
      final date = DateTime(2024, 12, 24);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;
      final gospel = readings.firstWhere(
        (reading) => (reading.position ?? '').toLowerCase() == 'gospel',
      );

      expect(gospel.position, 'Gospel');
      expect(gospel.reading, 'Luke 1:67-79');
      expect(gospel.gospelAcclamation, isNotNull);
      expect(gospel.gospelAcclamation!.trim(), isNotEmpty);
      expect(
        gospel.gospelAcclamation!.startsWith('Reading text unavailable'),
        isFalse,
      );
    });

    test('Saint Joseph solemnity on March 19, 2026 overrides Lenten weekday readings', () async {
      final date = DateTime(2026, 3, 19);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 5);

      expect(readings[0].position, 'First Reading');
      expect(readings[0].reading, '2 Sam 7:4-5a, 12-14a, 16');

      expect(readings[1].position, 'Responsorial Psalm');
      expect(readings[1].reading, 'Ps 89:2-3, 4-5, 27, 29');
      expect(readings[1].psalmResponse, 'The son of David will live for ever.');

      expect(readings[2].position, 'Second Reading');
      expect(readings[2].reading, 'Rom 4:13, 16-18, 22');

      expect(readings[3].position, 'Gospel');
      expect(readings[3].reading, 'Matt 1:16, 18-21, 24a');
      expect(readings[3].gospelAcclamation, isNotNull);
      expect(readings[3].gospelAcclamation, isNot('Ps 84:5'));
      expect(
        readings[3].gospelAcclamation!.toLowerCase(),
        contains('blessed are'),
      );

      expect(readings[4].position, 'Gospel (alternative)');
      expect(readings[4].reading, 'Luke 2:41-51a');
    });

    test('March 19, 2026 does not reuse previous day readings', () async {
      final march18 = await backend.getReadingsForDate(DateTime(2026, 3, 18));
      final march19 = await backend.getReadingsForDate(DateTime(2026, 3, 19));

      expect(march18, isNotEmpty);
      expect(march19, isNotEmpty);

      final march18Refs = march18.map((reading) => reading.reading).toSet();
      final march19Refs = march19.map((reading) => reading.reading).toSet();

      expect(march19Refs.contains('2 Sam 7:4-5a, 12-14a, 16'), isTrue);
      expect(march19Refs.contains('Matt 1:16, 18-21, 24a'), isTrue);
      expect(march19Refs.intersection(march18Refs).contains('John 5:31-47'), isFalse);
    });

    test('March 17, 2026 memorial gospel rendering uses Jesus in the opening clause', () async {
      final date = DateTime(2026, 3, 17);
      final sets = await alternateReadings.getAvailableReadingSets(date);
      final patrickSet = sets.firstWhere(
        (set) => set.celebration?.id == 'patrick_of_ireland',
      );
      final hydrated = await readingFlow.hydrateReadingSet(
        date: date,
        readings: patrickSet.readings,
      );
      final readings = hydrated.readings;

      final gospel = readings.firstWhere(
        (reading) => (reading.position ?? '').toLowerCase() == 'gospel',
      );

      final rendered = await backend.getReadingText(
        gospel.reading,
        psalmResponse: gospel.psalmResponse,
        incipit: gospel.incipit,
      );

      expect(gospel.reading, equals('Luke 5:1-11'));
      expect(rendered, startsWith('At that time:'));
      expect(rendered, contains('While the people pressed upon Jesus'));
      expect(rendered, isNot(contains('While the people pressed upon him')));
    });
  });
}
