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
    tempDocsDir = await createTempTestDir('catholic_daily_catalog_fix_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  group('Verify Catalog Fix for 4th Sunday of Lent 2026', () {
    test('Should show correct Cycle C psalm response after catalog integration', () async {
      final date = DateTime(2026, 3, 15); // 4th Sunday of Lent 2026
      final backend = ReadingsBackendIo();
      final readingFlow = ReadingFlowService.instance;

      // Get hydrated readings (this should use the catalog)
      final hydrated = await readingFlow.hydrateReadingSet(date: date, readings: await backend.getReadingsForDate(date));
      
      final psalmReading = hydrated.readings.where((r) => r.position?.toLowerCase().contains('psalm') == true).first;
      
      print('Psalm reading: ${psalmReading.reading}');
      print('Psalm response: ${psalmReading.psalmResponse}');
      
      // 2026 = Cycle A → Lent 4 A → Psalm 23 → "The Lord is my shepherd..."
      // The catalog must override the stale DB response
      expect(psalmReading.psalmResponse, equals('The Lord is my shepherd; there is nothing I shall want.'));
      expect(psalmReading.psalmResponse, isNot(equals('I shall live in the house of the Lord all the days of my life.')));
    });
  });
}
