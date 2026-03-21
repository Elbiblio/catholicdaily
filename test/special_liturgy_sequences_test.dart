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
    tempDocsDir = await createTempTestDir('catholic_daily_special_liturgy_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  final backend = ReadingsBackendIo();
  final readingFlow = ReadingFlowService.instance;

  group('Special Liturgy Sequences', () {
    test('Easter Vigil has proper sequence: 7 OT readings + Epistle + Gospel, each with psalm', () async {
      final date = DateTime(2026, 4, 4);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 17);

      // Verify the complete structure: Reading + Psalm pattern
      final expectedStructure = [
        ['First Reading', 'Gen 1:1-2:2'],
        ['Responsorial Psalm', 'Ps 104:'],
        ['Second Reading', 'Gen 22:1-18'],
        ['Responsorial Psalm', 'Ps 16:'],
        ['Third Reading', 'Exod 14:15-15:1'],
        ['Responsorial Psalm', 'Exod 15:'],
        ['Fourth Reading', 'Isa 54:5-14'],
        ['Responsorial Psalm', 'Ps 30:'],
        ['Fifth Reading', 'Isa 55:1-11'],
        ['Responsorial Psalm', 'Isa 12:'],
        ['Sixth Reading', 'Bar 3:9-15, 32-4:4'],
        ['Responsorial Psalm', 'Ps 19:'],
        ['Seventh Reading', 'Ezek 36:16-28'],
        ['Responsorial Psalm', 'Ps 42:'],
        ['Reading 8', 'Rom 6:3-11'], // Epistle
        ['Responsorial Psalm', 'Ps 118:'],
        ['Gospel', 'Matt 28:1-10'],
      ];

      for (int i = 0; i < expectedStructure.length; i++) {
        expect(readings[i].position, expectedStructure[i][0]);
        expect(readings[i].reading, startsWith(expectedStructure[i][1]));
        
        // Every psalm should have a response, every reading should not
        if (readings[i].position!.contains('Psalm')) {
          expect(readings[i].psalmResponse, isNotNull);
          expect(readings[i].psalmResponse!.isNotEmpty, isTrue);
        } else {
          expect(readings[i].psalmResponse, isNull);
        }
      }

      // Verify gospel has proper acclamation
      expect(readings.last.gospelAcclamation, isNotNull);
      expect(readings.last.gospelAcclamation!.isNotEmpty, isTrue);
    });

    test('Pentecost Sunday 2026 has proper sequence and cycle-specific readings', () async {
      // Pentecost 2026 is May 24 (Year A)
      final date = DateTime(2026, 5, 24);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 6); // First Reading, Psalm, Second Reading, Sequence, Gospel, Alternative Gospel

      // 1. First Reading
      expect(readings[0].position, 'First Reading');
      expect(readings[0].reading, 'Acts 2:1-11');

      // 2. Responsorial Psalm
      expect(readings[1].position, 'Responsorial Psalm');
      expect(readings[1].reading, 'Ps 104:1, 24, 29-30, 31, 34');
      expect(readings[1].psalmResponse, 'Lord, send out your Spirit, and renew the face of the earth.');

      // 3. Second Reading (Year A uses 1 Cor)
      expect(readings[2].position, 'Second Reading');
      expect(readings[2].reading, '1 Cor 12:3b-7, 12-13');

      // 4. Sequence (Veni Sancte Spiritus)
      expect(readings[3].position, 'Sequence');
      expect(readings[3].reading, 'Veni Sancte Spiritus (Sequence)');

      // 5. Gospel (Year A uses John 20:19-23)
      expect(readings[4].position, 'Gospel');
      expect(readings[4].reading, 'John 20:19-23');
      expect(readings[4].gospelAcclamation, 'Come, Holy Spirit, fill the hearts of your faithful and kindle in them the fire of your love.');
    });

    test('Pentecost Sunday 2027 (Year B) has correct cycle-specific readings', () async {
      // Pentecost 2027 is May 16 (Year B)
      final date = DateTime(2027, 5, 16);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 6); // First Reading, Psalm, Second Reading, Sequence, Gospel, Alternative Gospel

      // First Reading is the same for all cycles
      expect(readings[0].reading, 'Acts 2:1-11');

      // Second Reading (Year B uses 1 Cor)
      expect(readings[2].reading, '1 Cor 12:3b-7, 12-13');

      // Sequence (Veni Sancte Spiritus)
      expect(readings[3].position, 'Sequence');
      expect(readings[3].reading, 'Veni Sancte Spiritus (Sequence)');

      // Gospel (Year B uses John 20:19-23)
      expect(readings[4].reading, 'John 20:19-23');
    });

    test('Pentecost Sunday 2028 (Year C) has correct cycle-specific readings', () async {
      // Pentecost 2028 is June 4 (Year C)
      final date = DateTime(2028, 6, 4);
      final raw = await backend.getReadingsForDate(date);
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: raw);
      final readings = hydrated.readings;

      expect(readings.length, 5); // First Reading, Psalm, Second Reading, Sequence, Gospel (no alternative in Year C)

      // First Reading
      expect(readings[0].reading, 'Acts 2:1-11');

      // Second Reading (Year C uses Romans)
      expect(readings[2].reading, 'Rom 8:8-17');

      // Sequence (Veni Sancte Spiritus)
      expect(readings[3].position, 'Sequence');
      expect(readings[3].reading, 'Veni Sancte Spiritus (Sequence)');

      // Gospel (Year C uses John 14)
      expect(readings[4].reading, 'John 14:15-16, 23b-26');
    });
  });
}
