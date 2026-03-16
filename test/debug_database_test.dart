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
    tempDocsDir = await createTempTestDir('catholic_daily_debug_db_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  group('Debug Database for 4th Sunday of Lent 2026', () {
    test('Check what psalm reference is in database for today', () async {
      final date = DateTime(2026, 3, 15); // 4th Sunday of Lent 2026
      final backend = ReadingsBackendIo();
      final readingFlow = ReadingFlowService.instance;

      // Get raw readings from database
      final rawReadings = await backend.getReadingsForDate(date);
      print('Found ${rawReadings.length} raw readings for $date');
      
      for (final reading in rawReadings) {
        print('Reading: ${reading.reading}');
        print('  Position: ${reading.position}');
        print('  Psalm Response: ${reading.psalmResponse}');
        print('  Gospel Acclamation: ${reading.gospelAcclamation}');
        print('');
      }

      // Get hydrated readings
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: rawReadings);
      print('Hydrated readings:');
      
      for (final reading in hydrated.readings) {
        print('Reading: ${reading.reading}');
        print('  Position: ${reading.position}');
        print('  Psalm Response: ${reading.psalmResponse}');
        print('  Gospel Acclamation: ${reading.gospelAcclamation}');
        print('');
      }
    }, skip: true);
  }, skip: true);
}
