import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';

/// Verifies the resolver returns correct, non-garbage readings for a range of
/// randomized dates (including the specific case the user reported broken:
/// 2026-04-15 should show Acts 5:17-26, not Acts 2:1-11).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Ensure asset bundle is used (not network). Tests use DefaultAssetBundle.
  // For rootBundle, flutter_test provides a ServicesBinding with asset bundle.

  // Register asset bundle manifest loader through the flutter test binding.
  // This is normally required when loading non-standard asset paths.

  group('CsvReadingsResolverService - randomized dates', () {
    late CsvReadingsResolverService resolver;

    setUpAll(() async {
      // Populate mock bundle expectations if needed
      resolver = CsvReadingsResolverService.instance;
    });

    test('2026-04-15 (Easter Week 2 Wednesday) returns Acts 5:17-26', () async {
      final readings = await resolver.resolve(DateTime(2026, 4, 15));
      expect(readings, isNotEmpty, reason: 'Should resolve readings for today');

      final first = readings.firstWhere(
        (r) => (r.position ?? '').toLowerCase().contains('first reading'),
        orElse: () => throw StateError('No first reading resolved'),
      );
      expect(first.reading, contains('Acts 5'),
          reason: 'Easter Week 2 Wednesday first reading must be Acts 5:17-26');
      expect(first.reading.contains('Acts 2'), isFalse,
          reason: 'Must not be Pentecost reading Acts 2:1-11');

      // Must not contain invalid truncated references like "22-23"
      for (final r in readings) {
        final ref = r.reading;
        expect(
          RegExp(r'^\s*\d+[-:,\s]').hasMatch(ref) && !RegExp(r'^[A-Za-z]|^\d+\s+[A-Za-z]').hasMatch(ref),
          isFalse,
          reason: 'Reading "$ref" looks like truncated/malformed reference',
        );
      }
    });

    test('All resolved readings have a book-name prefix', () async {
      final randomDates = <DateTime>[
        DateTime(2026, 1, 1),   // Mary Mother of God
        DateTime(2026, 1, 6),   // Epiphany (actually observed on Sunday)
        DateTime(2026, 2, 18),  // Ash Wednesday 2026
        DateTime(2026, 3, 29),  // Palm Sunday 2026
        DateTime(2026, 4, 2),   // Holy Thursday 2026
        DateTime(2026, 4, 3),   // Good Friday 2026
        DateTime(2026, 4, 5),   // Easter Sunday 2026
        DateTime(2026, 4, 6),   // Easter Monday (Octave)
        DateTime(2026, 4, 12),  // Divine Mercy Sunday
        DateTime(2026, 4, 15),  // Easter Wed week 2
        DateTime(2026, 5, 24),  // Pentecost 2026
        DateTime(2026, 6, 7),   // Holy Trinity 2026
        DateTime(2026, 6, 28),  // Ordinary Time Sunday
        DateTime(2026, 8, 15),  // Assumption
        DateTime(2026, 11, 1),  // All Saints
        DateTime(2026, 12, 8),  // Immaculate Conception
        DateTime(2026, 12, 25), // Christmas
        DateTime(2026, 7, 15),  // Random weekday in Ordinary Time
        DateTime(2026, 10, 30), // Random weekday
        DateTime(2026, 11, 25), // Random weekday
      ];

      for (final date in randomDates) {
        final readings = await resolver.resolve(date);
        if (readings.isEmpty) {
          fail('No readings resolved for ${date.toIso8601String()}');
        }
        for (final r in readings) {
          final ref = r.reading.trim();
          // Sequence is a special literal like "Veni Sancte Spiritus (Sequence)"
          if (r.position == 'Sequence') continue;
          // Valid ref starts with letter, or digit+space+letter (e.g. "1 Cor", "2 Sam")
          final valid = RegExp(r'^[A-Za-z]|^\d+\s+[A-Za-z]').hasMatch(ref);
          expect(valid, isTrue,
              reason: '${date.toIso8601String()} ${r.position}: "$ref" is malformed');
        }
      }
    });
  });
}
