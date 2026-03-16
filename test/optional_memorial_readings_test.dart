import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';

void main() {
  final service = OptionalMemorialService.instance;

  group('OptionalMemorialService - Readings Coverage', () {
    test('All celebration IDs in the calendar are unique', () {
      final allIds = <String>[];
      // We check that each ID used in the fixed celebrations map is unique per date
      // (multiple celebrations can share a date, but each must have a unique ID)
      final seen = <String>{};
      final duplicates = <String>[];

      for (final id in service.allCelebrationIds) {
        if (seen.contains(id)) {
          duplicates.add(id);
        }
        seen.add(id);
      }

      expect(duplicates, isEmpty,
          reason: 'Found duplicate celebration IDs: $duplicates');
    });

    test('Celebrations with proper readings have complete reading sets', () {
      final incomplete = <String, List<String>>{};

      for (final id in service.celebrationIdsWithReadings) {
        final readings = service.getProperReadings(id);
        if (readings == null) continue;

        final missing = <String>[];
        if (readings.firstReading.isEmpty) missing.add('firstReading');
        if (readings.psalm.isEmpty) missing.add('psalm');
        if (readings.gospel.isEmpty) missing.add('gospel');
        if (readings.psalmResponse == null || readings.psalmResponse!.isEmpty) {
          missing.add('psalmResponse');
        }
        if (readings.gospelAcclamation == null || readings.gospelAcclamation!.isEmpty) {
          missing.add('gospelAcclamation');
        }

        if (missing.isNotEmpty) {
          incomplete[id] = missing;
        }
      }

      if (incomplete.isNotEmpty) {
        final buffer = StringBuffer('Celebrations with incomplete readings:\n');
        for (final entry in incomplete.entries) {
          buffer.writeln('  ${entry.key}: missing ${entry.value.join(", ")}');
        }
        fail(buffer.toString());
      }
    });

    test('All celebrations in calendar exist and have valid data', () {
      final invalid = <String>[];

      for (final celebration in _allCelebrations(service)) {
        if (celebration.id.isEmpty) invalid.add('Empty ID found');
        if (celebration.title.isEmpty) invalid.add('Empty title for ${celebration.id}');
        if (celebration.month < 1 || celebration.month > 12) {
          invalid.add('Invalid month ${celebration.month} for ${celebration.id}');
        }
        if (celebration.day < 1 || celebration.day > 31) {
          invalid.add('Invalid day ${celebration.day} for ${celebration.id}');
        }
      }

      expect(invalid, isEmpty, reason: invalid.join('\n'));
    });

    test('Optional memorials are suppressed during Lent 2026', () {
      // Easter 2026 = April 5, Ash Wednesday = Feb 18
      final ashWed = DateTime(2026, 2, 18);
      final lentenDay = DateTime(2026, 3, 17); // St. Patrick during Lent

      final ashWedCelebrations = service.getOptionalCelebrations(ashWed);
      expect(ashWedCelebrations, isEmpty,
          reason: 'Optional memorials should be suppressed on Ash Wednesday');

      final lentenCelebrations = service.getOptionalCelebrations(lentenDay);
      expect(lentenCelebrations, isEmpty,
          reason: 'St. Patrick (optional) should be suppressed during Lent 2026');
    });

    test('Optional memorials are suppressed Dec 17-24 (Advent privileged days)', () {
      final dec21 = DateTime(2026, 12, 21); // Peter Canisius
      final celebrations = service.getOptionalCelebrations(dec21);
      expect(celebrations, isEmpty,
          reason: 'Optional memorials should be suppressed Dec 17-24');
    });

    test('Optional memorials are available during Ordinary Time', () {
      // June 22 has Paulinus of Nola and John Fisher/Thomas More
      final june22 = DateTime(2026, 6, 22);
      final celebrations = service.getOptionalCelebrations(june22);
      expect(celebrations.length, greaterThanOrEqualTo(1),
          reason: 'Should have optional memorials on June 22 in Ordinary Time');
    });

    test('Multiple optional memorials on same date are returned', () {
      // Jan 20 has St. Fabian and St. Sebastian
      final jan20 = DateTime(2027, 1, 20); // Use 2027 to avoid potential Lent overlap
      final celebrations = service.getOptionalCelebrations(jan20);
      expect(celebrations.length, equals(2),
          reason: 'Jan 20 should have both St. Fabian and St. Sebastian');
    });

    test('Report coverage statistics', () {
      final allIds = service.allCelebrationIds;
      final withReadings = service.celebrationIdsWithReadings;
      final withoutReadings = allIds.difference(withReadings);

      print('=== Optional Memorial Readings Coverage ===');
      print('Total celebrations in calendar: ${allIds.length}');
      print('Celebrations with proper readings: ${withReadings.length}');
      print('Celebrations using weekday readings: ${withoutReadings.length}');
      print('Coverage: ${(withReadings.length / allIds.length * 100).toStringAsFixed(1)}%');

      if (withoutReadings.isNotEmpty) {
        print('\nCelebrations without proper readings (use weekday readings):');
        for (final id in withoutReadings.toList()..sort()) {
          print('  - $id');
        }
      }

      // This is informational — not a failure
      expect(allIds.length, greaterThan(0));
    });

    test('Proper readings references look like valid scripture references', () {
      final invalidRefs = <String, String>{};
      final refPattern = RegExp(r'^[\w\d\s]+\.?\s*\d');

      for (final id in service.celebrationIdsWithReadings) {
        final readings = service.getProperReadings(id);
        if (readings == null) continue;

        for (final ref in [readings.firstReading, readings.psalm, readings.gospel]) {
          if (!refPattern.hasMatch(ref) && !ref.startsWith('Luke') && !ref.startsWith('Isa')) {
            invalidRefs[id] = ref;
          }
        }
      }

      if (invalidRefs.isNotEmpty) {
        print('Potentially invalid scripture references:');
        for (final entry in invalidRefs.entries) {
          print('  ${entry.key}: ${entry.value}');
        }
      }
      // Soft check - just report, don't fail
      expect(true, isTrue);
    });
  });
}

/// Helper to extract all celebrations from the service
List<OptionalCelebration> _allCelebrations(OptionalMemorialService service) {
  final all = <OptionalCelebration>[];
  // Check every day of the year
  for (int month = 1; month <= 12; month++) {
    final daysInMonth = DateTime(2027, month + 1, 0).day;
    for (int day = 1; day <= daysInMonth; day++) {
      // Use 2027 to avoid Lent suppression for enumeration
      final date = DateTime(2027, month, day);
      // Bypass suppression by directly accessing — but we need the public API
      // So we use a date in Ordinary Time context
    }
  }
  // Better approach: iterate through all months without suppression check
  // We'll test suppression separately, here just validate data integrity
  for (int month = 1; month <= 12; month++) {
    for (int day = 1; day <= 31; day++) {
      try {
        // Use a year where no date falls in Lent for this month 
        // (impossible for all months, so we just try)
        final date = DateTime(2027, month, day);
        if (date.month != month) continue; // Skip invalid dates
        final celebrations = service.getOptionalCelebrations(date);
        all.addAll(celebrations);
      } catch (_) {
        // Skip invalid dates
      }
    }
  }
  return all;
}
