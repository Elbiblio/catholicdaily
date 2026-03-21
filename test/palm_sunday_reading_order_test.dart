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
    tempDocsDir = await createTempTestDir('catholic_daily_palm_sunday_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  final backend = ReadingsBackendIo();
  final readingFlow = ReadingFlowService.instance;

  group('Palm Sunday reading order', () {
    test('Palm Sunday 2026 has correct reading order: Gospel at Procession, First Reading, Psalm, Second Reading, Gospel', () async {
      // Palm Sunday 2026 is March 29
      final date = DateTime(2026, 3, 29);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 5);

      // 1. Gospel at Procession should be first
      expect(readings[0].position, 'Gospel at Procession');
      expect(readings[0].reading, 'Matt 21:1-11');

      // 2. First Reading
      expect(readings[1].position, 'First Reading');
      expect(readings[1].reading, 'Isa 50:4-7');

      // 3. Responsorial Psalm
      expect(readings[2].position, 'Responsorial Psalm');
      expect(readings[2].reading, 'Ps 22:8-9, 17-18, 19-20, 23-24');
      expect(readings[2].psalmResponse, 'My God, my God, why have you abandoned me?');

      // 4. Second Reading
      expect(readings[3].position, 'Second Reading');
      expect(readings[3].reading, 'Phil 2:6-11');

      // 5. Gospel (Passion)
      expect(readings[4].position, 'Gospel');
      expect(readings[4].reading, 'Matt 26:14-27:66');
      final acclamation = readings[4].gospelAcclamation ?? '';
      expect(acclamation.contains('Phil 2:8-9') || acclamation.contains('obedient unto death'), isTrue);
    });

    test('Palm Sunday 2027 (Year B) has correct cycle-specific readings', () async {
      // Palm Sunday 2027 is March 21 (Year B)
      final date = DateTime(2027, 3, 21);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 5);

      // Gospel at Procession - Year B uses Mark
      expect(readings[0].position, 'Gospel at Procession');
      expect(readings[0].reading, 'Mark 11:1-10');

      // Passion Gospel - Year B uses Mark
      expect(readings[4].position, 'Gospel');
      expect(readings[4].reading, 'Mark 14:1-15:47');
    });

    test('Palm Sunday 2028 (Year C) has correct cycle-specific readings', () async {
      // Palm Sunday 2028 is April 9 (Year C)
      final date = DateTime(2028, 4, 9);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 5);

      // Gospel at Procession - Year C uses Luke
      expect(readings[0].position, 'Gospel at Procession');
      expect(readings[0].reading, 'Luke 19:28-40');

      // Passion Gospel - Year C uses Luke
      expect(readings[4].position, 'Gospel');
      expect(readings[4].reading, 'Luke 22:14-23:56');
    });
  });
}
