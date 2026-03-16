import 'package:flutter_test/flutter_test.dart';
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

  group('Special day readings regression', () {
    test('Easter Vigil keeps liturgical sequence and psalm response attaches to psalm rows', () async {
      final date = DateTime(2026, 4, 4);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 17);
      expect(readings.first.reading, 'Gen 1:1-2:2');
      expect(readings.first.position, 'First Reading');

      expect(readings[1].reading, 'Ps 104:1-35');
      expect(readings[1].position, 'Responsorial Psalm');
      expect(readings[1].psalmResponse, isNotNull);
      expect(
        readings[1].psalmResponse!.toLowerCase(),
        anyOf(contains('lord, send out your spirit'), contains('lord, send forth your spirit')),
      );

      expect(readings[2].reading, 'Gen 22:1-18');
      expect(readings[2].position, 'Second Reading');
      expect(
        readings[2].psalmResponse == null || readings[2].psalmResponse!.trim().isEmpty,
        isTrue,
      );

      expect(readings[14].reading, 'Rom 6:3-11');
      expect(readings[14].position, 'Epistle');

      expect(readings[15].reading, 'Ps 118:1-23');
      expect(readings[15].position, 'Alleluia Psalm');
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

      expect(readings[2].position, 'Gospel');
      expect(readings[2].reading, 'Luke 1:67-79');
      expect(readings[2].gospelAcclamation, isNotNull);
      expect(readings[2].gospelAcclamation!.trim(), isNotEmpty);
      // Catalog (authoritative) provides the Advent Dec 24 acclamation
      expect(
        readings[2].gospelAcclamation!.toLowerCase(),
        contains('come, radiant dawn'),
      );
    });

    test('Christmas Eve fallback acclamation resolves even when DB value is missing', () async {
      final date = DateTime(2024, 12, 24);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;
      final gospel = readings.last;

      expect(gospel.position, 'Gospel');
      expect(gospel.reading, 'Luke 1:67-79');
      expect(gospel.gospelAcclamation, isNotNull);
      expect(gospel.gospelAcclamation!.trim(), isNotEmpty);
      expect(
        gospel.gospelAcclamation!.startsWith('Reading text unavailable'),
        isFalse,
      );
    });
  });
}
