import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'dart:io';
import 'helpers/test_helpers.dart';

/// Comprehensive 2026 liturgical year verification test.
///
/// Validates the full CSV-backed reading resolution chain against
/// authoritative USCCB readings for 2026 (Cycle A, Easter = April 5).
///
/// Key dates tested:
/// - Ordinary weekdays (period-notation CSV rows)
/// - Sundays (colon-notation CSV rows)
/// - Advent special days (Dec 17-24)
/// - Ash Wednesday (multiple alternate psalm rows)
/// - Holy Week movable feasts (Palm Sunday, Holy Thursday, Good Friday)
/// - Easter Vigil
/// - Easter Octave (multiple alternate psalm rows)
/// - Movable solemnities (Pentecost, Trinity, Corpus Christi, Sacred Heart)
/// - Holy Family (movable feast with dateRule, no fixed month/day)
/// - Christ the King
/// - Fixed feasts from memorial_feasts.csv
void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;
  late ReadingsBackendIo backend;
  late ReadingFlowService readingFlow;
  late OfflineOrdoLookupService ordoLookup;
  late CsvReadingsResolverService csvResolver;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_2026_verification_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    backend = ReadingsBackendIo();
    readingFlow = ReadingFlowService.instance;
    ordoLookup = OfflineOrdoLookupService.instance;
    csvResolver = CsvReadingsResolverService.instance;
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  // Helper: resolve readings and return position->reference map
  Future<Map<String, String>> readingsFor(DateTime date) async {
    final readings = await backend.getReadingsForDate(date);
    final map = <String, String>{};
    for (final r in readings) {
      map[r.position ?? 'unknown'] = r.reading;
    }
    return map;
  }

  // Helper: get liturgical day title
  String titleFor(DateTime date) {
    return ordoLookup.resolve(date).title;
  }

  group('2026 Liturgical Calendar Fundamentals', () {
    test('Easter 2026 is April 5', () {
      final title = titleFor(DateTime(2026, 4, 5));
      expect(title, contains('Easter Sunday'));
    });

    test('Sunday cycle is A for 2026', () async {
      final yearVars = await OrdoResolverService.instance
          .resolveYearVariables(DateTime(2026, 3, 15));
      expect(yearVars.sundayCycle, 'A');
    });

    test('Ash Wednesday is February 18, 2026', () {
      final title = titleFor(DateTime(2026, 2, 18));
      expect(title, 'Ash Wednesday');
    });

    test('Palm Sunday is March 29, 2026', () {
      final title = titleFor(DateTime(2026, 3, 29));
      expect(title, contains('Palm Sunday'));
    });

    test('Pentecost is May 24, 2026', () {
      final title = titleFor(DateTime(2026, 5, 24));
      expect(title, contains('Pentecost'));
    });

    test('Christ the King is November 22, 2026', () {
      final title = titleFor(DateTime(2026, 11, 22));
      expect(title, contains('King of the Universe'));
    });
  });

  group('Ordinary Weekday Readings (period-notation CSV)', () {
    test('Monday of Week 1 in Ordinary Time resolves readings', () async {
      // Jan 12, 2026 is Monday of OT Week 1
      final readings = await readingsFor(DateTime(2026, 1, 12));
      expect(readings, isNotEmpty, reason: 'Should resolve weekday readings');
      expect(readings.keys, contains('First Reading'));
      expect(readings.keys, contains('Responsorial Psalm'));
      expect(readings.keys, contains('Gospel'));
      // Should not have duplicate psalm entries
      final psalmCount = readings.keys.where((k) => k.contains('Psalm')).length;
      expect(psalmCount, 1, reason: 'Should have exactly one psalm');
    });

    test('Weekday psalm reference uses colon notation after normalization', () async {
      final readings = await readingsFor(DateTime(2026, 1, 12));
      final psalmRef = readings['Responsorial Psalm'] ?? '';
      expect(psalmRef, isNotEmpty);
      // After normalization, period-notation psalms should have colon for chapter:verse
      if (psalmRef.contains(':')) {
        // Verify no space after colon (the bug we fixed)
        expect(psalmRef, isNot(matches(RegExp(r':\s\d'))),
            reason: 'Should not have space after colon in psalm reference');
      }
    });

    test('Wednesday March 18, 2026 resolves Lent weekday readings (regression)', () async {
      final readings = await readingsFor(DateTime(2026, 3, 18));
      expect(readings, isNotEmpty,
          reason: 'Reported regression: date returned no readings');
      expect(readings['First Reading'], 'Isa 49:8-15');
      expect(readings['Gospel'], isNotEmpty);
    });

    test('Lent Saturdays expose shorter alternatives and normalize references', () async {
      final lent4Saturday = await backend.getReadingsForDate(DateTime(2026, 3, 21));
      final lent5Saturday = await backend.getReadingsForDate(DateTime(2026, 3, 28));

      expect(lent4Saturday.any((r) => r.position == 'Gospel'), isTrue);
      expect(lent4Saturday.any((r) => r.position == 'Gospel (alternative)'), isTrue);

      expect(lent5Saturday.any((r) => r.position == 'First Reading'), isTrue);
      expect(lent5Saturday.any((r) => r.position == 'Gospel'), isTrue);
      // The Lent 4 Saturday pair includes the known shorter gospel option.
      // Lent 5 Saturday may or may not carry alternatives in source data.

      final affected = [...lent4Saturday, ...lent5Saturday]
          .where((r) => (r.position ?? '').toLowerCase().contains('reading') || (r.position ?? '').toLowerCase().contains('gospel'));

      for (final row in affected) {
        expect(row.reading.toLowerCase(), isNot(contains('(s h o')),
            reason: 'Malformed shorter marker should be stripped: ${row.reading}');
      }
    }, skip: 'Defunct broad verification assumption from older Lent shorter-option resolver path.');

    test('Lent shorter-option gospels load text (no unavailable message)', () async {
      final readings = await backend.getReadingsForDate(DateTime(2026, 3, 21));
      final alternatives = readings.where((r) => r.position == 'Gospel (alternative)').toList();
      expect(alternatives, isNotEmpty);

      for (final gospel in alternatives) {
        final text = await backend.getReadingText(
          gospel.reading,
          psalmResponse: gospel.psalmResponse,
          incipit: gospel.incipit,
        );
        expect(text, isNot(contains('Reading text unavailable')),
            reason: 'Alternative gospel should parse and load: ${gospel.reading}');
      }
    }, skip: 'Defunct broad verification assumption from older Lent shorter-option resolver path.');
  });

  group('Sunday Readings (colon-notation CSV, Cycle A)', () {
    test('1st Sunday of Advent 2025 (start of Cycle A)', () async {
      // Nov 30, 2025 — 1st Sunday of Advent, Cycle A
      final readings = await readingsFor(DateTime(2025, 11, 30));
      expect(readings, isNotEmpty);
      expect(readings['First Reading'], contains('Isa'));
      expect(readings['Gospel'], contains('Matt'));
    });

    test('3rd Sunday of Lent 2026 (Cycle A)', () async {
      // Mar 8, 2026
      final readings = await readingsFor(DateTime(2026, 3, 8));
      expect(readings, isNotEmpty);
      expect(readings['First Reading'], 'Exod 17:3-7');
      expect(readings['Gospel'], 'John 4:5-42');
    });

    test('4th Sunday of Lent 2026 has correct psalm response', () async {
      final readings = await backend.getReadingsForDate(DateTime(2026, 3, 15));
      final hydrated = await readingFlow.hydrateReadingSet(
        date: DateTime(2026, 3, 15),
        readings: readings,
      );
      final psalm = hydrated.readings.firstWhere(
        (r) => r.position?.contains('Psalm') == true,
        orElse: () => throw StateError('No psalm found'),
      );
      expect(psalm.psalmResponse, isNotNull);
      expect(psalm.psalmResponse, isNotEmpty);
    });
  });

  group('Advent Special Days (Dec 17-24)', () {
    test('December 17 readings resolve correctly', () async {
      final readings = await readingsFor(DateTime(2025, 12, 17));
      expect(readings, isNotEmpty);
      expect(readings['First Reading'], isNotEmpty);
      expect(readings['Gospel'], contains('Matt'));
      // Psalm should not have space-after-colon bug
      final psalmRef = readings['Responsorial Psalm'] ?? '';
      expect(psalmRef, isNot(contains(': ')),
          reason: 'Psalm reference should not have space after colon');
    });

    test('December 24 (Christmas Eve) readings resolve correctly', () async {
      final readings = await readingsFor(DateTime(2025, 12, 24));
      expect(readings, isNotEmpty);
    });
  });

  group('Ash Wednesday (multiple alternate psalms)', () {
    test('Ash Wednesday produces exactly 3 readings + psalm', () async {
      // Feb 18, 2026
      final readings = await readingsFor(DateTime(2026, 2, 18));
      expect(readings, isNotEmpty);
      expect(readings['First Reading'], isNotEmpty);
      expect(readings['Responsorial Psalm'], isNotEmpty);
      expect(readings['Gospel'], isNotEmpty);
      // Should have exactly one psalm despite 3 alternate rows in CSV
      final psalmCount = readings.keys.where((k) => k.contains('Psalm')).length;
      expect(psalmCount, 1,
          reason: 'Should deduplicate to one psalm despite 3 alternate CSV rows');
    });
  });

  group('Holy Week Movable Feasts', () {
    test('Palm Sunday (March 29, 2026) resolves authoritative readings', () async {
      final readings = await readingsFor(DateTime(2026, 3, 29));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 3, 29));
      expect(title, contains('Palm Sunday'));
      // Palm Sunday readings should include Passion Gospel
      expect(readings['First Reading'], isNotEmpty);
      expect(readings['Gospel'], isNotEmpty);
    });

    test('Palm Sunday starts with processional gospel before first reading', () async {
      final ordered = await backend.getReadingsForDate(DateTime(2026, 3, 29));
      expect(ordered, isNotEmpty);
      expect(ordered.first.position, 'Gospel at Procession');
      expect(
        ordered.first.reading,
        anyOf('Matt 21:1-11', 'Mark 11:1-10', 'Luke 19:28-40'),
      );
    });

    test('Holy Thursday (April 2, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 4, 2));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 4, 2));
      expect(title, contains('Holy Thursday'));
    });

    test('Good Friday (April 3, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 4, 3));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 4, 3));
      expect(title, contains('Passion'));
    });
  });

  group('Easter Vigil and Easter Sunday', () {
    test('Easter Vigil (April 4, 2026) has full liturgical sequence', () async {
      final readings = await readingsFor(DateTime(2026, 4, 4));
      expect(readings.length, greaterThanOrEqualTo(8),
          reason: 'Easter Vigil should have many readings');
      expect(readings.values.any((r) => r.contains('Gen')), true,
          reason: 'Should include Genesis reading');
      expect(readings.values.any((r) => r.contains('Exod')), true,
          reason: 'Should include Exodus reading');
      expect(readings.keys, contains('Gospel'));
    });

    test('Easter Sunday (April 5, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 4, 5));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 4, 5));
      expect(title, contains('Easter Sunday'));
    });

    test('Easter Octave Wednesday (April 8, 2026) deduplicates psalm rows', () async {
      // Easter Octave Wed has 6 alternate psalm rows in CSV
      final readings = await readingsFor(DateTime(2026, 4, 8));
      expect(readings, isNotEmpty);
      final psalmCount = readings.keys.where((k) => k.contains('Psalm')).length;
      expect(psalmCount, 1,
          reason: 'Should deduplicate to one psalm despite 6 alternate CSV rows');
    });
  });

  group('Post-Easter Movable Solemnities', () {
    test('Pentecost (May 24, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 5, 24));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 5, 24));
      expect(title, contains('Pentecost'));
    });

    test('Trinity Sunday (May 31, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 5, 31));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 5, 31));
      expect(title, contains('Trinity'));
    });

    test('Corpus Christi (June 7, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 6, 7));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 6, 7));
      expect(title, contains('Body and Blood'));
    });

    test('Sacred Heart (June 12, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 6, 12));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 6, 12));
      expect(title, contains('Sacred Heart'));
    });
  });

  group('Christmas Season Movable Feasts', () {
    test('Holy Family (Dec 27, 2026 — Sunday within Christmas Octave)', () async {
      // In 2026, Dec 25 is Friday, so Dec 27 is Sunday
      final date = DateTime(2026, 12, 27);
      final title = titleFor(date);
      expect(title, contains('Holy Family'),
          reason: 'Should resolve Holy Family feast title for Sunday within Christmas Octave');
      final readings = await readingsFor(date);
      expect(readings, isNotEmpty,
          reason: 'Holy Family readings should resolve correctly');
      expect(readings['First Reading'], isNotEmpty);
    });
  });

  group('Christ the King', () {
    test('Christ the King (Nov 22, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 11, 22));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 11, 22));
      expect(title, contains('King of the Universe'));
    });
  });

  group('Fixed-date feasts from memorial_feasts.csv', () {
    test('Immaculate Conception (Dec 8) resolves readings', () async {
      final readings = await readingsFor(DateTime(2025, 12, 8));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2025, 12, 8));
      expect(title, contains('Immaculate Conception'));
    });

    test('Assumption (Aug 15, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 8, 15));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 8, 15));
      expect(title, contains('Assumption'));
    });

    test('All Saints (Nov 1, 2026) resolves readings', () async {
      final readings = await readingsFor(DateTime(2026, 11, 1));
      expect(readings, isNotEmpty);
      final title = titleFor(DateTime(2026, 11, 1));
      expect(title, contains('All Saints'));
    });
  });

  group('Normalization Correctness', () {
    test('Period notation correctly normalized (no space-after-colon)', () async {
      // Sample a weekday that uses period notation
      final readings = await readingsFor(DateTime(2026, 1, 13)); // Tuesday OT1
      for (final entry in readings.entries) {
        if (entry.value.contains(':')) {
          expect(entry.value, isNot(matches(RegExp(r'Ps \d+: \d'))),
              reason: '${entry.key}: should not have space after colon: ${entry.value}');
        }
      }
    });

    test('Mid-string periods preserved (e.g., verse separators)', () async {
      // Readings with "and 12.13" patterns should NOT convert to "and 12:13"
      final readings = await csvResolver.resolve(DateTime(2026, 4, 4)); // Easter Vigil
      for (final r in readings) {
        if (r.reading.contains('and ')) {
          expect(r.reading, isNot(matches(RegExp(r'and \d+:\d+'))),
              reason: 'Mid-string periods should not be converted to colons: ${r.reading}');
        }
      }
    });
  });

  group('Full Year Coverage Spot Check', () {
    test('Every month in 2026 resolves at least some readings', () async {
      for (var month = 1; month <= 12; month++) {
        // Pick the 15th of each month
        final date = DateTime(2026, month, 15);
        final readings = await readingsFor(date);
        expect(readings, isNotEmpty,
            reason: '${date.toIso8601String().split("T")[0]} should have readings');
      }
    });
  });
}
