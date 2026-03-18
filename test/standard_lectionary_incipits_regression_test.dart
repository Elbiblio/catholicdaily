import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'dart:io';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  late CsvReadingsResolverService csvResolver;
  late Directory tempDocsDir;
  late void Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_incipits_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
    csvResolver = CsvReadingsResolverService.instance;
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  DailyReading? byPosition(List<DailyReading> readings, String position) {
    for (final r in readings) {
      if (r.position == position) return r;
    }
    return null;
  }

  group('Standard lectionary incipits', () {
    test('Lent weekday first reading incipit resolves (Isa 65:17-21)', () async {
      // Monday of the Fourth Week of Lent in 2026.
      final date = DateTime(2026, 3, 16);
      final readings = await csvResolver.resolve(date);
      expect(readings, isNotEmpty);

      final first = byPosition(readings, 'First Reading');
      expect(first, isNotNull);
      expect(first!.reading, 'Isa 65:17-21');
      expect(first.incipit, isNotNull);
      expect(first.incipit!, startsWith('Thus says the Lord'));
    });

    test('Lent weekday gospel incipit avoids contextless opening (John 7:1-2, 10, 25-30)', () async {
      // Friday of the Fourth Week of Lent in 2026.
      final date = DateTime(2026, 3, 20);
      final readings = await csvResolver.resolve(date);
      expect(readings, isNotEmpty);

      final first = byPosition(readings, 'First Reading');
      expect(first, isNotNull);
      expect(first!.reading, 'Wisdom 2:1a, 12-22');
      expect(first.incipit, isNotNull);
      expect(first.incipit!, startsWith('The ungodly reasoned unsoundly'));

      final gospel = byPosition(readings, 'Gospel');
      expect(gospel, isNotNull);
      expect(gospel!.reading, 'John 7:1-2, 10, 25-30');
      expect(gospel.incipit, isNotNull);
      expect(gospel.incipit!.toLowerCase(), startsWith('jesus went about in galilee'));
    });
  });
}
